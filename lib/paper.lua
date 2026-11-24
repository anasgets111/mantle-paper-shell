-- The paper kit: tokens, torn shapes, the paper finish, tape, sheets, cards, doodles and text
-- helpers. Every module draws with these, so the desk reads as one material.
local DIR = mantle.config_dir
local PAPER = "#EEE3CB"
local INK = "#3A3631"
local INK_SOFT = "#6B6258"
local BLUE = "#3F74C7"
local DEEP_BLUE = "#24477F"
local RED = "#D9534F"
local DEEP_RED = "#8E2B25"
local HAND = "Caveat"

-- Park-Miller LCG with a fixed seed per shape, so edges stay put across reloads.
local function rng(seed)
    local s = seed % 2147483647
    if s <= 0 then s = s + 2147483646 end
    return function()
        s = s * 16807 % 2147483647
        return s / 2147483647
    end
end

-- Deckle offset: mostly small fuzz, now and then a deeper bite. Always inward, always below `depth`.
local function bite(r, depth)
    local v = r()
    if v > 0.92 then return depth * (0.7 + 0.3 * r()) end
    return depth * 0.45 * r() ^ 1.5
end

-- A torn contour for a fixed w x h box: every edge jittered inward, at most 254 points.
local function torn(w, h, seed, depth, flat_top)
    depth = depth or 4
    local r = rng(seed)
    local step = math.max(6, 2 * (w + h) / 240)
    local pts = {}
    local function edge(x0, y0, x1, y1, nx, ny)
        local len = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
        local n = math.max(1, math.floor(len / step))
        for i = 0, n - 1 do
            local t = i / n
            local d = (flat_top and ny == 1) and 0 or bite(r, depth)
            pts[#pts + 1] = { x0 + (x1 - x0) * t + nx * d, y0 + (y1 - y0) * t + ny * d }
        end
    end
    edge(0, 0, w, 0, 0, 1)
    edge(w, 0, w, h, -1, 0)
    edge(w, h, 0, h, 0, -1)
    edge(0, h, 0, 0, 1, 0)
    local commands = { { op = "M", points = pts[1] } }
    for i = 2, #pts do commands[i] = { op = "L", points = pts[i] } end
    commands[#commands + 1] = { op = "Z", points = {} }
    return { commands = commands }
end

-- The bar spans the output, so its torn bottom edge is laid out to 3840 px (4K logical width); a
-- narrower output clips the rest. ponytail: a shape takes 256 commands, so the deckle has a 16 px
-- step here. Upgrade: a shader edge, or a shape that repeats a pattern along an edge.
local function torn_bottom(height, seed)
    local r = rng(seed)
    local span, step = 3840, 16
    local commands = {
        { op = "M", points = { 0, 0 } },
        { op = "L", points = { span, 0 } },
    }
    for x = span, 0, -step do
        commands[#commands + 1] = { op = "L", points = { x, height - bite(r, 5) } }
    end
    commands[#commands + 1] = { op = "Z", points = {} }
    return { commands = commands }
end

-- The mirror of `torn_bottom`: straight bottom, torn top, for a strip along the screen's bottom edge.
local function torn_top(height, seed)
    local r = rng(seed)
    local span, step = 3840, 16
    local commands = { { op = "M", points = { 0, height } } }
    for x = 0, span, step do
        commands[#commands + 1] = { op = "L", points = { x, bite(r, 5) } }
    end
    commands[#commands + 1] = { op = "L", points = { span, height } }
    commands[#commands + 1] = { op = "Z", points = {} }
    return { commands = commands }
end

-- A punched paper disc: a circle whose rim is torn inward.
local function torn_circle(size, seed, depth)
    local r = rng(seed)
    local c, n, R = {}, 48, size / 2
    for i = 0, n - 1 do
        local a = 2 * math.pi * i / n
        local rad = R - 0.5 - bite(r, depth or 1.8)
        c[#c + 1] = { op = i == 0 and "M" or "L", points = { R + rad * math.cos(a), R + rad * math.sin(a) } }
    end
    c[#c + 1] = { op = "Z", points = {} }
    return { commands = c }
end

-- The paper finish (shaders/paper.frag) for any box: grain, torn-fibre rim, optional hatching.
local function paper_fx(o)
    o = o or {}
    return {
        shader = {
            source = DIR .. "/shaders/paper.frag",
            images = { grain = DIR .. "/img/grain.png" },
            params = {
                grain_amt = o.grain or 0.12,
                mottle_amt = o.mottle or 0.12,
                rim = o.rim or 0,
                hatch = o.hatch or 0,
                hatch_color = o.hatch_color or { 0.25, 0.45, 0.78, 0.85 },
                hatch_spacing = o.hatch_spacing or 4,
            },
        },
    }
end

-- A strip of tape with zigzag torn ends.
local function tape_shape(w, h, seed)
    local r = rng(seed)
    local c = { { op = "M", points = { 0, 0 } }, { op = "L", points = { w, 0 } } }
    for i = 1, 5 do c[#c + 1] = { op = "L", points = { w - (i % 2) * (2 + 3 * r()), h * i / 6 } } end
    c[#c + 1] = { op = "L", points = { w, h } }
    c[#c + 1] = { op = "L", points = { 0, h } }
    for i = 5, 1, -1 do c[#c + 1] = { op = "L", points = { (i % 2) * (2 + 3 * r()), h * i / 6 } } end
    c[#c + 1] = { op = "Z", points = {} }
    return { commands = c }
end

local function tape(o)
    return rect {
        width = o.width or 86,
        height = o.height or 24,
        align_h = o.align_h or "center",
        align_v = o.align_v or "start",
        translate = o.translate or { y = -12 },
        rotate = o.rotate or -3,
        z = 2,
        background = o.color or "#D9C89BB0",
        shape = tape_shape(o.width or 86, o.height or 24, o.seed or 3),
        shadows = { { blur = 3, offset = { y = 1 }, color = "#00000030" } },
        effect = paper_fx { grain = 0.35, mottle = 0.2, rim = 0 },
    }
end

local SHEET_SHADOW = { { blur = 14, offset = { x = 2, y = 5 }, color = "#00000070" } }

-- A sheet of paper: torn shape, paper finish, a soft drop shadow.
local function sheet(o)
    local children = { o.child }
    local shape = o.shape or torn(o.width, o.height, o.seed or 1, o.depth)
    -- The finish runs on a backing sibling, so the grain never speckles the ink on top.
    table.insert(children, 1, rect {
        width = "fill",
        height = "fill",
        shape = shape,
        background = o.color or PAPER,
        shadows = o.shadows or SHEET_SHADOW,
        animate = o.animate,
        effect = paper_fx(o.fx),
    })
    return rect {
        width = o.width,
        height = o.height,
        children = children,
    }
end

-- A card: a sheet with optional tape, slightly turned as if stuck on by hand.
local function card(o)
    o.fx = o.fx or { rim = 2.2 }
    local children = { sheet(o) }
    for _, t in ipairs(o.tapes or {}) do children[#children + 1] = tape(t) end
    return rect {
        padding = { top = 6, bottom = 6, left = 6, right = 6 },
        rotate = o.rotate or 0,
        align_h = o.align_h,
        children = children,
    }
end

-- Doodles ---------------------------------------------------------------------------------------

local function stroke_path(w, h, commands, color, width)
    return path {
        width = w,
        height = h,
        stroke = color or INK,
        stroke_width = width or 1.6,
        stroke_cap = "round",
        stroke_join = "round",
        commands = commands,
    }
end

local function squiggle(w, color)
    local c = { { op = "M", points = { 2, 5 } } }
    local n = math.floor((w - 4) / 14)
    for i = 0, n - 1 do
        local x = 2 + i * 14
        c[#c + 1] = { op = "Q", points = { x + 7, i % 2 == 0 and 1 or 9, x + 14, 5 } }
    end
    return stroke_path(w, 10, c, color or RED, 2.2)
end

local function sprig(size)
    local s = size / 60
    local function p(...)
        local t = { ... }
        for i = 1, #t do t[i] = t[i] * s end
        return t
    end
    local c = { { op = "M", points = p(14, 58) }, { op = "Q", points = p(22, 30, 44, 4) } }
    local leaves = { { 18, 44, -1 }, { 22, 34, 1 }, { 27, 26, -1 }, { 32, 18, 1 }, { 38, 11, -1 } }
    for _, l in ipairs(leaves) do
        local x, y, side = l[1], l[2], l[3]
        local tx, ty = x + side * 12, y - 8
        c[#c + 1] = { op = "M", points = p(x, y) }
        c[#c + 1] = { op = "Q", points = p(x + side * 10, y + 2, tx, ty) }
        c[#c + 1] = { op = "Q", points = p(x + side * 2, y - 9, x, y) }
    end
    return stroke_path(size, size, c, INK, 1.4)
end

local function star(size, color, filled)
    local c = {}
    for i = 0, 9 do
        local a = math.rad(i * 36 - 90)
        local r = (i % 2 == 0) and size * 0.48 or size * 0.2
        c[#c + 1] = { op = i == 0 and "M" or "L", points = { size / 2 + r * math.cos(a), size / 2 + 0.04 * size + r * math.sin(a) } }
    end
    c[#c + 1] = { op = "Z", points = {} }
    return path {
        width = size,
        height = size,
        fill = filled and color or nil,
        stroke = color,
        stroke_width = 1.6,
        stroke_join = "round",
        commands = c,
    }
end

local function heart(size, color)
    local k = size / 20
    local function p(...)
        local t = { ... }
        for i = 1, #t do t[i] = t[i] * k end
        return t
    end
    return path {
        width = size,
        height = size,
        fill = color,
        commands = {
            { op = "M", points = p(10, 18) },
            { op = "C", points = p(3, 13, 0, 9, 0, 6) },
            { op = "C", points = p(0, 3, 2, 1, 5, 1) },
            { op = "C", points = p(7, 1, 9, 2.5, 10, 4) },
            { op = "C", points = p(11, 2.5, 13, 1, 15, 1) },
            { op = "C", points = p(18, 1, 20, 3, 20, 6) },
            { op = "C", points = p(20, 9, 17, 13, 10, 18) },
            { op = "Z", points = {} },
        },
    }
end

-- A hand-drawn box: a rectangle whose corners wander a pixel or two, drawn twice like pencil.
local function wobble_box(w, h, seed, color, fill)
    local r = rng(seed)
    local function j() return (r() - 0.5) * 3 end
    local c = {}
    for pass = 0, 1 do
        local o = pass * 1.2
        c[#c + 1] = { op = "M", points = { 3 + j(), 3 + j() + o } }
        c[#c + 1] = { op = "L", points = { w - 3 + j(), 3 + j() } }
        c[#c + 1] = { op = "L", points = { w - 3 + j() - o, h - 3 + j() } }
        c[#c + 1] = { op = "L", points = { 3 + j(), h - 3 + j() - o } }
        c[#c + 1] = { op = "Z", points = {} }
    end
    return path {
        width = w,
        height = h,
        fill = fill,
        stroke = color,
        stroke_width = 1.3,
        stroke_join = "round",
        commands = c,
    }
end

local function checkbox(size, checked)
    local children = { wobble_box(size, size, size * 7 + (checked and 1 or 0), INK) }
    if checked then
        -- A marker tick that overshoots the box, as a quick hand does.
        children[2] = stroke_path(size, size, {
            { op = "M", points = { size * 0.18, size * 0.48 } },
            { op = "Q", points = { size * 0.32, size * 0.62, size * 0.42, size * 0.8 } },
            { op = "Q", points = { size * 0.7, size * 0.2, size * 1.08, -size * 0.12 } },
        }, BLUE, math.max(2, size / 9))
    end
    return rect { width = size, height = size, align_v = "center", children = children }
end

local function hand(content, size, props)
    -- Caveat's last glyph inks past its advance and a text node cuts ink at its box: pad the right.
    local t = { content = content, font = HAND, font_size = size, foreground = INK, padding = { right = math.ceil(size * 0.15) } }
    for k, v in pairs(props or {}) do t[k] = v end
    return text(t)
end

local function body(content, size, props)
    local t = { content = content, font_size = size, foreground = INK }
    for k, v in pairs(props or {}) do t[k] = v end
    return text(t)
end

local function glyph(name, size, color)
    return icon { name = name, size = size or 20, foreground = color or INK, align_v = "center" }
end


-- Card stocks: the tint of the paper and the ink written on it.
local STOCK = {
    primary = { "#C5D7EE", DEEP_BLUE },
    plain = { "#F4ECDA", INK },
    danger = { "#F2CFC8", DEEP_RED },
}

-- Light from the top left; a control rests low and lifts on hover.
local SHADOW = {
    card = SHEET_SHADOW,
    rest = { { blur = 5, offset = { x = 1, y = 2 }, color = "#00000050" } },
    lift = { { blur = 16, offset = { x = 3, y = 9 }, color = "#00000055" } },
    tape = { { blur = 3, offset = { y = 1 }, color = "#00000030" } },
}

local function lift(hovered)
    return hovered:map(function(v) return v and SHADOW.lift or SHADOW.rest end)
end

return {
    DIR = DIR, PAPER = PAPER, INK = INK, INK_SOFT = INK_SOFT, BLUE = BLUE, DEEP_BLUE = DEEP_BLUE,
    RED = RED, DEEP_RED = DEEP_RED, HAND = HAND,
    STICKY = "#F3E3A0", STICKY_FOLD = "#DCC67A", GROOVE = "#E2D6BC", HIGHLIGHT = "#F2C94C80",
    STOCK = STOCK, SHADOW = SHADOW, lift = lift,
    rng = rng, bite = bite, torn = torn, torn_bottom = torn_bottom, torn_top = torn_top, torn_circle = torn_circle,
    paper_fx = paper_fx, tape = tape, tape_shape = tape_shape, sheet = sheet, card = card,
    stroke_path = stroke_path, squiggle = squiggle, sprig = sprig, star = star, heart = heart,
    wobble_box = wobble_box, checkbox = checkbox, hand = hand, body = body, glyph = glyph,
}
