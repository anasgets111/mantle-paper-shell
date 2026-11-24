-- The right end of the taskbar: status icons (one button for quick settings), the date and time
-- (the notification centre), and the show-desktop strip at the edge.
local k = require("lib.paper")
local quick = require("modules.quick")
local notifications = require("modules.notifications")
local icons = require("modules.taskbar.icons")
local tips = require("modules.taskbar.tips")
local menus = require("modules.taskbar.menus")
local press = require("modules.taskbar.press")

local M = {}

local now = mantle.clock:map(function(s) return s.time end, os.time())

-- Doodle names for the live levels. Pure, so every name they can return is a known glyph.
function M.wifi_name(n)
    if not n or not n.connected then return "wifi-off" end
    if n.ssid == "Ethernet" then return "ethernet" end
    for _, d in ipairs(n.wifi_devices or {}) do
        if d.connected then return "wifi-" .. math.max(0, math.min(4, math.floor((d.strength + 12) / 25))) end
    end
    return "wifi-0"
end

function M.bluetooth_name(b)
    return (b and b.enabled) and "bluetooth" or "bluetooth-off"
end

local function default_sink(a)
    for _, s in ipairs(a and a.sinks or {}) do
        if s.active then return s end
    end
end

function M.volume_name(a)
    local s = default_sink(a)
    if not s or s.muted or (s.volume or 0) == 0 then return "volume-muted" end
    local v = s.volume or 0
    return v > 66 and "volume-high" or v > 33 and "volume-medium" or "volume-low"
end

function M.battery_name(b)
    if not b or not b.present then return "battery-0" end
    if b.state == "charging" then return "battery-charging" end
    return "battery-" .. math.max(0, math.min(4, math.floor((b.percent + 12) / 25)))
end

local battery = mantle.battery:map(function(b) return b.present and b or false end, false)

