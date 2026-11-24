-- Quick settings (GNOME system menu): a card-stock sheet that pops up from the taskbar's status
-- icons. Interface the taskbar relies on:
--   surfaces      list of popups to add to the shell
--   open(rect)    toggle the quick-settings popup anchored to the clicked status icons
local k = require("lib.paper")
local controls = require("components.controls")
local ui_state = require("lib.ui_state")
local tiles = require("modules.quick.tiles")

local M = {}

local W = 480
local MAX_VOLUME = 150

local open = state("quick.open", false)
local anchor = state("quick.anchor", { x = 0, y = 0, width = 1, height = 1 })

function M.open(r)
    if open:get() then
        open:set(false)
        return
    end
    anchor:set({ x = r.x or 0, y = r.y or 0, width = math.max(1, r.width or 1), height = math.max(1, r.height or 1) })
    open:set(true)
end

local function close() open:set(false) end

local function sink_of(audio)
    for _, sink in ipairs(audio and audio.sinks or {}) do
        if sink.active then return sink end
    end
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
    return controls.disc_button {
        id = "quick." .. id, icon = icon_name, size = 46, tooltip = tooltip,
        on_click = function()
            close()
            fn()
        end,
    }
end

local header = row {
    width = "fill",
    spacing = 12,
    children = {
        icon {
            name = mantle.battery:map(function(b) return b.present and battery_icon(b) or "ac-adapter-symbolic" end,
                "ac-adapter-symbolic"),
            size = 22, foreground = k.INK, align_v = "center",
        },
        k.body(mantle.battery:map(battery_line, ""), 21, { align_v = "center", width = "fill" }),
        action_disc("settings", "emblem-system-symbolic", "Settings", function() ui_state.toggle_modal("settings") end),
        action_disc("lock", "system-lock-screen-symbolic", "Lock", function() mantle.lock:lock() end),
        action_disc("power", "system-shutdown-symbolic", "Power", function() ui_state.toggle_modal("startmenu") end),
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
        controls.disc_button {
            id = "quick.mute",
            seed = 61,
            size = 38,
            tooltip = "Mute",
            icon = mantle.audio:map(function(a)
                local s = sink_of(a)
                if not s or s.muted or (s.volume or 0) <= 0 then return "audio-volume-muted-symbolic" end
                return s.volume < 50 and "audio-volume-low-symbolic" or "audio-volume-high-symbolic"
            end, "audio-volume-high-symbolic"),
            on_click = function()
                local s = sink_of(mantle.audio:get())
                if s then mantle.audio:toggle_mute(s.id) end
            end,
        },
        -- The bar spans the sink's whole range, 0 to 150%, so a boosted volume still has a place on it.
        controls.slider {
            id = "quick.volume",
            width = 300,
            show_value = false,
            value = mantle.audio:map(function(a)
                local s = sink_of(a)
                return s and (s.volume or 0) / MAX_VOLUME or 0
            end, 0),
            on_change = function(v)
                local s = sink_of(mantle.audio:get())
                if s then mantle.audio:set_volume(s.id, math.floor(v * MAX_VOLUME + 0.5)) end
            end,
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
        rect { width = 38, height = 38, children = { k.glyph("display-brightness-symbolic", 20) } },
        controls.slider {
            id = "quick.brightness",
            width = 300,
            show_value = false,
            value = mantle.brightness:map(function(b) return b.percent / 100 end, 0),
            -- Never fully dark from a slider: 1% keeps the screen readable enough to drag back.
            on_change = function(v) mantle.brightness:set(math.max(1, math.floor(v * 100 + 0.5))) end,
        },
        percent_label(mantle.brightness:map(function(b) return b.percent .. "%" end, "")),
    },
}

-- The sheet -------------------------------------------------------------------------------------

local has_brightness = mantle.brightness:map(function(b) return b ~= nil end, false)

-- The torn edge is cut for a fixed size, so the sheet is rebuilt when a tile or slider comes or goes.
local sheet = computed({ tiles.count, has_brightness }, function(count, lit)
    local rows = (count + 1) // 2
    local height = 24 + 46 + 16 + 6 + 16 + 38 + (lit and 54 or 0) + 16 + rows * tiles.HEIGHT + (rows - 1) * 10 + 22
    return k.card {
        width = W,
        height = height,
        seed = 811,
        rotate = 0.4,
        color = k.STOCK.plain[1],
        tapes = { { width = 96, height = 22, translate = { y = -10 }, rotate = -3, seed = 23, color = "#A9C3E3B8" } },
        child = column {
            width = "fill",
            height = "fill",
            spacing = 16,
            padding = { left = 22, right = 22, top = 24, bottom = 22 },
            children = {
                header,
                controls.divider(W - 44, false, 7),
                volume,
                brightness,
                row { width = "fill", wrap = true, spacing = 8, line_spacing = 10, children = tiles.build() },
            },
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
        on_escape = close,
        on_dismiss = close,
        child = rect {
            padding = 18,
            -- Hyprland's `blur_popups` frosts a whole popup that asks for no blur region; a blur box
            -- under the opaque sheet makes the region the sheet itself, where the blur never shows.
            children = sheet:map(function(card)
                return { rect { width = W - 16, height = "fill", margin = 14, compositor_blur = true }, card }
            end),
        },
    },
}

return M
