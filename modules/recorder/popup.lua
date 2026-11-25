-- The recorder's paper card, hung above the quick-settings icons: what to capture, audio and
-- quality, then Start; while recording, the elapsed time with Stop and Pause.
local theme = require("theme")
local k = require("lib.paper")
local util = require("lib.util")
local controls = require("components.controls")
local icons = require("components.icons")
local ui_state = require("lib.ui_state")
local svc = require("modules.recorder.service")
local marks = require("modules.recorder.marks")
local catcher = require("components.catcher")

local M = {}

local KIND = "recorder"
local MS = 160
local W = theme.recorder.width

-- A click opens the grab popup, so an outside click closes it; the action has no press to grab with,
-- so it opens the same card on a keyboard catcher instead.
local grab = state("recorder.grab", true)
-- The compositor closed it: hidden at once, so the exit fade cannot reopen it.
local dismissed = state("recorder.dismissed", false)
local showing = ui_state.panel_showing(KIND)

local function close() ui_state.close_panel() end

local function open(rect, with_grab)
    if ui_state.panel_is(KIND) then return close() end
    grab:set(with_grab)
    dismissed:set(false)
    ui_state.open_panel(KIND, rect)
end

-- Toggle the card anchored to `rect`, from a click (the quick-settings "Record screen" disc).
function M.open(rect)
    open(rect, true)
end

-- `mantle call recorder.toggle_popup`, for a keybind: anchored where the last popup hung, or above
-- the right end of the first output's taskbar before any.
action("recorder.toggle_popup", function()
    local rect = ui_state.popup_anchor:get()
    if rect.x == 0 then
        local screen = mantle.screens:get()[1]
        rect = { x = (screen and screen.width or 1920) - theme.recorder.anchor_inset, y = theme.spacing.md, width = theme.recorder.anchor_w, height = theme.control.md }
    end
    open(rect, false)
end)

local AUDIO = { { "off", "Off" }, { "desktop", "Desktop" }, { "mic", "Desktop + mic" } }
local QUALITY = { { "low", "Low" }, { "medium", "Medium" }, { "high", "High" } }
local AUDIO_WORD = { off = "no audio", desktop = "desktop audio", mic = "desktop audio + mic" }

local function choice(key, title, options)
    return column {
        spacing = theme.spacing.sm,
        children = {
            k.hand(title, theme.font.heading, { font_weight = theme.BOLD, foreground = theme.BLUE }),
            controls.radio_group {
                id = "recorder." .. key,
                vertical = true,
                options = options,
                value = svc.settings[key],
                on_select = function(v) svc.settings:set(key, v) end,
            },
        },
    }
end

-- Region needs `slurp`; without it the only capture is the whole screen, so the group says so.
local capture = svc.has_slurp:map(function(has)
    local options = { { "screen", "Whole screen" } }
    if has then options[2] = { "region", "Region" } end
    return { choice("target", "Capture", options) }
end)

local function folder_link()
    return controls.link { id = "recorder.folder", label = "Recordings folder", size = theme.font.xl, on_click = function()
        close()
        svc.open_directory()
    end }
end

local function setup()
    return column {
        width = "fill",
        spacing = theme.spacing.lg,
        children = {
            row {
                spacing = theme.spacing.snug,
                children = {
                    rect { align_v = "center", children = { icons.doodle("video", theme.icon.sticker, theme.INK) } },
                    k.hand("Record screen", theme.font.section, { font_weight = theme.BOLD }),
                },
            },
            row {
                spacing = theme.spacing.binding,
                children = {
                    column { children = capture },
                    choice("audio", "Audio", AUDIO),
                    choice("quality", "Quality", QUALITY),
                },
            },
            controls.divider(W - theme.recorder.setup_icon, false, 17),
            row {
                width = "fill",
                align_v = "center",
                children = {
                    controls.button {
                        id = "recorder.start",
                        label = "Start recording",
                        kind = "danger",
                        on_click = function()
                            -- Off the screen before `slurp` or the first frame.
                            close()
                            svc.start(svc.settings.target:get() == "region")
                        end,
                    },
                    rect { width = "fill" },
                    folder_link(),
                },
            },
        },
    }
