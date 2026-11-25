-- The updater's marks: a pencil "package" doodle in the style of components/icons.lua, a pink stock
-- count badge, a red exclamation, a pencil arrow for version changes and a progress ring.
local theme = require("theme")
local k = require("lib.paper")
local util = require("lib.util")

local M = {}

-- Strokes on icons.lua's 24-unit grid: a box seen from above with a strip of tape over its lid.
local PACKAGE = {
    { 12, 3.2, 20.5, 7.6, 20.5, 16.6, 12, 21, 3.5, 16.6, 3.5, 7.6, 12, 3.2 },
    { 3.5, 7.6, 12, 12, 20.5, 7.6 },
    { 12, 12, 12, 21 },
    { 7.6, 5.4, 16.2, 9.9, 16.2, 13.4 },
}

-- Each segment a slightly bowed curve, drawn twice with a drift, as icons.lua's pencil does.
local function pencil(strokes, size, color, seed)
    local s = size / 24
    local width = math.max(1.3, 1.6 * s)
    local passes = {}
    for pass = 1, 2 do
        local r = k.rng(seed + pass * 7)
        local dx, dy = (pass - 1) * 0.7 * s, (pass - 1) * 0.5 * s
        local c = {}
        for _, st in ipairs(strokes) do
            local function at(i)
                return st[i] * s + (r() - 0.5) * 0.8 * s + dx, st[i + 1] * s + (r() - 0.5) * 0.8 * s + dy
            end
            local x0, y0 = at(1)
            c[#c + 1] = { op = "M", points = { x0, y0 } }
            for i = 3, #st - 1, 2 do
                local x1, y1 = at(i)
                local bow = (r() - 0.5) * 0.1
                local mx, my = (x0 + x1) / 2 - (y1 - y0) * bow, (y0 + y1) / 2 + (x1 - x0) * bow
                c[#c + 1] = { op = "Q", points = { mx, my, x1, y1 } }
                x0, y0 = x1, y1
            end
        end
        passes[pass] = path {
            width = size, height = size, stroke = color, stroke_cap = "round", stroke_join = "round",
            stroke_width = pass == 1 and width or width * 0.7, opacity = pass == 1 and 1 or 0.5, commands = c,
        }
    end
    return rect { width = size, height = size, align_v = "center", children = passes }
end

function M.package(size, color)
    return pencil(PACKAGE, size or theme.updates.package_sticker, color or theme.INK, 4417)
end

-- A red marker exclamation: a stroke that thins as the marker lifts, and a dot.
function M.exclamation(size)
    local s = size / 24
    return rect {
        width = size,
        height = size,
        align_v = "center",
        children = {
            util.with(k.stroke_path(size, size, {
                { op = "M", points = { 12.6 * s, 3.5 * s } },
                { op = "Q", points = { 11.6 * s, 9 * s, 12 * s, 15 * s } },
            }, theme.RED, 3.6 * s), "taper_end", 8 * s),
            path {
                width = size, height = size, fill = theme.RED,
                commands = { { op = "A", points = { 12 * s, 19.8 * s, 1.9 * s, 0, 360 } } },
            },
        },
    }
end

-- The count on a disc of pink stock in deep red, as the taskbar's unread badges; it widens with the
-- digits.
function M.badge(count)
    return rect {
        min_width = theme.updates.badge_size,
        height = theme.updates.badge_size,
        radius = theme.radius.spine,
        padding = { left = theme.spacing.xxs, right = theme.spacing.xxs },
        background = theme.STOCK.danger[1],
        shadows = theme.SHADOW.tiny,
        effect = k.paper_fx { rim = 0 },
        children = {
            k.body(util.lift(count, function(n) return n > 99 and "99+" or tostring(n) end), theme.font.mono_small, {
                font_weight = theme.BOLD, foreground = theme.DEEP_RED, align_h = "center", align_v = "center",
            }),
        },
    }
end

-- old → new: an arrow in pencil.
local arrow_points = theme.updates.arrow_points
function M.arrow()
    return k.stroke_path(theme.updates.arrow_w, theme.updates.arrow_h, {
        { op = "M", points = { arrow_points[1], arrow_points[2] } }, { op = "Q", points = { arrow_points[3], arrow_points[4], arrow_points[5], arrow_points[6] } },
        { op = "M", points = { arrow_points[7], arrow_points[8] } }, { op = "Q", points = { arrow_points[9], arrow_points[10], arrow_points[11], arrow_points[6] } },
        { op = "Q", points = { arrow_points[12], arrow_points[13], arrow_points[14], arrow_points[15] } },
    }, theme.INK_SOFT, 1.3)
end

-- A pencil circle with a blue marker arc over `fraction` (0..1, a signal) of it; `nil` spins a
-- quarter arc for a step count pacman has not reported yet.
function M.ring(size, fraction, spinning)
    local c = size / 2
    local circle = { { op = "A", points = { c, c, c - 2.5, -90, 360 } } }
    return rect {
        width = size,
        height = size,
        align_h = "center",
        align_v = "center",
        children = {
            path {
                width = size, height = size, stroke = theme.INK_FAINT, stroke_width = 1.3, commands = {
                    { op = "A", points = { c + 0.4, c - 0.3, c - 2.2, -100, 375 } },
                },
            },
            path {
                width = size,
                height = size,
                stroke = theme.BLUE,
                stroke_width = 2.6,
                stroke_cap = "round",
                commands = circle,
                trim_end = computed({ fraction, spinning }, function(f, spin) return spin and 0.25 or f end, 0),
                rotate = 0,
                animate = spinning:map(function(spin)
                    if not spin then return { trim_end = { duration = 300, easing = "out_cubic" } } end
                    return {
                        rotate = { duration = 1400, easing = "linear", keyframes = { 0, 360 }, loops = "infinite" },
                    }
                end),
            },
        },
    }
end

return M
