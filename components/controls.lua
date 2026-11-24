-- Paper controls: card-stock buttons, paper discs, a groove toggle, pencil radios and checkboxes,
-- a highlighter slider, a ruled-line field, index tabs, washi chips and sticky notes.
-- Every interactive control takes `id` (its hover/focus name, unique per instance) and either a
-- plain value or a signal, and reports changes through a callback; none owns a state, so a
-- capability or the store can drive it.
local k = require("lib.paper")
local util = require("lib.util")

local INK, INK_SOFT, BLUE, RED, HAND = k.INK, k.INK_SOFT, k.BLUE, k.RED, k.HAND
local hand, body = k.hand, k.body

local M = {}

local function hover_of(prefix, id)
    return hover("paper." .. prefix .. "." .. id)
end

local function capsule_shape(w, h)
    local r = h / 2
    return { commands = {
        { op = "M", points = { r, 0 } },
        { op = "corner", points = { w, 0 }, radius = r },
        { op = "corner", points = { w, h }, radius = r },
        { op = "corner", points = { 0, h }, radius = r },
        { op = "corner", points = { 0, 0 }, radius = r },
        { op = "Z", points = {} },
    } }
end
M.capsule_shape = capsule_shape

-- A section heading in blue Caveat over its rows.
function M.section(title, children, spacing)
    return column {
        spacing = 12,
        width = "fill",
        children = {
            hand(title, 30, { font_weight = 700, foreground = BLUE }),
            column { spacing = spacing or 16, width = "fill", children = children },
        },
    }
end

