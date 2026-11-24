-- A torn sheet that follows its content's size. `lib/paper.lua`'s `torn` cuts an outline for a fixed
-- box; this one places its points in percents with inward pixel bites, so the popup grows and shrinks
-- with its list and never needs a height worked out in Lua.
local k = require("lib.paper")

local M = {}

local function pct(i) return string.format("%d%%", i) end

-- 50 points a side (2% steps) keeps the outline inside a shape's 256 commands.
function M.torn_fit(seed, depth)
    local r = k.rng(seed)
    depth = depth or 4
    local p = {}
    for i = 0, 98, 2 do p[#p + 1] = { pct(i), k.bite(r, depth) } end
    for i = 0, 98, 2 do p[#p + 1] = { { from = "right", px = -k.bite(r, depth) }, pct(i) } end
    for i = 100, 2, -2 do p[#p + 1] = { pct(i), { from = "bottom", px = -k.bite(r, depth) } } end
    for i = 100, 2, -2 do p[#p + 1] = { k.bite(r, depth), pct(i) } end
    local c = { { op = "M", points = p[1] } }
    for i = 2, #p do c[i] = { op = "L", points = p[i] } end
    c[#c + 1] = { op = "Z", points = {} }
    return { commands = c }
end

-- o = { child, seed, color?, rim?, padding?, width? }: the paper and its finish sit behind the child.
function M.sheet(o)
    return rect {
        width = o.width,
        children = {
            rect {
                width = "fill",
                height = "fill",
                shape = M.torn_fit(o.seed or 1, o.depth),
                background = o.color or k.PAPER,
                shadows = k.SHADOW.card,
                effect = k.paper_fx { rim = o.rim or 2.2 },
            },
            rect { width = o.width and "fill" or nil, padding = o.padding, children = { o.child } },
        },
    }
end

return M
