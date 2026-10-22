use crate::bluetooth::aacp::ControlCommandIdentifiers;
use crate::devices::enums::AirPodsNoiseControlMode;
use crate::tui::app::{App, DeviceState, FocusedSection, SettingsItem};
use crossterm::event::{Event, KeyCode, KeyEvent, KeyModifiers};

pub fn handle_key(app: &mut App, key: KeyEvent) {
    // Rename mode intercepts all keys
    if app.rename_mode.is_some() {
        handle_rename_key(app, key);
        return;
    }

    // The settings list changes shape as the device reports capabilities and
    // as the listening mode changes, so the cursor is checked against the
    // current list before it is used, not only when a section takes focus.
    normalize_row(app);

    match key.code {
        // Quit
        KeyCode::Char('q') => app.should_quit = true,
        KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.should_quit = true;
        }

        // Tab / Shift+Tab: cycle focused section
        KeyCode::Tab if has_settings(app) => {
            app.focused_section = app.focused_section.next();
            enter_section(app);
        }
        KeyCode::BackTab if has_settings(app) => {
            app.focused_section = app.focused_section.prev();
            enter_section(app);
        }

        // Up/Down: navigate within current section
        KeyCode::Up | KeyCode::Char('k') => move_row(app, -1),
        KeyCode::Down | KeyCode::Char('j') => move_row(app, 1),
        KeyCode::Char('l') | KeyCode::Char('p') => {
            if let Some(mac) = app.selected_mac()
                && let Some(tx) = &app.command_tx
            {
                let command = if key.code == KeyCode::Char('l') {
                    crate::tui::app::DeviceCommand::UseLaptop
                } else {
                    crate::tui::app::DeviceCommand::Release
                };
                let _ = tx.send((mac.clone(), command));
            }
        }

        // Left/Right: adjust the focused row in Settings, switch device tab otherwise
        KeyCode::Left => {
            if app.effective_section() == FocusedSection::Settings {
                adjust_settings_item(app, -1);
            } else if app.selected_device_idx > 0 {
                app.selected_device_idx -= 1;
                app.focused_section = FocusedSection::NoiseControl;
                enter_section(app);
            }
        }
        KeyCode::Right => {
            if app.effective_section() == FocusedSection::Settings {
                adjust_settings_item(app, 1);
            } else if app.selected_device_idx + 1 < app.device_order.len() {
                app.selected_device_idx += 1;
                app.focused_section = FocusedSection::NoiseControl;
                enter_section(app);
            }
        }

        // Direct noise mode shortcuts: the digit is the row number as drawn,
        // so they stay aligned with the list whatever the model supports.
        KeyCode::Char(c @ '1'..='9') => {
            let row = c as usize - '1' as usize;
            select_noise_row(app, row);
        }

        // Toggle conversation awareness directly
        KeyCode::Char('c') => toggle_conversation_awareness(app),

        // Space/Enter - activate the focused row
        KeyCode::Char(' ') | KeyCode::Enter => activate_row(app),

        // Device info popup
        KeyCode::Char('i') => app.show_info = !app.show_info,

        // Enter rename mode
        KeyCode::Char('r') => {
            if let Some(DeviceState::AirPods(s)) = app.selected_device() {
                app.rename_mode = Some(s.name.clone());
            }
        }

        _ => {}
    }
}

fn handle_rename_key(app: &mut App, key: KeyEvent) {
    let Some(ref mut buf) = app.rename_mode else {
        return;
    };
    match key.code {
        KeyCode::Enter => {
            let new_name = buf.clone();
            if let Some(mac) = app.selected_mac().cloned() {
                if let Some(DeviceState::AirPods(s)) = app.devices.get_mut(&mac) {
                    s.name = new_name.clone();
                }
                app.send_rename(&mac, new_name);
            }
            app.rename_mode = None;
        }
        KeyCode::Esc => {
            app.rename_mode = None;
        }
        KeyCode::Backspace => {
            buf.pop();
        }
        KeyCode::Char(c) if buf.len() < 32 => {
            buf.push(c);
        }
        _ => {}
    }
}

fn has_settings(app: &App) -> bool {
    matches!(app.selected_device(), Some(DeviceState::AirPods(s)) if s.has_anc)
}

/// Pull the cursor back onto a row that exists and does something.
fn normalize_row(app: &mut App) {
    match app.effective_section() {
        FocusedSection::Settings => {
            let items = app.settings_items();
            if items.is_empty() {
                app.section_row = 0;
                return;
            }
            app.section_row = app.section_row.min(items.len() - 1);
            if matches!(items[app.section_row], SettingsItem::Header(_)) {
                // A header is never a destination: prefer the row under it,
                // falling back to the first real row when it is the last one.
                app.section_row = next_selectable_or(&items, app.section_row, 1);
            }
        }
        FocusedSection::NoiseControl => clamp_noise_row(app),
    }
}

/// Move the cursor by `dir` within the focused section, clamped to its rows.
/// In Settings the group headers are stepped over, so the cursor only ever
/// lands somewhere that does something.
fn move_row(app: &mut App, dir: i64) {
    if app.effective_section() == FocusedSection::Settings {
        let items = app.settings_items();
        app.section_row = next_selectable(&items, app.section_row, dir);
        return;
    }
    let max = app.noise_control_rows().saturating_sub(1);
    app.section_row = app.section_row.saturating_add_signed(dir as isize).min(max);
}

