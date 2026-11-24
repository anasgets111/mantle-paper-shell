-- Every icon the taskbar draws goes through here, so a sticker or doodle icon set swaps in one place.
local k = require("lib.paper")

local M = {}

-- An app's own icon (desktop entry `Icon=`, a theme name or a path), full colour.
function M.app(name, size, props)
    local t = { name = name or "application-x-executable", size = size, align_h = "center", align_v = "center" }
    for key, v in pairs(props or {}) do t[key] = v end
    return icon(t)
end

-- A symbolic glyph tinted with ink (status icons, tray icons drawn for a theme).
function M.glyph(name, size, color)
    return k.glyph(name, size, color)
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
