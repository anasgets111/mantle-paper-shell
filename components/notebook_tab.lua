-- A card-stock index tab down a notebook's left edge, as Settings and the start menu draw it: stock
-- cut by `controls.tab_shape`, a doodle and a Caveat title, and the pencil loop while it has
-- keyboard focus. Where it sits, how far it tucks and what it does on input stay with the caller.
local k = require("lib.paper")
local controls = require("components.controls")

local M = {}

-- DESIGN.md's three tab stocks, cream, blue and pink, in turn down the edge.
local TINTS = { "#E9DDBB", "#C9D8EA", "#EBCBC5" }

function M.tint(i)
    return TINTS[(i - 1) % #TINTS + 1]
end

-- The doodle and title; the chosen tab's are larger and in full ink. `icon(size, color)` draws the
-- doodle. `geometry` binds the row's laid-out box, for a caller that sizes tabs to their faces.
function M.face(icon, title, chosen, geometry)
    return row {
        spacing = chosen and 10 or 8,
        align_v = "center",
        padding = { left = chosen and 18 or 14 },
        geometry = geometry,
        children = {
            icon(20, chosen and k.INK or k.INK_SOFT),
            k.hand(title, chosen and 27 or 22, {
                font_weight = chosen and 700 or 400,
                foreground = chosen and k.INK or k.INK_SOFT,
                align_v = "center",
            }),
        },
    }
end

-- o = { width, height, seed, background, shadows, icon, title, chosen?, focus, loop_width, loop_x }.
-- `focus` is the `focus_visible` signal that shows the loop, `loop_width` wide from `loop_x`.
function M.tab(o)
    return rect {
        width = o.width,
        height = o.height,
        children = {
            rect {
                width = "fill",
                height = "fill",
                shape = controls.tab_shape(o.width, o.height, o.seed),
                background = o.background,
                shadows = o.shadows,
                animate = { shadows = { duration = 160, easing = "out_cubic" } },
                effect = k.paper_fx { rim = 0 },
            },
            M.face(o.icon, o.title, o.chosen),
            rect {
                visible = o.focus,
                translate = { x = o.loop_x },
                children = { controls.pencil_loop(o.loop_width, o.height, o.seed + 10) },
            },
        },
    }
end

return M
