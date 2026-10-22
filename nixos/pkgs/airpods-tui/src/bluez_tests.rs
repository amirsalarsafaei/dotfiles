//! Private-bus regressions: no real BlueZ service or Bluetooth hardware required.
use super::*;
use std::process::Stdio;
use tokio::io::AsyncBufReadExt;

const DEVICE_PATH: &str = "/org/bluez/hci1/dev_AA_BB_CC_DD_EE_FF";

pub(crate) struct TestBus {
    _child: tokio::process::Child,
    address: String,
}

impl TestBus {
    pub(crate) async fn start() -> Self {
        let mut child = tokio::process::Command::new("dbus-daemon")
            .args([
                "--session",
                "--nofork",
                "--print-address=1",
                "--address=unix:tmpdir=/tmp",
            ])
            .stdout(Stdio::piped())
            .kill_on_drop(true)
            .spawn()
            .expect("dbus-daemon is required for private-bus tests");
        let mut stdout = tokio::io::BufReader::new(child.stdout.take().unwrap());
        let mut address = String::new();
        tokio::time::timeout(Duration::from_secs(3), stdout.read_line(&mut address))
            .await
            .expect("private bus startup timed out")
            .unwrap();
        assert!(!address.is_empty(), "private bus did not start");
        Self {
            _child: child,
            address: address.trim().to_owned(),
        }
    }

    pub(crate) async fn connection(&self) -> zbus::Connection {
        build_bluez_connection(zbus::connection::Builder::address(self.address.as_str()).unwrap())
            .await
            .unwrap()
    }

    async fn bluez(&self) -> zbus::Connection {
        self.bluez_with_device(TestDevice::default()).await
    }

    async fn bluez_with_device(&self, device: TestDevice) -> zbus::Connection {
        build_bluez_connection(
            zbus::connection::Builder::address(self.address.as_str())
                .unwrap()
                .name("org.bluez")
                .unwrap()
                .serve_at(DEVICE_PATH, device)
                .unwrap(),
        )
        .await
        .unwrap()
    }
}

#[derive(Default)]
struct TestDevice {
    name_started: Arc<tokio::sync::Notify>,
}

#[zbus::interface(name = "org.bluez.Device1")]
impl TestDevice {
    #[zbus(property)]
    fn address(&self) -> &str {
        "AA:BB:CC:DD:EE:FF"
    }

    #[zbus(property)]
    async fn name(&self) -> String {
        self.name_started.notify_one();
        std::future::pending().await
    }

    #[zbus(property, name = "UUIDs")]
    fn uuids(&self) -> Vec<String> {
        vec![AIRPODS_AACP_UUID.into()]
    }
}

async fn emit_change(conn: &zbus::Connection, path: &str, interface: &str) {
    emit_connection_change(conn, path, interface, true).await;
}

async fn emit_connection_change(
    conn: &zbus::Connection,
    path: &str,
    interface: &str,
    connected: bool,
) {
    let changed = HashMap::from([("Connected", zbus::zvariant::Value::from(connected))]);
    conn.emit_signal(
        None::<&str>,
        path,
        "org.freedesktop.DBus.Properties",
        "PropertiesChanged",
        &(interface, changed, Vec::<String>::new()),
    )
    .await
    .unwrap();
}

#[tokio::test]
async fn property_lookup_completes_with_a_saturated_signal_connection() {
    let bus = TestBus::start().await;
    let bluez = bus.bluez().await;
    let signal_conn = bus.connection().await;
    let query_conn = bus.connection().await;
    let mut stream = bluez_properties_stream(&signal_conn, "org.bluez.Device1")
        .await
        .unwrap();

    // Deliberately stop polling past the subscription capacity. A same-socket
    // round trip cannot finish until these signals have been consumed.
    for _ in 0..BLUEZ_SIGNAL_QUEUE * 2 {
        emit_change(&bluez, DEVICE_PATH, "org.bluez.Device1").await;
    }
    // The broker handles this only after the preceding signals from BlueZ,
    // so the reply below cannot overtake the queue-filling traffic.
    bluez
        .call_method(
            Some("org.freedesktop.DBus"),
            "/org/freedesktop/DBus",
            Some("org.freedesktop.DBus"),
            "GetId",
            &(),
        )
        .await
        .unwrap();
    let blocked = tokio::time::timeout(
        Duration::from_millis(200),
        signal_conn.call_method(
            Some("org.freedesktop.DBus"),
            "/org/freedesktop/DBus",
            Some("org.freedesktop.DBus"),
            "GetId",
            &(),
        ),
    )
    .await;
    assert!(blocked.is_err(), "signal queue was not saturated");

    let address = tokio::time::timeout(
        Duration::from_secs(2),
        zbus_get_property::<String>(&query_conn, DEVICE_PATH, "org.bluez.Device1", "Address"),
    )
    .await
    .expect("separate query connection must keep receiving replies");
    assert_eq!(address.as_deref(), Some("AA:BB:CC:DD:EE:FF"));

    // Draining recovers the signal connection, and its stream contains only
    // signals, never the GetId reply from the intentionally blocked call.
    tokio::time::timeout(Duration::from_secs(2), async {
        for _ in 0..BLUEZ_SIGNAL_QUEUE * 2 {
            let msg = stream.next().await.unwrap().unwrap();
            assert_eq!(msg.message_type(), zbus::message::Type::Signal);
        }
    })
    .await
    .unwrap();
}