/// Like `next_selectable`, but when nothing follows in that direction it falls
/// back to the first real row rather than staying put on a header.
fn next_selectable_or(items: &[SettingsItem], from: usize, dir: i64) -> usize {
    let next = next_selectable(items, from, dir);
    if matches!(items[next], SettingsItem::Header(_)) {
        first_selectable(items)
    } else {
        next
    }
}

/// The next row in direction `dir` that is not a header, or `from` when there
/// is none, which keeps the cursor still at either end of the list.
fn next_selectable(items: &[SettingsItem], from: usize, dir: i64) -> usize {
    let mut row = from;
    loop {
        let Some(next) = row.checked_add_signed(dir as isize) else {
            return from;
        };
        if next >= items.len() {
            return from;
        }
        row = next;
        if !matches!(items[row], SettingsItem::Header(_)) {
            return row;
        }
    }
}

/// Keep the Noise Control cursor inside the list after the Off row appears or
/// disappears.
fn clamp_noise_row(app: &mut App) {
    let rows = app.noise_control_rows();
    if app.section_row >= rows {
        app.section_row = rows.saturating_sub(1);
    }
}

/// The first row that is not a header. Settings always opens on a real row.
fn first_selectable(items: &[SettingsItem]) -> usize {
    items
        .iter()
        .position(|i| !matches!(i, SettingsItem::Header(_)))
        .unwrap_or(0)
}

/// Place the cursor sensibly for the section that just took focus.
fn enter_section(app: &mut App) {
    app.section_row = match app.effective_section() {
        FocusedSection::Settings => first_selectable(&app.settings_items()),
        FocusedSection::NoiseControl => 0,
    };
}

fn current_settings_item(app: &App) -> Option<SettingsItem> {
    let items = app.settings_items();
    items.into_iter().nth(app.section_row)
}

/// Left/Right on a settings row: `dir` is -1 or 1.
fn adjust_settings_item(app: &mut App, dir: i8) {
    let Some(item) = current_settings_item(app) else {
        return;
    };
    match item {
        SettingsItem::Header(_) => {}
        SettingsItem::Slider {
            value,
            min,
            max,
            cmd,
            ..
        } => {
            let new_val = if dir < 0 {
                value.saturating_sub(5).max(min)
            } else {
                (value + 5).min(max)
            };
            send_setting(app, cmd, new_val);
        }
        SettingsItem::Enum {
            value,
            options,
            cmd,
            ..
        } => {
            if dir < 0 {
                if value > 0 {
                    send_setting(app, cmd, value - 1);
                }
            } else {
                let max_idx = (options.len() as u8).saturating_sub(1);
                if value < max_idx {
                    send_setting(app, cmd, value + 1);
                }
            }
        }
        SettingsItem::HoldMode { right, value, .. } => {
            let new_idx = if dir < 0 { 0 } else { 1 };
            if new_idx != value {
                set_hold_mode(app, right, new_idx);
            }
        }
        SettingsItem::CycleBit { bit, value, .. } => {
            // Left removes the mode from the cycle, Right adds it.
            let enable = dir > 0;
            if enable != value {
                toggle_cycle_bit(app, bit);
            }
        }
        SettingsItem::SinglePod { value, .. } => {
            // Left turns it off, Right on, like the hold-cycle rows.
            let enable = dir > 0;
            if enable != value {
                set_single_pod(app, enable);
            }
        }
        SettingsItem::Toggle { .. } => {}
    }
}

/// Switch the daemon's one-pod setting for the selected device. Shown at once;
/// the daemon echoes the stored value back.
fn set_single_pod(app: &mut App, on: bool) {
    let Some(mac) = app.selected_mac().cloned() else {
        return;
    };
    if let Some(DeviceState::AirPods(s)) = app.devices.get_mut(&mac) {
        s.single_pod = Some(on);
    }
    app.send_single_pod(&mac, on);
}

/// Update one bud's press-and-hold action and send both buds' wire bytes
/// (ClickHoldMode is a two-byte command: [right, left]).
fn set_hold_mode(app: &mut App, right: bool, idx: u8) {
    let Some(mac) = app.selected_mac().cloned() else {
        return;
    };
    let wire = crate::tui::app::hold_idx_to_wire(idx);
    let (right_wire, left_wire) = {
        let Some(DeviceState::AirPods(s)) = app.devices.get_mut(&mac) else {
            return;
        };
        if right {
            s.hold_right = Some(wire);
        } else {
            s.hold_left = Some(wire);
        }
        (s.hold_right.unwrap_or(0x01), s.hold_left.unwrap_or(0x01))
    };
    app.send_command(
        &mac,
        ControlCommandIdentifiers::ClickHoldMode,
        vec![right_wire, left_wire],
    );
}

