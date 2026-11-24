-- The settings notebook: a ruled page under a wire coil binding, card-stock index tabs down its
-- left edge, and the open page's rows on a cream index card that fits them, so a short page leaves
-- a margin of notebook paper. The chosen tab is cut from the card's stock and joins it.
-- Every page is built once; switching pages only flips `visible`.
-- o = { pages = { { key, title, build, on_open?, on_close? } ... }, page = state of the open key }
local k = require("lib.paper")
local util = require("lib.util")
local c = require("components.controls")
local rows = require("modules.settings.rows")
local icons = require("modules.settings.icons")

local PAGE_W, PAGE_H = 800, 680
local TOP = 22
-- Every tab tucks 22 px under the page; the chosen one reaches across the margin to its card.
local PAGE_X = 200
local TABS_W, TAB_H, TAB_GAP, TABS_Y = 222, 50, 6, TOP + 74
local CARD_X, CARD_Y = 76, 96
local CARD_PAD = 14
local CARD_MAX_H = PAGE_H - CARD_Y - 22
-- The last 24 px of a scrolling card fade out, and every page ends in that much blank card. The
-- top 10 px fade too, inside the blank pitch above the first heading, so a scrolled row never cuts hard.
local FADE, FADE_TOP = 24, 10

-- Tab card stock: DESIGN.md's three tab tints.
local TINTS = { "#E9DDBB", "#C9D8EA", "#EBCBC5" }

local function tab_face(p, chosen)
    return row {
        spacing = 10,
        align_v = "center",
        padding = { left = chosen and 18 or 16 },
        children = {
            icons.glyph(p.key, 20, chosen and k.INK or k.INK_SOFT),
            k.hand(p.title, chosen and 27 or 24, {
                font_weight = chosen and 700 or 400,
                foreground = chosen and k.INK or k.INK_SOFT,
                align_v = "center",
            }),
        },
    }
end

