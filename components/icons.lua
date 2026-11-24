-- Icons on paper: app icons cut out as die-cut stickers, and a hand-drawn pencil glyph set for
-- symbolic icons. `sticker(name, size, opts)`, `doodle(name, size, color)`,
-- `doodle_for(symbolic_name, size, color)`, `has(name)`, `names`.
local k = require("lib.paper")
local util = require("lib.util")

local M = {}

local function hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
    return h
end

-- Stickers ---------------------------------------------------------------------------------------

local CUT = "#FBF8F0"

-- The white margin of a die-cut sticker: sharp copies of the icon's silhouette pushed out in 12
-- directions. A `spread` would scale the silhouette about the centre, not grow it evenly.
local function cut_layers(r)
    local layers = {}
    for i = 0, 11 do
        local a = i * math.pi / 6
        layers[#layers + 1] = { color = CUT, offset = { x = r * math.cos(a), y = r * math.sin(a) } }
    end
    return layers
end

-- Light from the top left: a tight contact shadow under a soft resting one.
local STICKER_SHADOW = {
    { blur = 1.5, offset = { x = 0.5, y = 1 }, color = "#00000038" },
    { blur = 6, offset = { x = 1.5, y = 3 }, color = "#00000042" },
}

-- Stable per app: stickers turn up to 4 degrees either way.
local function turn(name)
    if name == nil or name == "" then return 0 end
    return (hash(name) % 81 - 40) / 10
end

--- An app icon cut out as a sticker. `name`: a theme name or an image path, plain or a signal.
--- opts: `size`, `rotate` (degrees, default derived from the name), `grain` (default true).
--- The box is `size + 2 * pad` square, pad = `M.sticker_pad(size)`; the drop shadow reaches
--- about 8 px further right and down, so give a clipping parent that much room.
function M.sticker(name, size, opts)
    opts = opts or {}
    size = opts.size or size or 32
    local r = M.sticker_cut(size)
    return rect {
        width = size + 2 * M.sticker_pad(size),
        height = size + 2 * M.sticker_pad(size),
        align_v = "center",
        shadow_mode = "content",
        shadows = STICKER_SHADOW,
        children = {
            rect {
                padding = M.sticker_pad(size),
                rotate = opts.rotate or util.lift(name, turn),
                -- Grain multiplies the colour by 1 +- a few percent, so the icon keeps its hue.
                effect = opts.grain ~= false and k.paper_fx { grain = 0.16, mottle = 0.08 } or nil,
                children = { icon { name = name, size = size, shadows = cut_layers(r) } },
            },
        },
    }
end

function M.sticker_cut(size)
    return math.max(2, math.min(3, size / 16))
end

-- Room for the cut margin, plus the corner a turned square sweeps out.
function M.sticker_pad(size)
    return math.ceil(M.sticker_cut(size) + 1 + size * 0.04)
end

-- Doodles ----------------------------------------------------------------------------------------
-- Each glyph is drawn on a 24-unit grid, kept inside 2.5..21.5 so the wobble and half the stroke
-- never reach the box edge. A stroke is a list of points with a style: "line" (each segment a
-- slightly bowed curve), "smooth" (a Catmull-Rom curve through the points) or "fill" (a closed
-- smooth blob filled with ink). `faint` strokes show an unreached level: same shape, light pencil.

local function pts(...)
    local t, a = {}, { ... }
    for i = 1, #a, 2 do t[#t + 1] = { a[i], a[i + 1] } end
    return t
end

local function line(...) return { kind = "line", pts = pts(...) } end
local function smooth(...) return { kind = "smooth", pts = pts(...) } end

local function closed(...)
    local s = line(...)
    s.pts[#s.pts + 1] = { s.pts[1][1], s.pts[1][2] }
    return s
end

-- Degrees, clockwise from +x as `path`'s `A`.
local function arc(cx, cy, r, a0, a1)
    local p = {}
    local n = math.max(3, math.ceil(math.abs(a1 - a0) / 24))
    for i = 0, n do
        local a = math.rad(a0 + (a1 - a0) * i / n)
        p[#p + 1] = { cx + r * math.cos(a), cy + r * math.sin(a) }
    end
    return { kind = "smooth", pts = p }
end

local function dot(x, y, r)
    local s = arc(x, y, r or 1.1, 0, 360)
    s.kind = "fill"
    return s
end

local function faint(s, on)
    s.faint = not on
    return s
end

-- An unreached mark that is not drawn at all; it still draws its random numbers, so the marks
-- around it keep their wobble from level to level.
local function shown(s, on)
    s.hidden = not on
    return s
end

-- An arc ending in an arrowhead that points along the sweep.
local function arc_arrow(cx, cy, r, a0, a1, head)
    local s = arc(cx, cy, r, a0, a1)
    local a = math.rad(a1)
    local x, y = cx + r * math.cos(a), cy + r * math.sin(a)
    local dir = a1 > a0 and 1 or -1
    local tx, ty = -math.sin(a) * dir, math.cos(a) * dir
    local nx, ny = -ty, tx
    head = head or 3.6
    return s, line(x - tx * head + nx * head * 0.8, y - ty * head + ny * head * 0.8, x, y,
        x - tx * head - nx * head * 0.8, y - ty * head - ny * head * 0.8)
end

local function slash() return line(4, 3.5, 20, 20.5) end

local function with_slash(list, off)
    if off then list[#list + 1] = slash() end
    return list
end

local function moon(cx, cy, s)
    local p = arc(cx, cy, 8 * s, 15, 285).pts
    local inner = {
        { cx + 2.3 * s, cy - 7.3 * s }, { cx + 0.3 * s, cy - 3 * s }, { cx + 2.2 * s, cy + 1.4 * s },
        { cx + 6.6 * s, cy + 2.3 * s },
    }
    for i = #inner, 1, -1 do table.insert(p, 1, inner[i]) end
    p[#p + 1] = { inner[1][1] - 0.4 * s, inner[1][2] + 0.6 * s }
    return { kind = "smooth", pts = p }
end

local function wifi(level, off)
    local lit = function(i) return off or level >= i end
    return with_slash({
        faint(dot(12, 19, 1.3), lit(1)),
        faint(arc(12, 19.5, 5, 228, 312), lit(2)),
        faint(arc(12, 19.5, 9.5, 228, 312), lit(3)),
        faint(arc(12, 19.5, 14, 228, 312), lit(4)),
    }, off)
end

local function speaker() return closed(3.5, 9.5, 7.5, 9.5, 12, 5, 12, 19, 7.5, 14.5, 3.5, 14.5) end

local function volume(level)
    if level == 0 then return { speaker(), line(15.5, 9.5, 20.5, 14.5), line(20.5, 9.5, 15.5, 14.5) } end
    return {
        speaker(),
        shown(arc(12, 12, 3.6, -42, 42), level >= 1),
        shown(arc(12, 12, 6.6, -44, 44), level >= 2),
        shown(arc(12, 12, 9.5, -46, 46), level >= 3),
    }
end

local function mic(off)
    return with_slash({
        smooth(9, 11, 9, 6.5, 10, 4, 12, 3.5, 14, 4, 15, 6.5, 15, 11, 14, 13.4, 12, 14, 10, 13.4, 9, 11),
        arc(12, 11, 6.5, 8, 172),
        line(12, 17.5, 12, 20.5),
        line(8.5, 20.5, 15.5, 20.5),
    }, off)
end

local function battery(level, charging)
    local list = { closed(3, 7, 18.5, 7, 18.5, 17, 3, 17), line(19, 10, 21, 10, 21, 14, 19, 14) }
    if charging then
        list[#list + 1] = line(11.5, 8.8, 8, 12.6, 12.5, 12.4, 9.5, 15.6)
        return list
    end
    for i = 1, 4 do
        local x = 3 + i * 3.1
        list[#list + 1] = shown(line(x, 9.8, x, 14.2), level >= i)
    end
    return list
end

local function gear()
    local p, teeth = {}, 6
    for i = 0, teeth - 1 do
        local a = i * 360 / teeth
        for _, v in ipairs({ { -19, 6.6 }, { -10, 9.2 }, { 10, 9.2 }, { 19, 6.6 } }) do
            local t = math.rad(a + v[1])
            p[#p + 1] = { 12 + v[2] * math.cos(t), 12 + v[2] * math.sin(t) }
        end
    end
    p[#p + 1] = p[1]
    return { { kind = "line", pts = p }, arc(12, 12, 2.8, 0, 380) }
end

local function sun()
    local list = { arc(12, 12, 3.8, -20, 365) }
    for i = 0, 7 do
        local a = math.rad(i * 45)
        local c, d = math.cos(a), math.sin(a)
        list[#list + 1] = line(12 + 6.4 * c, 12 + 6.4 * d, 12 + 9 * c, 12 + 9 * d)
    end
    return list
end

local function bell(off)
    return with_slash({
        smooth(4.5, 17.5, 6.8, 15, 7.2, 10, 12, 5.3, 16.8, 10, 17.2, 15, 19.5, 17.5),
        line(4.5, 17.5, 19.5, 17.5),
        arc(12, 18.3, 2.2, 10, 170),
        line(12, 3.5, 12, 5.3),
    }, off)
end

local function bluetooth(off)
    return with_slash({ line(7, 7.5, 16.5, 16, 12, 20.5, 12, 3.5, 16.5, 8, 7, 16.5) }, off)
end

local function restart()
    local a, b = arc_arrow(12, 12.5, 7.5, -50, 245)
    return { a, b }
end

local GLYPHS = {
    ["wifi-off"] = function() return wifi(4, true) end,
    ethernet = function()
        return {
            closed(3.5, 6, 20.5, 6, 20.5, 16, 16, 16, 16, 19.5, 8, 19.5, 8, 16, 3.5, 16),
            line(9, 8.8, 9, 11.5), line(12, 8.8, 12, 11.5), line(15, 8.8, 15, 11.5),
        }
    end,
    bluetooth = function() return bluetooth(false) end,
    ["bluetooth-off"] = function() return bluetooth(true) end,
    ["volume-muted"] = function() return volume(0) end,
    ["volume-low"] = function() return volume(1) end,
    ["volume-medium"] = function() return volume(2) end,
    ["volume-high"] = function() return volume(3) end,
    mic = function() return mic(false) end,
    ["mic-off"] = function() return mic(true) end,
    ["battery-charging"] = function() return battery(0, true) end,
    brightness = sun,
    power = function() return { arc(12, 13, 7.5, -58, 238), line(12, 3.5, 12, 11.5) } end,
    lock = function()
        return {
            smooth(7.6, 11, 7.6, 8, 9, 4.8, 12, 4, 15, 4.8, 16.4, 8, 16.4, 11),
            closed(5, 11, 19, 11, 19, 20.5, 5, 20.5),
            dot(12, 14.8, 1.2), line(12, 15.5, 12, 17.6),
        }
    end,
    logout = function()
        return { line(10.5, 4, 4, 4, 4, 20, 10.5, 20), line(9, 12, 20.5, 12), line(16.8, 8.3, 20.5, 12, 16.8, 15.7) }
    end,
    restart = restart,
    suspend = function() return { moon(12, 12, 1) } end,
    settings = gear,
    search = function() return { arc(10.5, 10.5, 6.3, 10, 375), line(15.2, 15.2, 20.5, 20.5) } end,
    close = function() return { line(6, 6, 18, 18), line(18, 6, 6, 18) } end,
    ["chevron-left"] = function() return { line(15, 5, 8, 12, 15, 19) } end,
    ["chevron-right"] = function() return { line(9, 5, 16, 12, 9, 19) } end,
    ["chevron-up"] = function() return { line(5, 15, 12, 8, 19, 15) } end,
    ["chevron-down"] = function() return { line(5, 9, 12, 16, 19, 9) } end,
    plus = function() return { line(12, 4.5, 12, 19.5), line(4.5, 12, 19.5, 12) } end,
    check = function() return { line(4.5, 12.5, 9.8, 18, 19.8, 5.5) } end,
    bell = function() return bell(false) end,
    ["bell-off"] = function() return bell(true) end,
    calendar = function()
        return {
            closed(3.5, 6, 20.5, 6, 20.5, 20.5, 3.5, 20.5), line(3.5, 10.2, 20.5, 10.2),
            line(8, 3.5, 8, 7.8), line(16, 3.5, 16, 7.8),
            dot(7.8, 15.3, 1.1), arc(14.6, 15.3, 3, -60, 330),
        }
    end,
    folder = function()
        return { closed(3, 5.5, 9.5, 5.5, 11.5, 8, 21, 8, 21, 19, 3, 19), line(3, 11, 21, 11) }
    end,
    file = function()
        return {
            closed(5.5, 3.5, 14, 3.5, 18.5, 8, 18.5, 20.5, 5.5, 20.5), line(14, 3.5, 14, 8, 18.5, 8),
            line(8.5, 12.5, 15.5, 12.5), line(8.5, 16, 15.5, 16),
        }
    end,
    home = function()
        return {
            line(3, 11.5, 12, 3.8, 21, 11.5), line(5.8, 9.5, 5.8, 20.3, 18.2, 20.3, 18.2, 9.5),
            line(10.3, 20.3, 10.3, 14.8, 13.7, 14.8, 13.7, 20.3),
        }
    end,
    download = function()
        return {
            line(12, 3.5, 12, 14.5), line(7.5, 10, 12, 14.5, 16.5, 10), line(3.5, 15, 3.5, 20, 20.5, 20, 20.5, 15),
        }
    end,
    image = function()
        return {
            closed(3, 4.5, 21, 4.5, 21, 19.5, 3, 19.5),
            line(3, 17.5, 9, 11.2, 13, 15.2, 15.5, 12.8, 21, 18),
            arc(15.8, 8.8, 1.6, 0, 380),
        }
    end,
    music = function()
        return {
            dot(7.3, 17.8, 2.4), dot(16.3, 15.8, 2.4),
            line(9.6, 17.6, 9.6, 6.2), line(18.6, 15.6, 18.6, 4.2), line(9.6, 6.2, 18.6, 4.2),
        }
    end,
    video = function()
        return { closed(3, 7, 15, 7, 15, 17, 3, 17), closed(15, 10.5, 21, 7.5, 21, 16.5, 15, 13.5) }
    end,
    terminal = function()
        return { closed(3, 4.5, 21, 4.5, 21, 19.5, 3, 19.5), line(6.5, 9, 10, 12, 6.5, 15), line(12, 15.5, 17, 15.5) }
    end,
    trash = function()
        return {
            line(4, 6.5, 20, 6.5), line(9.5, 6.5, 9.5, 3.8, 14.5, 3.8, 14.5, 6.5),
            line(6, 6.5, 7.2, 20.5, 16.8, 20.5, 18, 6.5), line(10, 10, 10.3, 17.2), line(14, 10, 13.7, 17.2),
        }
    end,
    keyboard = function()
        local list = { closed(3, 6, 21, 6, 21, 18, 3, 18), line(8, 14.8, 16, 14.8) }
        for _, y in ipairs({ 9.2, 11.8 }) do
            for x = 7, 17, 5 do list[#list + 1] = dot(x, y, 0.8) end
        end
        return list
    end,
    display = function()
        return { closed(3, 4, 21, 4, 21, 16, 3, 16), line(12, 16, 12, 19.8), line(7.5, 20, 16.5, 20) }
    end,
    user = function()
        return { arc(12, 8.3, 4.3, -30, 345), smooth(4.5, 20.5, 5.8, 16.6, 12, 14.4, 18.2, 16.6, 19.5, 20.5) }
    end,
    airplane = function()
        return {
            closed(12, 2.8, 13.3, 4.4, 13.3, 9.2, 21, 13.6, 21, 15.2, 13.3, 12.9, 13.3, 17.4, 15.6, 19.4,
                15.6, 20.8, 12, 19.8, 8.4, 20.8, 8.4, 19.4, 10.7, 17.4, 10.7, 12.9, 3, 15.2, 3, 13.6,
                10.7, 9.2, 10.7, 4.4),
        }
    end,
    night = function()
        return { moon(10.5, 13.5, 0.85), line(18, 3.5, 18, 8.5), line(15.5, 6, 20.5, 6) }
    end,
}
for i = 0, 4 do
    GLYPHS["wifi-" .. i] = function() return wifi(i, false) end
    GLYPHS["battery-" .. i] = function() return battery(i, false) end
end
GLYPHS.wifi = GLYPHS["wifi-4"]
GLYPHS.volume = GLYPHS["volume-high"]
GLYPHS.battery = GLYPHS["battery-4"]

M.names = {}
for name in pairs(GLYPHS) do
    if name ~= "wifi" and name ~= "volume" and name ~= "battery" then M.names[#M.names + 1] = name end
end
table.sort(M.names)

function M.has(name)
    return GLYPHS[name] ~= nil
end

-- Pencil rendering --------------------------------------------------------------------------------

-- `sketch` draws each straight segment on its own, run a little past both ends, as a quick
-- second pass over a pencil outline does.
local function append(c, stroke, s, r, jit, dx, dy, sketch)
    local p = {}
    for i, q in ipairs(stroke.pts) do
        -- A hand closing an outline runs a little past where it began.
        local closing = i > 2 and i == #stroke.pts and q[1] == stroke.pts[1][1] and q[2] == stroke.pts[1][2]
        local jx, jy = (r() - 0.5) * 2 * jit * s, (r() - 0.5) * 2 * jit * s
        if closing then
            local ux, uy = p[2][1] - p[1][1], p[2][2] - p[1][2]
            local len = math.max(0.01, math.sqrt(ux * ux + uy * uy))
            local over = math.min(1.4, len * 0.3) * s
            p[i] = { p[1][1] + ux / len * over + jx * 0.5, p[1][2] + uy / len * over + jy * 0.5 }
        else
            p[i] = { q[1] * s + jx + dx, q[2] * s + jy + dy }
        end
    end
    c[#c + 1] = { op = "M", points = p[1] }
    if stroke.kind == "line" then
        for i = 2, #p do
            local a, b = p[i - 1], p[i]
            local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
            local bow = (r() - 0.5) * 0.1 * len
            local ux, uy = 0, 0
            if len > 0 then ux, uy = (b[1] - a[1]) / len, (b[2] - a[2]) / len end
            local mx, my = (a[1] + b[1]) / 2 - uy * bow, (a[2] + b[2]) / 2 + ux * bow
            if sketch then
                local ext = math.min(0.9 * s, len * 0.12)
                c[#c + 1] = { op = "M", points = { a[1] - ux * ext, a[2] - uy * ext } }
                c[#c + 1] = { op = "Q", points = { mx, my, b[1] + ux * ext, b[2] + uy * ext } }
            else
                c[#c + 1] = { op = "Q", points = { mx, my, b[1], b[2] } }
            end
        end
    else
        local n = #p
        local function at(i) return p[math.max(1, math.min(n, i))] end
        for i = 1, n - 1 do
            local p0, p1, p2, p3 = at(i - 1), p[i], p[i + 1], at(i + 2)
            c[#c + 1] = { op = "C", points = {
                p1[1] + (p2[1] - p0[1]) / 6, p1[2] + (p2[2] - p0[2]) / 6,
                p2[1] - (p3[1] - p1[1]) / 6, p2[2] - (p3[2] - p1[2]) / 6,
                p2[1], p2[2],
            } }
        end
    end
end

local function family(name)
    return (name:gsub("%-%d$", ""):gsub("%-off$", ""):gsub("%-charging$", ""):gsub("%-muted$", "")
        :gsub("%-low$", ""):gsub("%-medium$", ""):gsub("%-high$", ""))
end

local function draw(name, size, color)
    local build = GLYPHS[name]
    if build == nil then return { k.glyph(name, size, color) } end
    local strokes = build()
    local s = size / 24
    local width = math.max(1.3, 1.6 * s)
    -- Seeded by family and pass, so a level or an added slash only changes its own marks.
    local seed = hash(family(name))
    local jit = 0.4
    local drift = math.max(0.5, math.min(1.2, 0.9 * s))
    local da = k.rng(seed + 3)() * 2 * math.pi
    local passes = {
        { dx = 0, dy = 0, solid = {}, faint = {}, fill = {} },
        { dx = drift * math.cos(da), dy = drift * math.sin(da), solid = {}, faint = {}, fill = {} },
    }
    for i, pass in ipairs(passes) do
        local r = k.rng(seed + 7 * i)
        for _, st in ipairs(strokes) do
            local bucket = st.faint and pass.faint or (st.kind == "fill" and pass.fill or pass.solid)
            if st.hidden then bucket = {} end
            append(bucket, st, s, r, jit, pass.dx, pass.dy, pass ~= passes[1])
        end
    end
    local function node(commands, props)
        local t = {
            width = size, height = size, stroke = color, stroke_width = width,
            stroke_cap = "round", stroke_join = "round", commands = commands,
        }
        for key, v in pairs(props or {}) do t[key] = v end
        return path(t)
    end
    local children = {}
    local a, b = passes[1], passes[2]
    if #a.faint > 0 then children[#children + 1] = node(a.faint, { opacity = 0.28 }) end
    if #a.fill > 0 then children[#children + 1] = node(a.fill, { fill = color }) end
    children[#children + 1] = node(a.solid)
    children[#children + 1] = node(b.solid, { stroke_width = width * 0.7, opacity = 0.5 })
    return children
end

--- A hand-drawn pencil glyph: `name` from `M.names` (plain or a signal), `size` px square,
--- `color` (default ink; a signal works). An unknown name falls back to the theme icon.
function M.doodle(name, size, color)
    size = size or 20
    color = color or k.INK
    return rect {
        width = size,
        height = size,
        align_v = "center",
        children = util.lift(name, function(n) return draw(n, size, color) end),
    }
end

-- Freedesktop symbolic names to doodles. Battery and wifi levels are matched by pattern below.
local SYMBOLIC = {
    ["network-wireless"] = "wifi-4",
    ["network-wireless-connected"] = "wifi-4",
    ["network-wireless-offline"] = "wifi-off",
    ["network-wireless-disabled"] = "wifi-off",
    ["network-wireless-disconnected"] = "wifi-off",
    ["network-wireless-hardware-disabled"] = "wifi-off",
    ["network-wireless-acquiring"] = "wifi-0",
    ["network-wireless-no-route"] = "wifi-0",
    ["network-wired"] = "ethernet",
    ["network-wired-disconnected"] = "ethernet",
    ["network-wired-acquiring"] = "ethernet",
    ["bluetooth"] = "bluetooth",
    ["bluetooth-active"] = "bluetooth",
    ["bluetooth-disabled"] = "bluetooth-off",
    ["bluetooth-disconnected"] = "bluetooth-off",
    ["audio-volume-muted"] = "volume-muted",
    ["audio-volume-low"] = "volume-low",
    ["audio-volume-medium"] = "volume-medium",
    ["audio-volume-high"] = "volume-high",
    ["audio-volume-overamplified"] = "volume-high",
    ["audio-speakers"] = "volume-high",
    ["audio-input-microphone"] = "mic",
    ["audio-input-microphone-muted"] = "mic-off",
    ["microphone-disabled"] = "mic-off",
    ["microphone-sensitivity-muted"] = "mic-off",
    ["microphone-sensitivity-low"] = "mic",
    ["microphone-sensitivity-medium"] = "mic",
    ["microphone-sensitivity-high"] = "mic",
    ["battery-missing"] = "battery-0",
    ["battery-empty"] = "battery-0",
    ["battery-caution"] = "battery-1",
    ["battery-low"] = "battery-1",
    ["battery-medium"] = "battery-2",
    ["battery-good"] = "battery-3",
    ["battery-full"] = "battery-4",
    ["battery-full-charged"] = "battery-4",
    ["display-brightness"] = "brightness",
    ["weather-clear"] = "brightness",
    ["system-shutdown"] = "power",
    ["system-lock-screen"] = "lock",
    ["changes-prevent"] = "lock",
    ["system-log-out"] = "logout",
    ["application-exit"] = "logout",
    ["system-reboot"] = "restart",
    ["system-restart"] = "restart",
    ["view-refresh"] = "restart",
    ["system-suspend"] = "suspend",
    ["weather-clear-night"] = "suspend",
    ["night-light"] = "night",
    ["preferences-system"] = "settings",
    ["emblem-system"] = "settings",
    ["applications-system"] = "settings",
    ["system-search"] = "search",
    ["edit-find"] = "search",
    ["window-close"] = "close",
    ["edit-clear"] = "close",
    ["process-stop"] = "close",
    ["go-previous"] = "chevron-left",
    ["go-next"] = "chevron-right",
    ["go-up"] = "chevron-up",
    ["go-down"] = "chevron-down",
    ["pan-start"] = "chevron-left",
    ["pan-end"] = "chevron-right",
    ["pan-up"] = "chevron-up",
    ["pan-down"] = "chevron-down",
    ["list-add"] = "plus",
    ["object-select"] = "check",
    ["emblem-ok"] = "check",
    ["preferences-system-notifications"] = "bell",
    ["notifications"] = "bell",
    ["notifications-disabled"] = "bell-off",
    ["x-office-calendar"] = "calendar",
    ["office-calendar"] = "calendar",
    ["folder"] = "folder",
    ["folder-open"] = "folder",
    ["text-x-generic"] = "file",
    ["document"] = "file",
    ["user-home"] = "home",
    ["go-home"] = "home",
    ["folder-download"] = "download",
    ["document-save"] = "download",
    ["image-x-generic"] = "image",
    ["folder-pictures"] = "image",
    ["audio-x-generic"] = "music",
    ["folder-music"] = "music",
    ["video-x-generic"] = "video",
    ["folder-videos"] = "video",
    ["camera-video"] = "video",
    ["utilities-terminal"] = "terminal",
    ["user-trash"] = "trash",
    ["user-trash-full"] = "trash",
    ["edit-delete"] = "trash",
    ["input-keyboard"] = "keyboard",
    ["video-display"] = "display",
    ["preferences-desktop-display"] = "display",
    ["avatar-default"] = "user",
    ["system-users"] = "user",
    ["airplane-mode"] = "airplane",
}

local WIFI_SIGNAL = { none = "wifi-0", weak = "wifi-1", ok = "wifi-2", good = "wifi-3", excellent = "wifi-4" }

--- The doodle name for a freedesktop icon name (with or without `-symbolic`), or nil.
function M.doodle_name(symbolic)
    if symbolic == nil then return nil end
    local base = symbolic:gsub("%-symbolic$", "")
    if GLYPHS[base] then return base end
    if SYMBOLIC[base] then return SYMBOLIC[base] end
    local signal = base:match("^network%-wireless%-signal%-(%a+)")
    if signal then return WIFI_SIGNAL[signal] end
    local pct, charging = base:match("^battery%-level%-(%d+)(.*)$")
    if pct then
        if charging:find("charg") and pct ~= "100" then return "battery-charging" end
        return "battery-" .. math.min(4, math.floor((tonumber(pct) + 12) / 25))
    end
    local state = base:match("^battery%-(%a+)%-charging$")
    if state then return "battery-charging" end
    return nil
end

--- A doodle for a freedesktop icon name; the theme icon (`k.glyph`) when none matches.
--- `symbolic` may be a signal.
function M.doodle_for(symbolic, size, color)
    return M.doodle(util.lift(symbolic, function(n) return M.doodle_name(n) or n end), size, color)
end

return M
