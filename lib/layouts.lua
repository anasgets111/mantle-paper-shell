-- Keyboard layouts from `mantle.keyboard` alone, so they work on any compositor Mantle reads them
-- from: each layout's name as it becomes active, and short codes ("EN", "AR") from the XKB rules
-- file's `shortDescription` for a layout's name.
local L = {}

local kbd = mantle.keyboard
local XKB = "/usr/share/X11/xkb/rules/evdev.xml"

-- ponytail: `mantle.keyboard` names only the active layout, so the others are named as they
-- become active ("Layout 2" until then). Upgrade: a configured-layouts list in the payload.
-- { ["0"] = name, ... } for every layout seen active this session, by 0-based index.
local seen = state("layouts.seen", {})
-- { [name] = short code } from the rules file; empty until read or without it.
local shorts = state("layouts.shorts", {})

file.read(XKB, function(xml)
    local map = {}
    for short, name in (xml or ""):gmatch("<shortDescription>([^<]*)</shortDescription>%s*<description>([^<]*)</description>") do
        if map[name] == nil then map[name] = short:upper() end
    end
    shorts:set(map)
end)

local function remember(s)
    if not s or s.active_layout == "" then return end
    local map = seen:get()
    local key = tostring(s.active_layout_index)
    if map[key] == s.active_layout then return end
    local copy = {}
    for i, name in pairs(map) do copy[i] = name end
    copy[key] = s.active_layout
    seen:set(copy)
end
kbd:on_change(remember)
remember(kbd:get())

--- The configured layouts as `{ name, active }`, in order; unseen ones read "Layout N".
function L.list()
    local s, map, out = kbd:get(), seen:get(), {}
    if not s then return out end
    for i = 0, s.layout_count - 1 do
        out[i + 1] = { name = map[tostring(i)] or ("Layout " .. (i + 1)), active = s.active_layout_index == i }
    end
    return out
end
L.seen, L.shorts = seen, shorts

return L