-- Up and Down on a focused tab open the page above or below and carry the focus with it.
local function step(pages, page, from, by)
    local to = pages[(from - 1 + by) % #pages + 1]
    page:set(to.key)
    focus_target("settings.tab." .. to.key):request()
    return true
end

-- A tab behind the page. The chosen one stays in place, covered by its card-stock twin, so the
-- column keeps its slots; keyboard focus stays on it and its twin draws the pencil loop.
local function tab(p, i, page, pages)
    local hovered = hover("settings.tab." .. p.key)
    local keyed = focus_visible("settings.tab." .. p.key)
    return rect {
        width = TABS_W,
        height = TAB_H,
        hover = hovered,
        accessible_name = p.title,
        cursor = "pointer",
        on_click = function() page:set(p.key) end,
        focus_target = focus_target("settings.tab." .. p.key),
        focus_visible = keyed,
        focus_ring = false,
        on_key = function(key)
            if key.name == "Down" then return step(pages, page, i, 1) end
            if key.name == "Up" then return step(pages, page, i, -1) end
        end,
        children = {
            rect {
                width = TABS_W,
                height = TAB_H,
                translate = hovered:map(function(over) return { x = over and 12 or 22 } end),
                animate = { translate = { spring = { stiffness = 320, damping = 22 } } },
                children = {
                    rect {
                        width = "fill",
                        height = "fill",
                        shape = c.tab_shape(TABS_W, TAB_H, 70 + i),
                        background = TINTS[(i - 1) % #TINTS + 1],
                        shadows = k.lift(hovered),
                        animate = { shadows = { duration = 160, easing = "out_cubic" } },
                        effect = k.paper_fx { rim = 0 },
                    },
                    tab_face(p, false),
                    rect { visible = keyed, translate = { x = 4 }, children = { c.pencil_loop(TABS_W - 40, TAB_H, 80 + i) } },
                },
            },
        },
    }
end

-- The chosen tab, over the page and under its card: one strip of card stock from the edge to the card.
local function chosen_tab(pages, page)
    local w = PAGE_X + CARD_X + 8
    local function index(key)
        for i, p in ipairs(pages) do
            if p.key == key then return i, p end
        end
    end
    return rect {
        padding = page:map(function(key)
            return { top = TABS_Y + ((index(key) or 1) - 1) * (TAB_H + TAB_GAP) }
        end),
        children = page:map(function(key)
            local i, p = index(key)
            if not i then return {} end
            return {
                rect {
                    width = w,
                    height = TAB_H,
                    children = {
                        rect {
                            width = "fill",
                            height = "fill",
                            shape = c.tab_shape(w, TAB_H, 70 + i),
                            background = k.CARD,
                            shadows = k.SHADOW.rest,
                            effect = k.paper_fx { rim = 0 },
                        },
                        tab_face(p, true),
                        rect {
                            visible = focus_visible("settings.tab." .. p.key),
                            translate = { x = 6 },
                            children = { c.pencil_loop(TABS_W - 30, TAB_H, 80 + i) },
                        },
                    },
                },
            }
        end),
    }
end

-- A marker squiggle as a filled band whose points are percents, so it spans whatever box holds it:
-- one wave per letter keeps the pitch near the original 14 px squiggle at any title length.
local function underline(waves)
    local function x(f) return string.format("%d%%", math.floor(f * 100 + 0.5)) end
    local cmds = { { op = "M", points = { 0, 4 } } }
    for i = 1, waves do
        cmds[#cmds + 1] = { op = "Q", points = { x((i - 0.5) / waves), i % 2 == 1 and 0 or 8, x(i / waves), 4 } }
    end
    cmds[#cmds + 1] = { op = "L", points = { "100%", 6.4 } }
    for i = waves, 1, -1 do
        cmds[#cmds + 1] = { op = "Q", points = { x((i - 0.5) / waves), i % 2 == 1 and 2.4 or 10.4, x((i - 1) / waves), 6.4 } }
    end
    cmds[#cmds + 1] = { op = "Z", points = {} }
    return { commands = cmds }
end

-- A deckled outline that follows its box: whole percents along each edge, bitten inward.
local function card_shape(seed)
    local r = k.rng(seed)
    local function pc(i, n) return string.format("%d%%", math.floor(i * 100 / n)) end
    local cmds = { { op = "M", points = { 0, 0 } } }
    for i = 1, 25 do cmds[#cmds + 1] = { op = "L", points = { pc(i, 25), k.bite(r, 3) } } end
    for i = 1, 10 do cmds[#cmds + 1] = { op = "L", points = { { from = "right", px = -k.bite(r, 3) }, pc(i, 10) } } end
    for i = 24, 0, -1 do cmds[#cmds + 1] = { op = "L", points = { pc(i, 25), { from = "bottom", px = -k.bite(r, 3) } } } end
    for i = 9, 1, -1 do cmds[#cmds + 1] = { op = "L", points = { k.bite(r, 3), pc(i, 10) } } end
    cmds[#cmds + 1] = { op = "Z", points = {} }
    return { commands = cmds }
end

-- ponytail: rules stop at 60 pitches (2040 px); a longer page goes unruled past that.
local RULE_COUNT = 60
local RULES = {}
for y = rows.PITCH, rows.PITCH * RULE_COUNT, rows.PITCH do
    RULES[#RULES + 1] = { op = "M", points = { 0, y } }
    RULES[#RULES + 1] = { op = "L", points = { rows.WIDTH, y } }
end

local FADE_MASK = {
    gradient = "linear",
    angle = 180,
    stops = {
        { 0, "#00000000" }, { FADE_TOP / CARD_MAX_H, "#000000" },
        { 1 - FADE / CARD_MAX_H, "#000000" }, { 1, "#00000000" },
    },
}

local function card(p, page)
    local body = p.build()
    body[#body + 1] = rect { height = FADE }
    return rect {
        visible = page:map(function(key) return key == p.key end),
        children = {
            rect {
                width = "fill",
                height = "fill",
                shape = card_shape(500 + #p.key),
                background = k.CARD,
                shadows = k.SHADOW.card,
                effect = k.paper_fx { rim = 1.6 },
            },
            column {
                width = rows.WIDTH,
                max_height = CARD_MAX_H - 2 * CARD_PAD,
                margin = { left = CARD_PAD, right = CARD_PAD, top = CARD_PAD - 8, bottom = CARD_PAD },
                scroll = scroll("settings.scroll." .. p.key),
                mask = FADE_MASK,
                children = {
                    -- Index-card rules behind the rows, scrolling with them: every row is a
                    -- whole number of pitches, so each sits on one.
                    rect {
                        width = "fill",
                        clip = "box",
                        children = {
                            -- A "fill" height would make the scroll content as tall as the viewport,
                            -- so the rules hang from a zero-height box and the wrapper clips them.
                            rect {
                                height = 0,
                                children = {
                                    path {
                                        width = rows.WIDTH, height = rows.PITCH * RULE_COUNT,
                                        stroke = "#7FA3D050", stroke_width = 1, commands = RULES,
                                    },
                                },
                            },
                            column { width = "fill", children = body },
                        },
                    },
                },
            },
            k.tape { width = 78, height = 22, align_h = "start", translate = { x = 40, y = -11 }, rotate = -3, seed = #p.key },
            k.tape { width = 78, height = 22, align_h = "end", translate = { x = -40, y = -11 }, rotate = 2.5, seed = #p.key + 9 },
        },
    }
end

-- The wire binding: a punched hole and a coil that loops over the top edge, every 32 px.
local function binding()
    local holes, wire, shine = {}, {}, {}
    for x = 34, PAGE_W - 30, 32 do
        holes[#holes + 1] = { op = "M", points = { x + 4.5, TOP + 14 } }
        holes[#holes + 1] = { op = "A", points = { x, TOP + 14, 4.5, 0, 360 } }
        wire[#wire + 1] = { op = "M", points = { x - 1, TOP + 15 } }
        wire[#wire + 1] = { op = "C", points = { x - 4, TOP - 6, x + 9, TOP - 16, x + 12, TOP - 2 } }
        shine[#shine + 1] = { op = "M", points = { x - 1.6, TOP + 6 } }
        shine[#shine + 1] = { op = "C", points = { x - 2, TOP - 6, x + 6, TOP - 12, x + 9, TOP - 8 } }
    end
    local function layer(commands, props)
        props.width, props.height, props.commands = PAGE_W, TOP + 30, commands
        props.stroke_cap = "round"
        return path(props)
    end
    return rect {
        padding = { left = PAGE_X },
        children = {
            layer(holes, { fill = "#2A2520" }),
            layer(wire, {
                stroke = "#55524C", stroke_width = 3.4,
                shadows = { { blur = 3, offset = { x = 1, y = 2 }, color = "#00000060" } },
            }),
            layer(shine, { stroke = "#C9C5BD", stroke_width = 1.1 }),
        },
    }
end

return function(o)
    local tabs, cards = {}, {}
    for i, p in ipairs(o.pages) do
        tabs[i] = tab(p, i, o.page, o.pages)
        cards[i] = card(p, o.page)
    end
    local title = o.page:map(function(key)
        for _, p in ipairs(o.pages) do
            if p.key == key then return p.title end
        end
        return ""
    end)
    local page_sheet = k.sheet {
        width = PAGE_W,
        height = PAGE_H,
        seed = 4242,
        depth = 5,
        fx = { rim = 2.2 },
        child = rect {
            width = PAGE_W,
            height = PAGE_H,
            children = c.ruled(PAGE_W, PAGE_H, { top = CARD_Y - 10, pitch = rows.PITCH, margin = 70 }),
        },
    }
    -- The column is as wide as the title, and the underline fills it, less Caveat's ink padding.
    local header = column {
        padding = { left = PAGE_X + CARD_X + CARD_PAD, top = TOP + 18 },
        children = title:map(function(t)
            return {
                k.hand(t, 46, { font_weight = 700 }),
                rect {
                    width = "fill",
                    height = 11,
                    margin = { right = 8 },
                    translate = { x = 2, y = -8 },
                    background = k.BLUE,
                    shape = underline(math.max(4, utf8.len(t) or #t)),
                },
            }
        end),
    }
    return rect {
        width = PAGE_X + PAGE_W + 8,
        height = TOP + PAGE_H + 8,
        children = {
            column { padding = { top = TABS_Y }, spacing = TAB_GAP, children = tabs },
            -- The layers below are placed by left padding, so their boxes start at x = 0 and cover the
            -- tab column; they pass the pointer through, and only the cards take it back.
            rect { hittable = false, padding = { left = PAGE_X, top = TOP }, children = { page_sheet } },
            util.with(header, "hittable", false),
            util.with(chosen_tab(o.pages, o.page), "hittable", false),
            rect {
                hittable = false,
                padding = { left = PAGE_X + CARD_X, top = TOP + CARD_Y },
                children = { rect { hittable = true, children = cards } },
            },
            util.with(binding(), "hittable", false),
        },
    }
end
