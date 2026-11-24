-- Quick-settings toggle tiles: card-stock scraps with a paper disc, a Caveat name and a status
-- line. On, a tile turns to blue stock and is hatched in pencil, so state never rests on colour.
local k = require("lib.paper")
local G = require("modules.quick.glyphs")
local icons = require("components.icons")
local util = require("lib.util")

local TW, TH = 214, 78

local function tile(o)
    local hovered = hover("quick.tile." .. o.id)
    local on = o.on
    local ink = on:map(function(v) return v and k.DEEP_BLUE or k.INK end)
    return rect {
        width = TW,
        height = TH,
        visible = o.visible,
        hover = hovered,
        accessible_name = o.label,
        cursor = "pointer",
        on_click = o.on_click,
        rotate = hovered:map(function(v) return v and -1.5 or o.tilt end),
        translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
        animate = {
            rotate = { spring = { stiffness = 300, damping = 16 } },
            translate = { duration = 140, easing = "out_cubic" },
        },
        children = {
            rect {
                width = "fill",
                height = "fill",
                shape = k.torn(TW, TH, o.seed, 3),
                background = on:map(function(v) return v and k.STOCK.primary[1] or k.STOCK.plain[1] end),
                shadows = k.lift(hovered),
                animate = { shadows = { duration = 160, easing = "out_cubic" }, background = { duration = 140 } },
                effect = on:map(function(v)
                    return k.paper_fx { rim = 0, hatch = v and 1 or 0, hatch_color = { 0.2, 0.38, 0.7, 0.22 }, hatch_spacing = 5 }
                end),
            },
            row {
                width = "fill",
                height = "fill",
                spacing = 12,
                padding = { left = 12, right = 8 },
                children = {
                    rect {
                        width = 44,
                        height = 44,
                        align_v = "center",
                        children = {
                            k.sheet {
                                width = 44, height = 44, shape = k.torn_circle(44, o.seed + 1), color = "#F6EFDF",
                                shadows = k.SHADOW.rest, fx = { rim = 1.4 },
                            },
                            util.with(icons.doodle(o.icon, 22, on:map(function(v) return v and k.BLUE or k.INK end)),
                                "align_h", "center"),
                        },
                    },
                    column {
                        width = "fill",
                        align_v = "center",
                        spacing = -2,
                        children = {
                            k.hand(o.label, 25, { font_weight = 700, foreground = ink, elide = "end", width = "fill" }),
                            k.body(o.status, 17, { foreground = ink, elide = "end", width = "fill" }),
                        },
                    },
                },
            },
        },
    }
end

local network = mantle.network
local wifi_on = network:map(function(n) return n.wifi_enabled and n.wifi_present end, false)
local bt_on = mantle.bluetooth:map(function(b) return b.enabled end, false)
local dnd_on = mantle.notifications:map(function(n) return n.dnd end, false)
local airplane_on = mantle.radio:map(function(r)
    if #r.radios == 0 then return false end
    for _, radio in ipairs(r.radios) do
        if not (radio.soft_blocked or radio.hard_blocked) then return false end
    end
    return true
end, false)
local profile = mantle.power:map(function(p) return p.active_profile or "" end, "")

local PROFILE_NAMES = { ["power-saver"] = "Power saver", balanced = "Balanced", performance = "Performance" }

local function next_profile()
    local p = mantle.power:get()
    local list = p and p.profiles or {}
    for i, name in ipairs(list) do
        if name == p.active_profile then
            mantle.power:set_profile(list[i % #list + 1])
            return
        end
    end
    if list[1] then mantle.power:set_profile(list[1]) end
end

local count = computed({ network, mantle.bluetooth, mantle.power, mantle.radio }, function(n, b, p, r)
    local c = 1
    if n and n.wifi_present then c = c + 1 end
    if b and b.available then c = c + 1 end
    if p and p.profiles and #p.profiles > 1 then c = c + 1 end
    if r and #r.radios > 0 then c = c + 1 end
    return c
end)

return {
    HEIGHT = TH,
    -- How many tiles show, so the sheet can be cut to fit.
    count = count,
    build = function(tips)
        local tiles = {
            tile {
                id = "wifi", label = "Wi-Fi", seed = 41, tilt = -0.6,
                icon = wifi_on:map(function(v) return v and G.wifi or G.wifi_off end),
                on = wifi_on,
                status = network:map(function(n)
                    if not n.wifi_enabled then return "Off" end
                    return n.ssid and n.ssid ~= "Ethernet" and n.ssid or "Not connected"
                end, ""),
                visible = network:map(function(n) return n.wifi_present end, false),
                on_click = function()
                    local n = network:get()
                    if n then network:set_wifi_enabled(not n.wifi_enabled) end
                end,
            },
            tile {
                id = "bluetooth", label = "Bluetooth", seed = 43, tilt = 0.6,
                icon = bt_on:map(function(v) return v and G.bluetooth or G.bluetooth_off end),
                on = bt_on,
                status = mantle.bluetooth:map(function(b)
                    if not b.enabled then return "Off" end
                    local n = #b.connected_devices
                    if n == 1 then return b.connected_devices[1].name or "1 device" end
                    return n > 0 and n .. " devices" or "On"
                end, ""),
                visible = mantle.bluetooth:map(function(b) return b.available end, false),
                on_click = function()
                    local b = mantle.bluetooth:get()
                    if b then mantle.bluetooth:set_enabled(not b.enabled) end
                end,
            },
            tile {
                id = "dnd", label = "Do not disturb", seed = 47, tilt = 0,
                icon = G.dnd,
                on = dnd_on,
                status = dnd_on:map(function(v) return v and "Sounds muted" or "Off" end),
                on_click = function() mantle.notifications:set_dnd(not dnd_on:get()) end,
            },
            tile {
                id = "profile", label = "Power mode", seed = 53, tilt = -0.6,
                icon = profile:map(function(p) return G.profile[p] or G.profile.balanced end),
                -- "Balanced" is the resting mode; the other two are a choice someone made.
                on = profile:map(function(p) return p ~= "" and p ~= "balanced" end),
                status = profile:map(function(p) return PROFILE_NAMES[p] or p end),
                visible = mantle.power:map(function(p) return p.profiles ~= nil and #p.profiles > 1 end, false),
                on_click = next_profile,
            },
            tile {
                id = "airplane", label = "Airplane", seed = 59, tilt = 0.6,
                icon = G.airplane,
                on = airplane_on,
                status = airplane_on:map(function(v) return v and "Radios off" or "Off" end),
                visible = mantle.radio:map(function(r) return #r.radios > 0 end, false),
                on_click = function() mantle.radio:set_all_blocked(not airplane_on:get()) end,
            },
        }
        -- The network name can be cut short on the tile.
        tiles[1] = tips.wrap(tiles[1], "quick.tile.wifi", function()
            local n = network:get()
            if not (n and n.wifi_enabled) then return "Wi-Fi is off" end
            return n.ssid and n.ssid ~= "Ethernet" and "Connected to " .. n.ssid or "Wi-Fi is on, no network joined"
        end)
        return tiles
    end,
}