/// Toggle one mode's membership in the long-press noise cycle.
fn toggle_cycle_bit(app: &mut App, bit: u8) {
    let Some(mac) = app.selected_mac().cloned() else {
        return;
    };
    let new_mask = {
        let Some(DeviceState::AirPods(s)) = app.devices.get_mut(&mac) else {
            return;
        };
        let Some(mask) = s.listening_mode_configs else {
            return;
        };
        let new_mask = mask ^ bit;
        // The device needs at least two modes to cycle between.
        if new_mask.count_ones() < 2 {
            return;
        }
        s.listening_mode_configs = Some(new_mask);
        new_mask
    };
    app.send_command(
        &mac,
        ControlCommandIdentifiers::ListeningModeConfigs,
        vec![new_mask],
    );
}

fn send_setting(app: &mut App, cmd: ControlCommandIdentifiers, value: u8) {
    let Some(mac) = app.selected_mac().cloned() else {
        return;
    };
    // Update local state
    if let Some(DeviceState::AirPods(state)) = app.devices.get_mut(&mac) {
        match cmd {
            ControlCommandIdentifiers::DoubleClickInterval => state.press_speed = Some(value),
            ControlCommandIdentifiers::ClickHoldInterval => state.press_hold_duration = Some(value),
            ControlCommandIdentifiers::ChimeVolume => state.tone_volume = Some(value),
            ControlCommandIdentifiers::VolumeSwipeInterval => {
                state.volume_swipe_length = Some(value)
            }
            ControlCommandIdentifiers::AutoAncStrength => state.adaptive_noise_level = Some(value),
            ControlCommandIdentifiers::MicMode => state.mic_mode = Some(value),
            ControlCommandIdentifiers::InCaseToneVolume => state.in_case_tone_volume = Some(value),
            ControlCommandIdentifiers::CrownRotationDirection => {
                state.crown_reversed = Some(value == 1)
            }
            _ => {}
        }
    }
    let wire_value = match cmd {
        // Crown: UI 0 = Default (wire 0x02), UI 1 = Reversed (wire 0x01)
        ControlCommandIdentifiers::CrownRotationDirection => {
            if value == 1 {
                0x01
            } else {
                0x02
            }
        }
        _ => value,
    };
    app.send_command(&mac, cmd, vec![wire_value]);
}

fn set_noise_mode(app: &mut App, mode: AirPodsNoiseControlMode) {
    let Some(mac) = app.selected_mac().cloned() else {
        return;
    };
    match app.devices.get_mut(&mac) {
        Some(DeviceState::AirPods(state)) if state.has_anc => {
            state.listening_mode = mode.clone();
        }
        _ => return,
    }
    app.send_command(
        &mac,
        ControlCommandIdentifiers::ListeningMode,
        vec![mode.to_byte()],
    );
}

fn toggle_conversation_awareness(app: &mut App) {
    let Some(mac) = app.selected_mac().cloned() else {
        return;
    };
    let new_val = match app.devices.get(&mac) {
        Some(DeviceState::AirPods(s))
            if s.has_anc
                && crate::devices::apple_models::model_info(s.product_id)
                    .has_conversation_awareness =>
        {
            !s.conversation_awareness
        }
        _ => return,
    };
    if let Some(DeviceState::AirPods(s)) = app.devices.get_mut(&mac) {
        s.conversation_awareness = new_val;
    }
    app.send_command(
        &mac,
        ControlCommandIdentifiers::ConversationDetectConfig,
        vec![if new_val { 0x01 } else { 0x02 }],
    );
}

fn activate_row(app: &mut App) {
    match app.effective_section() {
        FocusedSection::NoiseControl => activate_noise_row(app),
        FocusedSection::Settings => activate_settings_row(app),
    }
}

/// Apply the noise mode drawn at `row` of the noise-control list, if that row exists.
fn select_noise_row(app: &mut App, row: usize) {
    let (has_anc, has_adaptive, allow_off) = match app.selected_device() {
        Some(DeviceState::AirPods(s)) => (s.has_anc, s.has_adaptive, s.allow_off_mode),
        _ => return,
    };
    if !has_anc {
        return;
    }
    if let Some(mode) = crate::tui::ui::noise_mode_list(has_adaptive, allow_off)
        .into_iter()
        .nth(row)
    {
        set_noise_mode(app, mode);
    }
}

fn activate_noise_row(app: &mut App) {
    select_noise_row(app, app.section_row);
}