-- One line for the status tooltip: "Wi-Fi: home (72%) · Bluetooth on · Volume 40% · Battery 80%".
local function status_text()
    local parts = {}
    local n = mantle.network:get()
    if not n or not n.connected then
        parts[1] = "Offline"
    elseif n.ssid == "Ethernet" then
        parts[1] = "Wired"
    else
        local strength
        for _, d in ipairs(n.wifi_devices or {}) do
            if d.connected then strength = d.strength end
        end
        parts[1] = "Wi-Fi: " .. (n.ssid or "?") .. (strength and (" (" .. strength .. "%)") or "")
    end
    local b = mantle.bluetooth:get()
    parts[#parts + 1] = (b and b.enabled) and "Bluetooth on" or "Bluetooth off"
    local s = default_sink(mantle.audio:get())
    if s then parts[#parts + 1] = s.muted and "Muted" or ("Volume " .. math.floor((s.volume or 0) + 0.5) .. "%") end
    local bat = mantle.battery:get()
    if bat and bat.present then
        parts[#parts + 1] = "Battery " .. bat.percent .. "%" .. (bat.state == "charging" and ", charging" or "")
    end
    return table.concat(parts, " \u{00B7} ")
end

-- A yellow highlighter swipe behind a hovered button, as on the menu rows.
-- Fills the button, whatever its content: the button is a stack sized by its row.
local function swipe(hovered, h, seed)
    return rect {
        width = "fill",
        height = h,
        align_v = "center",
        background = k.HIGHLIGHT,
        blend = "multiply",
        shape = k.tape_shape(nil, nil, seed),
        opacity = hovered:map(function(v) return v and 1 or 0 end),
        animate = { opacity = { duration = 120 } },
    }
end

local function button(o)
    local hovered = hover(o.name)
    return tips.wrap(rect {
        height = "fill",
        hover = hovered,
        accessible_name = o.label,
        cursor = "pointer",
        on_click = o.on_click,
        on_drag = press.track(o.name),
        children = {
            swipe(hovered, 30, o.seed),
            row {
                height = "fill",
                spacing = o.spacing or 12,
                padding = { left = 10, right = 10 },
                translate = hovered:map(function(v) return { y = v and -2 or 0 } end),
                scale = press.scale(o.name),
                animate = {
                    translate = { duration = 140, easing = "out_cubic" },
                    scale = { duration = 80, easing = "out_cubic" },
                },
                children = o.children,
            },
        },
    }, o.name, o.tip)
end

function M.icons(output)
    return button {
        name = "taskbar.status." .. output,
        label = "Quick settings",
        seed = 21,
        on_click = function(r, button)
            if button == "middle" then
                local s = default_sink(mantle.audio:get())
                if s then mantle.audio:toggle_mute(s.id) end
            elseif button == "right" then
                menus.open_settings(r)
            else
                quick.open(r)
            end
        end,
        tip = status_text,
        children = {
            icons.doodle(mantle.network:map(M.wifi_name, "wifi-off"), icons.STATUS),
            icons.doodle(mantle.bluetooth:map(M.bluetooth_name, "bluetooth-off"), icons.STATUS),
            -- Wheel over the speaker: the default sink, 5 % a notch.
            rect {
                align_v = "center",
                on_wheel = function(_, steps)
                    local s = default_sink(mantle.audio:get())
                    if not s then return end
                    mantle.audio:set_volume(s.id, math.max(0, math.min(100, (s.volume or 0) + 5 * steps)))
                end,
                children = { icons.doodle(mantle.audio:map(M.volume_name, "volume-muted"), icons.STATUS) },
            },
            row {
                spacing = 4,
                visible = battery:map(function(b) return b ~= false end),
                children = {
                    icons.doodle(battery:map(M.battery_name), icons.STATUS),
                    k.body(battery:map(function(b) return b and (b.percent .. "%") or "" end), 19,
                        { align_v = "center" }),
                },
            },
        },
    }
end

function M.clock(output)
    local unread = notifications.unread:map(function(n) return (n or 0) > 0 end)
    return button {
        name = "taskbar.clock." .. output,
        label = "Date, calendar and notifications",
        seed = 34,
        spacing = 10,
        on_click = function(r) notifications.open_center(r) end,
        tip = function() return (os.date("%A, %d %B %Y"):gsub(" 0(%d)", " %1")) end,
        children = {
            k.body(now:map(function(t) return os.date("%a, %d %b", t) end), 19,
                { foreground = k.INK_SOFT, align_v = "center" }),
            k.body(now:map(function(t) return (os.date("%I:%M %p", t):gsub("^0", "")) end), 19,
                { font_weight = 700, align_v = "center" }),
            -- Unread notifications: a red marker bell.
            rect { visible = unread, align_v = "center", children = { icons.doodle("bell", icons.STATUS, k.RED) } },
        },
    }
end

-- Show desktop: Hyprland has no minimize through Mantle, so this hops to an empty workspace and back.
local desktop_return = state("taskbar.desktop_return", "")

local function show_desktop(output)
    local w = mantle.workspaces:get()
    if not w then return end
    local mine, used = nil, {}
    for _, o in ipairs(w.outputs) do
        for _, e in ipairs(o.workspaces) do
            if e.number then used[e.number] = e.populated end
        end
        if o.name == output then mine = o end
    end
    if not mine then return end
    local back = desktop_return:get()
    local here
    for _, e in ipairs(mine.workspaces) do
        if e.id == mine.active_workspace then here = e end
    end
    if back ~= "" and here and not here.populated then
        desktop_return:set("")
        mantle.workspaces:focus(back)
        return
    end
    local n = 1
    while used[n] ~= nil do n = n + 1 end
    desktop_return:set(mine.active_workspace)
    mantle.workspaces:focus(tostring(n))
end

function M.desktop_strip(output)
    local hovered = hover("taskbar.desktop." .. output)
    return tips.wrap(rect {
        width = 14,
        height = "fill",
        hover = hovered,
        accessible_name = "Show desktop",
        cursor = "pointer",
        on_click = function() show_desktop(output) end,
        children = {
            path {
                width = 6,
                height = 34,
                align_h = "center",
                align_v = "center",
                stroke = hovered:map(function(v) return v and k.BLUE or "#3A363160" end),
                stroke_width = hovered:map(function(v) return v and 2.4 or 1.3 end),
                stroke_cap = "round",
                commands = { { op = "M", points = { 3, 2 } }, { op = "Q", points = { 4.5, 17, 3, 32 } } },
            },
        },
    }, "taskbar.desktop." .. output, "Show desktop")
end

return M
