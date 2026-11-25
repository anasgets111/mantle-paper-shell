local theme = {}

-- The engine re-evaluates the config when the logical output size changes.
local height = math.huge
for _, screen in ipairs(mantle.screens:get() or {}) do
    height = math.min(height, screen.height)
end
local compact = height < 1000
local SCALE = compact and 0.8 or 1.0

local function s(base, min)
    if SCALE == 1.0 then return base end
    return math.max(min or 0, math.floor(base * SCALE + 0.5))
end

theme.PAPER = "#EEE3CB"
theme.INK = "#3A3631"
theme.INK_SOFT = "#6B6258"
theme.BLUE = "#3F74C7"
theme.DEEP_BLUE = "#24477F"
theme.RED = "#D9534F"
theme.DEEP_RED = "#8E2B25"
theme.CARD = "#F4ECDA"
theme.CARD_LIGHT = "#F6EFE0"
theme.CARD_BLUE = "#C5D7EE"
theme.CARD_PINK = "#F2CFC8"
theme.STICKY = "#F3E3A0"
theme.STICKY_FOLD = "#DCC67A"
theme.STICKY_PINK_FOLD = "#D9A9A0"
theme.GROOVE = "#E2D6BC"
theme.GROOVE_ON = "#D5E0EE"
theme.HIGHLIGHT = "#F2C94C80"
theme.SELECTION = "#F2C94C90"
theme.TAB_CREAM = "#E9DDBB"
theme.TAB_BLUE = "#C9D8EA"
theme.TAB_PINK = "#EBCBC5"
theme.TAB_GREEN = "#D6E3C4"
theme.TAB_LILAC = "#E4D3E8"
theme.TAB_PEACH = "#F0DDB8"
theme.PENCIL = "#3A363170"
theme.INK_FADED = "#3A363160"
theme.INK_FAINT = "#3A363140"
theme.TRACK_INK = "#3A363199"
theme.STAMP_INK = "#3A363155"
theme.FIELD_RULE = "#3A363180"
theme.PROGRESS_INK = "#3A3631A0"
theme.PREVIEW_WASH = "#3A363114"
theme.TRACK_HIGHLIGHT = "#9EC0EC99"
theme.RULE_BLUE = "#7FA3D040"
theme.NOTEBOOK_RULE = "#7FA3D050"
theme.UPDATE_RULE = "#7FA3D055"
theme.RULE_RED = "#D9534F60"
theme.FILE_RULE = "#D9534F80"
theme.PROGRESS_RED = "#D9534FCC"
theme.TAPE = "#DDCDA5"
theme.TAPE_BLUE = "#B5CBE6"
theme.QUICK_TAPE = "#B4CBE6"
theme.UPDATE_TAPE = "#B4CBE6C0"
theme.DESK_TAPE = "#A9C3E3B8"
theme.LOCK_TAPE = "#E9D9A6"
theme.DESK_BACKDROP = "#1E1B18"
theme.LOCK_BACKDROP = "#1C1A24"
theme.LOCK_BOOKMARK = "#C8463F"
theme.LOCK_BINDING = "#33528A"
theme.SLIDER_PIN_INK = "#7A2522"
theme.RECORDING_TAPE = "#E5877C"
theme.BINDING_HOLE = "#2A2520"
theme.BINDING_WIRE = "#55524C"
theme.BINDING_SHINE = "#C9C5BD"
theme.OSD_OFF = "#B9B0A2"
theme.OSD_ON = "#86AEEA"
theme.OSD_PAPER = "#EFE2B4"
theme.LOG_PAPER = "#F8F2E4"
theme.PHOTO_WASH = "#2A20150F"
theme.PHOTO_EDGE = "#2A201530"
theme.SWATCH_DARK = "#3B3732"
theme.SWATCH_LIGHT = "#E9E1CF"
theme.HATCH_DEFAULT = { 0.25, 0.45, 0.78, 0.85 }
theme.HATCH_INK = { 0.2, 0.38, 0.7, 0.75 }
theme.HATCH_FAINT = { 0.2, 0.38, 0.7, 0.22 }

theme.HAND = "Caveat"
theme.BODY = "Kalam"
theme.MONO = "Nimbus Mono PS"
theme.BOLD = 700
theme.REGULAR = 400

