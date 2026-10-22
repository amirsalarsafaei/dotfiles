use crate::bluetooth::aacp::{BatteryStatus, EarDetectionStatus};
use crate::devices::enums::AirPodsNoiseControlMode;
use crate::tui::app::{AirPodsDeviceState, App, DeviceState, FocusedSection, SettingsItem};
use ratatui::{
    Frame,
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Paragraph, Row, Table, TableState},
};

const ACCENT: Color = Color::Indexed(12);
const FOCUS_COLOR: Color = Color::Indexed(14);
const HEADER: Color = Color::Indexed(11);
const FG: Color = Color::Reset;
const DIM: Color = Color::Indexed(8);

static UI_CONFIG: std::sync::LazyLock<crate::config::Config> =
    std::sync::LazyLock::new(crate::config::Config::load);

pub fn draw(f: &mut Frame, app: &App) {
    draw_with_config(f, app, &UI_CONFIG);
}

fn draw_with_config(f: &mut Frame, app: &App, config: &crate::config::Config) {
    let area = f.area();
    if area.width < 20 || area.height < 8 {
        f.render_widget(
            Paragraph::new("AIRPODS\nResize terminal")
                .style(Style::default().fg(ACCENT))
                .alignment(Alignment::Center),
            area,
        );
        return;
    }
    let header = Layout::vertical([Constraint::Length(2), Constraint::Fill(1)]).split(area);
    let policy = if config.automatic_takeover {
        "follow local playback"
    } else {
        "manual switching"
    };
    f.render_widget(
        Paragraph::new(vec![
            Line::from(Span::styled(
                config.tui_title.as_str(),
                Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
            )),
            Line::from(Span::styled(
                format!("{policy}  ·  l use laptop  /  p release to phone"),
                Style::default().fg(DIM),
            )),
        ])
        .alignment(Alignment::Center),
        header[0],
    );
    let area = header[1];

    if app.device_order.is_empty() {
        let msg = Paragraph::new("Your audio, your choice.\n\nConnect paired AirPods with Bluetooth settings.\nNearby AirPods appear here after their first session.")
            .style(Style::default().fg(DIM))
            .alignment(Alignment::Center);
        f.render_widget(msg, centered_rect(area, 50, 30));
        draw_footer(f, footer_row(area), app);
        return;
    }

    let col = centered_col(area, 80);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(if app.device_order.len() > 1 { 2 } else { 0 }),
            Constraint::Fill(1),
            Constraint::Length(1), // single-line key hint footer
        ])
        .split(col);

    if app.device_order.len() > 1 {
        draw_tabs(f, chunks[0], app);
    }
    draw_content(f, chunks[1], app);
    draw_footer(f, chunks[2], app);

    // Rename popup overlay
    if let Some(ref buf) = app.rename_mode {
        draw_rename_popup(f, area, buf);
    }

    // Device info popup
    if app.show_info
        && let Some(DeviceState::AirPods(state)) = app.selected_device()
    {
        draw_info_popup(f, area, state);
    }
}

fn draw_tabs(f: &mut Frame, area: Rect, app: &App) {
    let spans: Vec<Span> = app
        .device_order
        .iter()
        .enumerate()
        .flat_map(|(i, mac)| {
            let name = app
                .devices
                .get(mac)
                .map(|d| d.name().to_string())
                .unwrap_or_else(|| mac.clone());
            let style = if i == app.selected_device_idx {
                Style::default()
                    .fg(ACCENT)
                    .add_modifier(Modifier::BOLD | Modifier::UNDERLINED)
            } else {
                Style::default().fg(DIM)
            };
            if i == 0 {
                vec![Span::styled(format!(" {} ", name), style)]
            } else {
                vec![
                    Span::styled("  ", Style::default().fg(DIM)),
                    Span::styled(format!(" {} ", name), style),
                ]
            }
        })
        .collect();
    f.render_widget(
        Paragraph::new(Line::from(spans)).alignment(Alignment::Center),
        area,
    );
}

fn draw_content(f: &mut Frame, area: Rect, app: &App) {
    let Some(mac) = app.selected_mac() else {
        return;
    };
    let Some(device) = app.devices.get(mac) else {
        return;
    };
    match device {
        DeviceState::AirPods(state) => draw_airpods(f, area, state, app),
    }
}

