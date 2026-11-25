-- Quick settings (GNOME system menu): a card-stock sheet that pops up from the taskbar's status
-- icons. Interface the taskbar relies on:
--   surfaces      list of popups to add to the shell
--   open(rect, section, output)  toggle the quick-settings popup anchored to the clicked status icons;
--                         section "privacy" circles the "In use" strip (the privacy stickers)
local theme = require("theme")
local k = require("lib.paper")
local util = require("lib.util")
local icons = require("components.icons")
local controls = require("components.controls")
local ui_state = require("lib.ui_state")
local tiles = require("modules.quick.tiles")
local privacy = require("modules.quick.privacy")
local devices = require("modules.quick.devices")
local G = require("modules.quick.glyphs")
local tooltip = require("components.tooltip")
local recorder = require("modules.recorder")

local M = {}

local W = theme.quick.width
local MAX_VOLUME = 150
local POPUP_PAD, PAD, GAP = theme.quick.popup_pad, theme.quick.pad, theme.quick.gap
local sheet_scroll = scroll("quick.sheet")
local anchor_output = state("quick.output", "")

local open = state("quick.open", false)
-- True while the popup is shown, so the notification toasts can stay clear of it.
M.is_open = open
local anchor = state("quick.anchor", { x = 0, y = 0, width = 1, height = 1 })
-- The section the opener asked for; "" for none.
local section = state("quick.section", "")
-- The device list open under its row: "sinks", "sources" or "" for none.
local chooser = state("quick.chooser", "")

-- A click on the status icons while open dismisses the grab first; if that same click then reaches
-- `open`, it must close rather than reopen.
local dismissed_at = -1

function M.open(r, wanted, output)
    if open:get() or mantle.clock:now() - dismissed_at < 0.3 then
        open:set(false)
        return
    end
    section:set(wanted or "")
    anchor_output:set(output or "")
    -- One surface at a time: a modal left open would sit under the sheet holding the keyboard.
    ui_state.active_modal:set("")
    anchor:set({ x = r.x or 0, y = r.y or 0, width = math.max(1, r.width or 1), height = math.max(1, r.height or 1) })
    open:set(true)
end

local function close() open:set(false) end

local tips = tooltip.new { id = "paper-quick-tip", parent = "paper-quick", side = "top" }

local function default_of(audio, kind)
    for _, device in ipairs(audio and audio[kind] or {}) do
        if device.active then return device end
    end
end

local function sink_of(audio) return default_of(audio, "sinks") end
local function source_of(audio) return default_of(audio, "sources") end

-- One wheel notch is 5%, as on the taskbar's volume icon. A source tops out at 100%.
local function nudge(kind, ceiling)
    return function(_, steps)
        local d = default_of(mantle.audio:get(), kind)
        if d then mantle.audio:set_volume(d.id, math.max(0, math.min(ceiling, (d.volume or 0) + steps * 5))) end
    end
end
local nudge_volume, nudge_mic = nudge("sinks", MAX_VOLUME), nudge("sources", 100)
-- The taskbar's speaker wheel, so both stop at the same ceiling.
M.nudge_volume = nudge_volume

local function nudge_brightness(_, steps)
    local b = mantle.brightness:get()
    if b then mantle.brightness:set(math.max(1, math.min(100, b.percent + steps * 5))) end
end

-- Header ----------------------------------------------------------------------------------------

local function battery_icon(b)
    local level = math.floor((b.percent + 5) / 10) * 10
    local charging = b.state == "charging" or b.state == "fully_charged" or b.state == "pending_charge"
    return string.format("battery-level-%d%s-symbolic", level, charging and "-charging" or "")
end

local function battery_line(b)
    if not b.present then return "Plugged in" end
    local s = b.percent .. "%"
    local left = b.state == "discharging" and b.time_to_empty or b.state == "charging" and b.time_to_full
    if left and left > 0 then
        s = s .. string.format(" · %d:%02d %s", left // 3600, left // 60 % 60,
            b.state == "charging" and "to full" or "left")
    end
    return s
end

local function action_disc(id, icon_name, tooltip, fn)
    return tips.wrap(controls.disc_button {
        id = "quick." .. id, icon = icon_name, size = theme.control.button, tooltip = tooltip,
        on_click = function()
            close()
            fn()
        end,
    }, "paper.disc.quick." .. id, tooltip)
end