fn activate_settings_row(app: &mut App) {
    let Some(item) = current_settings_item(app) else {
        return;
    };
    let Some(mac) = app.selected_mac().cloned() else {
        return;
    };

    match item {
        SettingsItem::Header(_) => {}
        SettingsItem::Toggle { value, cmd, .. } => {
            let new_val = !value;
            // Update local state
            if let Some(DeviceState::AirPods(state)) = app.devices.get_mut(&mac) {
                match cmd {
                    ControlCommandIdentifiers::ConversationDetectConfig => {
                        state.conversation_awareness = new_val
                    }
                    ControlCommandIdentifiers::OneBudAncMode => state.one_bud_anc = new_val,
                    ControlCommandIdentifiers::AdaptiveVolumeConfig => {
                        state.adaptive_volume = new_val
                    }
                    ControlCommandIdentifiers::VolumeSwipeMode => state.volume_swipe = new_val,
                    ControlCommandIdentifiers::AllowAutoConnect => {
                        state.auto_connect = Some(new_val)
                    }
                    ControlCommandIdentifiers::EarDetectionConfig => {
                        state.ear_detection_enabled = Some(new_val)
                    }
                    ControlCommandIdentifiers::SleepDetectionConfig => {
                        state.sleep_detection = Some(new_val)
                    }
                    ControlCommandIdentifiers::InCaseToneConfig => {
                        state.in_case_tone = Some(new_val)
                    }
                    // Adds or removes the Off row in Noise Control, so the
                    // cursor there can end up past the end.
                    ControlCommandIdentifiers::AllowOffOption => state.allow_off_mode = new_val,
                    _ => {}
                }
            }
            // All AACP toggle commands use 0x01 = enabled, 0x02 = disabled
            let byte: u8 = if new_val { 0x01 } else { 0x02 };
            app.send_command(&mac, cmd, vec![byte]);
            if cmd == ControlCommandIdentifiers::AllowOffOption {
                clamp_noise_row(app);
            }
        }
        SettingsItem::Enum {
            value,
            options,
            cmd,
            ..
        } => {
            let next = if (value as usize + 1) < options.len() {
                value + 1
            } else {
                0
            };
            send_setting(app, cmd, next);
        }
        SettingsItem::CycleBit { bit, .. } => toggle_cycle_bit(app, bit),
        SettingsItem::SinglePod { value, .. } => set_single_pod(app, !value),
        SettingsItem::HoldMode { right, value, .. } => set_hold_mode(app, right, 1 - value),
        SettingsItem::Slider { .. } => {
            // Sliders are adjusted with Left/Right.
        }
    }
}

