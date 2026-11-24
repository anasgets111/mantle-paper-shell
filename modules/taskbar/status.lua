-- The right end of the taskbar: status icons (one button for quick settings), the date and time
-- (the notification centre), and the show-desktop strip at the edge.
local k = require("lib.paper")
local quick = require("modules.quick")
local notifications = require("modules.notifications")
local icons = require("modules.taskbar.icons")

local M = {}

local now = mantle.clock:map(function(s) return s.time end, os.time())

local wifi_icon = mantle.network:map(function(n)
    if not n.connected then return "network-offline-symbolic" end
    if n.ssid == "Ethernet" then return "network-wired-symbolic" end
    return "network-wireless-symbolic"
end, "network-wireless-symbolic")

local bt_icon = mantle.bluetooth:map(function(b)
    return b.enabled and "bluetooth-active-symbolic" or "bluetooth-disabled-symbolic"
end, "bluetooth-disabled-symbolic")

local volume_icon = mantle.audio:map(function(a)
    for _, s in ipairs(a.sinks or {}) do
        if s.active then
            if s.muted then return "audio-volume-muted-symbolic" end
            local v = s.volume or 0
            return v > 66 and "audio-volume-high-symbolic" or v > 33 and "audio-volume-medium-symbolic"
                or "audio-volume-low-symbolic"
        end
    end
    return "audio-volume-muted-symbolic"
end, "audio-volume-high-symbolic")

local battery = mantle.battery:map(function(b) return b.present and b or false end, false)

local function battery_icon(b)
    if not b then return "battery-missing-symbolic" end
    local level = b.percent > 80 and "full" or b.percent > 40 and "good" or b.percent > 15 and "low" or "caution"
    return "battery-" .. level .. (b.state == "charging" and "-charging" or "") .. "-symbolic"
end

-- A yellow highlighter swipe behind a hovered button, as on the menu rows.
local function swipe(hovered, w, h, seed)
    return rect {
        width = w,
        height = h,
        align_v = "center",
        background = k.HIGHLIGHT,
        blend = "multiply",
        shape = k.tape_shape(w, h, seed),
        opacity = hovered:map(function(v) return v and 1 or 0 end),
        animate = { opacity = { duration = 120 } },
    }
end

local function button(o)
    local hovered = hover(o.name)
    return rect {
        height = "fill",
        hover = hovered,
        accessible_name = o.label,
        cursor = "pointer",
        on_click = o.on_click,
        children = {
            swipe(hovered, o.swipe_w, 30, o.seed),
            row {
                height = "fill",
                spacing = o.spacing or 12,
                padding = { left = 10, right = 10 },
                translate = hovered:map(function(v) return { y = v and -2 or 0 } end),
                animate = { translate = { duration = 140, easing = "out_cubic" } },
                children = o.children,
            },
        },
    }
end

function M.icons(output)
    return button {
        name = "taskbar.status." .. output,
        label = "Quick settings",
        swipe_w = 178,
        seed = 21,
        on_click = function(r) quick.open(r) end,
        children = {
            icons.glyph(wifi_icon, 20),
            icons.glyph(bt_icon, 20),
            icons.glyph(volume_icon, 20),
            row {
                spacing = 4,
                visible = battery:map(function(b) return b ~= false end),
                children = {
                    icons.glyph(battery:map(battery_icon), 20),
                    k.body(battery:map(function(b) return b and (b.percent .. "%") or "" end), 19, { align_v = "center" }),
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
        swipe_w = 210,
        seed = 34,
        spacing = 10,
        on_click = function(r) notifications.open_center(r) end,
        children = {
            k.body(now:map(function(t) return os.date("%a, %d %b", t) end), 19,
                { foreground = k.INK_SOFT, align_v = "center" }),
            k.body(now:map(function(t) return (os.date("%I:%M %p", t):gsub("^0", "")) end), 19,
                { font_weight = 700, align_v = "center" }),
            rect {
                width = 9,
                height = 9,
                align_v = "center",
                visible = unread,
                background = k.RED,
                shape = k.torn_circle(9, 5, 0.8),
            },
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
    return rect {
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
    }
end

return M