/// One row of the battery box.
struct BatteryEntry {
    label: &'static str,
    /// `None` for a case whose lid is known before its level is.
    level: Option<u8>,
    status: BatteryStatus,
    note: Option<&'static str>,
}

/// What to say about the case next to its level: the lid while a pod sits in
/// it (only then does anything report the lid), otherwise that the level is
/// the last one seen, since the case reports nothing on its own.
fn case_note(state: &AirPodsDeviceState) -> Option<&'static str> {
    use crate::bluetooth::aacp::LidState;
    match state.case_lid {
        Some(LidState::Open) => Some("lid open"),
        Some(LidState::Closed) => Some("lid closed"),
        None if [state.ear_left, state.ear_right].contains(&Some(EarDetectionStatus::InCase)) => {
            None
        }
        None => Some("last seen"),
    }
}

fn battery_entries(state: &AirPodsDeviceState) -> Vec<BatteryEntry> {
    let mut entries: Vec<BatteryEntry> = [
        ("Left  ", state.battery_left, None),
        ("Right ", state.battery_right, None),
        ("Case  ", state.battery_case, case_note(state)),
        ("      ", state.battery_headphone, None),
    ]
    .into_iter()
    .filter_map(|(label, battery, note)| {
        battery.map(|(level, status)| BatteryEntry {
            label,
            level: Some(level),
            status,
            note,
        })
    })
    .take(3)
    .collect();
    // The case often reports its level only after the lid has been opened
    // once with a pod inside; the lid itself is known straight away.
    if state.battery_case.is_none() && state.case_lid.is_some() {
        entries.push(BatteryEntry {
            label: "Case  ",
            level: None,
            status: BatteryStatus::Disconnected,
            note: case_note(state),
        });
    }
    entries
}

fn draw_airpods(f: &mut Frame, area: Rect, state: &AirPodsDeviceState, app: &App) {
    let bat_entries = battery_entries(state);
    let bat_count = bat_entries.len().max(1) as u16;
    let display_name = state.model.as_deref().unwrap_or(&state.name);
    let header = name_line(
        display_name,
        state.connected,
        state.ear_left,
        state.ear_right,
    );

    // Seen only through its broadcasts: state, but nothing to control.
    if !state.connected {
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(1),
                Constraint::Length(bat_count + 2),
                Constraint::Length(1),
                Constraint::Fill(1),
            ])
            .split(area);
        f.render_widget(
            Paragraph::new(header).alignment(Alignment::Center),
            chunks[0],
        );
        draw_battery_box(f, chunks[1], &bat_entries);
        f.render_widget(
            Paragraph::new("Not connected to this computer; settings need a connection")
                .style(Style::default().fg(DIM))
                .alignment(Alignment::Center),
            chunks[2],
        );
        return;
    }

    // No noise control box for non-ANC devices; settings still apply.
    if !state.has_anc {
        let settings_items = app.settings_items();
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(1),             // name line
                Constraint::Length(bat_count + 2), // battery box
                // Settings box sized to content; spare space stays empty
                Constraint::Max(settings_items.len() as u16 + 2),
                Constraint::Fill(1),
            ])
            .split(area);

        f.render_widget(
            Paragraph::new(header.clone()).alignment(Alignment::Center),
            chunks[0],
        );
        draw_battery_box(f, chunks[1], &bat_entries);

        let st_focused = app.effective_section() == FocusedSection::Settings;
        let st_block = section_block("Settings", st_focused);
        let st_inner = st_block.inner(chunks[2]);
        f.render_widget(st_block, chunks[2]);
        draw_settings_table(f, st_inner, &settings_items, app.section_row, st_focused);
        return;
    }

    // Full ANC view with boxes
    let noise_count = noise_mode_list(state.has_adaptive, state.allow_off_mode).len() as u16;
    let settings_items = app.settings_items();

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),               // name line
            Constraint::Length(bat_count + 2),   // Battery box
            Constraint::Length(noise_count + 2), // Noise Control box
            // Settings box sized to content; spare space stays empty
            Constraint::Max(settings_items.len() as u16 + 2),
            Constraint::Fill(1),
        ])
        .split(area);

    // Name line
    f.render_widget(
        Paragraph::new(header.clone()).alignment(Alignment::Center),
        chunks[0],
    );

    // Battery box (informational, never focused)
    draw_battery_box(f, chunks[1], &bat_entries);

    // Noise Control box
    let nc_focused = app.focused_section == FocusedSection::NoiseControl;
    let nc_block = section_block("Noise Control", nc_focused);
    let nc_inner = nc_block.inner(chunks[2]);
    f.render_widget(nc_block, chunks[2]);
    draw_noise_options(f, nc_inner, state, app.section_row, nc_focused);

    // Settings box
    let st_focused = app.focused_section == FocusedSection::Settings;
    let st_block = section_block("Settings", st_focused);
    let st_inner = st_block.inner(chunks[3]);
    f.render_widget(st_block, chunks[3]);
    draw_settings_table(f, st_inner, &settings_items, app.section_row, st_focused);
}

