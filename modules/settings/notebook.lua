-- The settings notebook: a ruled page under a wire coil binding, with card-stock index tabs down
-- its left edge. Every page is built once; switching pages only flips `visible`.
-- o = { pages = { { key, title, build, on_open?, on_close? } ... }, page = state of the open key }
local k = require("lib.paper")
local c = require("components.controls")
local rows = require("modules.settings.rows")
local icons = require("modules.settings.icons")

local PAGE_W, PAGE_H = 800, 680
local TABS_W = 222
-- Where the page starts: every tab tucks 22 px under it; the chosen one stands 22 px further out.
local PAGE_X = 200
local TOP = 22
local CONTENT_X, CONTENT_Y = 86, 86
local CONTENT_H = PAGE_H - CONTENT_Y - 18

local TINTS = { "#E9DDBB", "#C9D8EA", "#EBCBC5", "#D6E3C4", "#E4D3E8", "#F0DDB8" }

-- Card stock with rounded outer corners and a deckled top, end and bottom; the inner end is
-- tucked under the page.
local function tab_shape(w, h, seed)
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

local function tab(p, i, page)
    local hovered = hover("settings.tab." .. p.key)
    local chosen = page:map(function(key) return key == p.key end)
    local tint = TINTS[(i - 1) % #TINTS + 1]
    return rect {
        width = TABS_W,
        height = 54,
        hover = hovered,
        accessible_name = p.title,
        cursor = "pointer",
        on_click = function() page:set(p.key) end,
        children = {
            rect {
                width = TABS_W,
                height = 54,
                translate = computed({ chosen, hovered }, function(on, over)
                    return { x = on and 0 or over and 12 or 22 }
                end),
                animate = { translate = { spring = { stiffness = 320, damping = 22 } } },
                children = chosen:map(function(on)
                    return {
                        rect {
                            width = "fill",
                            height = "fill",
                            shape = tab_shape(TABS_W, 54, 70 + i),
                            background = tint,
                            shadows = on and k.SHADOW.lift or k.lift(hovered),
                            animate = { shadows = { duration = 160, easing = "out_cubic" } },
                            effect = k.paper_fx { rim = 0 },
                        },
                        row {
                            spacing = 10,
                            align_v = "center",
                            padding = { left = on and 18 or 16 },
                            children = {
                                icons.glyph(p.key, 20, on and k.INK or k.INK_SOFT),
                                k.hand(p.title, on and 27 or 24, {
                                    font_weight = on and 700 or 400,
                                    foreground = on and k.INK or k.INK_SOFT,
                                    align_v = "center",
                                }),
                            },
                        },
                    }
                end),
            },
        },
    }
end

-- A marker squiggle as a filled band whose points are percents, so it spans whatever box holds it:
-- one wave per letter keeps the pitch near the original 14 px squiggle at any title length.
local function underline(waves)
    local function x(f) return string.format("%d%%", math.floor(f * 100 + 0.5)) end
    local c = { { op = "M", points = { 0, 4 } } }
    for i = 1, waves do
        c[#c + 1] = { op = "Q", points = { x((i - 0.5) / waves), i % 2 == 1 and 0 or 8, x(i / waves), 4 } }
    end
    c[#c + 1] = { op = "L", points = { "100%", 6.4 } }
    for i = waves, 1, -1 do
        c[#c + 1] = { op = "Q", points = { x((i - 0.5) / waves), i % 2 == 1 and 2.4 or 10.4, x((i - 1) / waves), 6.4 } }
    end
    c[#c + 1] = { op = "Z", points = {} }
    return { commands = c }
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

local function page_body(p, page)
    return column {
        width = rows.WIDTH,
        height = CONTENT_H,
        visible = page:map(function(key) return key == p.key end),
        scroll = scroll("settings.scroll." .. p.key),
        children = p.build(),
    }
end

return function(o)
    local tabs, bodies = {}, {}
    for i, p in ipairs(o.pages) do
        tabs[i] = tab(p, i, o.page)
        bodies[i] = page_body(p, o.page)
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
            children = c.ruled(PAGE_W, PAGE_H, { top = CONTENT_Y + rows.PITCH, pitch = rows.PITCH, margin = 70 }),
        },
    }
    -- The column is as wide as the title, and the underline fills it, less Caveat's ink padding.
    local header = column {
        padding = { left = PAGE_X + CONTENT_X, top = TOP + 24 },
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
            column { padding = { top = TOP + 74 }, spacing = 8, children = tabs },
            rect { padding = { left = PAGE_X, top = TOP }, children = { page_sheet } },
            header,
            rect {
                padding = { left = PAGE_X + CONTENT_X, top = TOP + CONTENT_Y },
                children = bodies,
            },
            binding(),
        },
    }
end
