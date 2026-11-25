-- The recorder's two marker marks, which the doodle set has no word for: a red dot while recording,
-- two deep-red bars while paused.
local k = require("lib.paper")

local M = {}

function M.dot(size)
    local r = size / 2
    return path {
        width = size,
        height = size,
        fill = k.RED,
        commands = { { op = "A", points = { r, r, r - 0.5, 0, 360 } }, { op = "Z", points = {} } },
    }
end

function M.bars(size)
    return path {
        width = size,
        height = size,
        stroke = k.DEEP_RED,
        stroke_width = 3.4,
        stroke_cap = "round",
        commands = {
            { op = "M", points = { size * 0.3, 2 } }, { op = "L", points = { size * 0.28, size - 2 } },
            { op = "M", points = { size * 0.72, 2.5 } }, { op = "L", points = { size * 0.7, size - 2 } },
        },
    }
end

-- The mark for a `paused` signal, as a child list.
function M.state(paused, size)
    return paused:map(function(p) return { p and M.bars(size or 16) or M.dot(size or 16) } end)
end

return M
