-- Quick settings (GNOME system menu): a card-stock sheet that pops up from the taskbar's status
-- icons. Interface the taskbar relies on:
--   surfaces      list of popups to add to the shell
--   open(rect, section?)  toggle the quick-settings popup anchored to the clicked status icons;
--                         section "privacy" circles the "In use" strip (the privacy stickers)
local k = require("lib.paper")
local util = require("lib.util")
local icons = require("components.icons")
local controls = require("components.controls")
local ui_state = require("lib.ui_state")
local tiles = require("modules.quick.tiles")
local privacy = require("modules.quick.privacy")
local G = require("modules.quick.glyphs")
local tooltip = require("components.tooltip")
local recorder = require("modules.recorder")

local M = {}

local W = 500
local MAX_VOLUME = 150

local open = state("quick.open", false)
-- True while the popup is shown, so the notification toasts can stay clear of it.
M.is_open = open
local anchor = state("quick.anchor", { x = 0, y = 0, width = 1, height = 1 })
-- The section the opener asked for; "" for none.
local section = state("quick.section", "")

-- A click on the status icons while open dismisses the grab first; if that same click then reaches
-- `open`, it must close rather than reopen.
local dismissed_at = -1

function M.open(r, wanted)
    if open:get() or mantle.clock:now() - dismissed_at < 0.3 then
        open:set(false)
        return
    end
    section:set(wanted or "")
    -- One surface at a time: a modal left open would sit under the sheet holding the keyboard.
    ui_state.active_modal:set("")
    anchor:set({ x = r.x or 0, y = r.y or 0, width = math.max(1, r.width or 1), height = math.max(1, r.height or 1) })
    open:set(true)
end

local function close() open:set(false) end

local tips = tooltip.new { id = "paper-quick-tip", parent = "paper-quick", side = "top" }

local function sink_of(audio)
    for _, sink in ipairs(audio and audio.sinks or {}) do
        if sink.active then return sink end
    end
end

-- One wheel notch is 5%, as on the taskbar's volume icon.
local function nudge_volume(_, steps)
    local s = sink_of(mantle.audio:get())
    if s then mantle.audio:set_volume(s.id, math.max(0, math.min(MAX_VOLUME, (s.volume or 0) + steps * 5))) end
end

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
        id = "quick." .. id, icon = icon_name, size = 46, tooltip = tooltip,
        on_click = function()
            close()
            fn()
        end,
    }, "paper.disc.quick." .. id, tooltip)
end

local header = row {
    width = "fill",
    spacing = 12,
    children = {
        icons.doodle_for(mantle.battery:map(function(b) return b.present and battery_icon(b) or G.ac end, G.ac), 22),
        k.body(mantle.battery:map(battery_line, ""), 21, { align_v = "center", width = "fill" }),
        action_disc("settings", G.settings, "Settings", function() ui_state.toggle_modal("settings") end),
        action_disc("lock", G.lock, "Lock", function() mantle.lock:lock() end),
        action_disc("record", "video", "Record screen", function() recorder.open(anchor:get()) end),
        action_disc("power", G.power, "Power", function() ui_state.toggle_modal("startmenu") end),
    },
}

-- Sliders ---------------------------------------------------------------------------------------

local function percent_label(value)
    return k.body(value, 20, { align_v = "center", width = 50 })
end

local volume = row {
    width = "fill",
    spacing = 12,
    visible = mantle.audio:map(function(a) return sink_of(a) ~= nil end, false),
    children = {
        util.with(tips.wrap(controls.disc_button {
            id = "quick.mute",
            seed = 61,
            size = 38,
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
            width = 320,
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
    },
}

local brightness = row {
    width = "fill",
    spacing = 12,
    visible = mantle.brightness:map(function(b) return b ~= nil end, false),
    children = {
        rect { width = 38, height = 38, children = { icons.doodle(G.brightness, 20) } },
        controls.slider {
            id = "quick.brightness",
            width = 320,
            show_value = false,
            value = mantle.brightness:map(function(b) return b.percent / 100 end, 0),
            -- Never fully dark from a slider: 1% keeps the screen readable enough to drag back.
            on_change = function(v) mantle.brightness:set(math.max(1, math.floor(v * 100 + 0.5))) end,
            on_wheel = nudge_brightness,
        },
        percent_label(mantle.brightness:map(function(b) return b.percent .. "%" end, "")),
    },
}

-- The sheet -------------------------------------------------------------------------------------

local has_brightness = mantle.brightness:map(function(b) return b ~= nil end, false)

-- The torn edge is cut for a fixed size, so the sheet is rebuilt when a tile or slider comes or goes.
local flagged = section:map(function(s) return s == "privacy" end)

local sheet = computed({ tiles.count, has_brightness, privacy.in_use }, function(count, lit, in_use)
    local rows = (count + 1) // 2
    local strip = privacy.height(#in_use)
    local height = 28 + 46 + 18 + (strip > 0 and strip + 18 or 0) + 6 + 18 + 38 + (lit and 56 or 0) + 18
        + rows * tiles.HEIGHT + (rows - 1) * 10 + 28
    return k.card {
        width = W,
        height = height,
        seed = 811,
        rotate = 0.4,
        color = k.STOCK.plain[1],
        tapes = { { width = 96, height = 22, translate = { y = -10 }, rotate = -3, seed = 23, color = "#B4CBE6" } },
        child = column {
            width = "fill",
            height = "fill",
            spacing = 18,
            padding = { left = 28, right = 28, top = 28, bottom = 28 },
            children = util.concat(
                { header },
                util.concat(#in_use > 0 and { privacy.build(in_use, W - 56, tips, flagged) } or {}, {
                    controls.divider(W - 56, false, 7),
                    volume,
                    brightness,
                    row { width = "fill", wrap = true, spacing = 8, line_spacing = 10, children = tiles.build(tips) },
                })
            ),
        },
    }
end)

M.surfaces = {
    popup {
        id = "paper-quick",
        parent = "paper-taskbar",
        visible = open,
        anchor_rect = anchor,
        anchor = "top_right",
        gravity = "top_left",
        offset = { y = -6 },
        constraint_adjustment = { "slide_x", "flip_y" },
        grab = true,
        on_escape = close,
        reset_on_close = { section },
        on_dismiss = function()
            dismissed_at = mantle.clock:now()
            close()
        end,
        child = rect {
            padding = 18,
            children = sheet:map(function(card) return { card } end),
        },
    },
    tips.surface,
}

return M
