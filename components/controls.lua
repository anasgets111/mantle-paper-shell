-- Paper controls: card-stock buttons, paper discs, a groove toggle, pencil radios and checkboxes,
-- a highlighter slider, a ruled-line field, index tabs, washi chips and sticky notes.
-- Every interactive control takes `id` (its hover/focus name, unique per instance) and either a
-- plain value or a signal, and reports changes through a callback; none owns a state, so a
-- capability or the store can drive it.
local k = require("lib.paper")
local util = require("lib.util")
local icons = require("components.icons")

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

-- Keyboard focus: a blue pencil loop drawn just outside a w x h box, in place of the engine's
-- square outline. Returns the focus signal (for the control's `focus_visible`) and the loop node.
local function focus_mark(name, w, h, seed)
    local f = focus_visible(name .. ".focus")
    return f, rect {
        width = w,
        height = h,
        opacity = f:map(function(v) return v and 1 or 0 end),
        animate = { opacity = { duration = 120 } },
        children = { M.pencil_loop(w, h, seed, 5) },
    }
end

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
    local focus, mark = focus_mark("paper.btn." .. id, w, h, #o.label)
    return rect {
        hover = hovered,
        focus_visible = focus,
        focus_ring = false,
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
            mark,
        },
    }
end

-- Link: deep-blue Caveat with a squiggle, a yellow highlighter swipe on hover and the pencil loop on
-- keyboard focus. The swipe fills the label's box; squiggle and loop take its laid-out size.
function M.link(o)
    local id = o.id or o.label
    local hovered = hover_of("link", id)
    local focus = focus_visible("paper.link." .. id .. ".focus")
    local size = o.size or 24
    local box = geometry("paper.link." .. id .. ".label")
    -- Whole pixels, so a link that only moves (a scrolled list) does not redraw its strokes.
    local w = box:map(function(r) return math.floor(r.width) end)
    local h = box:map(function(r) return math.floor(r.height) end)
    return rect {
        align_v = "center",
        hover = hovered,
        focus_visible = focus,
        focus_ring = false,
        accessible_name = o.label,
        cursor = "pointer",
        on_click = o.on_click or function() end,
        children = {
            rect {
                width = "fill",
                height = math.floor(size * 0.6),
                align_v = "end",
                translate = { y = -4 },
                background = k.HIGHLIGHT,
                blend = "multiply",
                shape = k.tape_shape(nil, nil, #o.label),
                opacity = hovered:map(function(v) return v and 1 or 0 end),
                animate = { opacity = { duration = 140 } },
            },
            hand(o.label, size, { foreground = k.DEEP_BLUE, geometry = box }),
            rect {
                align_v = "end",
                translate = { y = 5 },
                children = w:map(function(px) return px > 8 and { k.squiggle(px, BLUE) } or {} end),
            },
            rect {
                opacity = focus:map(function(v) return v and 1 or 0 end),
                animate = { opacity = { duration = 120 } },
                children = computed({ w, h }, function(pw, ph)
                    return pw > 8 and { M.pencil_loop(pw, ph, #o.label, 5) } or {}
                end),
            },
        },
    }
end

-- Icon button: a punched paper disc. o = { id?, icon, size?, seed?, on_click, tooltip? }
function M.disc_button(o)
    local size = o.size or 44
    local hovered = hover_of("disc", o.id or o.icon)
    local focus, mark = focus_mark("paper.disc." .. (o.id or o.icon), size, size, size)
    return rect {
        width = size,
        height = size,
        hover = hovered,
        focus_visible = focus,
        focus_ring = false,
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
                color = o.color or k.CARD,
                shadows = k.lift(hovered),
                animate = { shadows = { duration = 160 } },
                fx = { rim = 1.4 },
            },
            util.with(icons.doodle(o.icon, math.floor(size * 0.46), o.ink or INK), "align_h", "center"),
            mark,
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
                        color = k.CARD_LIGHT,
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
    local focus, mark = focus_mark("paper.toggle." .. o.id, W, H, 7)
    local children = {
        rect { width = W, height = H, align_v = "center", children = { rect { children = util.lift(on, track) }, mark } },
    }
    if o.label then children[2] = body(o.label, 21, { align_v = "center" }) end
    return row {
        spacing = 14,
        focus_visible = focus,
        focus_ring = false,
        accessible_name = o.label or o.id,
        cursor = "pointer",
        on_click = function()
            local now = util.get(on)
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
        local focus, mark = focus_mark("paper.radio." .. (o.id or "") .. "." .. i, 24, 24, 40 + i)
        rows[i] = row {
            spacing = 10,
            focus_visible = focus,
            focus_ring = false,
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
                rect { width = 0, height = 24, align_v = "center", translate = { x = -34 }, children = { mark } },
                body(label, 21, { align_v = "center" }),
            },
        }
    end
    if o.vertical then return column { spacing = 10, children = rows } end
    return row { spacing = 26, children = rows }
end

-- Dropdown: a card-stock strip showing the current choice and a chevron. A click, Enter or Space
-- opens `o.menu` (a `components/menu.lua` menu on the same surface) under it, the current option
-- ticked; the wheel steps through the options without opening it, unless `wheel = false`.
-- o = { id, options = { {value, label}, ... }, value = signal|plain, on_select = fn(v), menu, width?,
--       height?, label? (accessible name), empty? (text while no option matches), wheel?,
--       elided? (an `elided` signal for the shown value, so a caller can tooltip a cut one) }
function M.dropdown(o)
    local W, H = o.width or 260, o.height or 28
    local hovered = hover_of("dropdown", o.id)
    local focus, mark = focus_mark("paper.dropdown." .. o.id, W, H, #o.id)
    local function index(v)
        for i, opt in ipairs(o.options) do
            if opt[1] == v then return i end
        end
    end
    local current = util.lift(o.value, function(v)
        local i = index(v)
        return i and o.options[i][2] or (o.empty or "")
    end)
    -- Touchpads send fractions of a notch: a step waits for a whole one.
    local notches = 0
    local function step(by)
        local i = index(util.get(o.value))
        local to = o.options[i and i + by or (by > 0 and 1 or #o.options)]
        if to and o.on_select then o.on_select(to[1]) end
    end
    return rect {
        width = W,
        height = H,
        hover = hovered,
        focus_visible = focus,
        focus_ring = false,
        accessible_name = o.label or o.id,
        cursor = "pointer",
        on_click = function(r, button)
            -- Middle and right clicks mean nothing here; an empty list has nothing to show.
            if button ~= "left" or #o.options == 0 then return end
            local now = util.get(o.value)
            local items = {}
            for i, opt in ipairs(o.options) do
                items[i] = {
                    label = opt[2],
                    checked = opt[1] == now or nil,
                    on_click = function() if o.on_select then o.on_select(opt[1]) end end,
                }
            end
            o.menu.open(r, items, { anchor = "bottom_left", gravity = "bottom_right", width = math.max(W + 28, 250) })
        end,
        on_wheel = o.wheel ~= false and function(_, steps)
            notches = notches + steps
            while math.abs(notches) >= 1 do
                -- Away from the user is up the list.
                step(notches > 0 and -1 or 1)
                notches = notches - (notches > 0 and 1 or -1)
            end
        end or nil,
        translate = hovered:map(function(v) return { y = v and -2 or 0 } end),
        animate = { translate = { duration = 140, easing = "out_cubic" } },
        children = {
            k.sheet {
                width = W,
                height = H,
                seed = W + #o.id,
                depth = 2,
                color = k.CARD_LIGHT,
                shadows = k.lift(hovered),
                animate = { shadows = { duration = 160, easing = "out_cubic" } },
                child = row {
                    width = "fill",
                    height = "fill",
                    spacing = 6,
                    padding = { left = 12, right = 8 },
                    children = {
                        body(current, 19, { width = "fill", elide = "end", elided = o.elided, align_v = "center" }),
                        util.with(icons.doodle("chevron-down", 18, INK_SOFT), "align_v", "center"),
                    },
                },
            },
            mark,
        },
    }
end

-- Checkbox with a label. o = { id?, label, value, on_toggle = fn(new) }
function M.checkbox_row(o)
    local focus, mark = focus_mark("paper.check." .. (o.id or o.label), 22, 22, #o.label)
    return row {
        spacing = 10,
        focus_visible = focus,
        focus_ring = false,
        accessible_name = o.label,
        cursor = "pointer",
        on_click = function()
            local now = util.get(o.value)
            if o.on_toggle then o.on_toggle(not now) end
        end,
        children = util.lift(o.value, function(d)
            return { rect { children = { k.checkbox(22, d == true), mark } }, body(o.label, 21, { align_v = "center" }) }
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
    local focus, mark = focus_mark("paper.slider." .. (o.id or ""), W, 32, W)
    local children = {}
    if o.icon then children[#children + 1] = k.glyph(o.icon, 22) end
    children[#children + 1] = rect {
        width = W,
        height = 32,
        focus_visible = focus,
        focus_ring = false,
        align_v = "center",
        cursor = "pointer",
        on_drag = function(r, p, phase) set(r, p, phase) end,
        on_click = function(r, _, p) set(r, p, "end") end,
        on_wheel = o.on_wheel,
        -- Tab reaches it; arrows step 5%. Enter and Space would click its centre (50%), so they stop here.
        accessible_name = o.accessible_name or o.id,
        on_key = function(key)
            local step = ({ Left = -0.05, Down = -0.05, Right = 0.05, Up = 0.05 })[key.name]
            if step and o.on_change then
                o.on_change(math.max(0, math.min(1, (util.get(value) or 0) + step)), "end")
            end
            return step ~= nil or key.name == "Return" or key.name == "KP_Enter" or key.name == "space"
        end,
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
            mark,
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

-- Index tabs, horizontal: the chosen tab stands taller. Pair with a card of `M.TINTS[i]` below, or
-- stand them on a ruled line. Left and Right on a focused tab choose its neighbour.
-- o = { id, names, value = index signal, on_select = fn(i), width? }
M.TINTS = { "#E9DDBB", "#C9D8EA", "#EBCBC5", "#D6E3C4", "#E4D3E8", "#F0DDB8" }
function M.tabs(o)
    local items = {}
    local w = o.width or 118
    local function target(i) return focus_target("paper.tabs." .. o.id .. "." .. i) end
    for i, n in ipairs(o.names) do
        local focus = focus_visible("paper.tabs." .. o.id .. "." .. i)
        items[i] = rect {
            accessible_name = n,
            cursor = "pointer",
            on_click = function(_, button)
                if button == "left" and o.on_select then o.on_select(i) end
            end,
            focus_target = target(i),
            focus_visible = focus,
            focus_ring = false,
            on_key = function(key)
                local to = i + (({ Left = -1, Right = 1 })[key.name] or 0)
                if to == i or not o.names[to] then return key.name == "Left" or key.name == "Right" end
                if o.on_select then o.on_select(to) end
                target(to):request()
                return true
            end,
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
                            -- Round the label, about 12 px a letter, with a little air.
                            rect {
                                translate = { x = (w - math.min(w - 12, #n * 12 + 20)) / 2, y = 4 },
                                opacity = focus:map(function(v) return v and 1 or 0 end),
                                children = { M.pencil_loop(math.min(w - 12, #n * 12 + 20), h - 8, 60 + i, 2) },
                            },
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
        background = color or "#B5CBE6",
        shape = k.tape_shape(w, 30, seed or 1),
        shadows = k.SHADOW.tape,
        effect = k.paper_fx { grain = 0.35, mottle = 0.2, rim = 0 },
        children = { hand(label, 24, { align_h = "center", align_v = "center" }) },
    }
end

-- Sticky note with a dog-eared corner, held by tape. o = { width, height?, seed, child, rotate?, tape?,
-- color? }; without `height` it fits its child.
function M.sticky(o)
    local w, f = o.width, 12
    local r = k.rng(o.seed or 1)
    local c = { { op = "M", points = { 0, 0 } } }
    for x = 12, w, 12 do c[#c + 1] = { op = "L", points = { math.min(x, w), r() * 2.5 } } end
    -- The bottom corners hang from the edges, so a note without `height` grows with its child.
    c[#c + 1] = { op = "L", points = { w, { from = "bottom", px = -f } } }
    c[#c + 1] = { op = "L", points = { w - f, "100%" } }
    c[#c + 1] = { op = "L", points = { 0, "100%" } }
    c[#c + 1] = { op = "Z", points = {} }
    local children = {
        rect {
            width = w,
            height = o.height,
            children = {
                rect {
                    width = "fill",
                    height = "fill",
                    shape = { commands = c },
                    background = o.color or k.STICKY,
                    shadows = { { blur = 10, offset = { x = 2, y = 6 }, color = "#00000055" } },
                    effect = k.paper_fx { rim = 0, grain = 0.18 },
                },
                o.child,
                path {
                    hittable = false,
                    width = f, height = f, align_h = "end", align_v = "end", fill = k.STICKY_FOLD,
                    shadows = { { blur = 3, offset = { x = -1, y = -1 }, color = "#00000040" } },
                    commands = {
                        { op = "M", points = { 0, f } }, { op = "L", points = { f, 0 } },
                        { op = "L", points = { 2, 2 } }, { op = "Z", points = {} },
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

-- A notebook tab: card stock with rounded outer corners and a deckled top, end and bottom; the
-- right end tucks under the page it belongs to.
function M.tab_shape(w, h, seed)
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

-- Focus: a blue pencil loop drawn round a control in place of a solid ring.
-- `pad` draws the loop that many px outside the w x h box: the path is that much bigger on every
-- side and shifted back, since a path clips its stroke to its own box.
function M.pencil_loop(w, h, seed, pad)
    local p = pad or 0
    w, h = w + 2 * p, h + 2 * p
    local r = k.rng(seed or 99)
    local c = {}
    for pass = 0, 1 do
        local j = function() return (r() - 0.5) * 2 end
        c[#c + 1] = { op = "M", points = { w * 0.15 + j(), 3 + j() } }
        c[#c + 1] = { op = "C", points = { w * 0.6, -1 + j(), w + 2, 2 + j(), w - 2 + j(), h / 2 } }
        -- The bottom-left join keeps its control points in line so the pencil doesn't kink there.
        c[#c + 1] = { op = "C", points = { w + 1, h - 1 + j(), w * 0.12, h + 1, 3, h * 0.7 } }
        c[#c + 1] = { op = "C", points = { -1, h * 0.4, 0, 4, w * 0.25 + pass * 8, 1 + j() } }
    end
    local loop = k.stroke_path(w, h, c, BLUE, 1.8)
    -- Thin at the pencil's touch-down and lift-off, as a drawn loop is.
    loop.taper_start, loop.taper_end = 10, 24
    if p > 0 then loop.translate = { x = -p, y = -p } end
    return loop
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
