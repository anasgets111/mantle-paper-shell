-- Index tabs down the notebook's left edge, drawn as the Settings notebook's (`components.notebook_tab`):
-- Favourites, Frequent, Recent files, All, then one per category. The others tuck behind the page;
-- the open one turns page paper, stands out furthest, and `bridge` covers the page's torn edge
-- beside it so tab and page read as one sheet.
local theme = require("theme")
local k = require("lib.paper")
local notebook_tab = require("components.notebook_tab")
local categories = require("modules.startmenu.categories")
local icons = require("modules.startmenu.icons")
local model = require("modules.startmenu.model")
local power = require("modules.startmenu.power")

local M = {}

-- Tabs reach this far under the left page.
M.OVERLAP = theme.startmenu.tab_overlap
local H, GAP, TOP = theme.startmenu.tab_h, theme.startmenu.tab_gap, theme.startmenu.tab_top
-- Room past a face before the page's torn edge.
local PAD_R = theme.startmenu.tab_pad_right
-- How far a tab tucks further under the page, as in Settings; a held one is pushed a little further.
local TUCK = { open = 0, hover = theme.startmenu.tab_tuck_hover, rest = theme.startmenu.tab_tuck_rest, held = theme.startmenu.tab_tuck_held }
-- While a search is typed, every tab shows only this much past the page.
local SEARCH_STUB = theme.startmenu.search_stub

local TABS = {
    { "favourites", "Favourites" },
    { "frequent", "Frequent" },
    { "recent", "Recent files" },
    { "all", "All" },
}
for _, name in ipairs(categories.NAMES) do TABS[#TABS + 1] = { name, name } end

local function icon_of(key)
    return function(size, color) return icons.glyph(key, size, color) end
end

local function widest(...)
    local w = 0
    for _, r in ipairs({ ... }) do w = math.max(w, r.width) end
    return w
end

-- Every tab is wide enough for the widest face, open (at no tuck) or not (at the resting tuck),
-- plus the overlap and a margin, so no title runs under the page whatever the font sets.
local open_faces, faces = {}, {}
for i, t in ipairs(TABS) do
    open_faces[i] = geometry("startmenu.tab.face.open." .. t[1])
    faces[i] = geometry("startmenu.tab.face." .. t[1])
end
M.width = computed({ computed(open_faces, widest), computed(faces, widest) }, function(open, rest)
    return math.ceil(math.max(open, rest + TUCK.rest)) + PAD_R + M.OVERLAP
end)

-- Both faces of every tab laid out unseen, for `M.width`.
local function measures()
    local list = {}
    for i, t in ipairs(TABS) do
        list[#list + 1] = notebook_tab.face(icon_of(t[1]), t[2], true, open_faces[i])
        list[#list + 1] = notebook_tab.face(icon_of(t[1]), t[2], false, faces[i])
    end
    return rect { width = 0, height = 0, opacity = 0, hittable = false, children = { column { children = list } } }
end

local searching = model.query:map(function(q) return q:match("%S") ~= nil end)

local function is_open(key)
    return computed({ model.view, searching }, function(v, s) return v == key and not s end)
end

local function tab(t, i)
    local key, label = t[1], t[2]
    local slot = "startmenu.tab." .. key
    local hovered, held = hover(slot), model.held(slot)
    -- Keyboard focus slides the stock out the way the pointer does and shows the pencil loop.
    local focus = focus_visible(slot .. ".focus")
    local lit = computed({ hovered, focus }, function(h, f) return h or f end)
    local open = is_open(key)
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
                translate = computed({ open, lit, searching, held, M.width }, function(on, over, s, h, w)
                    local x = s and w - M.OVERLAP - SEARCH_STUB or on and TUCK.open or over and TUCK.hover or TUCK.rest
                    return { x = x + (h and TUCK.held or 0) }
                end),
                animate = { translate = { spring = { stiffness = 320, damping = 22 } } },
                children = computed({ open, M.width }, function(on, w)
                    return {
                        notebook_tab.tab {
                            width = w,
                            height = H,
                            seed = 70 + i,
                            background = on and theme.PAPER or notebook_tab.tint(i),
                            shadows = on and theme.SHADOW.rest or k.lift(lit),
                            icon = icon_of(key),
                            title = label,
                            chosen = on,
                            focus = focus,
                            loop_width = w - (on and theme.startmenu.tab_loop_trim or theme.startmenu.tab_loop_closed_trim),
                            loop_x = on and theme.startmenu.tab_loop_x or theme.startmenu.tab_loop_closed_x,
                        },
                    }
                end),
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
            width = M.width:map(function(w) return w + theme.startmenu.bridge_pad end),
            height = H,
            children = is_open(t[1]):map(function(on)
                if not on then return {} end
                return {
                    rect {
                        width = theme.startmenu.bridge_w,
                        height = H - theme.startmenu.bridge_trim,
                        align_v = "center",
                        translate = M.width:map(function(w) return { x = w - M.OVERLAP - theme.spacing.md } end),
                        background = theme.PAPER,
                        effect = k.paper_fx { rim = 0 },
                    },
                }
            end),
        }
    end
    return column { spacing = GAP, padding = { top = TOP }, hittable = false, children = children }
end

return M