fn draw_battery_box(f: &mut Frame, area: Rect, entries: &[BatteryEntry]) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(DIM))
        .title(Span::styled(
            " Battery ",
            Style::default().fg(HEADER).add_modifier(Modifier::BOLD),
        ));
    let inner = block.inner(area);
    f.render_widget(block, area);

    if entries.is_empty() {
        f.render_widget(
            Paragraph::new("  Waiting for data…").style(Style::default().fg(DIM)),
            inner,
        );
        return;
    }

    let constraints: Vec<Constraint> = entries.iter().map(|_| Constraint::Length(1)).collect();
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints(constraints)
        .split(inner);

    for (entry, row) in entries.iter().zip(rows.iter()) {
        f.render_widget(bat_row(entry), *row);
    }
}

fn draw_noise_options(
    f: &mut Frame,
    area: Rect,
    state: &AirPodsDeviceState,
    section_row: usize,
    focused: bool,
) {
    let noise_modes = noise_mode_list(state.has_adaptive, state.allow_off_mode);

    let constraints: Vec<Constraint> = noise_modes.iter().map(|_| Constraint::Length(1)).collect();
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints(constraints)
        .split(area);

    for (i, mode) in noise_modes.iter().enumerate() {
        let is_focused = focused && section_row == i;
        let active = std::mem::discriminant(mode) == std::mem::discriminant(&state.listening_mode);
        f.render_widget(
            Paragraph::new(noise_row(&mode.to_string(), is_focused, active)),
            rows[i],
        );
    }
}

fn draw_settings_table(
    f: &mut Frame,
    area: Rect,
    items: &[SettingsItem],
    section_row: usize,
    focused: bool,
) {
    if items.is_empty() {
        f.render_widget(
            Paragraph::new("  No settings available").style(Style::default().fg(DIM)),
            area,
        );
        return;
    }

    let rows: Vec<Row> = items
        .iter()
        .enumerate()
        .map(|(i, item)| {
            let is_selected = focused && section_row == i;
            let cursor = if is_selected {
                Span::styled("▸ ", Style::default().fg(ACCENT))
            } else {
                Span::raw("  ")
            };
            let label_style = if is_selected {
                Style::default().fg(FG)
            } else {
                Style::default().fg(DIM)
            };

            let toggle_row = |label: &'static str, value: bool| {
                let val_str = if value { "On" } else { "Off" };
                let val_color = if value { ACCENT } else { DIM };
                Row::new(vec![
                    Line::from(vec![cursor.clone(), Span::styled(label, label_style)]),
                    Line::from(Span::styled(
                        val_str,
                        Style::default().fg(val_color).add_modifier(Modifier::BOLD),
                    ))
                    .alignment(Alignment::Right),
                ])
            };

            match item {
                // A group title: no cursor, no value, and never selected.
                SettingsItem::Header(title) => Row::new(vec![
                    Line::from(Span::styled(
                        format!("  {title}"),
                        Style::default().fg(HEADER).add_modifier(Modifier::BOLD),
                    )),
                    Line::from(Span::raw("")),
                ]),
                SettingsItem::Toggle { label, value, .. } => toggle_row(label, *value),
                SettingsItem::CycleBit { label, value, .. } => toggle_row(label, *value),
                SettingsItem::SinglePod { label, value } => toggle_row(label, *value),
                SettingsItem::HoldMode { label, value, .. } => {
                    let val_str = if *value == 1 { "Siri" } else { "Noise Control" };
                    Row::new(vec![
                        Line::from(vec![cursor.clone(), Span::styled(*label, label_style)]),
                        Line::from(Span::styled(
                            val_str,
                            Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
                        ))
                        .alignment(Alignment::Right),
                    ])
                }
                SettingsItem::Enum {
                    label,
                    value,
                    options,
                    ..
                } => {
                    let val_str = options.get(*value as usize).unwrap_or(&"?");
                    Row::new(vec![
                        Line::from(vec![cursor.clone(), Span::styled(*label, label_style)]),
                        Line::from(Span::styled(
                            *val_str,
                            Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
                        ))
                        .alignment(Alignment::Right),
                    ])
                }
                SettingsItem::Slider {
                    label,
                    value,
                    min,
                    max,
                    ..
                } => {
                    let range = (*max - *min) as usize;
                    let filled = ((*value - *min) as usize * 10)
                        .checked_div(range)
                        .unwrap_or(0)
                        .min(10);
                    let bar = format!(
                        "{}{}  {:>3}%",
                        "█".repeat(filled),
                        "░".repeat(10 - filled),
                        value
                    );
                    Row::new(vec![
                        Line::from(vec![cursor.clone(), Span::styled(*label, label_style)]),
                        Line::from(Span::styled(
                            bar,
                            Style::default().fg(if is_selected { ACCENT } else { Color::Gray }),
                        ))
                        .alignment(Alignment::Right),
                    ])
                }
            }
        })
        .collect();

    let table = Table::new(rows, [Constraint::Fill(1), Constraint::Length(20)]);

    let mut table_state = TableState::default();
    if focused {
        table_state.select(Some(section_row));
    }
    f.render_stateful_widget(table, area, &mut table_state);
}