-- Button: a torn scrap of card stock that peels up on hover.
-- o = { id?, label, kind = "primary"|"plain"|"danger", width?, height?, size?, on_click, icon? }
function M.button(o)
    local stock = k.STOCK[o.kind or "plain"]
    local id = o.id or o.label
    local hovered = hover_of("btn", id)
    local w, h = o.width or math.max(96, #o.label * 13 + 44), o.height or 46
    local label = hand(o.label, o.size or 25, {
        font_weight = 700, foreground = stock[2], align_v = "center",
    })
    return rect {
        hover = hovered,
        accessible_name = o.label,
        on_click = o.on_click or function() end,
        cursor = "pointer",
        rotate = hovered:map(function(v) return v and -2 or ((#o.label % 3) - 1) * 0.6 end),
        translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
        animate = {
            rotate = { spring = { stiffness = 300, damping = 16 } },
            translate = { duration = 140, easing = "out_cubic" },
        },
        children = {
            k.sheet {
                width = w,
                height = h,
                seed = #o.label * 31 + w,
                depth = 3,
                color = stock[1],
                shadows = k.lift(hovered),
                animate = { shadows = { duration = 160, easing = "out_cubic" } },
                child = row {
                    spacing = 8,
                    align_h = "center",
                    align_v = "center",
                    children = o.icon and { k.glyph(o.icon, 20, stock[2]), label } or { label },
                },
            },
        },
    }
end

-- Link: deep-blue Caveat with a squiggle, a yellow highlighter swipe on hover.
function M.link(o)
    local hovered = hover_of("link", o.id or o.label)
    local size = o.size or 24
    local w = math.floor(#o.label * size * 0.4) + 4
    return rect {
        align_v = "center",
        hover = hovered,
        accessible_name = o.label,
        cursor = "pointer",
        on_click = o.on_click or function() end,
        children = {
            rect {
                width = w,
                height = math.floor(size * 0.6),
                align_v = "end",
                translate = { y = -4 },
                background = k.HIGHLIGHT,
                blend = "multiply",
                shape = k.tape_shape(w, math.floor(size * 0.6), #o.label),
                opacity = hovered:map(function(v) return v and 1 or 0 end),
                animate = { opacity = { duration = 140 } },
            },
            hand(o.label, size, { foreground = k.DEEP_BLUE }),
            rect { align_v = "end", translate = { y = 5 }, children = { k.squiggle(w, BLUE) } },
        },
    }
end

-- Icon button: a punched paper disc. o = { id?, icon, size?, seed?, on_click, tooltip? }
function M.disc_button(o)
    local size = o.size or 44
    local hovered = hover_of("disc", o.id or o.icon)
    return rect {
        width = size,
        height = size,
        hover = hovered,
        accessible_name = o.tooltip or o.icon,
        cursor = "pointer",
        on_click = o.on_click or function() end,
        translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
        animate = { translate = { duration = 140, easing = "out_cubic" } },
        children = {
            k.sheet {
                width = size,
                height = size,
                shape = k.torn_circle(size, o.seed or #o.icon),
                color = o.color or "#F4ECDA",
                shadows = k.lift(hovered),
                animate = { shadows = { duration = 160 } },
                fx = { rim = 1.4 },
            },
            k.glyph(o.icon, math.floor(size * 0.46), o.ink or INK),
        },
    }
end

-- Toggle: a groove pressed into the page; on, it is hatched blue and the disc rolls right.
-- o = { id, value = bool|signal, on_toggle = fn(new), label? }
function M.toggle(o)
    local W, H, D = 62, 30, 26
    local on = util.lift(o.value, function(v) return v == true end)
    local function track(v)
        return {
            rect {
                id = "groove",
                width = W,
                height = H,
                shape = capsule_shape(W, H),
                background = v and "#D5E0EE" or k.GROOVE,
                border_width = 1.2,
                border_color = "#3A363170",
                shadows = { { inset = true, blur = 5, offset = { y = 2 }, color = "#00000048" } },
                effect = k.paper_fx { rim = 0, hatch = v and 1 or 0, hatch_color = { 0.2, 0.38, 0.7, 0.75 }, hatch_spacing = 3.2 },
            },
            rect {
                id = "disc",
                width = D,
                height = D,
                align_v = "center",
                translate = { x = v and W - D - 2 or 2 },
                rotate = v and 160 or 0,
                animate = {
                    translate = { spring = { stiffness = 380, damping = 24 } },
                    rotate = { spring = { stiffness = 380, damping = 24 } },
                },
                children = {
                    k.sheet {
                        width = D,
                        height = D,
                        shape = k.torn_circle(D, 9),
                        color = "#F6EFDF",
                        shadows = { { blur = 4, offset = { x = 1, y = 2 }, color = "#00000060" } },
                        fx = { rim = 1.4 },
                        child = rect {
                            width = 5, height = 5, radius = 3, translate = { x = 6, y = 6 },
                            background = v and BLUE or "#3A363160",
                        },
                    },
                },
            },
        }
    end
    local children = {
        rect { width = W, height = H, align_v = "center", children = util.lift(on, track) },
    }
    if o.label then children[2] = body(o.label, 21, { align_v = "center" }) end
    return row {
        spacing = 14,
        accessible_name = o.label or o.id,
        cursor = "pointer",
        on_click = function()
            local now = type(on) == "userdata" and on:get() or on
            if o.on_toggle then o.on_toggle(not now) end
        end,
        children = children,
    }
end

function M.pencil_circle(size, seed, color, width)
    local r = k.rng(seed)
    local c = size / 2
    return path {
        width = size,
        height = size,
        stroke = color or INK,
        stroke_width = width or 1.4,
        stroke_cap = "round",
        commands = { { op = "A", points = { c + (r() - 0.5), c + (r() - 0.5), c - 2.5, -100, 380 } } },
    }
end

local SCRIBBLE = {
    { op = "M", points = { 8, 9 } }, { op = "L", points = { 15, 7 } }, { op = "L", points = { 7, 13 } },
    { op = "L", points = { 17, 11 } }, { op = "L", points = { 8, 17 } }, { op = "L", points = { 16, 15.5 } },
}

-- Radio: pencil circles; the chosen one is scribbled in blue marker.
-- o = { id, options = { {value, label}, ... } | {"a","b"}, value = signal|plain, on_select = fn(v), vertical? }
function M.radio_group(o)
    local rows = {}
    for i, opt in ipairs(o.options) do
        local v, label = opt, opt
        if type(opt) == "table" then v, label = opt[1], opt[2] end
        rows[i] = row {
            spacing = 10,
            accessible_name = label,
            cursor = "pointer",
            on_click = function() if o.on_select then o.on_select(v) end end,
            children = {
                rect {
                    width = 24,
                    height = 24,
                    align_v = "center",
                    children = util.lift(o.value, function(p)
                        local c = { M.pencil_circle(24, 30 + i, INK) }
                        if p == v then
                            c[2] = path {
                                width = 24, height = 24, stroke = BLUE, stroke_width = 2.6,
                                stroke_cap = "round", stroke_join = "round", commands = SCRIBBLE,
                            }
                        end
                        return c
                    end),
                },
                body(label, 21, { align_v = "center" }),
            },
        }
    end
    if o.vertical then return column { spacing = 10, children = rows } end
    return row { spacing = 26, children = rows }
end

-- Checkbox with a label. o = { id?, label, value, on_toggle = fn(new) }
function M.checkbox_row(o)
    return row {
        spacing = 10,
        accessible_name = o.label,
        cursor = "pointer",
        on_click = function()
            local now = type(o.value) == "userdata" and o.value:get() or o.value
            if o.on_toggle then o.on_toggle(not now) end
        end,
        children = util.lift(o.value, function(d)
            return { k.checkbox(22, d == true), body(o.label, 21, { align_v = "center" }) }
        end),
    }
end

-- Slider: a pencil line with highlighter over the value and a red paper thumb.
-- o = { id, value = 0..1 signal|plain, on_change = fn(v, phase), width?, icon?, show_value? }
function M.slider(o)
    local W = o.width or 280
    local value = o.value
    local line = { { op = "M", points = { 6, 16 } }, { op = "Q", points = { W / 2, 14, W - 6, 17 } } }
    local function set(r, p, phase)
        local v = math.max(0, math.min(1, p.x / r.width))
        if o.on_change then o.on_change(v, phase) end
    end
    local children = {}
    if o.icon then children[#children + 1] = k.glyph(o.icon, 22) end
    children[#children + 1] = rect {
        width = W,
        height = 32,
        align_v = "center",
        cursor = "pointer",
        on_drag = function(r, p, phase) set(r, p, phase) end,
        on_click = function(r, _, p) set(r, p, "end") end,
        on_wheel = o.on_wheel,
        children = {
            k.stroke_path(W, 32, line, "#3A363199", 1.5),
            path {
                width = W, height = 32, stroke = "#9EC0EC99", stroke_width = 13, stroke_cap = "butt",
                blend = "multiply", trim_end = value, commands = line,
            },
            rect {
                width = 22,
                height = 22,
                align_v = "center",
                translate = util.lift(value, function(v) return { x = 6 + (v or 0) * (W - 12) - 11 } end),
                children = {
                    k.sheet {
                        width = 22, height = 22, shape = k.torn_circle(22, 13, 1.2), color = RED,
                        shadows = { { blur = 4, offset = { x = 1, y = 2 }, color = "#00000055" } },
                    },
                    M.pencil_circle(22, 14, "#7A2522", 1.3),
                },
            },
        },
    }
    if o.show_value ~= false then
        children[#children + 1] = body(util.lift(value, function(v) return math.floor((v or 0) * 100 + 0.5) .. "%" end), 20,
            { align_v = "center", width = 48 })
    end
    return row { spacing = 12, children = children }
end

-- Text field: writing on a ruled line; focus inks the line blue.
-- o = { id, placeholder, width?, size?, plus any textfield props (on_change, on_submit, on_key,
-- autofocus, masked, secure_submit, focus_target, ...) }
function M.field(o)
    local W = o.width or 320
    local has_focus = focused("paper.field." .. o.id)
    local props = {
        width = "fill",
        height = math.floor((o.size or 26) * 1.5),
        font = HAND,
        font_size = o.size or 26,
        foreground = INK,
        placeholder_color = "#3A363170",
        caret = { color = BLUE, width = 2 },
        selection = { background = "#F2C94C90" },
        accessible_name = o.placeholder,
        focus_ring = false,
    }
    for key, v in pairs(o) do
        if key ~= "id" and key ~= "width" and key ~= "size" then props[key] = v end
    end
    if not props.on_change and not props.secure_submit then props.on_change = function() end end
    return rect {
        width = W,
        focused = has_focus,
        children = {
            textfield(props),
            rect {
                align_v = "end",
                children = has_focus:map(function(f)
                    return {
                        k.stroke_path(W, 8, {
                            { op = "M", points = { 2, 4 } },
                            { op = "Q", points = { W / 2, 2, W - 2, 5 } },
                        }, f and BLUE or "#3A363180", f and 2 or 1.3),
                    }
                end),
            },
        },
    }
end

-- Index tabs, horizontal: the chosen tab stands taller. Pair with a card of `M.TINTS[i]` below.
-- o = { names, value = index signal, on_select = fn(i), width? }
M.TINTS = { "#E9DDBB", "#C9D8EA", "#EBCBC5", "#D6E3C4", "#E4D3E8", "#F0DDB8" }
function M.tabs(o)
    local items = {}
    local w = o.width or 118
    for i, n in ipairs(o.names) do
        items[i] = rect {
            accessible_name = n,
            cursor = "pointer",
            on_click = function() if o.on_select then o.on_select(i) end end,
            align_v = "end",
            z = util.lift(o.value, function(p) return p == i and #o.names + 1 or #o.names - i end),
            children = util.lift(o.value, function(p)
                local h = p == i and 44 or 36
                local tint = M.TINTS[(i - 1) % #M.TINTS + 1]
                return {
                    rect {
                        width = w,
                        height = h + 6,
                        translate = { y = 6 },
                        background = tint,
                        shadows = { { blur = 4, offset = { y = -1 }, color = "#00000030" } },
                        effect = k.paper_fx { rim = 0 },
                        shape = { commands = {
                            { op = "M", points = { 0, h + 6 } },
                            { op = "corner", points = { 10, 0 }, radius = 7 },
                            { op = "corner", points = { w - 10, 0 }, radius = 7 },
                            { op = "L", points = { w, h + 6 } },
                            { op = "Z", points = {} },
                        } },
                        children = {
                            hand(n, 24, {
                                font_weight = p == i and 700 or 400,
                                align_h = "center",
                                padding = { top = 6, right = 4 },
                                foreground = p == i and INK or INK_SOFT,
                            }),
                        },
                    },
                }
            end),
        }
    end
    return row { spacing = -8, padding = { left = 12 }, children = items }
end

-- Chip: a strip of washi tape with a Caveat label.
function M.chip(label, color, seed)
    local w = #label * 11 + 34
    return rect {
        width = w,
        height = 30,
        rotate = ((seed or 1) % 3 - 1) * 2,
        background = color or "#A9C3E3C8",
        shape = k.tape_shape(w, 30, seed or 1),
        shadows = k.SHADOW.tape,
        effect = k.paper_fx { grain = 0.35, mottle = 0.2, rim = 0 },
        children = { hand(label, 24, { align_h = "center", align_v = "center" }) },
    }
end

-- Sticky note with a dog-eared corner, held by tape. o = { width, height, seed, child, rotate?, tape? }
function M.sticky(o)
    local w, h, f = o.width, o.height, 12
    local r = k.rng(o.seed or 1)
    local c = { { op = "M", points = { 0, 0 } } }
    for x = 12, w, 12 do c[#c + 1] = { op = "L", points = { math.min(x, w), r() * 2.5 } } end
    c[#c + 1] = { op = "L", points = { w, h - f } }
    c[#c + 1] = { op = "L", points = { w - f, h } }
    c[#c + 1] = { op = "L", points = { 0, h } }
    c[#c + 1] = { op = "Z", points = {} }
    local children = {
        rect {
            width = w,
            height = h,
            shape = { commands = c },
            background = o.color or k.STICKY,
            shadows = { { blur = 10, offset = { x = 2, y = 6 }, color = "#00000055" } },
            effect = k.paper_fx { rim = 0, grain = 0.18 },
            children = {
                o.child,
                path {
                    width = w, height = h, fill = k.STICKY_FOLD,
                    shadows = { { blur = 3, offset = { x = -1, y = -1 }, color = "#00000040" } },
                    commands = {
                        { op = "M", points = { w - f, h } }, { op = "L", points = { w, h - f } },
                        { op = "L", points = { w - f + 2, h - f + 2 } }, { op = "Z", points = {} },
                    },
                },
            },
        },
    }
    if o.tape ~= false then
        children[2] = k.tape { width = 64, height = 20, translate = { y = -8 }, rotate = 3, seed = o.seed or 1 }
    end
    return rect { rotate = o.rotate or -2, padding = { top = 10 }, children = children }
end

-- Focus: a blue pencil loop drawn round a control in place of a solid ring.
function M.pencil_loop(w, h, seed)
    local r = k.rng(seed or 99)
    local c = {}
    for pass = 0, 1 do
        local j = function() return (r() - 0.5) * 2 end
        c[#c + 1] = { op = "M", points = { w * 0.15 + j(), 3 + j() } }
        c[#c + 1] = { op = "C", points = { w * 0.6, -1 + j(), w + 2, 2 + j(), w - 2 + j(), h / 2 } }
        c[#c + 1] = { op = "C", points = { w + 1, h - 1 + j(), w * 0.4, h + 2, 6 + j(), h - 6 + j() } }
        c[#c + 1] = { op = "C", points = { -2, h / 2 + j(), 0, 4, w * 0.25 + pass * 8, 1 + j() } }
    end
    return k.stroke_path(w, h, c, BLUE, 1.8)
end

-- A ruled-paper page: blue rules every `pitch` px from `top`, a red margin at `margin`.
function M.ruled(w, h, o)
    o = o or {}
    local rules = {}
    for y = o.top or 84, h - 10, o.pitch or 34 do
        rules[#rules + 1] = { op = "M", points = { 0, y } }
        rules[#rules + 1] = { op = "L", points = { w, y } }
    end
    local layers = { path { width = w, height = h, stroke = "#7FA3D040", stroke_width = 1, commands = rules } }
    if o.margin ~= false then
        local m = o.margin or 70
        layers[2] = path {
            width = w, height = h, stroke = "#D9534F60", stroke_width = 1.4,
            commands = { { op = "M", points = { m, 0 } }, { op = "L", points = { m, h } } },
        }
    end
    return layers
end

-- A hairline pencil divider. vertical = true for a column divider.
function M.divider(len, vertical, seed)
    local r = k.rng(seed or len)
    local wob = (r() - 0.5) * 2
    if vertical then
        return k.stroke_path(6, len, { { op = "M", points = { 3, 2 } }, { op = "Q", points = { 3 + wob, len / 2, 3, len - 2 } } },
            "#3A363170", 1.3)
    end
    return k.stroke_path(len, 6, { { op = "M", points = { 2, 3 } }, { op = "Q", points = { len / 2, 3 + wob, len - 2, 3 } } },
        "#3A363170", 1.3)
end

return M
