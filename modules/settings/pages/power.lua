-- Power page: power profile, screen brightness when there is a backlight, the battery and other
-- batteries UPower knows, then the idle settings the lock builder owns (`modules/lock/idle_page.lua`).
local c = require("components.controls")
local rows = require("modules.settings.rows")
local icons = require("modules.settings.icons")
local idle_page = require("modules.lock.idle_page")

local PROFILE_NAMES = { ["power-saver"] = "Power saver", balanced = "Balanced", performance = "Performance" }

local STATES = {
    charging = "charging",
    discharging = "on battery",
    empty = "empty",
    fully_charged = "full",
    pending_charge = "plugged in, not charging",
    pending_discharge = "waiting to discharge",
    unknown = "",
}

local function duration(seconds)
    local h, m = seconds // 3600, seconds % 3600 // 60
    return h > 0 and string.format("%d h %02d min", h, m) or string.format("%d min", m)
end

local function profile_rows()
    local profiles = mantle.power:map(function(p) return table.concat(p.profiles or {}, ",") end, "")
    return column {
        width = "fill",
        children = profiles:map(function(list)
            if list == "" then
                return { rows.note("power-profiles-daemon isn't running, so there are no profiles to pick.") }
            end
            local options = {}
            for name in list:gmatch("[^,]+") do options[#options + 1] = { name, PROFILE_NAMES[name] or name } end
            return {
                rows.list(
                    c.radio_group {
                        id = "settings.power.profile",
                        vertical = true,
                        options = options,
                        value = mantle.power:map(function(p) return p.active_profile end),
                        on_select = function(name) mantle.power:set_profile(name) end,
                    }, #options
                ),
            }
        end),
    }
end

-- `mantle.brightness` never pushes without a backlight, so the rows stay hidden on a desktop.
local function brightness_rows()
    return column {
        width = "fill",
        visible = mantle.brightness:map(function() return true end, false),
        children = {
            rows.heading("Screen"),
            rows.line({
                icons.glyph("brightness", 22),
                c.slider {
                    id = "settings.power.brightness",
                    width = 420,
                    value = mantle.brightness:map(function(b) return b.percent / 100 end, 0),
                    on_change = function(v) mantle.brightness:set(math.max(1, v * 100)) end,
                    on_wheel = function(_, steps)
                        local b = mantle.brightness:get()
                        if b then mantle.brightness:set(math.max(1, math.min(100, b.percent + steps * 5))) end
                    end,
                },
            }),
        },
    }
end

local function battery_text(b)
    if not b.present then return "No battery: this machine runs on mains." end
    local parts = { b.percent .. "%", STATES[b.state] or "" }
    if b.state == "discharging" and b.time_to_empty then parts[#parts + 1] = duration(b.time_to_empty) .. " left" end
    if b.state == "charging" and b.time_to_full then parts[#parts + 1] = "full in " .. duration(b.time_to_full) end
    if b.health then parts[#parts + 1] = "health " .. b.health .. "%" end
    return table.concat(parts, "  ·  ")
end

local function battery_rows()
    local others = mantle.battery:map(function(b) return rows.key(b.peripherals, { "id", "name" }) end, "")
    return {
        rows.heading("Battery", {
            rows.caption(mantle.power:map(function(p)
                return p.energy_rate and p.energy_rate > 0 and string.format("%.1f W", p.energy_rate) or ""
            end, "")),
        }),
        rows.line({
            icons.glyph("battery", 20),
            rows.label(mantle.battery:map(battery_text, "Reading the battery…")),
        }),
        column {
            width = "fill",
            children = others:map(function()
                local list = {}
                for _, p in ipairs(mantle.battery:get() and mantle.battery:get().peripherals or {}) do
                    list[#list + 1] = rows.line({
                        icons.glyph(p.icon or "peripheral", 20),
                        rows.label(p.name),
                    }, {
                        rows.caption(p.percent and (p.percent .. "%") or (p.level or "")),
                    })
                end
                return list
            end),
        },
    }
end

return {
    key = "power",
    title = "Power",
    build = function()
        local list = { rows.heading("Power mode"), profile_rows() }
        list[#list + 1] = brightness_rows()
        for _, node in ipairs(battery_rows()) do list[#list + 1] = node end
        list[#list + 1] = rows.heading("Idle and screen lock")
        list[#list + 1] = rect { width = "fill", padding = { top = 6 }, children = { idle_page() } }
        return list
    end,
}
