-- Wi-Fi page: radio power, wired link, visible networks (join, disconnect, forget), the password
-- line for a secured join, a hidden network, and VPN profiles with their secret prompts.
local k = require("lib.paper")
local c = require("components.controls")
local rows = require("modules.settings.rows")
local tips = require("modules.settings.tips")
local icons = require("modules.settings.icons")

local net = mantle.network

-- A Connect link can sit far down a long list; the key line is at the top, so go there.
net:map(function(n) return n.password_ssid ~= nil end, false):on_change(function(asking)
    if asking then scroll("settings.scroll.wifi"):scroll_to(0) end
end)

local function wifi_device(n)
    return n and n.wifi_devices and n.wifi_devices[1]
end

local function status(n)
    if not n then return "" end
    if not n.wifi_enabled then return "Off" end
    local dev = wifi_device(n)
    if n.connecting_ssid then return "Joining " .. n.connecting_ssid .. "…" end
    if dev and dev.ssid then
        return "Connected to " .. dev.ssid .. (dev.wifi_ip and ("  ·  " .. dev.wifi_ip) or "")
    end
    return dev and dev.scanning and "Looking for networks…" or "Not connected"
end

local function radio_rows()
    return {
        rows.heading("Wireless", {
            tips.wrap(c.disc_button {
                id = "settings.wifi.scan", icon = icons.name("refresh"), size = 34, tooltip = "Scan for networks",
                on_click = function() net:scan() end,
            }, "paper.disc.settings.wifi.scan", "Scan for networks"),
        }),
        rows.line({
            rows.label("Wi-Fi"),
        }, {
            rows.caption(net:map(status, "")),
            c.toggle {
                id = "settings.wifi.power",
                value = net:map(function(n) return n.wifi_enabled end, false),
                on_toggle = function(on) net:set_wifi_enabled(on) end,
            },
        }),
    }
end

local function ethernet_rows()
    return column {
        width = "fill",
        visible = net:map(function(n) return n.ethernet_present end, false),
        children = {
            rows.line({
                rows.label("Wired"),
            }, {
                rows.caption(net:map(function(n)
                    if not n.ethernet_enabled then return "Off" end
                    local speed = n.ethernet_speed and ("  ·  " .. n.ethernet_speed .. " Mb/s") or ""
                    return (n.ethernet_ip or "No address") .. speed
                end, "")),
                c.toggle {
                    id = "settings.wifi.ethernet",
                    value = net:map(function(n) return n.ethernet_enabled end, false),
                    on_toggle = function(on) net:set_ethernet_enabled(on) end,
                },
            }),
        },
    }
end

-- The key line: shown while NetworkManager waits for a secured network's key. The key goes
-- straight to the engine through `secure_submit`; Lua never sees it.
local function password_rows()
    return column {
        width = "fill",
        visible = net:map(function(n) return n.password_ssid ~= nil end, false),
        children = {
            rows.line({
                icons.glyph("password", 20),
                rows.label(net:map(function(n)
                    return n.password_ssid and ("Key for " .. n.password_ssid) or ""
                end, "")),
            }, {
                rows.button("wifi.cancel", "Cancel", "plain", function() net:cancel_connect() end),
            }),
            rows.line({
                c.field {
                    id = "settings.wifi.key",
                    width = 420,
                    size = 22,
                    placeholder = "Password, then Enter",
                    autofocus = true,
                    secure_submit = { capability = "network", action = "connect" },
                    on_cancel = function() net:cancel_connect() end,
                },
            }),
        },
    }
end

local function error_row()
    return column {
        width = "fill",
        visible = net:map(function(n) return n.connect_error ~= nil end, false),
        children = {
            rows.line({
                icons.glyph("warning", 20, k.DEEP_RED),
                rows.label(net:map(function(n)
                    local e = n.connect_error
                    return e and string.format("Couldn't join %s: %s", e.ssid, e.message) or ""
                end, ""), { foreground = k.DEEP_RED }),
            }),
        },
    }
end