-- Opaque paper stocks pair each fill with its ink.
theme.STOCK = {
    primary = { theme.CARD_BLUE, theme.DEEP_BLUE },
    plain = { theme.CARD, theme.INK },
    danger = { theme.CARD_PINK, theme.DEEP_RED },
}
theme.tab_tints = { theme.TAB_CREAM, theme.TAB_BLUE, theme.TAB_PINK, theme.TAB_GREEN, theme.TAB_LILAC, theme.TAB_PEACH }

theme.SHADOW = {
    card = { { blur = 14, offset = { x = s(2), y = s(5) }, color = "#00000070" } },
    rest = { { blur = 5, offset = { x = 1, y = 2 }, color = "#00000050" } },
    lift = { { blur = 16, offset = { x = s(3), y = s(9) }, color = "#00000055" } },
    tape = { { blur = 3, offset = { y = 1 }, color = "#00000030" } },
    notes_rest = { { blur = 10, offset = { x = s(2), y = s(6) }, color = "#00000055" } },
    notes_lift = { { blur = 16, offset = { x = s(3), y = s(10) }, color = "#00000055" } },
    fold = { { blur = 3, offset = { x = -s(1), y = -s(1) }, color = "#00000040" } },
    light_disc = { { blur = 4, offset = { x = s(1), y = s(2) }, color = "#00000045" } },
    pin = { { blur = 4, offset = { x = s(1), y = s(2) }, color = "#00000055" } },
    knob = { { blur = 4, offset = { x = s(1), y = s(2) }, color = "#00000060" } },
    tiny = { { blur = 3, offset = { x = s(1), y = s(1) }, color = "#00000050" } },
    tab = { { blur = 4, offset = { y = -s(1) }, color = "#00000030" } },
    tooltip = { { blur = 6, offset = { x = s(1), y = s(3) }, color = "#00000050" } },
    lock = { { blur = 30, offset = { x = s(6), y = s(14) }, color = "#00000088" } },
    bookmark = { { blur = 3, offset = { x = s(1), y = s(2) }, color = "#00000060" } },
    osd = { { blur = 6, offset = { x = s(1), y = s(3) }, color = "#00000045" } },
    deep_note = { { blur = 6, offset = { x = s(1), y = s(3) }, color = "#00000060" } },
    groove = { { inset = true, blur = 5, offset = { y = s(2) }, color = "#00000048" } },
    log_inset = { { inset = true, blur = 4, offset = { y = s(1) }, color = "#00000030" } },
    sticker_rest = {
        { blur = 1.5, offset = { x = s(0.5), y = s(1) }, color = "#00000038" },
        { blur = 6, offset = { x = s(1.5), y = s(3) }, color = "#00000042" },
    },
    sticker_lift = {
        { blur = 2.5, offset = { x = s(1), y = s(2) }, color = "#00000030" },
        { blur = 14, offset = { x = s(3), y = s(8) }, color = "#00000050" },
    },
}

theme.control = {
    check = s(22),
    xs = s(24),
    knob = s(26),
    sm = s(28),
    chip = s(30),
    slider = s(32),
    row = s(34),
    tab = s(36),
    option = s(38),
    md = s(40),
    disc = s(44),
    button = s(46),
    lg = s(48),
    wide = s(50),
    tile = s(52),
}

theme.font = {
    mono_small = s(13, 10),
    mono = s(14),
    version = s(15),
    xs = s(16),
    caption = s(17),
    sm = s(18),
    label = s(19),
    md = s(20),
    control = s(21),
    lg = s(22),
    compact_hand = s(23),
    xl = s(24),
    button = s(25),
    heading = s(26),
    tab = s(27),
    title = s(28),
    xxl = s(30),
    banner = s(32),
    display = s(34),
    section = s(36),
    feature = s(38),
    name = s(44),
    clock_large = s(110),
}

theme.icon = {
    xs = s(14),
    inline_marker = s(15),
    sm = s(16),
    label = s(18),
    md = s(20),
    control = s(22),
    lg = s(24),
    badge = s(26),
    sticker = s(28),
    task = s(30),
    xl = s(32),
    large = s(38),
    tile = s(44),
    xxl = s(48),
    hero = s(56),
}

theme.radius = {
    xs = s(3),
    sm = s(4),
    inset = s(5),
    md = s(6),
    tab = s(7),
    spine = s(9),
}