end

local function live()
    return column {
        width = "fill",
        spacing = theme.spacing.inset,
        children = {
            row {
                width = "fill",
                spacing = theme.spacing.md,
                children = {
                    rect { width = theme.recorder.live_badge, align_v = "center", children = marks.state(svc.paused) },
                    k.hand(util.choose(svc.paused, "Paused", "Recording"), theme.font.section, { font_weight = theme.BOLD, width = "fill" }),
                    k.hand(svc.elapsed, theme.font.section, { font_weight = theme.BOLD, foreground = theme.DEEP_RED }),
                },
            },
            k.body(computed({ svc.label, svc.settings.audio }, function(label, audio)
                return string.format("%s \u{00B7} %s", label, AUDIO_WORD[audio] or "")
            end, ""), theme.font.label, { foreground = theme.INK_SOFT, width = "fill", elide = "end" }),
            row {
                width = "fill",
                spacing = theme.spacing.inset,
                align_v = "center",
                children = {
                    controls.button { id = "recorder.stop", label = "Stop", kind = "danger", on_click = function()
                        close()
                        svc.stop()
                    end },
                    -- One width for both labels, so the link beside it holds still when it flips.
                    rect {
                        children = svc.paused:map(function(p)
                            return { controls.button {
                                id = "recorder.pause", label = p and "Resume" or "Pause", width = theme.recorder.live_button_w,
                                on_click = svc.toggle_pause,
                            } }
                        end),
                    },
                    rect { width = "fill" },
                    folder_link(),
                },
            },
        },
    }
end

-- The torn edge is cut for a fixed box, so each mode has its own height.
local function card(up)
    return k.card {
        width = W,
        height = up and theme.recorder.setup_h or theme.recorder.live_h,
        seed = up and 907 or 905,
        rotate = -0.5,
        color = theme.CARD,
        tapes = { { width = theme.recorder.tape_w, height = theme.control.check, rotate = 3, seed = 31 } },
        child = rect {
            width = "fill",
            height = "fill",
            padding = { top = theme.spacing.tab, left = theme.spacing.panel, right = theme.spacing.panel, bottom = theme.spacing.xxl },
            children = { up and live() or setup() },
        },
    }
end

-- The card as children, built per surface: a node belongs to one.
local function cards()
    return svc.recording:map(function(up) return { card(up) } end)
end

M.surface = popup {
    id = "paper-recorder",
    parent = "paper-taskbar",
    anchor_rect = ui_state.popup_anchor,
    anchor = "top_right",
    gravity = "top_left",
    offset = { y = -theme.spacing.xs },
    constraint_adjustment = { "slide_x", "flip_y" },
    grab = true,
    visible = computed({ util.linger(showing, MS), dismissed, grab }, function(v, gone, g) return v and g and not gone end),
    on_dismiss = function()
        dismissed:set(true)
        if ui_state.panel_is(KIND) then close() end
    end,
    on_escape = close,
    child = rect {
        padding = theme.spacing.roomy,
        opacity = util.choose(showing, 1, 0),
        translate = showing:map(function(v) return { y = v and 0 or theme.spacing.md } end),
        animate = {
            opacity = { duration = MS, easing = "out_cubic", from = 0 },
            translate = { duration = MS, easing = "out_cubic", from = { y = theme.spacing.md } },
        },
        children = cards(),
    },
}

M.keyboard_surface = catcher {
    id = "paper-recorder-keys",
    visible = computed({ showing, grab }, function(v, g) return v and not g end),
    close = close,
    card = function() return rect { padding = theme.spacing.roomy, children = cards() } end,
}

return M