#[tokio::test]
async fn subscriptions_exclude_other_senders_paths_and_interfaces() {
    let bus = TestBus::start().await;
    let bluez = bus.bluez().await;
    let unrelated = bus.connection().await;
    let signal_conn = bus.connection().await;
    let mut devices = bluez_properties_stream(&signal_conn, "org.bluez.Device1")
        .await
        .unwrap();
    let mut volumes = bluez_properties_stream(&signal_conn, "org.bluez.MediaTransport1")
        .await
        .unwrap();

    emit_change(&unrelated, DEVICE_PATH, "org.bluez.Device1").await;
    emit_change(&bluez, "/org/other/device", "org.bluez.Device1").await;
    emit_change(&bluez, DEVICE_PATH, "org.bluez.Adapter1").await;
    emit_change(&bluez, DEVICE_PATH, "org.bluez.MediaTransport1").await;
    emit_change(&bluez, DEVICE_PATH, "org.bluez.Device1").await;

    for (stream, expected) in [
        (&mut devices, "org.bluez.Device1"),
        (&mut volumes, "org.bluez.MediaTransport1"),
    ] {
        let msg = tokio::time::timeout(Duration::from_secs(2), stream.next())
            .await
            .unwrap()
            .unwrap()
            .unwrap();
        assert_eq!(
            msg.header().sender().map(|name| name.as_str()),
            bluez.unique_name().map(|name| name.as_str())
        );
        assert_eq!(msg.header().path().unwrap().as_str(), DEVICE_PATH);
        let (interface, _, _) = msg
            .body()
            .deserialize::<(
                String,
                HashMap<String, zbus::zvariant::OwnedValue>,
                Vec<String>,
            )>()
            .unwrap();
        assert_eq!(interface, expected);
        assert!(
            tokio::time::timeout(Duration::from_millis(50), stream.next())
                .await
                .is_err()
        );
    }
}

#[tokio::test]
async fn unresponsive_property_is_bounded_by_method_timeout() {
    let bus = TestBus::start().await;
    let _bluez = bus.bluez().await;
    let conn = bus.connection().await;
    assert_eq!(conn.method_timeout(), Some(DBUS_METHOD_TIMEOUT));
    let name = tokio::time::timeout(
        DBUS_METHOD_TIMEOUT + Duration::from_secs(2),
        zbus_get_property::<String>(&conn, DEVICE_PATH, "org.bluez.Device1", "Name"),
    )
    .await
    .expect("property call must stop at the configured timeout");
    assert!(name.is_none());
}

fn listener_context() -> (
    AirPodsInitContext,
    tokio::sync::mpsc::UnboundedReceiver<AppEvent>,
) {
    let (app_tx, app_rx) = unbounded_channel();
    let (reconnect_tx, _) = unbounded_channel();
    (
        AirPodsInitContext {
            app_tx,
            device_managers: Arc::new(RwLock::new(HashMap::new())),
            config: config::Config::default(),
            reconnect_tx,
        },
        app_rx,
    )
}

