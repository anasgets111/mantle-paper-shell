-- Bluetooth page: adapter power and visibility, the pairing question, connected and paired
-- devices, and a search for new ones. A search this page starts stops when the notebook closes.
local k = require("lib.paper")
local c = require("components.controls")
local rows = require("modules.settings.rows")
local icons = require("modules.settings.icons")

local bt = mantle.bluetooth

local BUSY = { pairing = "pairing…", connecting = "connecting…", disconnecting = "disconnecting…" }

local PROMPTS = {
    confirm = "Does %s show %s?",
    authorize = "%s wants to pair",
    service = "%s wants to connect",
    display = "Type %s on %s, then Enter",
    pin_entry = "PIN for %s",
    passkey_entry = "Passkey for %s",
}

local searching = state("settings.bluetooth.searching", false)

local function name_of(d)
    return d.name ~= "" and d.name or d.mac
end

local function device_row(d, actions, detail)
    local left = {
        icons.glyph(d.category or "generic", 20),
        rows.label(name_of(d)),
        detail and rows.caption(detail) or false,
    }
    if d.busy then return rows.line(left, { rows.caption(BUSY[d.busy] or d.busy) }) end
    return rows.line(left, actions)
end

local function section(title, field, build)
    local shape = bt:map(function(b)
        if not b.enabled then return "" end
        return rows.key(b[field], { "mac", "name", "busy", "battery" })
    end, "")
    return column {
        width = "fill",
        visible = shape:map(function(key) return key ~= "" end),
        children = shape:map(function(key)
            if key == "" then return {} end
            local list = { rows.heading(title) }
            local devices = table.move(bt:get()[field], 1, #bt:get()[field], 1, {})
            table.sort(devices, function(a, b) return name_of(a):lower() < name_of(b):lower() end)
            for _, d in ipairs(devices) do list[#list + 1] = build(d) end
            return list
        end),
    }
end

-- The pairing question on a sticky note. Entry kinds take the secret through `secure_submit`.
local function pairing_note()
    local asked = bt:map(function(b)
        local r = b.pairing_request
        return r and (r.id .. "#" .. r.kind) or ""
    end, "")
    return column {
        width = "fill",
        children = asked:map(function(key)
            if key == "" then return {} end
            local r = bt:get().pairing_request
            local who = r.name ~= "" and (r.name .. " (" .. r.mac .. ")") or r.mac
            local question = r.kind == "display" and string.format(PROMPTS.display, r.code or "", who)
                or r.kind == "confirm" and string.format(PROMPTS.confirm, who, r.code or "")
                or string.format(PROMPTS[r.kind] or "%s", who)
            local controls
            if r.kind == "pin_entry" or r.kind == "passkey_entry" then
                controls = {
                    c.field {
                        id = "settings.bluetooth.pin",
                        width = 260,
                        size = 24,
                        placeholder = r.kind == "pin_entry" and "PIN" or "Passkey",
                        secure_submit = { capability = "bluetooth", action = "pair", name = r.id .. "/" .. r.mac },
                        on_cancel = function() bt:answer_pairing(r.mac, false) end,
                    },
                }
            elseif r.kind ~= "display" then
                controls = {
                    rows.button("bt.accept", r.kind == "confirm" and "It matches" or "Allow", "primary",
                        function() bt:answer_pairing(r.mac, true) end),
                    rows.button("bt.reject", "Refuse", "danger", function() bt:answer_pairing(r.mac, false) end),
                }
            else
                controls = {}
            end
            return {
                rect {
                    padding = { top = 8, bottom = 8, left = 4 },
                    children = {
                        c.sticky {
                            width = 520,
                            height = 120,
                            seed = 7,
                            rotate = -1,
                            child = column {
                                padding = { left = 18, top = 14, right = 18 },
                                spacing = 10,
                                children = {
                                    k.hand(question, 28, { font_weight = 700 }),
                                    row { spacing = 12, children = controls },
                                },
                            },
                        },
                    },
                },
            }
        end),
    }
end

local function search_rows()
    local found = bt:map(function(b)
        if not b.enabled then return "" end
        return rows.key(b.discovered_devices, { "mac", "name", "busy", "blocked" })
    end, "")
    return column {
        width = "fill",
        visible = bt:map(function(b) return b.enabled end, false),
        children = {
            rows.heading("Other devices", {
                rect {
                    children = bt:map(function(b) return b.discovering end, false):map(function(on)
                        return {
                            rows.button("bt.search", on and "Stop" or "Search", "plain", function()
                                searching:set(not on)
                                if on then bt:stop_discovery() else bt:start_discovery() end
                            end),
                        }
                    end),
                },
            }),
            column {
                width = "fill",
                children = found:map(function()
                    local b = bt:get()
                    local list = {}
                    for _, d in ipairs(b and b.discovered_devices or {}) do
                        -- An address-only advert is noise in a list people read; BlueZ names those
                        -- after the address, dashed.
                        if d.name ~= "" and not d.name:match("^%x%x%-%x%x%-%x%x%-") then
                            list[#list + 1] = device_row(d, d.blocked and { rows.caption("blocked") } or {
                                rows.action("bt.pair." .. d.mac, "Pair", function() bt:pair(d.mac) end),
                            })
                        end
                    end
                    if #list == 0 then
                        list[1] = rows.note(b and b.discovering and "Looking…" or "Press Search to look for devices nearby.")
                    end
                    return list
                end),
            },
        },
    }
end

return {
    key = "bluetooth",
    title = "Bluetooth",
    on_close = function()
        if searching:get() then
            searching:set(false)
            bt:stop_discovery()
        end
    end,
    build = function()
        return {
            rows.heading("Adapter"),
            column {
                width = "fill",
                visible = bt:map(function(b) return not b.available end, true),
                children = { rows.note("No Bluetooth adapter, or bluetoothd isn't running.") },
            },
            column {
                width = "fill",
                visible = bt:map(function(b) return b.available end, false),
                children = {
                    rows.line({ rows.label("Bluetooth") }, {
                        c.toggle {
                            id = "settings.bluetooth.power",
                            value = bt:map(function(b) return b.enabled end, false),
                            on_toggle = function(on) bt:set_enabled(on) end,
                        },
                    }),
                    rows.line({
                        c.checkbox_row {
                            id = "settings.bluetooth.visible",
                            label = "Visible to other devices",
                            value = bt:map(function(b) return b.discoverable end, false),
                            on_toggle = function(on) bt:set_discoverable(on) end,
                        },
                    }),
                },
            },
            pairing_note(),
            section("Connected", "connected_devices", function(d)
                return device_row(d, {
                    rows.action("bt.off." .. d.mac, "Disconnect", function() bt:disconnect(d.mac) end),
                }, d.battery and (d.battery .. "%") or nil)
            end),
            section("Paired", "paired_devices", function(d)
                return device_row(d, d.blocked and { rows.caption("blocked") } or {
                    rows.action("bt.on." .. d.mac, "Connect", function() bt:connect(d.mac) end),
                    rows.action("bt.forget." .. d.mac, "Forget", function() bt:forget(d.mac) end),
                })
            end),
            search_rows(),
        }
    end,
}