local header = row {
    width = "fill",
    spacing = theme.spacing.md,
    children = {
        icons.doodle_for(mantle.battery:map(function(b) return b.present and battery_icon(b) or G.ac end, G.ac), theme.icon.control),
        k.body(mantle.battery:map(battery_line, ""), theme.font.control, { align_v = "center", width = "fill" }),
        action_disc("settings", G.settings, "Settings", function() ui_state.toggle_modal("settings") end),
        action_disc("lock", G.lock, "Lock", function() mantle.lock:lock() end),
        action_disc("record", "video", "Record screen", function() recorder.open(anchor:get()) end),
        action_disc("power", G.power, "Power", function() ui_state.toggle_modal("startmenu") end),
    },
}

-- Sliders ---------------------------------------------------------------------------------------

local function percent_label(value)
    return k.body(value, theme.font.md, { align_v = "center", width = theme.quick.percent_w })
end

local SLIDER_W = theme.quick.slider_w

-- The chevron that opens `kind`'s device list under its row, GNOME-style.
local function chooser_disc(kind, tip)
    local id = "quick.chooser." .. kind
    return tips.wrap(controls.disc_button {
        id = id,
        seed = kind == "sinks" and 63 or 67,
        size = theme.control.chip,
        tooltip = tip,
        icon = chooser:map(function(v) return v == kind and "chevron-up" or "chevron-down" end),
        on_click = function() chooser:set(chooser:get() == kind and "" or kind) end,
    }, "paper.disc." .. id, tip)
end