#[tokio::test]
async fn listener_drains_connect_storm_and_disconnect_while_property_is_stalled() {
    let mut bus = TestBus::start().await;
    let name_started = Arc::new(tokio::sync::Notify::new());
    let bluez = bus
        .bluez_with_device(TestDevice {
            name_started: name_started.clone(),
        })
        .await;
    let signal_conn = bus.connection().await;
    let query_conn = bus.connection().await;
    let stream = bluez_properties_stream(&signal_conn, "org.bluez.Device1")
        .await
        .unwrap();
    let (ctx, mut events) = listener_context();
    let listener = tokio::spawn(handle_bluez_connections(
        stream,
        query_conn,
        HashMap::new(),
        ctx,
    ));

    emit_change(&bluez, DEVICE_PATH, "org.bluez.Device1").await;
    tokio::time::timeout(Duration::from_secs(2), name_started.notified())
        .await
        .expect("lookup did not reach the stalled property");
    for _ in 0..BLUEZ_SIGNAL_QUEUE * 2 {
        emit_change(&bluez, DEVICE_PATH, "org.bluez.Device1").await;
    }
    emit_connection_change(&bluez, DEVICE_PATH, "org.bluez.Device1", false).await;
    let event = tokio::time::timeout(Duration::from_secs(2), events.recv())
        .await
        .expect("disconnect was blocked behind a property lookup");
    assert!(matches!(event, Some(AppEvent::DeviceDisconnected(mac)) if mac == "AA:BB:CC:DD:EE:FF"));

    // A dead bus must propagate an error to bluetooth_main and exit nonzero,
    // allowing the existing Restart=on-failure service policy to recover.
    bus._child.kill().await.unwrap();
    let result = tokio::time::timeout(Duration::from_secs(2), listener)
        .await
        .expect("listener did not stop after bus failure")
        .unwrap();
    assert!(result.map_err(bluetooth_dbus_error).is_err());
}

#[tokio::test]
async fn listener_eof_and_stream_error_are_failures() {
    let bus = TestBus::start().await;
    let conn = bus.connection().await;
    let (ctx, _) = listener_context();
    let eof = handle_bluez_connections(
        futures::stream::empty(),
        conn.clone(),
        HashMap::new(),
        ctx.clone(),
    )
    .await;
    assert!(eof.is_err());
    let error = handle_bluez_connections(
        futures::stream::iter([Err(zbus::Error::Failure("broken stream".into()))]),
        conn,
        HashMap::new(),
        ctx,
    )
    .await;
    assert!(matches!(error, Err(zbus::Error::Failure(message)) if message == "broken stream"));
}

#[test]
fn missing_properties_are_quiet_but_timeouts_warn() {
    for error in [
        zbus::fdo::Error::UnknownObject("removed".into()),
        zbus::fdo::Error::UnknownInterface("removed".into()),
        zbus::fdo::Error::UnknownProperty("unsupported".into()),
        zbus::fdo::Error::UnknownMethod("removed".into()),
    ] {
        assert_eq!(property_error_level(&error.into()), log::Level::Debug);
    }
    let timeout: zbus::Error = io::Error::new(io::ErrorKind::TimedOut, "no reply").into();
    assert_eq!(property_error_level(&timeout), log::Level::Warn);
    assert_eq!(
        property_error_level(&zbus::fdo::Error::NoReply("no reply".into()).into()),
        log::Level::Warn
    );
}

/// The synthetic errors above are only useful if they match what a live peer
/// actually returns, so classify an error straight off the bus as well.
#[tokio::test]
async fn a_removed_object_is_classified_from_a_live_error() {
    let bus = TestBus::start().await;
    let _bluez = bus.bluez().await;
    let conn = bus.connection().await;

    let error = zbus::proxy::Builder::<'_, zbus::Proxy<'_>>::new(&conn)
        .destination("org.bluez")
        .unwrap()
        .path("/org/bluez/hci1/dev_00_00_00_00_00_00")
        .unwrap()
        .interface("org.bluez.Device1")
        .unwrap()
        .cache_properties(zbus::proxy::CacheProperties::No)
        .build()
        .await
        .unwrap()
        .get_property::<String>("Address")
        .await
        .expect_err("a removed object must not answer");
    assert_eq!(property_error_level(&error), log::Level::Debug);

    assert!(
        zbus_get_property::<String>(
            &conn,
            "/org/bluez/hci1/dev_00_00_00_00_00_00",
            "org.bluez.Device1",
            "Address",
        )
        .await
        .is_none()
    );
}

#[test]
fn device_path_supplies_address_even_after_object_removal() {
    assert_eq!(
        address_from_bluez_path(DEVICE_PATH).unwrap().to_string(),
        "AA:BB:CC:DD:EE:FF"
    );
    for path in [
        "/org/bluez/hci1",
        "/org/other/hci1/dev_AA_BB_CC_DD_EE_FF",
        "/org/bluez/hci1/dev_invalid",
        "/org/bluez/hci1/dev_AA_BB_CC_DD_EE_FF/sep1",
    ] {
        assert!(address_from_bluez_path(path).is_none());
    }
}