pub fn handle_event(app: &mut App, event: Event) {
    if let Event::Key(key) = event {
        handle_key(app, key);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tui::app::{AppEvent, DeviceCommand};
    use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
    use tokio::sync::mpsc::{self, UnboundedReceiver};

    const MAC_A: &str = "AA:BB:CC:DD:EE:FF";
    const MAC_B: &str = "11:22:33:44:55:66";
    const PRO2: u16 = 0x2014;
    const AIRPODS3: u16 = 0x2013; // no ANC

    fn key(code: KeyCode) -> KeyEvent {
        KeyEvent::new(code, KeyModifiers::NONE)
    }

    fn key_mod(code: KeyCode, mods: KeyModifiers) -> KeyEvent {
        KeyEvent::new(code, mods)
    }

    /// Put the cursor on the settings row with this label. Tests address rows
    /// by name so that regrouping them does not silently retarget the test.
    fn focus_row(app: &mut App, label: &str) {
        let row = app
            .settings_items()
            .iter()
            .position(|item| settings_label(item) == Some(label))
            .unwrap_or_else(|| panic!("no settings row labelled {label}"));
        app.section_row = row;
    }

    fn settings_label(item: &SettingsItem) -> Option<&'static str> {
        match item {
            SettingsItem::Header(_) => None,
            SettingsItem::Toggle { label, .. }
            | SettingsItem::Enum { label, .. }
            | SettingsItem::Slider { label, .. }
            | SettingsItem::CycleBit { label, .. }
            | SettingsItem::SinglePod { label, .. }
            | SettingsItem::HoldMode { label, .. } => Some(label),
        }
    }

    fn mk_app(product_id: u16) -> (App, UnboundedReceiver<(String, DeviceCommand)>) {
        let (_etx, erx) = mpsc::unbounded_channel::<AppEvent>();
        let (ctx, crx) = mpsc::unbounded_channel();
        let mut app = App::new(erx, ctx);
        app.handle_event(AppEvent::DeviceConnected {
            mac: MAC_A.into(),
            name: "Pods".into(),
            product_id,
        });
        (app, crx)
    }

    #[test]
    fn q_quits() {
        let (mut app, _) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Char('q')));
        assert!(app.should_quit);
    }

    #[test]
    fn manual_route_keys_send_only_explicit_commands() {
        let (mut app, mut commands) = mk_app(PRO2);
        assert!(commands.try_recv().is_err());
        handle_key(&mut app, key(KeyCode::Char('l')));
        assert!(
            matches!(commands.try_recv().unwrap(), (mac, DeviceCommand::UseLaptop) if mac == MAC_A)
        );
        handle_key(&mut app, key(KeyCode::Char('p')));
        assert!(
            matches!(commands.try_recv().unwrap(), (mac, DeviceCommand::Release) if mac == MAC_A)
        );
    }

    #[test]
    fn vim_navigation_moves_selection_without_sending_device_commands() {
        let (mut app, mut commands) = mk_app(PRO2);
        assert_eq!(app.section_row, 0);
        handle_key(&mut app, key(KeyCode::Char('j')));
        assert_eq!(app.section_row, 1);
        handle_key(&mut app, key(KeyCode::Char('k')));
        assert_eq!(app.section_row, 0);
        assert!(commands.try_recv().is_err());
    }

    #[test]
    fn ctrl_c_quits() {
        let (mut app, _) = mk_app(PRO2);
        handle_key(&mut app, key_mod(KeyCode::Char('c'), KeyModifiers::CONTROL));
        assert!(app.should_quit);
    }

    #[test]
    fn lone_c_toggles_conversation_awareness_and_sends_byte_01() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Char('c')));
        let s = match app.devices.get(MAC_A) {
            Some(DeviceState::AirPods(s)) => s,
            _ => panic!(),
        };
        assert!(s.conversation_awareness);
        let (mac, cmd) = cmd_rx.try_recv().expect("command sent");
        assert_eq!(mac, MAC_A);
        match cmd {
            DeviceCommand::ControlCommand(id, val) => {
                assert_eq!(id, ControlCommandIdentifiers::ConversationDetectConfig);
                assert_eq!(val, vec![0x01]); // enable
            }
            _ => panic!(),
        }
    }

    #[test]
    fn tab_cycles_section_when_anc_capable() {
        let (mut app, _) = mk_app(PRO2);
        assert_eq!(app.focused_section, FocusedSection::NoiseControl);
        handle_key(&mut app, key(KeyCode::Tab));
        assert_eq!(app.focused_section, FocusedSection::Settings);
        handle_key(&mut app, key(KeyCode::Tab));
        assert_eq!(app.focused_section, FocusedSection::NoiseControl);
    }

    #[test]
    fn tab_noop_without_anc() {
        let (mut app, _) = mk_app(AIRPODS3);
        let before = app.focused_section;
        handle_key(&mut app, key(KeyCode::Tab));
        assert_eq!(app.focused_section, before);
    }

    #[test]
    fn noise_shortcuts_noop_without_anc() {
        let (mut app, mut cmd_rx) = mk_app(AIRPODS3);
        handle_key(&mut app, key(KeyCode::Char('1')));
        handle_key(&mut app, key(KeyCode::Char('2')));
        assert!(cmd_rx.try_recv().is_err());
    }

    #[test]
    fn ca_toggle_noop_without_conversation_awareness() {
        // AirPods Pro 1: ANC yes, Conversation Awareness no.
        let (mut app, mut cmd_rx) = mk_app(0x200e);
        handle_key(&mut app, key(KeyCode::Char('c')));
        assert!(cmd_rx.try_recv().is_err());
    }

    #[test]
    fn non_anc_device_falls_through_to_settings() {
        let (mut app, mut cmd_rx) = mk_app(AIRPODS3);
        // Without noise control rows, Space acts on the Settings section.
        assert_eq!(app.effective_section(), FocusedSection::Settings);
        handle_key(&mut app, key(KeyCode::Char(' ')));
        let (_, cmd) = cmd_rx.try_recv().expect("settings toggle sent");
        match cmd {
            DeviceCommand::ControlCommand(id, _) => {
                // The cursor starts under the first heading, Audio & Routing,
                // whose first row for a non-ANC model is Personalized Volume.
                assert_eq!(id, ControlCommandIdentifiers::AdaptiveVolumeConfig);
            }
            _ => panic!(),
        }
    }

    #[test]
    fn non_anc_device_down_clamps_to_settings_rows() {
        let (mut app, _) = mk_app(AIRPODS3);
        let max = app.settings_items().len() - 1;
        for _ in 0..20 {
            handle_key(&mut app, key(KeyCode::Down));
        }
        assert_eq!(app.section_row, max);
    }

    #[test]
    fn down_clamps_to_max_row() {
        let (mut app, _) = mk_app(PRO2);
        // NoiseControl rows = 3 → max idx 2
        for _ in 0..10 {
            handle_key(&mut app, key(KeyCode::Down));
        }
        assert_eq!(app.section_row, 2);
    }

    #[test]
    fn up_clamps_to_zero() {
        let (mut app, _) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Up));
        assert_eq!(app.section_row, 0);
    }

    #[test]
    fn left_right_switches_devices_in_noise_control() {
        let (mut app, _) = mk_app(PRO2);
        app.handle_event(AppEvent::DeviceConnected {
            mac: MAC_B.into(),
            name: "Pods 2".into(),
            product_id: PRO2,
        });
        assert_eq!(app.selected_device_idx, 0);
        handle_key(&mut app, key(KeyCode::Right));
        assert_eq!(app.selected_device_idx, 1);
        handle_key(&mut app, key(KeyCode::Left));
        assert_eq!(app.selected_device_idx, 0);
        // Left at index 0 stays at 0
        handle_key(&mut app, key(KeyCode::Left));
        assert_eq!(app.selected_device_idx, 0);
    }

    #[test]
    fn key_1_sets_transparency() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Char('1')));
        let (_, cmd) = cmd_rx.try_recv().unwrap();
        match cmd {
            DeviceCommand::ControlCommand(id, val) => {
                assert_eq!(id, ControlCommandIdentifiers::ListeningMode);
                assert_eq!(val, vec![AirPodsNoiseControlMode::Transparency.to_byte()]);
            }
            _ => panic!(),
        }
    }

    #[test]
    fn key_2_picks_adaptive_when_supported() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Char('2')));
        let (_, cmd) = cmd_rx.try_recv().unwrap();
        match cmd {
            DeviceCommand::ControlCommand(_, val) => {
                assert_eq!(val, vec![AirPodsNoiseControlMode::Adaptive.to_byte()]);
            }
            _ => panic!(),
        }
    }

    #[test]
    fn key_2_falls_back_to_nc_when_no_adaptive() {
        let (mut app, mut cmd_rx) = mk_app(0x200e); // AirPods Pro (no adaptive)
        handle_key(&mut app, key(KeyCode::Char('2')));
        let (_, cmd) = cmd_rx.try_recv().unwrap();
        match cmd {
            DeviceCommand::ControlCommand(_, val) => {
                assert_eq!(
                    val,
                    vec![AirPodsNoiseControlMode::NoiseCancellation.to_byte()]
                );
            }
            _ => panic!(),
        }
    }

    #[test]
    fn key_3_sets_nc_only_when_adaptive_capable() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Char('3')));
        let (_, cmd) = cmd_rx.try_recv().unwrap();
        match cmd {
            DeviceCommand::ControlCommand(_, val) => {
                assert_eq!(
                    val,
                    vec![AirPodsNoiseControlMode::NoiseCancellation.to_byte()]
                );
            }
            _ => panic!(),
        }
    }

    /// Regression: the digits index the list as drawn, so "Off" is reachable
    /// and no digit lands on a different row than the one it names.
    #[test]
    fn digits_follow_the_rows_as_drawn() {
        for (product_id, allow_off) in [(PRO2, true), (PRO2, false), (0x200e, true)] {
            let (mut app, mut cmd_rx) = mk_app(product_id);
            if allow_off {
                app.handle_event(AppEvent::AACPEvent(
                    MAC_A.into(),
                    Box::new(crate::bluetooth::aacp::AACPEvent::ControlCommand(
                        crate::bluetooth::aacp::ControlCommandStatus {
                            identifier: ControlCommandIdentifiers::AllowOffOption,
                            value: vec![0x01],
                        },
                    )),
                ));
            }
            let (has_adaptive, allow_off_mode) = match app.selected_device() {
                Some(DeviceState::AirPods(s)) => (s.has_adaptive, s.allow_off_mode),
                _ => panic!("no device"),
            };
            assert_eq!(allow_off_mode, allow_off);
            let rows = crate::tui::ui::noise_mode_list(has_adaptive, allow_off_mode);

            for (idx, mode) in rows.iter().enumerate() {
                let digit = char::from_digit(idx as u32 + 1, 10).unwrap();
                handle_key(&mut app, key(KeyCode::Char(digit)));
                let (_, cmd) = cmd_rx
                    .try_recv()
                    .unwrap_or_else(|_| panic!("key {digit} sent nothing for {rows:?}"));
                match cmd {
                    DeviceCommand::ControlCommand(id, val) => {
                        assert_eq!(id, ControlCommandIdentifiers::ListeningMode);
                        assert_eq!(
                            val,
                            vec![mode.to_byte()],
                            "key {digit} picked the wrong row"
                        );
                    }
                    _ => panic!("unexpected command"),
                }
            }

            // One past the last row must do nothing at all.
            let past = char::from_digit(rows.len() as u32 + 1, 10).unwrap();
            handle_key(&mut app, key(KeyCode::Char(past)));
            assert!(cmd_rx.try_recv().is_err(), "key {past} should be inert");
        }
    }

    #[test]
    fn key_3_does_nothing_when_no_adaptive() {
        let (mut app, mut cmd_rx) = mk_app(0x200e);
        handle_key(&mut app, key(KeyCode::Char('3')));
        assert!(cmd_rx.try_recv().is_err());
    }

    #[test]
    fn enter_in_noise_control_sends_listening_mode() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        // Default rows: [Transparency, Adaptive, NoiseCancellation]; row 0 = Transparency
        handle_key(&mut app, key(KeyCode::Enter));
        let (_, cmd) = cmd_rx.try_recv().unwrap();
        match cmd {
            DeviceCommand::ControlCommand(id, val) => {
                assert_eq!(id, ControlCommandIdentifiers::ListeningMode);
                assert_eq!(val, vec![AirPodsNoiseControlMode::Transparency.to_byte()]);
            }
            _ => panic!(),
        }
    }

    #[test]
    fn space_in_settings_toggles_active_row_to_enabled() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        // Switch to Settings
        handle_key(&mut app, key(KeyCode::Tab));
        // First row for PRO2 is "Conversation Awareness" - toggle on
        handle_key(&mut app, key(KeyCode::Char(' ')));
        let (_, cmd) = cmd_rx.try_recv().unwrap();
        match cmd {
            DeviceCommand::ControlCommand(id, val) => {
                assert_eq!(id, ControlCommandIdentifiers::ConversationDetectConfig);
                assert_eq!(val, vec![0x01]);
            }
            _ => panic!(),
        }
    }

    #[test]
    fn left_in_settings_decrements_slider_within_range() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        // Set tone_volume so we can decrement deterministically
        if let Some(DeviceState::AirPods(s)) = app.devices.get_mut(MAC_A) {
            s.tone_volume = Some(50);
        }
        handle_key(&mut app, key(KeyCode::Tab)); // → Settings
        focus_row(&mut app, "Tone Volume");
        handle_key(&mut app, key(KeyCode::Left));
        let (_, cmd) = cmd_rx.try_recv().expect("slider command");
        match cmd {
            DeviceCommand::ControlCommand(id, val) => {
                assert_eq!(id, ControlCommandIdentifiers::ChimeVolume);
                assert_eq!(val, vec![45]);
            }
            _ => panic!(),
        }
    }

    #[test]
    fn slider_clamps_to_min() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        if let Some(DeviceState::AirPods(s)) = app.devices.get_mut(MAC_A) {
            s.tone_volume = Some(15); // = min
        }
        handle_key(&mut app, key(KeyCode::Tab));
        focus_row(&mut app, "Tone Volume");
        handle_key(&mut app, key(KeyCode::Left));
        let (_, cmd) = cmd_rx.try_recv().unwrap();
        match cmd {
            DeviceCommand::ControlCommand(_, val) => assert_eq!(val, vec![15]),
            _ => panic!(),
        }
    }

    #[test]
    fn slider_clamps_to_max() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        if let Some(DeviceState::AirPods(s)) = app.devices.get_mut(MAC_A) {
            s.tone_volume = Some(98);
        }
        handle_key(&mut app, key(KeyCode::Tab));
        focus_row(&mut app, "Tone Volume");
        handle_key(&mut app, key(KeyCode::Right));
        let (_, cmd) = cmd_rx.try_recv().unwrap();
        match cmd {
            DeviceCommand::ControlCommand(_, val) => assert_eq!(val, vec![100]),
            _ => panic!(),
        }
    }

    #[test]
    fn r_enters_rename_mode_with_current_name() {
        let (mut app, _) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Char('r')));
        assert_eq!(app.rename_mode.as_deref(), Some("Pods"));
    }

    #[test]
    fn rename_mode_buffers_chars_and_commits_on_enter() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Char('r')));
        // Replace existing name: backspace through "Pods" then type new
        for _ in 0..4 {
            handle_key(&mut app, key(KeyCode::Backspace));
        }
        for c in "New".chars() {
            handle_key(&mut app, key(KeyCode::Char(c)));
        }
        handle_key(&mut app, key(KeyCode::Enter));
        assert!(app.rename_mode.is_none());
        let s = match app.devices.get(MAC_A) {
            Some(DeviceState::AirPods(s)) => s,
            _ => panic!(),
        };
        assert_eq!(s.name, "New");
        let (_, cmd) = cmd_rx.try_recv().unwrap();
        assert!(matches!(cmd, DeviceCommand::Rename(ref n) if n == "New"));
    }

    #[test]
    fn rename_mode_esc_discards() {
        let (mut app, _) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Char('r')));
        for c in "X".chars() {
            handle_key(&mut app, key(KeyCode::Char(c)));
        }
        handle_key(&mut app, key(KeyCode::Esc));
        assert!(app.rename_mode.is_none());
        // Name remains the original
        let s = match app.devices.get(MAC_A) {
            Some(DeviceState::AirPods(s)) => s,
            _ => panic!(),
        };
        assert_eq!(s.name, "Pods");
    }

    #[test]
    fn rename_mode_caps_at_32_chars() {
        let (mut app, _) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Char('r')));
        for _ in 0..4 {
            handle_key(&mut app, key(KeyCode::Backspace));
        }
        for _ in 0..40 {
            handle_key(&mut app, key(KeyCode::Char('a')));
        }
        assert_eq!(app.rename_mode.as_deref().unwrap().len(), 32);
    }

    #[test]
    fn mic_mode_setting_writes_wire_value_directly() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        if let Some(DeviceState::AirPods(s)) = app.devices.get_mut(MAC_A) {
            s.mic_mode = Some(0); // Automatic
        }
        handle_key(&mut app, key(KeyCode::Tab));
        let row = app
            .settings_items()
            .iter()
            .position(|i| matches!(i, SettingsItem::Enum { label, .. } if *label == "Microphone"))
            .unwrap();
        app.section_row = row;
        handle_key(&mut app, key(KeyCode::Right));
        let (_, cmd) = cmd_rx.try_recv().expect("mic mode command");
        match cmd {
            DeviceCommand::ControlCommand(id, val) => {
                assert_eq!(id, ControlCommandIdentifiers::MicMode);
                // Option index == wire value: 1 = Always Right (0x01).
                assert_eq!(val, vec![1]);
            }
            _ => panic!(),
        }
    }

    #[test]
    fn cycle_bit_toggle_keeps_at_least_two_modes() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        if let Some(DeviceState::AirPods(s)) = app.devices.get_mut(MAC_A) {
            s.listening_mode_configs = Some(0x06); // NC + Transparency
        }
        handle_key(&mut app, key(KeyCode::Tab)); // → Settings
        let items = app.settings_items();
        let row = items
            .iter()
            .position(
                |i| matches!(i, SettingsItem::CycleBit { label, .. } if *label == "Hold Cycle: Noise Cancellation"),
            )
            .unwrap();
        app.section_row = row;
        // Removing NC would leave only Transparency → must be refused.
        handle_key(&mut app, key(KeyCode::Char(' ')));
        assert!(cmd_rx.try_recv().is_err());
        assert_eq!(
            match app.devices.get(MAC_A) {
                Some(DeviceState::AirPods(s)) => s.listening_mode_configs,
                _ => None,
            },
            Some(0x06)
        );
        // Adding Adaptive is fine: mask 0x06 → 0x0E.
        let row = app
            .settings_items()
            .iter()
            .position(
                |i| matches!(i, SettingsItem::CycleBit { label, .. } if *label == "Hold Cycle: Adaptive"),
            )
            .unwrap();
        app.section_row = row;
        handle_key(&mut app, key(KeyCode::Char(' ')));
        let (_, cmd) = cmd_rx.try_recv().expect("mask sent");
        assert!(matches!(
            cmd,
            DeviceCommand::ControlCommand(ControlCommandIdentifiers::ListeningModeConfigs, ref v)
                if v == &vec![0x0E]
        ));
    }

    #[test]
    fn hold_mode_sends_both_buds_wire_bytes() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        if let Some(DeviceState::AirPods(s)) = app.devices.get_mut(MAC_A) {
            s.hold_left = Some(0x01); // Noise Control
            s.hold_right = Some(0x01);
        }
        let row = app
            .settings_items()
            .iter()
            .position(
                |i| matches!(i, SettingsItem::HoldMode { label, .. } if *label == "Hold Left"),
            )
            .unwrap();
        app.focused_section = FocusedSection::Settings;
        app.section_row = row;
        // Switch left bud to Siri: wire = [right, left] = [0x01, 0x05].
        handle_key(&mut app, key(KeyCode::Char(' ')));
        let (_, cmd) = cmd_rx.try_recv().expect("hold mode sent");
        assert!(matches!(
            cmd,
            DeviceCommand::ControlCommand(ControlCommandIdentifiers::ClickHoldMode, ref v)
                if v == &vec![0x01, 0x05]
        ));
    }

    /// Walking the whole list must never rest on a heading, in either
    /// direction, and must still visit every real row.
    #[test]
    fn navigation_steps_over_group_headings() {
        let (mut app, _) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Tab)); // → Settings
        let items = app.settings_items();
        assert!(
            items.iter().any(|i| matches!(i, SettingsItem::Header(_))),
            "this model should have headings to step over"
        );

        let mut visited = vec![app.section_row];
        for _ in 0..items.len() {
            handle_key(&mut app, key(KeyCode::Down));
            assert!(!matches!(items[app.section_row], SettingsItem::Header(_)));
            visited.push(app.section_row);
        }
        for _ in 0..items.len() {
            handle_key(&mut app, key(KeyCode::Up));
            assert!(!matches!(items[app.section_row], SettingsItem::Header(_)));
            visited.push(app.section_row);
        }

        let selectable = items
            .iter()
            .filter(|i| !matches!(i, SettingsItem::Header(_)))
            .count();
        visited.sort_unstable();
        visited.dedup();
        assert_eq!(visited.len(), selectable, "some rows were unreachable");
    }

    /// Off Listening Mode adds and removes a row in the other section, which
    /// must not leave that section's cursor pointing past the end.
    #[test]
    fn toggling_off_listening_mode_keeps_the_noise_cursor_valid() {
        let (mut app, mut cmd_rx) = mk_app(PRO2);
        if let Some(DeviceState::AirPods(s)) = app.devices.get_mut(MAC_A) {
            s.allow_off_mode = true;
        }
        // Sit on the last noise row, which only exists while Off is allowed.
        handle_key(&mut app, key(KeyCode::Down));
        handle_key(&mut app, key(KeyCode::Down));
        handle_key(&mut app, key(KeyCode::Down));
        assert_eq!(app.section_row, 3);

        handle_key(&mut app, key(KeyCode::Tab)); // → Settings
        focus_row(&mut app, "Off Listening Mode");
        handle_key(&mut app, key(KeyCode::Char(' ')));
        let (_, cmd) = cmd_rx.try_recv().expect("toggle sent");
        assert!(matches!(
            cmd,
            DeviceCommand::ControlCommand(ControlCommandIdentifiers::AllowOffOption, ref v)
                if v == &vec![0x02]
        ));

        handle_key(&mut app, key(KeyCode::BackTab)); // → Noise Control
        assert!(app.section_row < app.noise_control_rows());
    }

    #[test]
    fn up_down_clamp_to_settings_rows() {
        let (mut app, _) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Tab)); // → Settings
        let items = app.settings_items();
        // Settings opens on the first real row, never on a group heading.
        let first = first_selectable(&items);
        assert_eq!(app.section_row, first);
        assert!(!matches!(items[first], SettingsItem::Header(_)));
        // Walk past the end: cursor clamps to the last row.
        for _ in 0..items.len() + 2 {
            handle_key(&mut app, key(KeyCode::Down));
        }
        assert_eq!(app.section_row, items.len() - 1);
        // And back up: clamps to the first row.
        for _ in 0..items.len() + 2 {
            handle_key(&mut app, key(KeyCode::Up));
        }
        assert_eq!(app.section_row, first);
    }

    #[test]
    fn i_toggles_info_overlay() {
        let (mut app, _) = mk_app(PRO2);
        assert!(!app.show_info);
        handle_key(&mut app, key(KeyCode::Char('i')));
        assert!(app.show_info);
        handle_key(&mut app, key(KeyCode::Char('i')));
        assert!(!app.show_info);
    }

    #[test]
    fn unknown_keys_are_ignored() {
        let (mut app, _) = mk_app(PRO2);
        handle_key(&mut app, key(KeyCode::Char('z')));
        handle_key(&mut app, key(KeyCode::Char('9')));
        handle_key(&mut app, key(KeyCode::F(5)));
        assert!(!app.should_quit);
    }
}