fn section_block(title: &str, focused: bool) -> Block<'_> {
    if focused {
        Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Thick)
            .border_style(Style::default().fg(FOCUS_COLOR))
            .title(Span::styled(
                format!(" {} ", title),
                Style::default()
                    .fg(FOCUS_COLOR)
                    .add_modifier(Modifier::BOLD),
            ))
    } else {
        Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(DIM))
            .title(Span::styled(
                format!(" {} ", title),
                Style::default().fg(HEADER).add_modifier(Modifier::BOLD),
            ))
    }
}

fn ear_label(s: EarDetectionStatus) -> &'static str {
    match s {
        EarDetectionStatus::InEar => "in",
        EarDetectionStatus::OutOfEar => "out",
        EarDetectionStatus::InCase => "case",
        EarDetectionStatus::Disconnected => "off",
    }
}

fn name_line(
    display_name: &str,
    connected: bool,
    ear_left: Option<EarDetectionStatus>,
    ear_right: Option<EarDetectionStatus>,
) -> Line<'_> {
    // Fixed widths: the line is centered, so any change in length would
    // shift the whole header instead of just the word that changed.
    let status = if connected {
        Span::styled("● connected", Style::default().fg(Color::Green))
    } else {
        Span::styled("○ nearby   ", Style::default().fg(Color::Yellow))
    };
    let mut spans = vec![
        Span::styled(
            format!("  {} ", display_name),
            Style::default().fg(FG).add_modifier(Modifier::BOLD),
        ),
        status,
    ];
    if let (Some(l), Some(r)) = (ear_left, ear_right) {
        spans.push(Span::styled(
            format!("  L:{:<4}  R:{:<4}", ear_label(l), ear_label(r)),
            Style::default().fg(DIM),
        ));
    }
    Line::from(spans)
}

fn noise_row(label: &str, focused: bool, active: bool) -> Line<'static> {
    let prefix = if focused {
        Span::styled("  ▸ ", Style::default().fg(ACCENT))
    } else {
        Span::raw("    ")
    };
    let text_style = if active {
        Style::default().fg(FG).add_modifier(Modifier::BOLD)
    } else if focused {
        Style::default().fg(FG)
    } else {
        Style::default().fg(DIM)
    };
    let mut spans = vec![prefix, Span::styled(label.to_string(), text_style)];
    if active {
        spans.push(Span::styled("  (Active)", Style::default().fg(ACCENT)));
    }
    Line::from(spans)
}