theme.spacing = {
    hairline = s(2),
    xxs = s(4),
    compact = s(5),
    xs = s(6),
    sm = s(8),
    snug = s(10),
    md = s(12),
    inset = s(14),
    lg = s(16),
    roomy = s(18),
    xl = s(20),
    wide = s(22),
    xxl = s(24),
    tab = s(26),
    panel = s(28),
    page = s(30),
    xxxl = s(32),
    binding = s(34),
    section = s(40),
}

theme.bar = {
    anchor_w = s(70),
    badge_font_small = s(11),
    badge_offset = s(5),
    badge_size = s(18),
    dash_gap = s(3),
    dash_length = s(4),
    desk_gap = s(2),
    desk_icon = s(16),
    desk_min_w = s(32),
    desk_pad = s(5),
    desktop_rule_bend_x = s(4.5),
    desktop_rule_bend_y = s(17),
    desktop_rule_end_y = s(32),
    desktop_rule_start_y = s(2),
    desktop_rule_w = s(6),
    desktop_strip_w = s(14),
    divider_h = s(34),
    divider_w = s(22),
    headroom = s(16),
    height = s(56),
    indicator_loop_h = s(36),
    indicator_loop_w = s(38),
    indicator_w = s(56),
    layout_label_extra = s(2),
    layout_pad = s(5),
    live_enter_y = s(70),
    live_exit_x = s(110),
    live_exit_y = s(60),
    live_surface_w = s(230), live_surface_h = s(170),
    live_tape_w = s(220), live_tape_h = s(42),
    live_tape_x = s(46),
    live_tape_y = s(36),
    slot_gap = s(4),
    slot_stack_gap = s(3),
    slot_w = s(50),
    start_w = s(48), start_h = s(40),
    start_icon = s(22),
    start_pad = s(8),
    status_icon = s(24),
    status_swipe_h = s(30),
    task_drag = s(6),
    task_icon = s(30),
    tick_gap = s(3),
    tick_h = s(6),
    tick_w = s(7),
    tray_pad = s(12),
    urgent_dot = s(10),
}

theme.catcher = {
    bottom_pad = s(56),
}

theme.controls = {
    button_char_w = s(13),
    button_label_extra = s(44),
    button_min_w = s(96),
    chip_char_w = s(11),
    chip_extra = s(34),
    chip_h = s(30),
    divider_thickness = s(6),
    dropdown_menu_min_w = s(250),
    dropdown_w = s(260),
    field_rule_h = s(8),
    field_rule_y = s(5),
    field_w = s(320),
    focus_inset = s(5),
    knob_dot = s(5),
    link_min_w = s(8),
    loop_drift = s(8),
    loop_taper_end = s(24),
    loop_taper_start = s(10),
    pencil_inset = s(2.5),
    rule_bottom = s(10),
    rule_margin = s(70),
    rule_pitch = s(34),
    rule_top = s(84),
    slider_bend_y = s(14),
    slider_end_y = s(17),
    slider_ink_w = s(13),
    slider_inset = s(6),
    slider_pin = s(22),
    slider_pin_center = s(11),
    slider_start_y = s(16),
    slider_travel_trim = s(12),
    slider_value_w = s(48),
    slider_w = s(280),
    sticky_fold = s(12),
    sticky_tape_w = s(64), sticky_tape_h = s(20),
    tab_active_h = s(44),
    tab_corner = s(10),
    tab_edge_start = s(16),
    tab_edge_step = s(8),
    tab_loop_bottom = s(8),
    tab_loop_char_w = s(12),
    tab_loop_extra = s(20),
    tab_loop_inset = s(2),
    tab_overlap = s(6),
    tab_rest_h = s(36),
    tab_side_start = s(14),
    tab_w = s(118),
    toggle_h = s(30),
    toggle_w = s(62),
    radio_scribble = {
        s(8), s(9), s(15), s(7), s(13), s(17),
        s(11), s(16), s(15.5),
    },
}

theme.desk = {
    bottom = s(24),
    card_w = s(370),
    clock_font = s(104),
    clock_h = s(210),
    clock_sprig = s(58),
    clock_tape_h = s(20),
    clock_tape_w = s(300),
    clock_underline_w = s(210),
    clock_underline_y = s(9),
    gap = s(4),
    meter_h = s(14),
    meter_pin = s(10),
    meter_pin_center = s(5),
    music_art = s(92),
    music_h = s(200),
    music_value_w = s(44),
    note_h = s(190),
    quote_h = s(136),
    quote_pad_right = s(44),
    task_text_w = s(130),
    todo_field_inset = s(60),
    todo_h = s(116),
    top = s(18),
    track_w = s(196),
}

