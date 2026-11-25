-- Card-stock index tabs down the notebook's left edge: Favourites, Frequent, Recent files, All,
-- then one per category. The settings tabs' cut (`controls.tab_shape`), spaced apart, the inner
-- end tucked under the page. The open tab stands out furthest,
-- turns page paper, and `bridge` covers the page's torn edge beside it so tab and page read as one sheet.
local k = require("lib.paper")
local controls = require("components.controls")
local categories = require("modules.startmenu.categories")
local model = require("modules.startmenu.model")
local power = require("modules.startmenu.power")

local M = {}

-- Tabs reach this far under the left page.
M.OVERLAP = 22
local H, GAP, TOP = 44, 7, 22
-- Room either side of a label; the right side clears the page's torn edge.
local PAD_L, PAD_R = 16, 10
-- How far a tab tucks further under the page: the open one least; all of them nearly away while a
-- search is typed, since results ignore the tab.
local TUCK = { open = 0, hover = 8, rest = 14, held = 5 }
-- While a search is typed, every tab shows only this much past the page.
local SEARCH_STUB = 32
-- DESIGN.md's three tab stocks: cream, blue, pink.
local TINTS = { "#E9DDBB", "#C9D8EA", "#EBCBC5" }

local TABS = {
    { "favourites", "Favourites" },
    { "frequent", "Frequent" },
    { "recent", "Recent files" },
    { "all", "All" },
}
for _, name in ipairs(categories.NAMES) do TABS[#TABS + 1] = { name, name } end

-- Every tab is as wide as the widest label at the open tab's size and weight, plus its padding, the
-- resting tuck and the overlap, so no label runs under the page whatever the font sets.
local measured = {}
for i, t in ipairs(TABS) do measured[i] = geometry("startmenu.tab.label." .. t[1]) end
M.width = computed(measured, function(...)
    local widest = 0
    for _, r in ipairs({ ... }) do widest = math.max(widest, r.width) end
    return math.ceil(widest) + PAD_L + PAD_R + TUCK.rest + M.OVERLAP
end)

-- The labels laid out unseen, for `M.width`.
local function measures()
    local texts = {}
    for i, t in ipairs(TABS) do texts[i] = k.hand(t[2], 26, { font_weight = 700, geometry = measured[i] }) end
    return rect { width = 0, height = 0, opacity = 0, hittable = false, children = { column { children = texts } } }
end

local searching = model.query:map(function(q) return q:match("%S") ~= nil end)

local function is_open(key)
    return computed({ model.view, searching }, function(v, s) return v == key and not s end)
end

local function tab(t, i)
    local key, label = t[1], t[2]
    local slot = "startmenu.tab." .. key
    local hovered, held = hover(slot), model.held(slot)
    -- Keyboard focus slides the stock out the way the pointer does; the engine's square outline is off.
    local focus = focus_visible(slot .. ".focus")
    local lit = computed({ hovered, focus }, function(h, f) return h or f end)
    local open = is_open(key)
    local tint = TINTS[(i - 1) % #TINTS + 1]
    -- The slot stays put while the stock slides; input follows the stock, so a click where a
    -- tucked tab used to be is a click on the desk and closes the menu.
    return rect {
        width = M.width,
        height = H,
        cursor = "default",
        on_click = model.close,
        children = {
            rect {
                width = M.width,
                height = H,
                hover = hovered,
                focus_visible = focus,
                focus_ring = false,
                accessible_name = label,
                cursor = "pointer",
                on_click = function()
                    power.disarm()
                    model.show(key)
                end,
                on_drag = model.track(slot),
                -- Held, a tab is pushed a little further under the page.
                translate = computed({ open, lit, searching, held, M.width }, function(on, over, s, h, w)
                    local x = s and w - M.OVERLAP - SEARCH_STUB or on and TUCK.open or over and TUCK.hover or TUCK.rest
                    return { x = x + (h and TUCK.held or 0) }
                end),
                animate = { translate = { spring = { stiffness = 320, damping = 22 } } },
                children = {
                    rect {
                        width = "fill",
                        height = "fill",
                        children = computed({ open, M.width }, function(on, w)
                            return {
                                rect {
                                    width = "fill",
                                    height = "fill",
                                    shape = controls.tab_shape(w, H, 90 + i),
                                    background = on and k.PAPER or tint,
                                    shadows = on and k.SHADOW.lift or k.lift(lit),
                                    animate = { shadows = { duration = 160, easing = "out_cubic" } },
                                    effect = k.paper_fx { rim = 0 },
                                },
                                k.hand(label, on and 26 or 24, {
                                    font_weight = on and 700 or 400,
                                    foreground = on and k.INK or k.INK_SOFT,
                                    align_v = "center",
                                    padding = { left = PAD_L, right = PAD_R },
                                }),
                            }
                        end),
                    },
                    -- The part that shows past the page, looped in pencil while it has keyboard focus.
                    rect {
                        translate = { x = 2, y = 2 },
                        children = computed({ focus, M.width }, function(f, w)
                            return f and { controls.pencil_loop(w - M.OVERLAP - TUCK.hover - 4, H - 4, 60 + i) } or {}
                        end),
                    },
                },
            },
        },
    }
end

function M.column()
    local children = {}
    for i, t in ipairs(TABS) do children[i] = tab(t, i) end
    return rect { children = { column { spacing = GAP, padding = { top = TOP }, children = children }, measures() } }
end

-- Drawn above the page: a scrap of page paper over the torn edge beside the open tab, inset 3 px
-- from the tab's deckle so the join shows no seam and no new edge. It stops 5 px into the page,
-- past the deepest bite and short of the ruled lines, which start at 4 px.
function M.bridge()
    local children = {}
    for i, t in ipairs(TABS) do
        children[i] = rect {
            width = M.width:map(function(w) return w + 12 end),
            height = H,
            children = is_open(t[1]):map(function(on)
                if not on then return {} end
                return {
                    rect {
                        width = 17,
                        height = H - 6,
                        align_v = "center",
                        translate = M.width:map(function(w) return { x = w - M.OVERLAP - 12 } end),
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