fn bat_row(entry: &BatteryEntry) -> Paragraph<'static> {
    let BatteryEntry {
        label,
        level,
        status,
        note,
    } = *entry;
    let Some(level) = level else {
        let mut spans = vec![
            Span::styled(format!("  {}", label), Style::default().fg(DIM)),
            Span::styled(format!("{}  ", "░".repeat(10)), Style::default().fg(DIM)),
            Span::styled(" --%", Style::default().fg(DIM)),
        ];
        if let Some(note) = note {
            spans.push(Span::styled(format!("  {note}"), Style::default().fg(DIM)));
        }
        return Paragraph::new(Line::from(spans));
    };
    let charging = matches!(status, BatteryStatus::Charging | BatteryStatus::InUse);
    let color = if charging {
        Color::Cyan
    } else if level > 50 {
        Color::Green
    } else if level >= 20 {
        Color::Yellow
    } else {
        Color::Red
    };
    let filled = (level as usize * 10 / 100).min(10);
    let bar = format!("{}{}", "█".repeat(filled), "░".repeat(10 - filled));
    let mut spans = vec![
        Span::styled(format!("  {}", label), Style::default().fg(DIM)),
        Span::styled(format!("{}  ", bar), Style::default().fg(color)),
        Span::styled(
            format!("{:>3}%", level),
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        ),
    ];
    if charging {
        spans.push(Span::styled(
            "  [charging]",
            Style::default().fg(Color::Cyan),
        ));
    }
    if let Some(note) = note {
        spans.push(Span::styled(format!("  {note}"), Style::default().fg(DIM)));
    }
    Paragraph::new(Line::from(spans))
}

fn draw_footer(f: &mut Frame, area: Rect, app: &App) {
    let has_anc = matches!(
        app.selected_device(),
        Some(DeviceState::AirPods(s)) if s.has_anc
    );
    let hint = |key: &'static str, action: &'static str| {
        [
            Span::styled(key, Style::default().fg(ACCENT)),
            Span::styled(" ", Style::default()),
            Span::styled(action, Style::default().fg(DIM)),
            Span::styled("  ", Style::default()),
        ]
    };

    let mut hints: Vec<Span> = Vec::new();
    if has_anc {
        hints.extend(hint("tab", "section"));
    }
    hints.extend(hint("j/k", "move"));
    hints.extend(hint("space", "select"));
    if has_anc {
        hints.extend(hint("1-3", "noise"));
    }
    hints.extend(hint("r", "rename"));
    hints.extend(hint("i", "info"));
    hints.extend(hint("q", "quit"));
    if app.audio_unavailable {
        hints.push(Span::styled(
            "PulseAudio unavailable",
            Style::default().fg(Color::Red),
        ));
    }

    f.render_widget(
        Paragraph::new(Line::from(hints)).alignment(Alignment::Center),
        area,
    );
}

fn draw_rename_popup(f: &mut Frame, area: Rect, buf: &str) {
    let popup = centered_rect(area, 60, 30);
    // Clear the area behind the popup
    f.render_widget(ratatui::widgets::Clear, popup);

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(ACCENT))
        .title(Span::styled(
            " Rename Device ",
            Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
        ));
    let inner = block.inner(popup);
    f.render_widget(block, popup);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Fill(1),
            Constraint::Length(1),
        ])
        .split(inner);

    // Input line with cursor
    let input_text = format!(" {}▏", buf);
    f.render_widget(
        Paragraph::new(input_text).style(Style::default().fg(FG)),
        chunks[1],
    );

    // Help text
    f.render_widget(
        Paragraph::new(Line::from(vec![
            Span::styled("Enter", Style::default().fg(ACCENT)),
            Span::styled(" confirm  ", Style::default().fg(DIM)),
            Span::styled("Esc", Style::default().fg(ACCENT)),
            Span::styled(" cancel", Style::default().fg(DIM)),
        ]))
        .alignment(Alignment::Center),
        chunks[3],
    );
}