theme.icon_preview = {
    label_w = s(160),
    width = s(1560), height = s(760),
    title = s(40),
}

theme.icons = {
    outline_pad = s(1),
}

theme.lock = {
    account_inset = s(150),
    account_x = s(54),
    binding_w = s(46),
    bookmark_w = s(28), bookmark_h = s(150),
    bookmark_notch = s(24),
    bookmark_x = s(96),
    bookmark_y = s(104),
    content_top = s(48),
    cover_w = s(600), cover_h = s(800),
    disabled_note_inset = s(40),
    duration_w = s(90),
    label_w = s(460), label_h = s(270),
    label_rule_inset = s(130),
    label_tape_w = s(120),
    media_art = s(66),
    media_w = s(460), media_h = s(104),
    media_play_disc = s(40),
    media_skip_disc = s(32),
    media_tape_w = s(34), media_tape_h = s(13),
    message_inset = s(28),
    password_gap = s(14),
    password_inset = s(70),
    password_shake_left = s(7),
    password_shake_right = s(11),
    password_submit_inset = s(52),
    password_w = s(360),
    polkit_button_w = s(120),
    polkit_pad_left = s(30),
    polkit_pad_right = s(28),
    polkit_w = s(560),
    stage_highlight_inset = s(2),
    stage_title_inset = s(18),
}

theme.menu = {
    body_extra = s(26),
    divider_trim = s(28),
    highlight_trim_x = s(16),
    highlight_trim_y = s(8),
    lead_size = s(18),
    row_h = s(34),
    separator_h = s(10),
    title_h = s(34),
    title_trim = s(20),
    width = s(250),
}

theme.nightlight = {
    minutes_w = s(56),
    percent_w = s(30),
    slider_w = s(420),
    time_value_w = s(70),
}

theme.notifications = {
    anchor_inset = s(140),
    anchor_w = s(120),
    body_inset = s(7),
    calendar_base_h = s(190),
    calendar_cell = s(40),
    calendar_divider_inset = s(10),
    calendar_extra_h = s(4),
    calendar_grid_inset = s(28),
    calendar_row = s(34),
    calendar_rule_h = s(4),
    calendar_rule_inset = s(10),
    calendar_rule_w = s(8),
    calendar_tape_w = s(72),
    calendar_w = s(300),
    clear_icon = s(15),
    date_chars = s(30),
    date_font = s(36),
    drag_threshold = s(6),
    empty_h = s(90),
    fade_distance = s(260),
    fold = s(14),
    group_name_w = s(260),
    group_rule_inset = s(40),
    history_h = s(400),
    margin_rule_w = s(6),
    media_art = s(70),
    media_w = s(328), media_h = s(124),
    media_tape_w = s(36), media_tape_h = s(14),
    note_edge_step = s(12),
    note_tape_w = s(70), note_tape_h = s(20),
    notepad_h = s(560),
    notepad_margin = s(46),
    notepad_rule_pitch = s(34),
    notepad_rule_top = s(78),
    notepad_tape_w = s(96),
    notepad_w = s(450),
    photo_size = s(72),
    photo_tape_w = s(34), photo_tape_h = s(14),
    reply_w = s(270),
    throw_distance = s(110),
    toast_shadow_w = s(80),
    today_inset = s(4),
    turn_distance = s(40),
    underline_base_y = s(5),
    underline_drift = s(2),
    underline_h = s(10),
    width = s(380),
}

theme.osd = {
    fill_h = s(17),
    height = s(58),
    mark_bottom = s(25),
    mark_end_x = s(2.5),
    mark_start_x = s(3.5),
    mark_top = s(5),
    mark_w = s(6),
    popup_extra_h = s(12),
    slide = s(14),
    track_bend_y = s(12),
    track_end_y = s(16),
    track_h = s(30),
    track_inset = s(4),
    track_start_y = s(15),
    track_trim = s(8),
    track_w = s(230),
    value_w = s(84),
}

