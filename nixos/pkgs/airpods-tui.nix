{
  lib,
  rustPlatform,
  pkg-config,
  dbus,
  libpulseaudio,
}:
rustPlatform.buildRustPackage {
  pname = "airpods-tui";
  version = "0.3.3-dotfiles.1";

  src = ./airpods-tui;

  cargoDepsName = "airpods-tui-0.3.3";
  cargoHash = "sha256-Buf5wPQ8fPAimMd49rNkgPcA6a6rYsagFZ62E8bzpzw=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    dbus
    libpulseaudio
  ];

  nativeCheckInputs = [ dbus ];

  postPatch = ''
    substituteInPlace src/bluez_tests.rs \
      --replace-fail '"--session",' '"--config-file=${dbus}/share/dbus-1/session.conf",'
  '';

  meta = {
    description = "Terminal UI for managing AirPods on Linux over Bluetooth AACP";
    homepage = "https://github.com/annoyedmilk/airpods-tui";
    license = lib.licenses.gpl3Plus;
    mainProgram = "airpods-tui";
    platforms = lib.platforms.linux;
  };
}