local function network_row(ap, busy)
    local right = {}
    if busy == ap.ssid then
        right[#right + 1] = rows.caption("joining…")
    elseif ap.active then
        right[#right + 1] = rows.action("wifi.off." .. ap.ssid, "Disconnect", function() net:disconnect_wifi() end)
    else
        right[#right + 1] = rows.action("wifi.join." .. ap.ssid, "Connect", function()
            net:connect(ap.ssid, false)
        end)
    end
    if ap.saved then
        right[#right + 1] = rows.action("wifi.forget." .. ap.ssid, "Forget", function() net:forget(ap.ssid) end)
    end
    local left = {
        rows.bars(net:map(function(n)
            local dev = wifi_device(n)
            for _, a in ipairs(dev and dev.available_networks or {}) do
                if a.ssid == ap.ssid then return a.strength end
            end
            return 0
        end, ap.strength), "wifi.bars." .. ap.ssid),
        rows.label(ap.ssid, { font_weight = ap.active and 700 or 400, tip = "wifi.ssid." .. ap.ssid }),
        -- Fixed slots keep the lock and band in columns down the list.
        ap.secure and icons.glyph("secure", 16, k.INK_SOFT) or rect { width = 16 },
        rows.caption(ap.band, { width = 58, text_align = "end" }),
        ap.saved and c.chip("saved", "#C9D8EA", #ap.ssid) or false,
    }
    return rows.line(left, right)
end

-- Rebuilt only when the list's shape changes; strength follows each row's own map.
local function network_list()
    local shape = net:map(function(n)
        local dev = wifi_device(n)
        if not (n.wifi_enabled and dev) then return "off" end
        return (n.connecting_ssid or "") .. "#" .. rows.key(dev.available_networks, { "ssid", "active", "saved", "secure", "band" })
    end, "")
    return column {
        width = "fill",
        children = shape:map(function(key)
            local n = net:get()
            local dev = wifi_device(n)
            if key == "off" or key == "" or not dev then
                return { rows.note(key == "off" and "Wi-Fi is off." or "No networks in range.") }
            end
            local list = {}
            for _, ap in ipairs(dev.available_networks) do
                if ap.ssid ~= "" then list[#list + 1] = network_row(ap, n.connecting_ssid) end
            end
            if #list == 0 then list[1] = rows.note("No networks in range.") end
            return list
        end),
    }
end

local function hidden_row()
    return rows.line({
        rows.label("Hidden network", { width = 170 }),
        c.field {
            id = "settings.wifi.hidden",
            width = 300,
            size = 22,
            placeholder = "Network name, then Enter",
            on_submit = function(ssid)
                if ssid ~= "" then net:connect(ssid, true) end
            end,
        },
    })
end

local function vpn_rows()
    local shape = net:map(function(n) return rows.key(n.vpns, { "uuid", "id", "kind" }) end, "")
    return column {
        width = "fill",
        children = shape:map(function()
            local n = net:get()
            local list = {}
            for _, vpn in ipairs(n and n.vpns or {}) do
                list[#list + 1] = rows.line({
                    icons.glyph("vpn", 20),
                    rows.label(vpn.id, { tip = "wifi.vpn." .. vpn.uuid }),
                    rows.caption(vpn.kind),
                }, {
                    rows.caption(net:map(function(now)
                        for _, v in ipairs(now.vpns or {}) do
                            if v.uuid == vpn.uuid then return v.activating and "connecting…" or "" end
                        end
                        return ""
                    end, "")),
                    c.toggle {
                        id = "settings.vpn." .. vpn.uuid,
                        value = net:map(function(now)
                            for _, v in ipairs(now.vpns or {}) do
                                if v.uuid == vpn.uuid then return v.active or v.activating end
                            end
                            return false
                        end, false),
                        on_toggle = function(on)
                            if on then net:connect_vpn(vpn.uuid) else net:disconnect_vpn(vpn.uuid) end
                        end,
                    },
                })
            end
            if #list == 0 then list[1] = rows.note("No VPN profiles saved in NetworkManager.") end
            return list
        end),
    }
end

-- NetworkManager asks for one secret per field; each field answers through its own secure line.
local function vpn_secret_rows()
    local asked = net:map(function(n)
        local s = n.vpn_secret
        return s and (s.id .. "#" .. table.concat(s.fields, ",")) or ""
    end, "")
    return column {
        width = "fill",
        children = asked:map(function(key)
            if key == "" then return {} end
            local s = net:get().vpn_secret
            local list = {
                rows.line({
                    icons.glyph("password", 20),
                    rows.label((s.retry and "Try again: " or "") .. s.vpn_id .. " needs a secret"),
                }, {
                    rows.button("vpn.cancel", "Cancel", "plain", function() net:cancel_vpn_secret() end),
                }),
            }
            for _, field in ipairs(s.fields) do
                list[#list + 1] = rows.line({
                    rows.label(field, { width = 140 }),
                    c.field {
                        id = "settings.vpn.secret." .. field,
                        width = 360,
                        size = 22,
                        placeholder = "Then Enter",
                        secure_submit = { capability = "network", action = "vpn_secret", name = s.id .. "/" .. field },
                        on_cancel = function() net:cancel_vpn_secret() end,
                    },
                })
            end
            return list
        end),
    }
end

local function vpn_error_row()
    return column {
        width = "fill",
        visible = net:map(function(n) return n.vpn_error ~= nil end, false),
        children = {
            rows.line({
                icons.glyph("warning", 20, k.DEEP_RED),
                rows.label(net:map(function(n)
                    return n.vpn_error and ("VPN failed: " .. n.vpn_error.message) or ""
                end, ""), { foreground = k.DEEP_RED }),
            }),
        },
    }
end

return {
    key = "wifi",
    title = "Wi-Fi",
    on_open = function() net:scan() end,
    build = function()
        local list = radio_rows()
        list[#list + 1] = ethernet_rows()
        list[#list + 1] = password_rows()
        list[#list + 1] = error_row()
        list[#list + 1] = rows.heading("Visible networks")
        list[#list + 1] = network_list()
        list[#list + 1] = hidden_row()
        list[#list + 1] = rows.heading("VPN")
        list[#list + 1] = vpn_secret_rows()
        list[#list + 1] = vpn_error_row()
        list[#list + 1] = vpn_rows()
        return list
    end,
}