-- Only worth a chevron when there is a choice to make.
local function with_choice(node, kind)
    return util.with(node, "visible", mantle.audio:map(function(a) return #(a[kind] or {}) > 1 end, false))
end

local volume = row {
    width = "fill",
    spacing = theme.spacing.md,
    visible = mantle.audio:map(function(a) return sink_of(a) ~= nil end, false),
    children = {
        util.with(tips.wrap(controls.disc_button {
            id = "quick.mute",
            seed = 61,
            size = theme.control.option,
            tooltip = "Mute",
            icon = mantle.audio:map(function(a)
                local s = sink_of(a)
                if not s or s.muted or (s.volume or 0) <= 0 then return G.volume_muted end
                return s.volume < 50 and G.volume_low or G.volume_high
            end, G.volume_high),
            on_click = function()
                local s = sink_of(mantle.audio:get())
                if s then mantle.audio:toggle_mute(s.id) end
            end,
        }, "paper.disc.quick.mute", function()
            local s = sink_of(mantle.audio:get())
            return s and s.muted and "Unmute" or "Mute"
        end), "on_wheel", nudge_volume),
        -- The bar spans the sink's whole range, 0 to 150%, so a boosted volume still has a place on it.
        controls.slider {
            id = "quick.volume",
            width = SLIDER_W,
            show_value = false,
            value = mantle.audio:map(function(a)
                local s = sink_of(a)
                return s and (s.volume or 0) / MAX_VOLUME or 0
            end, 0),
            on_change = function(v)
                local s = sink_of(mantle.audio:get())
                if s then mantle.audio:set_volume(s.id, math.floor(v * MAX_VOLUME + 0.5)) end
            end,
            on_wheel = nudge_volume,
        },
        percent_label(mantle.audio:map(function(a)
            local s = sink_of(a)
            return s and s.muted and "muted" or string.format("%d%%", math.floor((s and s.volume or 0) + 0.5))
        end, "")),
        with_choice(chooser_disc("sinks", "Output device"), "sinks"),
    },
}

local has_source = mantle.audio:map(function(a) return source_of(a) ~= nil end, false)

local mic = row {
    width = "fill",
    spacing = theme.spacing.md,
    visible = has_source,
    children = {
        util.with(tips.wrap(controls.disc_button {
            id = "quick.mic",
            seed = 65,
            size = theme.control.option,
            tooltip = "Mute microphone",
            icon = mantle.audio:map(function(a)
                local s = source_of(a)
                return (s and s.muted) and G.mic_off or G.mic
            end, G.mic),
            on_click = function()
                local s = source_of(mantle.audio:get())
                if s then mantle.audio:toggle_mute(s.id) end
            end,
        }, "paper.disc.quick.mic", function()
            local s = source_of(mantle.audio:get())
            return s and s.muted and "Unmute microphone" or "Mute microphone"
        end), "on_wheel", nudge_mic),
        controls.slider {
            id = "quick.mic",
            accessible_name = "Microphone volume",
            width = SLIDER_W,
            show_value = false,
            value = mantle.audio:map(function(a)
                local s = source_of(a)
                return s and (s.volume or 0) / 100 or 0
            end, 0),
            on_change = function(v)
                local s = source_of(mantle.audio:get())
                if s then mantle.audio:set_volume(s.id, math.floor(v * 100 + 0.5)) end
            end,
            on_wheel = nudge_mic,
        },
        percent_label(mantle.audio:map(function(a)
            local s = source_of(a)
            return s and s.muted and "muted" or string.format("%d%%", math.floor((s and s.volume or 0) + 0.5))
        end, "")),
        with_choice(chooser_disc("sources", "Input device"), "sources"),
    },
}

local brightness = row {
    width = "fill",
    spacing = theme.spacing.md,
    visible = mantle.brightness:map(function(b) return b ~= nil end, false),
    children = {
        rect { width = theme.control.option, height = theme.control.option, children = { icons.doodle(G.brightness, theme.icon.md) } },
        controls.slider {
            id = "quick.brightness",
            width = SLIDER_W,
            show_value = false,
            value = mantle.brightness:map(function(b) return b.percent / 100 end, 0),
            -- Never fully dark from a slider: 1% keeps the screen readable enough to drag back.
            on_change = function(v) mantle.brightness:set(math.max(1, math.floor(v * 100 + 0.5))) end,
            on_wheel = nudge_brightness,
        },
        percent_label(mantle.brightness:map(function(b) return b.percent .. "%" end, "")),
        rect { width = theme.quick.brightness_step_w },
    },
}

-- The sheet -------------------------------------------------------------------------------------

local has_brightness = mantle.brightness:map(function(b) return b ~= nil end, false)

-- The torn edge is cut for a fixed size, so the sheet is rebuilt when a tile or slider comes or goes.
local flagged = section:map(function(s) return s == "privacy" end)

-- The open device list's kind and devices, as a key: the sheet is rebuilt only when it opens,
-- closes, or its devices come or go, not on every volume push.
local listed = computed({ chooser, mantle.audio }, function(kind, a)
    if kind == "" or not a then return "" end
    local parts = { kind }
    for _, d in ipairs(a[kind] or {}) do parts[#parts + 1] = d.id .. "=" .. d.name end
    return table.concat(parts, "\n")
end, "")

local function build_sheet(count, lit, in_use, mic_shown, key, output)
    local rows = (count + 1) // 2
    local strip = privacy.height(#in_use)
    local kind = key:match("^[^\n]*")
    local list = kind ~= "" and devices.build(kind, mantle.audio:get(), W - 2 * PAD, tips) or nil
    local list_h = list and devices.height(#(mantle.audio:get()[kind] or {})) + GAP or 0
    local slider_row = theme.control.option + GAP
    local height = 2 * PAD + theme.control.button + GAP + theme.controls.divider_thickness + GAP + slider_row
        + (strip > 0 and strip + GAP or 0) + (mic_shown and slider_row or 0) + list_h + (lit and slider_row or 0)
        + rows * tiles.HEIGHT + (rows - 1) * theme.spacing.snug
    local max_height = math.max(1, ui_state.screen_height(output) - ui_state.BAR_H - ui_state.BAR_HEADROOM
        - 2 * (POPUP_PAD + theme.paper.card_pad))
    local body = { header }
    if #in_use > 0 then body[#body + 1] = privacy.build(in_use, W - 2 * PAD, tips, flagged) end
    body[#body + 1] = controls.divider(W - 2 * PAD, false, 7)
    body[#body + 1] = volume
    if kind == "sinks" then body[#body + 1] = list end
    body[#body + 1] = mic
    if kind == "sources" then body[#body + 1] = list end
    body[#body + 1] = brightness
    body[#body + 1] = row { width = "fill", wrap = true, spacing = theme.spacing.sm, line_spacing = theme.spacing.snug, children = tiles.build(tips) }
    return k.card {
        width = W,
        height = math.min(height, max_height),
        seed = 811,
        rotate = 0.4,
        color = theme.STOCK.plain[1],
        tapes = { { width = theme.quick.tape_w, height = theme.control.check, translate = { y = -theme.spacing.snug }, rotate = -3, seed = 23, color = theme.QUICK_TAPE } },
        child = column {
            width = "fill",
            height = "fill",
            spacing = GAP,
            padding = PAD,
            scroll = height > max_height and sheet_scroll or nil,
            children = body,
        },
    }
end

local sheet = computed({ tiles.count, has_brightness, privacy.in_use, has_source, listed, anchor_output }, build_sheet)

M.surfaces = {
    popup {
        id = "paper-quick",
        parent = "paper-taskbar",
        visible = open,
        anchor_rect = anchor,
        anchor = "top_right",
        gravity = "top_left",
        offset = { y = -theme.spacing.xs },
        constraint_adjustment = { "slide_x", "flip_y" },
        grab = true,
        on_escape = close,
        reset_on_close = { section, chooser, sheet_scroll },
        on_dismiss = function()
            dismissed_at = mantle.clock:now()
            close()
        end,
        child = rect {
            padding = POPUP_PAD,
            children = sheet:map(function(card) return { card } end),
        },
    },
    tips.surface,
}

return M