fn draw_info_popup(f: &mut Frame, area: Rect, state: &AirPodsDeviceState) {
    let fields: Vec<(&str, Option<&str>)> = vec![
        ("Model", state.model.as_deref()),
        ("Firmware", state.firmware.as_deref()),
        ("Hardware", state.hardware_revision.as_deref()),
        ("Serial", state.serial_number.as_deref()),
        ("L Serial", state.left_serial.as_deref()),
        ("R Serial", state.right_serial.as_deref()),
    ];
    let row_count = fields.iter().filter(|(_, v)| v.is_some()).count() as u16;
    let popup_h = row_count.max(1) + 2; // +2 for border
    let popup_w = 50u16.min(area.width);
    let popup = Rect {
        x: area.x + (area.width.saturating_sub(popup_w)) / 2,
        y: area.y + (area.height.saturating_sub(popup_h)) / 2,
        width: popup_w,
        height: popup_h,
    };
    f.render_widget(ratatui::widgets::Clear, popup);

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(ACCENT))
        .title(Span::styled(
            " Device Info ",
            Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
        ));
    let inner = block.inner(popup);
    f.render_widget(block, popup);

    if row_count == 0 {
        // The device sends its info packet a few seconds after connecting.
        f.render_widget(
            Paragraph::new("Waiting for device information…").style(Style::default().fg(DIM)),
            inner,
        );
        return;
    }

    let rows: Vec<Row> = fields
        .iter()
        .filter_map(|(label, val)| {
            val.map(|v| {
                Row::new(vec![
                    Line::from(Span::styled(*label, Style::default().fg(DIM))),
                    Line::from(Span::styled(v.to_owned(), Style::default().fg(FG)))
                        .alignment(Alignment::Right),
                ])
            })
        })
        .collect();

    f.render_widget(
        Table::new(rows, [Constraint::Length(12), Constraint::Fill(1)]),
        inner,
    );
}

/// Ordered list of noise control modes shown in the TUI.
/// Order: Transparency → Adaptive (if available) → Noise Cancellation → Off (if allowed).
/// Must match the row→mode mapping in `events::activate_noise_row`.
pub fn noise_mode_list(has_adaptive: bool, allow_off: bool) -> Vec<AirPodsNoiseControlMode> {
    let mut modes = vec![AirPodsNoiseControlMode::Transparency];
    if has_adaptive {
        modes.push(AirPodsNoiseControlMode::Adaptive);
    }
    modes.push(AirPodsNoiseControlMode::NoiseCancellation);
    if allow_off {
        modes.push(AirPodsNoiseControlMode::Off);
    }
    modes
}

fn centered_col(area: Rect, width: u16) -> Rect {
    let w = width.min(area.width);
    Rect {
        x: area.x + (area.width - w) / 2,
        y: area.y,
        width: w,
        height: area.height,
    }
}

fn footer_row(area: Rect) -> Rect {
    Rect {
        x: area.x,
        y: area.y + area.height.saturating_sub(1),
        width: area.width,
        height: 1,
    }
}

fn centered_rect(area: Rect, percent_x: u16, percent_y: u16) -> Rect {
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(area);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}

#[cfg(test)]
mod tests {
    use super::*;

    fn render_personal_ui(width: u16, height: u16, connected: bool, automatic: bool) -> String {
        let (_, events) = tokio::sync::mpsc::unbounded_channel();
        let (commands, _) = tokio::sync::mpsc::unbounded_channel();
        let mut app = App::new(events, commands);
        if connected {
            app.handle_event(crate::tui::app::AppEvent::DeviceConnected {
                mac: "AA:BB:CC:DD:EE:FF".into(),
                name: "Salar's AirPods".into(),
                product_id: 0x200e,
            });
        }
        let config = crate::config::Config {
            tui_title: "AIRPODS / amirsalar".into(),
            automatic_takeover: automatic,
            ..Default::default()
        };
        let mut terminal =
            ratatui::Terminal::new(ratatui::backend::TestBackend::new(width, height)).unwrap();
        terminal
            .draw(|frame| draw_with_config(frame, &app, &config))
            .unwrap();
        terminal
            .backend()
            .buffer()
            .content
            .iter()
            .map(|cell| cell.symbol())
            .collect()
    }

    #[test]
    fn personal_header_and_manual_shortcuts_render_with_and_without_a_device() {
        for connected in [false, true] {
            let screen = render_personal_ui(80, 28, connected, false);
            assert!(screen.contains("AIRPODS / amirsalar"));
            assert!(screen.contains("manual switching"));
            assert!(screen.contains("l use laptop"));
            assert!(screen.contains("p release to phone"));
        }
    }

