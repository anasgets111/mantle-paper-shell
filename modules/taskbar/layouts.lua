-- Keyboard layout: the active layout's short code ("EN", "AR") left of the status group, shown
-- only with two or more layouts. Click or wheel cycles; right-click lists them by name. Mantle
-- publishes only the active layout's name and index, so the configured list comes from
-- `hyprctl -j devices` and the codes and names from XKB's rules file.
local k = require("lib.paper")
local icons = require("modules.taskbar.icons")
local status = require("modules.taskbar.status")
local menus = require("modules.taskbar.menus")

local M = {}

local kbd = mantle.keyboard
local XKB = "/usr/share/X11/xkb/rules/evdev.xml"

-- { { short, name }, ... } in configured order; empty until read, or if hyprctl fails.
local layouts = state("taskbar.layouts", {})

local function split(s)
    local out = {}
    for item in ((s or "") .. ","):gmatch("([^,]*),") do out[#out + 1] = item end
    return out
end

-- The `kind` ("layout" or "variant") entry named `name` at or after `from`: its short code and
-- description. Anchored on the element, since variant names reuse layout codes ("ba" has "us").
local function item(xml, kind, name, from)
    local at = xml:find("<" .. kind .. ">%s*<configItem>%s*<name>" .. name:gsub("%p", "%%%0") .. "</name>", from or 1)
    if not at then return nil end
    local block = xml:sub(at, xml:find("</configItem>", at, true) or at)
    return at, block:match("<shortDescription>(.-)</shortDescription>"), block:match("<description>(.-)</description>")
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
        file.read(XKB, function(xml)
            xml = xml or ""
            local variants, list = split(main.variant), {}
            for i, code in ipairs(split(main.layout)) do
                local at, short, name = item(xml, "layout", code)
                local variant = variants[i] or ""
                if at and variant ~= "" then
                    local _, v_short, v_name = item(xml, "variant", variant, at)
                    short, name = v_short or short, v_name or name
                end
                list[i] = { short = (short or code):upper(), name = name or code }
            end
            layouts:set(list)
        end)
    end)
end

-- Re-read when the list no longer matches what Hyprland reports: another count, or another name at
-- the active index (a config reload that replaced or reordered layouts). Once per count and name,
-- so a name the rules file spells differently can't loop.
-- ponytail: a replaced layout that is not active shows its old name in the menu until it becomes
-- active. Upgrade: re-read on a Hyprland config-reload event, if Mantle publishes one.
local loaded_key
local function refresh(s)
    if not s or s.layout_count < 2 then return end
    local list = layouts:get()
    local entry = list[s.active_layout_index + 1]
    local stale = #list ~= s.layout_count or not entry or entry.name ~= s.active_layout
    local key = s.layout_count .. "\0" .. s.active_layout
    if stale and key ~= loaded_key then
        loaded_key = key
        load()
    end
end
kbd:on_change(refresh)
refresh(kbd:get())

local multi = kbd:map(function(s) return (s.layout_count or 0) >= 2 end, false)

local code = computed({ kbd, layouts }, function(s, list)
    local entry = s and list[(s.active_layout_index or 0) + 1]
    if entry then return entry.short end
    return ((s and s.active_layout or ""):sub(1, 2)):upper()
end, "")

local function cycle(step)
    local s = kbd:get()
    if not s or s.layout_count < 2 then return end
    kbd:switch_layout((s.active_layout_index + step) % s.layout_count)
end

function M.widget(output)
    local wheel = 0
    local node = status.button {
        name = "taskbar.layout." .. output,
        label = "Keyboard layout",
        seed = 47,
        -- Lettering carries its own side bearing, so less padding keeps its gaps equal to the doodles'.
        pad = 5,
        on_click = function(r, button)
            if button == "right" then
                menus.open_layouts(r, layouts:get(), kbd:get().active_layout_index)
            elseif button ~= "middle" then
                cycle(1)
            end
        end,
        tip = function()
            local name = kbd:get().active_layout
            return name ~= "" and ("Keyboard: " .. name) or "Keyboard layout"
        end,
        -- Caveat's capitals at this size stand as tall as the status doodles' ink.
        children = { k.hand(code, icons.STATUS + 2, { font_weight = 700, align_v = "center" }) },
    }
    node.visible = multi
    -- One layout per notch; up goes back, as on the workspace numerals.
    node.on_wheel = function(_, steps)
        wheel = wheel + steps
        if math.abs(wheel) < 1 then return end
        cycle(wheel > 0 and -1 or 1)
        wheel = 0
    end
    return node
end

return M
