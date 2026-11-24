-- Keyboard page: the configured layouts, by name, and the lock keys. Mantle lists only the active
-- layout's name (gap 20), so the layout codes come from `hyprctl -j devices` and their names from
-- the XKB rules list. Layouts are added in Hyprland's `input.kb_layout`.
local k = require("lib.paper")
local c = require("components.controls")
local rows = require("modules.settings.rows")

local kbd = mantle.keyboard

-- { { code, variant, name }, ... } of the main keyboard, in configured order.
local layouts = state("settings.keyboard.layouts", {})
local XKB_LIST = "/usr/share/X11/xkb/rules/evdev.lst"

local function split(s)
    local out = {}
    for item in ((s or "") .. ","):gmatch("([^,]*),") do out[#out + 1] = item end
    return out
end

-- `! layout` lines are `  code  Name`; `! variant` lines are `  variant  code: Name`.
local function parse_names(text)
    local names, section = {}, nil
    for line in text:gmatch("[^\n]+") do
        local header = line:match("^! (%w+)")
        if header then
            section = header
        elseif section == "layout" then
            local code, name = line:match("^%s+(%S+)%s+(.+)$")
            if code then names[code] = name end
        elseif section == "variant" then
            local variant, code, name = line:match("^%s+(%S+)%s+(%S+): (.+)$")
            if variant then names[code .. "(" .. variant .. ")"] = name end
        end
    end
    return names
end

local function load()
    process.capture("hyprctl", { "-j", "devices" }, function(out)
        local ok, devices = pcall(json.decode, out or "")
        if not ok or type(devices) ~= "table" then return end
        local main
        for _, d in ipairs(devices.keyboards or {}) do
            if d.main then main = d end
        end
        if not main then return end
        file.read(XKB_LIST, function(text)
            local names = text and parse_names(text) or {}
            local variants = split(main.variant)
            local list = {}
            for i, code in ipairs(split(main.layout)) do
                local variant = variants[i] or ""
                local key = variant ~= "" and (code .. "(" .. variant .. ")") or code
                list[i] = { code = code, variant = variant, name = names[key] or names[code] or code }
            end
            layouts:set(list)
        end)
    end)
end

local function layout_rows()
    return column {
        width = "fill",
        children = layouts:map(function(list)
            if #list == 0 then return { rows.note("Reading layouts from Hyprland…") } end
            local options = {}
            for i, l in ipairs(list) do
                local code = l.variant ~= "" and (l.code .. " · " .. l.variant) or l.code
                options[i] = { i - 1, l.name .. "  ·  " .. code }
            end
            return {
                rows.list(
                    c.radio_group {
                        id = "settings.keyboard.layout",
                        vertical = true,
                        options = options,
                        value = kbd:map(function(s) return s.active_layout_index end),
                        on_select = function(index) kbd:switch_layout(index) end,
                    }, #options
                ),
            }
        end),
    }
end

-- Read only, so a plain ticked box with no pointer: lock keys change on the keyboard.
local function lock_key(name, field)
    return row {
        spacing = 10,
        padding = { right = 24 },
        children = kbd:map(function(s)
            return { k.checkbox(22, s[field] == true), k.body(name, 21, { align_v = "center" }) }
        end, { k.checkbox(22, false), k.body(name, 21, { align_v = "center" }) }),
    }
end

local function backlight_rows()
    return column {
        width = "fill",
        visible = kbd:map(function(s) return s.backlight_percent ~= nil end, false),
        children = {
            rows.line({
                rows.label("Backlight", { width = 120 }),
                c.slider {
                    id = "settings.keyboard.backlight",
                    width = 380,
                    value = kbd:map(function(s) return (s.backlight_percent or 0) / 100 end, 0),
                    on_change = function(v) kbd:set_backlight(v * 100) end,
                    on_wheel = function(_, steps)
                        local now = kbd:get()
                        local pct = now and now.backlight_percent
                        if pct then kbd:set_backlight(math.max(0, math.min(100, pct + steps * 5))) end
                    end,
                },
            }),
        },
    }
end

return {
    key = "keyboard",
    title = "Keyboard",
    on_open = load,
    build = function()
        return {
            rows.heading("Input sources", {
                rows.caption(kbd:map(function(s) return s.active_layout ~= "" and ("now: " .. s.active_layout) or "" end, "")),
            }),
            layout_rows(),
            rows.note("Add or reorder layouts in Hyprland's input config (kb_layout).", 1),
            rows.heading("Lock keys"),
            rows.line({ lock_key("Caps Lock", "caps_lock"), lock_key("Num Lock", "num_lock"), lock_key("Scroll Lock", "scroll_lock") }),
            backlight_rows(),
        }
    end,
}