theme.paper = {
    avatar_tear = s(2.4),
    bar_tear = s(5),
    card_pad = s(6),
    control_tear = s(3),
    deckle_step = s(6),
    edge_span = 3840, edge_step = 16,
    disc_tear = s(1.8),
    fine_tear = s(1),
    hatch = s(3.5),
    hatch_broad = s(5),
    hatch_fine = s(3.2),
    hatch_wide = s(4),
    light_tear = s(2),
    pin_tear = s(1.2),
    pip_tear = s(0.8),
    sheet_tear = s(4),
    squiggle_bottom = s(9),
    squiggle_h = s(10),
    squiggle_half_step = s(7),
    squiggle_mid = s(5),
    squiggle_step = s(14),
    squiggle_top = s(1),
    tape_w = s(86), tape_h = s(24),
    tape_lift = s(12),
}

theme.previews = {
    card_gap = s(14),
    close_offset = s(9),
    frame = s(10),
    label_area_h = s(40),
    note_extra_w = s(26),
    overflow_w = s(60),
    shot_w = s(248), shot_h = s(140),
}

theme.quick = {
    brightness_step_w = s(30),
    device_highlight_inset = s(4),
    device_loop_inset = s(5),
    device_mark = s(20),
    device_pad = s(8),
    device_row_h = s(38),
    gap = s(18),
    pad = s(28),
    percent_w = s(50),
    popup_pad = s(18),
    privacy_head_h = s(38),
    privacy_loop_inset = s(2),
    privacy_loop_w = s(96),
    privacy_pad = s(14),
    privacy_row_h = s(40),
    slider_w = s(276),
    tape_w = s(96),
    tile_w = s(218), tile_h = s(78),
    tile_loop_inset = s(8),
    width = s(500),
}

theme.recorder = {
    anchor_inset = s(300),
    anchor_w = s(120),
    clock_base_w = s(40),
    clock_char_w = s(10),
    clock_idle_w = s(80),
    clock_pad = s(7),
    indicator_h = s(36),
    live_badge = s(18),
    live_button_w = s(124),
    live_h = s(330),
    pause_stroke = s(3.4),
    record_dot = s(13),
    setup_h = s(214),
    setup_icon = s(56),
    state_mark = s(16),
    tape_w = s(84),
    width = s(560),
}

theme.settings = {
    about_title = s(52),
    backlight_label_w = s(120),
    backlight_slider_w = s(380),
    binding_end = s(30),
    binding_hole_inset = s(4.5),
    binding_hole_x = s(32),
    binding_hole_y = s(15),
    binding_pitch = s(34),
    binding_shine_h = s(8),
    binding_stroke = s(3.4),
    binding_w = s(30),
    binding_wire_bend = s(14),
    binding_wire_h = s(12),
    binding_wire_inset = s(6),
    binding_wire_overhang = s(16),
    binding_wire_start = s(9),
    brightness_slider_w = s(420),
    card_bottom = s(22),
    card_pad = s(14),
    card_tape_lift = s(11),
    card_tape_w = s(78),
    card_x = s(76),
    card_y = s(96),
    default_app_w = s(320),
    display_footer_h = s(16),
    display_hint_line_h = s(16),
    display_map_inset = s(20),
    display_map_trim = s(16),
    display_min_size = s(40),
    display_scale_inset = s(30),
    display_tape_w = s(74),
    fact_label_w = s(150),
    fade = s(24),
    fade_top = s(10),
    header_font = s(46),
    header_rule_h = s(11),
    heading_underline_bend = s(2.4),
    heading_underline_h = s(8),
    heading_underline_inset = s(4),
    heading_underline_left = s(6.4),
    heading_underline_right = s(10.4),
    note_line_h = s(18),
    notification_sound_w = s(220),
    page_bleed = s(8),
    page_w = s(800), page_h = s(680),
    page_rule_margin = s(70),
    page_x = s(200),
    pair_code_w = s(260),
    pair_title_w = s(560),
    row_pitch = s(34),
    row_sink = s(6),
    row_w = s(672),
    sound_app_level_w = s(200),
    sound_app_name_w = s(230),
    sound_device_w = s(440),
    sound_level_w = s(420),
    sound_profile_label_w = s(150),
    sound_tab_w = s(130),
    subtab_w = s(150),
    swatch_first_rule = s(26),
    swatch_w = s(170), swatch_h = s(112),
    swatch_lines_top = s(44),
    swatch_loop_h = s(136),
    swatch_loop_w = s(194),
    swatch_line_long = s(110),
    swatch_line_short = s(80),
    swatch_rule_end = s(160),
    swatch_rule_end_inset = s(10),
    swatch_line_x = s(18),
    swatch_line_pitch = s(14),
    swatch_title_top = s(3),
    tab_active_inset = s(30),
    tab_edge_inset = s(8),
    tab_gap = s(4),
    tab_h = s(48),
    tab_idle_inset = s(40),
    tab_loop_extra = s(6),
    tab_loop_nudge = s(4),
    tabs_offset_y = s(74),
    tabs_w = s(222),
    top = s(22),
    vpn_field_w = s(360),
    vpn_label_w = s(140),
    wallpaper_badge = s(24),
    wallpaper_badge_offset = s(9),
    wallpaper_border = s(6),
    wallpaper_cell_w = s(152),
    wallpaper_fade = s(12),
    wallpaper_fit_w = s(260),
    wallpaper_folder_w = s(420),
    wallpaper_gap = s(14),
    wallpaper_image_w = s(124), wallpaper_image_h = s(70),
    wallpaper_label_inset = s(12),
    wallpaper_label_w = s(70),
    wallpaper_loop_inset = s(16),
    wallpaper_tape_w = s(44), wallpaper_tape_h = s(14),
    wallpaper_tape_lift = s(7),
    wifi_hidden_label_w = s(170),
    wifi_lock_slot_w = s(16),
    wifi_passphrase_w = s(420),
    wifi_ssid_w = s(300),
    wifi_strength_w = s(58),
}

