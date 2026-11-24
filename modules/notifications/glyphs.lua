-- Every icon and pencil mark this module draws, in one place: app stickers, doodles, doodled paper
-- discs, and marker strokes that fit whatever box holds them.
local k = require("lib.paper")
local icons = require("components.icons")
local controls = require("components.controls")

-- Doodle names from `components/icons.lua`; a freedesktop name with no doodle falls back to the
-- theme's symbolic icon.
local M = {
    close = "close",
    send = "mail-send-symbolic",
    prev_month = "chevron-left",
    next_month = "chevron-right",
    previous = "media-skip-backward-symbolic",
    next = "media-skip-forward-symbolic",
    play = "media-playback-start-symbolic",
    pause = "media-playback-pause-symbolic",
    music = "music",
    bell = "bell",
    bell_off = "bell-off",
    trash = "trash",
}

-- An app's icon as a die-cut sticker; a bell doodle when the sender named none.
function M.app(name, size)
    if name == nil or name == "" then return icons.doodle(M.bell, size) end
    return icons.sticker(name, size)
end

function M.doodle(name, size, color)
    return icons.doodle_for(name, size, color)
end

-- A punched paper disc carrying a doodle: `controls.disc_button` with its theme icon swapped.
function M.disc(o)
    local node = controls.disc_button(o)
    local mark = icons.doodle_for(o.icon, math.floor((o.size or 44) * 0.5), o.ink)
    mark.align_h = "center"
    node.children[2] = mark
    return node
end

-- A wavy marker stroke as a thin filled band, laid out in percents so it spans its box.
function M.underline(color, seed)
    local r = k.rng(seed or 3)
    local n, top, bottom = 24, {}, {}
    for i = 0, n do
        local x = string.format("%.2f%%", i * 100 / n)
        local y = 4.5 + 2.6 * math.sin(i * math.pi / 2.2) + (r() - 0.5) * 0.6
        top[#top + 1] = { op = i == 0 and "M" or "L", points = { x, y - 1.1 } }
        bottom[#bottom + 1] = { op = "L", points = { x, y + 1.1 } }
    end
    local c = top
    for i = #bottom, 1, -1 do c[#c + 1] = bottom[i] end
    c[#c + 1] = { op = "Z", points = {} }
    return rect { width = "fill", height = 10, background = color, shape = { commands = c } }
end

-- A marker line down the left margin of whatever it sits beside, wobbling a little.
function M.margin_rule(color, seed)
    local r = k.rng(seed or 5)
    local n, left, right = 10, {}, {}
    for i = 0, n do
        local y = string.format("%.2f%%", i * 100 / n)
        local x = 1.5 + (r() - 0.5) * 1.2
        left[#left + 1] = { op = i == 0 and "M" or "L", points = { x, y } }
        right[#right + 1] = { op = "L", points = { x + 2.6, y } }
    end
    local c = left
    for i = #right, 1, -1 do c[#c + 1] = right[i] end
    c[#c + 1] = { op = "Z", points = {} }
    return rect { width = 6, height = "fill", background = color, shape = { commands = c } }
end

return M
