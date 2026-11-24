-- Card-stock index tabs down the notebook's left edge: Favourites, Frequent, Recent files, All,
-- then one per category. Cut as the settings tabs are: deckled card stock with rounded outer
-- corners, spaced apart, the inner end tucked under the page. The open tab stands out furthest,
-- turns page paper, and `bridge` covers the page's torn edge beside it so tab and page read as one sheet.
local k = require("lib.paper")
local controls = require("components.controls")
local categories = require("modules.startmenu.categories")
local model = require("modules.startmenu.model")
local power = require("modules.startmenu.power")

local M = {}

M.WIDTH = 166
-- Tabs reach this far under the left page.
M.OVERLAP = 22
local H, GAP, TOP = 44, 7, 22
-- How far a resting tab tucks further under the page; the open one tucks least.
local TUCK = { open = 0, hover = 8, rest = 14 }

local TABS = {
    { "favourites", "Favourites" },
    { "frequent", "Frequent" },
    { "recent", "Recent files" },
    { "all", "All" },
}
for _, name in ipairs(categories.NAMES) do TABS[#TABS + 1] = { name, name } end

-- Adapted from modules/settings/notebook.lua: rounded outer corners, a deckled top, end and
-- bottom, and a straight inner end that the page hides.
local function shape(w, h, seed)
    local r = k.rng(seed)
    local c = { { op = "M", points = { w, 0 } } }
    for x = w - 8, 16, -8 do c[#c + 1] = { op = "L", points = { x, k.bite(r, 2) } } end
    c[#c + 1] = { op = "corner", points = { 0, 0 }, radius = 9 }
    for y = 14, h - 14, 8 do c[#c + 1] = { op = "L", points = { k.bite(r, 2), y } } end
    c[#c + 1] = { op = "corner", points = { 0, h }, radius = 9 }
    for x = 16, w - 8, 8 do c[#c + 1] = { op = "L", points = { x, h - k.bite(r, 2) } } end
    c[#c + 1] = { op = "L", points = { w, h } }
    c[#c + 1] = { op = "Z", points = {} }
    return { commands = c }
end

local function is_open(key)
    return model.view:map(function(v) return v == key end)
end

local function tab(t, i)
    local key, label = t[1], t[2]
    local hovered = hover("startmenu.tab." .. key)
    local open = is_open(key)
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
                            shape = shape(M.WIDTH, H, 90 + i),
                            background = on and k.PAPER or tint,
                            shadows = on and k.SHADOW.lift or k.lift(hovered),
                            animate = { shadows = { duration = 160, easing = "out_cubic" } },
                            effect = k.paper_fx { rim = 0 },
                        },
                        k.hand(label, on and 26 or 24, {
                            font_weight = on and 700 or 400,
                            foreground = on and k.INK or k.INK_SOFT,
                            align_v = "center",
                            padding = { left = 16, right = 6 },
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
    return column { spacing = GAP, padding = { top = TOP }, children = children }
end

-- Drawn above the page: a scrap of page paper over the torn edge beside the open tab, inset 3 px
-- from the tab's deckle so the join shows no seam and no new edge.
function M.bridge()
    local children = {}
    for i, t in ipairs(TABS) do
        children[i] = rect {
            width = M.WIDTH + 12,
            height = H,
            children = is_open(t[1]):map(function(on)
                if not on then return {} end
                return {
                    rect {
                        width = 26,
                        height = H - 6,
                        align_v = "center",
                        translate = { x = M.WIDTH - M.OVERLAP - 12 },
                        background = k.PAPER,
                        effect = k.paper_fx { rim = 0 },
                    },
                }
            end),
        }
    end
    return column { spacing = GAP, padding = { top = TOP }, hittable = false, children = children }
end

return M