theme.startmenu = {
    account_inset = s(170),
    app_name_w = s(300),
    app_swipe_trim = s(10),
    avatar_initial_pad = s(7),
    avatar_shadow_pad = s(8),
    avatar_size = s(96),
    avatar_tape_w = s(58), avatar_tape_h = s(18),
    bridge_pad = s(12),
    bridge_trim = s(6),
    bridge_w = s(17),
    calc_swipe_h = s(38),
    cell_h = s(112),
    cell_w = s(112),
    content_trim = s(150),
    height = s(660),
    left_pad_left = s(74),
    left_pad_right = s(30),
    left_w = s(560),
    name_max = s(34),
    name_min = s(24),
    places_inset = s(56),
    places_rule_inset = s(60),
    power_w = s(52), power_h = s(50),
    power_loop_pad = s(6),
    recent_w = s(218), recent_h = s(66),
    recent_margin_y = s(15),
    recent_rule_y = s(42),
    recent_shadow_pad = s(8),
    right_w = s(340),
    row_h = s(40),
    rule_left_inset = s(6),
    rule_left_margin = s(54),
    rule_pitch = s(40),
    rule_right_inset = s(10),
    rule_top = s(172),
    search_icon_w = s(32),
    search_stub = s(32),
    spine_seam_x = s(31.5),
    spine_tall_extra = s(12),
    spine_w = s(64),
    tab_gap = s(4),
    tab_h = s(48),
    tab_loop_closed_trim = s(40),
    tab_loop_closed_x = s(4),
    tab_loop_trim = s(30),
    tab_loop_x = s(6),
    tab_overlap = s(22),
    tab_pad_right = s(10),
    tab_top = s(20),
    tab_tuck_held = s(5),
    tab_tuck_hover = s(6),
    tab_tuck_rest = s(16),
    tile_loop_inset_x = s(8),
    tile_loop_inset_y = s(6),
    tile_swipe_h = s(24),
}

theme.tooltip = {
    gap = s(6),
    max_width = s(420),
    pad_side = s(11),
    pad_top = s(7),
    tape_w = s(34), tape_h = s(12),
}

theme.updates = {
    anchor_inset = s(420),
    anchor_w = s(40),
    arrow_h = s(12),
    arrow_w = s(22),
    badge_corner_offset = s(8),
    badge_ring_extra = s(12),
    badge_size = s(18),
    empty_rule_w = s(120),
    fade = s(24),
    head_h = s(40),
    header_icon_w = s(36),
    indent = s(34),
    interval_w = s(180),
    list_max = s(430),
    log_h = s(220),
    note_inset = s(48),
    package_sticker = s(22),
    progress_h = s(22),
    progress_ink_w = s(9),
    progress_inset = s(6),
    row_h = s(31),
    sheet_inset = s(64),
    size_w = s(64),
    tab_w = s(190),
    tape_w = s(110),
    tool_command_w = s(300),
    version_w = s(150),
    width = s(600),
    arrow_points = {
        s(2), s(6.5), s(10), s(5), s(19), s(6),
        s(15), s(2.5), s(17.5), s(4.5), s(19.5), s(17),
        s(8), s(15.5), s(9.8),
    },
}

return theme
