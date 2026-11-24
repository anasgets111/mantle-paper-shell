-- Every icon the taskbar draws goes through here: die-cut app stickers, hand-drawn doodles, tray
-- icons. Swapping a set means editing this file only.
local k = require("lib.paper")
local stickers = require("components.icons")

local M = {}

-- components/icons.lua's resting sticker shadow, and the same light lifted as a hovered control is.
local REST = {
    { blur = 1.5, offset = { x = 0.5, y = 1 }, color = "#00000038" },
    { blur = 6, offset = { x = 1.5, y = 3 }, color = "#00000042" },
}
local LIFT = {
    { blur = 2.5, offset = { x = 1, y = 2 }, color = "#00000030" },
    { blur = 14, offset = { x = 3, y = 8 }, color = "#00000050" },
}

-- The box an app sticker of icon size `size` takes.
function M.app_box(size)
    return size + 2 * stickers.sticker_pad(size)
end

-- An app's icon (desktop entry `Icon=`) as a die-cut sticker. `hovered`, when given, lifts its shadow.
function M.app(name, size, hovered)
    local node = stickers.sticker(name or "application-x-executable", size)
    if hovered then
        node.shadows = hovered:map(function(v) return v and LIFT or REST end)
        node.animate = { shadows = { duration = 160, easing = "out_cubic" } }
    end
    return node
end

-- A hand-drawn glyph by doodle name (`"wifi-3"`, `"bluetooth-off"`); name and colour may be signals.
function M.doodle(name, size, color)
    return stickers.doodle(name, size, color)
end

M.has = stickers.has
M.glyph = k.glyph -- TEMP while callers move to doodles

-- A tray item's theme icon, tinted with ink when it is symbolic.
function M.tray(name, size)
    return icon { name = name, size = size, foreground = k.INK, align_h = "center", align_v = "center" }
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
