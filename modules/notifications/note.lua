-- A sticky note whose height follows its content: torn top, folded bottom-right corner, tape on top.
-- It places the side and bottom points with "NN%" and edge anchors, so the paper grows with the
-- text. ponytail: `controls.sticky` without `height` now does the same; fold this into it.
local k = require("lib.paper")

local FOLD = 14

local function outline(w, seed)
    local r = k.rng(seed)
    local c = { { op = "M", points = { 0, r() * 2 } } }
    for x = 12, w - 12, 12 do c[#c + 1] = { op = "L", points = { x, r() * 2.6 } } end
    c[#c + 1] = { op = "L", points = { w, r() * 2 } }
    for _, y in ipairs({ "30%", "65%" }) do c[#c + 1] = { op = "L", points = { w - r() * 1.2, y } } end
    c[#c + 1] = { op = "L", points = { w, { from = "bottom", px = -FOLD } } }
    c[#c + 1] = { op = "L", points = { w - FOLD, "100%" } }
    c[#c + 1] = { op = "L", points = { 0.8, { from = "bottom", px = -r() } } }
    for _, y in ipairs({ "70%", "35%" }) do c[#c + 1] = { op = "L", points = { r() * 1.2, y } } end
    c[#c + 1] = { op = "Z", points = {} }
    return { commands = c }
end

local function fold(color)
    return path {
        width = FOLD,
        height = FOLD,
        align_h = "end",
        align_v = "end",
        fill = color,
        shadows = { { blur = 3, offset = { x = -1, y = -1 }, color = "#00000040" } },
        commands = {
            { op = "M", points = { 0, FOLD } }, { op = "L", points = { FOLD, 0 } },
            { op = "L", points = { 2, 2 } }, { op = "Z", points = {} },
        },
    }
end

-- o = { width, seed, child, color?, fold_color?, shadows?, tape_rotate? }
return function(o)
    return rect {
        width = o.width,
        padding = { top = 10 },
        children = {
            rect {
                width = o.width,
                children = {
                    -- The finish runs on a backing layer, so grain never speckles the ink.
                    rect {
                        width = "fill",
                        height = "fill",
                        shape = outline(o.width, o.seed),
                        background = o.color or k.STICKY,
                        shadows = o.shadows or { { blur = 10, offset = { x = 2, y = 6 }, color = "#00000055" } },
                        animate = { shadows = { duration = 160, easing = "out_cubic" } },
                        effect = k.paper_fx { rim = 0, grain = 0.18 },
                    },
                    o.child,
                    fold(o.fold_color or k.STICKY_FOLD),
                },
            },
            k.tape {
                width = 70,
                height = 20,
                translate = { y = -8 },
                rotate = o.tape_rotate or 3,
                seed = o.seed,
            },
        },
    }
end