    #[test]
    fn routing_label_reflects_opted_in_automatic_mode() {
        let screen = render_personal_ui(80, 28, false, true);
        assert!(screen.contains("follow local playback"));
        assert!(!screen.contains("manual switching"));
    }

    #[test]
    fn personal_ui_handles_small_terminals() {
        for (width, height) in [(1, 1), (20, 5), (40, 12)] {
            for connected in [false, true] {
                render_personal_ui(width, height, connected, false);
            }
        }
    }

    #[test]
    fn noise_mode_list_minimal() {
        let m = noise_mode_list(false, false);
        assert_eq!(
            m,
            vec![
                AirPodsNoiseControlMode::Transparency,
                AirPodsNoiseControlMode::NoiseCancellation,
            ]
        );
    }

    #[test]
    fn noise_mode_list_with_adaptive() {
        let m = noise_mode_list(true, false);
        assert_eq!(
            m,
            vec![
                AirPodsNoiseControlMode::Transparency,
                AirPodsNoiseControlMode::Adaptive,
                AirPodsNoiseControlMode::NoiseCancellation,
            ]
        );
    }

    #[test]
    fn noise_mode_list_with_off() {
        let m = noise_mode_list(false, true);
        assert_eq!(
            m,
            vec![
                AirPodsNoiseControlMode::Transparency,
                AirPodsNoiseControlMode::NoiseCancellation,
                AirPodsNoiseControlMode::Off,
            ]
        );
    }

    #[test]
    fn case_row_says_lid_or_that_the_level_is_old() {
        use crate::bluetooth::aacp::LidState;
        let mut s = AirPodsDeviceState {
            battery_case: Some((58, BatteryStatus::NotCharging)),
            ear_left: Some(EarDetectionStatus::InEar),
            ear_right: Some(EarDetectionStatus::InEar),
            ..Default::default()
        };
        // Both worn: the case says nothing, so its level is the last seen.
        assert_eq!(case_note(&s), Some("last seen"));
        s.ear_left = Some(EarDetectionStatus::InCase);
        s.case_lid = Some(LidState::Open);
        assert_eq!(case_note(&s), Some("lid open"));
        s.case_lid = Some(LidState::Closed);
        let entries = battery_entries(&s);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].note, Some("lid closed"));
    }

    /// Observed: the first time a pod went in, the case reported no level,
    /// so the lid had no row to show on.
    #[test]
    fn a_known_lid_gets_a_case_row_before_the_level_arrives() {
        use crate::bluetooth::aacp::LidState;
        let s = AirPodsDeviceState {
            ear_left: Some(EarDetectionStatus::InCase),
            case_lid: Some(LidState::Open),
            ..Default::default()
        };
        let entries = battery_entries(&s);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].level, None);
        assert_eq!(entries[0].note, Some("lid open"));
    }

    /// Only the words may change: the header keeps its width whatever the
    /// pods report, so the centered line does not jump.
    #[test]
    fn header_width_does_not_depend_on_ear_state() {
        use EarDetectionStatus::*;
        let width = |connected, l, r| {
            name_line("AirPods Pro 3", connected, Some(l), Some(r))
                .spans
                .iter()
                .map(|s| s.content.chars().count())
                .sum::<usize>()
        };
        let reference = width(true, InEar, InEar);
        for (l, r) in [
            (OutOfEar, InCase),
            (InCase, Disconnected),
            (InEar, OutOfEar),
        ] {
            assert_eq!(width(true, l, r), reference);
            assert_eq!(width(false, l, r), reference);
        }
    }

    #[test]
    fn noise_mode_list_full() {
        let m = noise_mode_list(true, true);
        assert_eq!(m.len(), 4);
        assert_eq!(m[0], AirPodsNoiseControlMode::Transparency);
        assert_eq!(m[1], AirPodsNoiseControlMode::Adaptive);
        assert_eq!(m[2], AirPodsNoiseControlMode::NoiseCancellation);
        assert_eq!(m[3], AirPodsNoiseControlMode::Off);
    }

    #[test]
    fn noise_mode_list_order_is_stable() {
        // Activate-noise-row in events.rs maps section_row index to this list.
        // Transparency must be first so key('1') and row 0 align with it.
        let m = noise_mode_list(true, true);
        assert_eq!(m[0], AirPodsNoiseControlMode::Transparency);
    }
}
