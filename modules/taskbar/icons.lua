-- Every icon the taskbar draws goes through here: die-cut app stickers, hand-drawn doodles, tray
-- icons. Swapping a set means editing this file only.
local theme = require("theme")
local util = require("lib.util")
local stickers = require("components.icons")

local M = {}

-- The one size for every glyph on the bar's right side: status doodles, tray icons, privacy
-- stickers, the updater. 24 matches the updater's package, which draws about 17 px of ink.
M.STATUS = theme.bar.status_icon

-- The box an app sticker of icon size `size` takes.
function M.app_box(size)
    return size + 2 * stickers.sticker_pad(size)
end

-- Icons that don't read as what the app is on the desk: Files is Papirus's blue folder. A path, since
-- the sticker resolves only Papirus's app icons by name and the system theme draws a drawer.
local APP_ICON = { ["org.gnome.Nautilus"] = "/usr/share/icons/Papirus/64x64/places/folder-blue.svg" }

-- An app's icon (desktop entry `Icon=`) as a die-cut sticker. `hovered`, when given, lifts its shadow.
function M.app(name, size, hovered)
    name = name or "application-x-executable"
    local node = stickers.sticker(APP_ICON[name] or name, size)
    if hovered then
        node.shadows = hovered:map(function(v) return v and theme.SHADOW.sticker_lift or theme.SHADOW.sticker_rest end)
        node.animate = { shadows = { duration = 160, easing = "out_cubic" } }
    end
    return node
end

-- A hand-drawn glyph by doodle name (`"wifi-3"`, `"bluetooth-off"`); name and colour may be signals.
function M.doodle(name, size, color)
    return stickers.doodle(name, size, color)
end

M.has = stickers.has

-- Horizontal ink extents of the status doodles on their 24-unit grid: the strokes in
-- components/icons.lua plus half a stroke. Glyph widths run from 11 (bluetooth) to 22 (wifi), so
-- spacing equal boxes leaves unequal gaps between the marks. Unlisted names keep the full box.
local INK = {
    wifi = { 0.8, 23.2 },
    ethernet = { 2.7, 21.3 },
    bluetooth = { 6.2, 17.3 },
    ["bluetooth-off"] = { 3.2, 20.8 },
    ["volume-muted"] = { 2.7, 21.3 },
    ["volume-low"] = { 2.7, 16.4 },
    ["volume-medium"] = { 2.7, 19.4 },
    ["volume-high"] = { 2.7, 22.3 },
    battery = { 2.2, 21.8 },
}

local function ink(name)
    return INK[name] or INK[(name:gsub("%-%w+$", ""))] or { 0, 24 }
end

-- A status doodle at `M.STATUS` in a box cut to its ink, so a row of them spaces mark to mark.
function M.status_glyph(name, color)
    local s = M.STATUS / 24
    return rect {
        width = util.lift(name, function(n) local e = ink(n) return (e[2] - e[1]) * s end),
        height = M.STATUS,
        align_v = "center",
        children = {
            rect {
                translate = util.lift(name, function(n) return { x = -ink(n)[1] * s } end),
                children = { M.doodle(name, M.STATUS, color) },
            },
        },
    }
end

-- A tray item's theme icon, tinted with ink when it is symbolic.
function M.tray(name, size)
    return icon { name = name, size = size, foreground = theme.INK, align_h = "center", align_v = "center" }
end

local INK_SHADER = mantle.config_dir .. "/modules/taskbar/ink.frag"

-- A tray pixmap (a PNG drawn for some dark bar), re-inked so pale glyphs read on paper.
function M.pixmap(path, size)
    return image {
        source = path,
        width = size,
        height = size,
        fit = "contain",
        align_h = "center",
        align_v = "center",
        effect = { shader = { source = INK_SHADER } },
    }
end

return M
