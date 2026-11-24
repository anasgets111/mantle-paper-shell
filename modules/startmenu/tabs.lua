-- Card-stock index tabs down the notebook's left edge: Favourites, Frequent, Recent files, All,
-- then one per category. The open tab stands out furthest and in bold.
local k = require("lib.paper")
local controls = require("components.controls")
local categories = require("modules.startmenu.categories")
local model = require("modules.startmenu.model")
local power = require("modules.startmenu.power")

local M = {}

M.WIDTH = 166
local H = 40
-- How far a resting tab tucks under the page; the open one tucks least.
local TUCK = { open = 0, hover = 8, rest = 14 }

local TABS = {
    { "favourites", "Favourites" },
    { "frequent", "Frequent" },
    { "recent", "Recent files" },
    { "all", "All" },
}
for _, name in ipairs(categories.NAMES) do TABS[#TABS + 1] = { name, name } end

local function shape(w, h)
    return { commands = {
        { op = "M", points = { w, 0 } },
        { op = "corner", points = { 0, 0 }, radius = 8 },
        { op = "corner", points = { 0, h }, radius = 8 },
        { op = "L", points = { w, h } },
        { op = "Z", points = {} },
    } }
end

local function tab(t, i)
    local key, label = t[1], t[2]
    local hovered = hover("startmenu.tab." .. key)
    local open = model.view:map(function(v) return v == key end)
    local tint = controls.TINTS[(i - 1) % #controls.TINTS + 1]
    return rect {
        width = M.WIDTH,
        height = H,
        hover = hovered,
        accessible_name = label,
        cursor = "pointer",
        on_click = function()
            power.disarm()
            model.show(key)
        end,
        children = {
            rect {
                width = M.WIDTH,
                height = H,
                translate = computed({ open, hovered }, function(on, over)
                    return { x = on and TUCK.open or over and TUCK.hover or TUCK.rest }
                end),
                animate = { translate = { spring = { stiffness = 320, damping = 22 } } },
                children = open:map(function(on)
                    return {
                        rect {
                            width = "fill",
                            height = "fill",
                            shape = shape(M.WIDTH, H),
                            background = tint,
                            shadows = on and k.SHADOW.lift or k.SHADOW.rest,
                            effect = k.paper_fx { rim = 0 },
                        },
                        k.hand(label, on and 26 or 24, {
                            font_weight = on and 700 or 400,
                            foreground = on and k.INK or k.INK_SOFT,
                            align_v = "center",
                            padding = { left = 14, right = 6 },
                        }),
                    }
                end),
            },
        },
    }
end

function M.column()
    local children = {}
    for i, t in ipairs(TABS) do children[i] = tab(t, i) end
    return column { spacing = 2, padding = { top = 70 }, children = children }
end

return M
