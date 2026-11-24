-- The control sheet: buttons, toggles and the rest as stationery on a desk. Card-stock scraps,
-- paper discs, pencil hatching, highlighter, washi tape and sticky notes, never UI wireframes.
-- `mantle toggle paper.controls` shows it. Every control works; the states are live.
return function(k)
    local INK, INK_SOFT, BLUE, RED, HAND = k.INK, k.INK_SOFT, k.BLUE, k.RED, k.HAND
    local hand, body = k.hand, k.body
    local STICKY, STICKY_FOLD = "#F3E3A0", "#DCC67A"
    local GROOVE = "#E2D6BC"

    -- Card stocks: the tint of the paper and the ink written on it.
    local STOCK = {
        primary = { "#C5D7EE", "#24477F" },
        plain = { "#F4ECDA", INK },
        danger = { "#F2CFC8", "#8E2B25" },
    }

    local function lift(hovered)
        return hovered:map(function(v)
            if v then return { { blur = 16, offset = { x = 3, y = 9 }, color = "#00000055" } } end
            return { { blur = 5, offset = { x = 1, y = 2 }, color = "#00000050" } }
        end)
    end

    local function section(title, children)
        return column {
            spacing = 12,
            children = {
                hand(title, 30, { font_weight = 700, foreground = BLUE }),
                column { spacing = 16, children = children },
            },
        }
    end

    -- Buttons: a torn scrap of card stock. Hover peels it up off the page: the shadow grows and
    -- the scrap tilts; the label is handwritten on it.
    local function button(label, kind, w)
        local stock = STOCK[kind or "plain"]
        local hovered = hover("paper.btn." .. label)
        w = w or 130
        return rect {
            hover = hovered,
            accessible_name = label,
            on_click = function() end,
            rotate = hovered:map(function(v) return v and -2 or (#label % 3 - 1) * 0.6 end),
            translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
            animate = {
                rotate = { spring = { stiffness = 300, damping = 16 } },
                translate = { duration = 140, easing = "out_cubic" },
            },
            children = {
                k.sheet {
                    width = w,
                    height = 50,
                    seed = #label * 31 + w,
                    depth = 3,
                    color = stock[1],
                    shadows = lift(hovered),
                    animate = { shadows = { duration = 160, easing = "out_cubic" } },
                    child = hand(label, 27, {
                        font_weight = 700,
                        foreground = stock[2],
                        align_h = "center",
                        align_v = "center",
                    }),
                },
            },
        }
    end

    -- A link is a word underlined in pencil that gets highlighted on hover.
    local function link(label)
        local hovered = hover("paper.link." .. label)
        local w = #label * 10 + 4
        return rect {
            align_v = "center",
            hover = hovered,
            accessible_name = label,
            on_click = function() end,
            children = {
                rect {
                    width = w,
                    height = 16,
                    align_v = "end",
                    translate = { y = -4 },
                    background = "#F2C94C80",
                    blend = "multiply",
                    shape = k.tape_shape(w, 16, #label),
                    opacity = hovered:map(function(v) return v and 1 or 0 end),
                    animate = { opacity = { duration = 140 } },
                },
                hand(label, 26, { foreground = "#24477F" }),
                rect { align_v = "end", translate = { y = 5 }, children = { k.squiggle(w, BLUE) } },
            },
        }
    end

    -- Icon buttons: punched paper discs, lifting on hover like the scraps.
    local function disc_button(name, seed)
        local hovered = hover("paper.disc." .. name)
        return rect {
            width = 48,
            height = 48,
            hover = hovered,
            accessible_name = name,
            on_click = function() end,
            translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
            animate = { translate = { duration = 140, easing = "out_cubic" } },
            children = {
                k.sheet {
                    width = 48,
                    height = 48,
                    shape = k.torn_circle(48, seed),
                    color = "#F4ECDA",
                    shadows = lift(hovered),
                    animate = { shadows = { duration = 160 } },
                    fx = { rim = 1.6 },
                },
                k.glyph(name, 22),
            },
        }
    end

    -- Toggle: a groove pressed into the page. On, the groove is shaded in blue pencil and the
    -- paper disc rolls to the far end, turning as it goes.
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

    local function toggle(name, initial)
        local on = state("paper.toggle." .. name, initial)
        local W, H, D = 66, 32, 28
        return row {
            spacing = 14,
            accessible_name = name,
            on_click = function() on:set(not on:get()) end,
            children = {
                rect {
                    width = W,
                    height = H,
                    children = on:map(function(v)
                        return {
                            rect {
                                id = "groove",
                                width = W,
                                height = H,
                                shape = capsule_shape(W, H),
                                background = v and "#D5E0EE" or GROOVE,
                                border_width = 1.2,
                                border_color = "#3A363170",
                                shadows = { { inset = true, blur = 5, offset = { y = 2 }, color = "#00000048" } },
                                effect = k.paper_fx {
                                    rim = 0,
                                    hatch = v and 1 or 0,
                                    hatch_color = { 0.2, 0.38, 0.7, 0.75 },
                                    hatch_spacing = 3.2,
                                },
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
                                        -- A pencil dot so the roll shows.
                                        child = rect {
                                            width = 5,
                                            height = 5,
                                            radius = 3,
                                            translate = { x = 6, y = 6 },
                                            background = v and BLUE or "#3A363160",
                                        },
                                    },
                                },
                            },
                        }
                    end),
                },
                body(name, 22, { align_v = "center" }),
            },
        }
    end

    local function pencil_circle(size, seed, color, width)
        local r = k.rng(seed)
        local c = size / 2
        return path {
            width = size,
            height = size,
            stroke = color,
            stroke_width = width or 1.4,
            stroke_cap = "round",
            commands = { { op = "A", points = { c + (r() - 0.5), c + (r() - 0.5), c - 2.5, -100, 380 } } },
        }
    end

    -- Radio: a pencil circle; the chosen one is coloured in with a blue marker scribble.
    local function radio_group(name, options)
        local picked = state("paper.radio." .. name, options[1])
        local rows = {}
        for i, opt in ipairs(options) do
            rows[i] = row {
                spacing = 10,
                accessible_name = opt,
                on_click = function() picked:set(opt) end,
                children = {
                    rect {
                        width = 24,
                        height = 24,
                        align_v = "center",
                        children = picked:map(function(p)
                            local c = { pencil_circle(24, 30 + i, INK) }
                            if p == opt then
                                c[2] = path {
                                    width = 24,
                                    height = 24,
                                    stroke = BLUE,
                                    stroke_width = 2.6,
                                    stroke_cap = "round",
                                    stroke_join = "round",
                                    commands = {
                                        { op = "M", points = { 8, 9 } },
                                        { op = "L", points = { 15, 7 } },
                                        { op = "L", points = { 7, 13 } },
                                        { op = "L", points = { 17, 11 } },
                                        { op = "L", points = { 8, 17 } },
                                        { op = "L", points = { 16, 15.5 } },
                                    },
                                }
                            end
                            return c
                        end),
                    },
                    body(opt, 21, { align_v = "center" }),
                },
            }
        end
        return row { spacing = 26, children = rows }
    end

    local function checkbox_row(label, initial)
        local done = state("paper.check." .. label, initial)
        return row {
            spacing = 10,
            accessible_name = label,
            on_click = function() done:set(not done:get()) end,
            children = done:map(function(d) return { k.checkbox(22, d), body(label, 21, { align_v = "center" }) } end),
        }
    end

    -- Slider: a pencil line; the value is a stroke of highlighter laid over it (multiply, so the
    -- line shows through), and the thumb is a red push-pin.
    local function slider(name, initial)
        local value = state("paper.slider." .. name, initial)
        local W = 300
        local line = { { op = "M", points = { 6, 16 } }, { op = "Q", points = { W / 2, 14, W - 6, 17 } } }
        local function set(r, p) value:set(math.max(0, math.min(1, p.x / r.width))) end
        return row {
            spacing = 14,
            children = {
                k.glyph("audio-volume-high-symbolic", 22),
                rect {
                    width = W,
                    height = 32,
                    on_drag = function(r, p) set(r, p) end,
                    on_click = function(r, _, p) set(r, p) end,
                    children = {
                        k.stroke_path(W, 32, line, "#3A363199", 1.5),
                        path {
                            width = W,
                            height = 32,
                            stroke = "#9EC0EC99",
                            stroke_width = 13,
                            stroke_cap = "butt",
                            blend = "multiply",
                            trim_end = value,
                            commands = line,
                        },
                        rect {
                            width = 22,
                            height = 22,
                            align_v = "center",
                            translate = value:map(function(v) return { x = 6 + v * (W - 12) - 11 } end),
                            children = {
                                -- A matte paper dot inked red, not a glossy pin.
                                k.sheet {
                                    width = 22,
                                    height = 22,
                                    shape = k.torn_circle(22, 13, 1.2),
                                    color = RED,
                                    shadows = { { blur = 4, offset = { x = 1, y = 2 }, color = "#00000055" } },
                                },
                                pencil_circle(22, 14, "#7A2522", 1.3),
                            },
                        },
                    },
                },
                body(value:map(function(v) return math.floor(v * 100 + 0.5) .. "%" end), 21, { align_v = "center" }),
            },
        }
    end

    -- Text field: writing on the page's own ruled line; focus inks the line blue.
    local function field(placeholder)
        local has_focus = focused("paper.field")
        return rect {
            width = 340,
            focused = has_focus,
            children = {
                textfield {
                    width = "fill",
                    height = 38,
                    font = HAND,
                    font_size = 26,
                    foreground = INK,
                    placeholder = placeholder,
                    placeholder_color = "#3A363170",
                    caret = { color = BLUE, width = 2 },
                    selection = { background = "#F2C94C90" },
                    accessible_name = placeholder,
                    focus_ring = false,
                    on_change = function() end,
                },
                rect {
                    align_v = "end",
                    children = has_focus:map(function(f)
                        return {
                            k.stroke_path(340, 8, {
                                { op = "M", points = { 2, 4 } },
                                { op = "Q", points = { 170, 2, 338, 5 } },
                            }, f and BLUE or "#3A363180", f and 2 or 1.3),
                        }
                    end),
                },
            },
        }
    end

    -- Index tabs on a card-stock folder: the chosen tab stands taller and joins its card.
    local TINTS = { "#E9DDBB", "#C9D8EA", "#EBCBC5" }
    local function tabs(names, pages)
        local picked = state("paper.tab", 1)
        local items = {}
        for i, n in ipairs(names) do
            items[i] = rect {
                accessible_name = n,
                on_click = function() picked:set(i) end,
                align_v = "end",
                z = picked:map(function(p) return p == i and 3 or 3 - i end),
                children = picked:map(function(p)
                    local w, h = 118, p == i and 44 or 36
                    return {
                        rect {
                            width = w,
                            height = h + 6,
                            translate = { y = 6 },
                            background = TINTS[i],
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
        return column {
            children = {
                row { spacing = -8, padding = { left = 12 }, children = items },
                rect {
                    width = 440,
                    height = 74,
                    z = 1,
                    background = picked:map(function(p) return TINTS[p] end),
                    shadows = { { blur = 8, offset = { x = 1, y = 3 }, color = "#00000045" } },
                    effect = k.paper_fx { rim = 0 },
                    -- Torn on three sides; the top stays straight where it joins the tabs.
                    shape = k.torn(440, 74, 707, 3, true),
                    padding = { left = 20, right = 20 },
                    children = { body(picked:map(function(p) return pages[p] end), 21, { align_v = "center" }) },
                },
            },
        }
    end

    -- Chips: washi tape, grainy and see-through.
    local function chip(label, color, seed)
        local w = #label * 11 + 34
        return rect {
            width = w,
            height = 30,
            rotate = (seed % 3 - 1) * 2,
            background = color,
            shape = k.tape_shape(w, 30, seed),
            shadows = { { blur = 2, offset = { y = 1 }, color = "#00000030" } },
            effect = k.paper_fx { grain = 0.35, mottle = 0.2, rim = 0 },
            children = { hand(label, 24, { align_h = "center", align_v = "center" }) },
        }
    end

    -- Sticky note with a dog-eared bottom-right corner, held by tape.
    local function sticky(w, h, seed, child, rotate)
        local f = 12
        local r = k.rng(seed)
        local c = { { op = "M", points = { 0, 0 } } }
        for x = 12, w, 12 do c[#c + 1] = { op = "L", points = { math.min(x, w), r() * 2.5 } } end
        c[#c + 1] = { op = "L", points = { w, h - f } }
        c[#c + 1] = { op = "L", points = { w - f, h } }
        c[#c + 1] = { op = "L", points = { 0, h } }
        c[#c + 1] = { op = "Z", points = {} }
        return rect {
            rotate = rotate or -2,
            padding = { top = 10 },
            children = {
                rect {
                    width = w,
                    height = h,
                    shape = { commands = c },
                    background = STICKY,
                    shadows = { { blur = 10, offset = { x = 2, y = 6 }, color = "#00000055" } },
                    effect = k.paper_fx { rim = 0, grain = 0.18 },
                    children = {
                        child,
                        path {
                            width = w,
                            height = h,
                            fill = STICKY_FOLD,
                            shadows = { { blur = 3, offset = { x = -1, y = -1 }, color = "#00000040" } },
                            commands = {
                                { op = "M", points = { w - f, h } },
                                { op = "L", points = { w, h - f } },
                                { op = "L", points = { w - f + 2, h - f + 2 } },
                                { op = "Z", points = {} },
                            },
                        },
                    },
                },
                k.tape { width = 64, height = 20, translate = { y = -8 }, rotate = 3, seed = seed },
            },
        }
    end

    local tooltip = sticky(196, 54, 81, rect {
        width = "fill",
        height = "fill",
        padding = { left = 14, right = 12, top = 6 },
        children = { body("Opens the trash bin", 19, { align_v = "center" }) },
    }, 2)

    local notification = sticky(340, 134, 82, column {
        width = "fill",
        padding = { left = 18, right = 16, top = 14, bottom = 10 },
        spacing = 4,
        children = {
            row {
                spacing = 10,
                width = "fill",
                children = {
                    k.glyph("software-update-available-symbolic", 22),
                    hand("12 updates ready", 28, { font_weight = 700, align_v = "center" }),
                },
            },
            body("Kernel, mesa and 10 more.", 19, { foreground = INK_SOFT }),
            row { spacing = 24, padding = { top = 4 }, children = { link("Install"), hand("Later", 26, { foreground = INK_SOFT }) } },
        },
    })

    -- Focus: a blue pencil loop drawn round the focused control, in place of a solid ring.
    local function pencil_loop(w, h)
        local r = k.rng(99)
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

    local focus_demo = rect {
        children = {
            button("Focused", "plain", 130),
            rect { translate = { x = -12, y = -8 }, children = { pencil_loop(154, 66) } },
        },
    }

    -- The page: ruled lines and a red margin, under the same paper finish.
    local PAGE_W, PAGE_H = 1180, 730
    local rules = {}
    for y = 84, PAGE_H - 10, 34 do
        rules[#rules + 1] = { op = "M", points = { 0, y } }
        rules[#rules + 1] = { op = "L", points = { PAGE_W, y } }
    end

    return k.sheet {
        width = PAGE_W,
        height = PAGE_H,
        seed = 999,
        depth = 5,
        fx = { rim = 2.2 },
        child = rect {
            width = "fill",
            height = "fill",
            children = {
                path { width = PAGE_W, height = PAGE_H, stroke = "#7FA3D040", stroke_width = 1, commands = rules },
                path {
                    width = PAGE_W,
                    height = PAGE_H,
                    stroke = "#D9534F60",
                    stroke_width = 1.4,
                    commands = { { op = "M", points = { 70, 0 } }, { op = "L", points = { 70, PAGE_H } } },
                },
                column {
                    padding = { left = 100, top = 22, right = 40 },
                    spacing = 22,
                    children = {
                        row {
                            spacing = 16,
                            children = {
                                hand("Desk controls", 52, { font_weight = 700 }),
                                rect { align_v = "end", translate = { y = -10 }, children = { k.star(28, RED, true) } },
                            },
                        },
                        row {
                            spacing = 70,
                            children = {
                                column {
                                    spacing = 26,
                                    children = {
                                        section("Buttons", {
                                            row {
                                                spacing = 18,
                                                children = {
                                                    button("Save", "primary", 116),
                                                    button("Cancel", "plain", 128),
                                                    button("Delete", "danger", 124),
                                                },
                                            },
                                            row {
                                                spacing = 22,
                                                children = {
                                                    link("Show more"),
                                                    disc_button("view-refresh-symbolic", 1),
                                                    disc_button("edit-find-symbolic", 2),
                                                    focus_demo,
                                                },
                                            },
                                        }),
                                        section("Toggles & choices", {
                                            row { spacing = 40, children = { toggle("Wi-Fi", true), toggle("Bluetooth", false) } },
                                            radio_group("profile", { "Quiet", "Balanced", "Fast" }),
                                            row { spacing = 30, children = { checkbox_row("Night light", true), checkbox_row("Do not disturb", false) } },
                                        }),
                                        section("Slider & field", {
                                            slider("volume", 0.62),
                                            field("Search apps\u{2026}"),
                                        }),
                                    },
                                },
                                column {
                                    spacing = 26,
                                    children = {
                                        section("Tabs", {
                                            tabs({ "Wi-Fi", "Sound", "Power" }, {
                                                "Connected to Home, 5 GHz, strong",
                                                "Speakers at 62%, mic muted",
                                                "Balanced, 4 h 10 min left",
                                            }),
                                        }),
                                        section("Chips", {
                                            row {
                                                spacing = 10,
                                                children = {
                                                    chip("#rust", "#A9C3E3C8", 4),
                                                    chip("work", "#E8B4ACC8", 5),
                                                    chip("ideas", "#D9C89BC8", 6),
                                                    chip("later", "#BFD8B0C8", 7),
                                                },
                                            },
                                        }),
                                        section("Tooltip & notification", {
                                            tooltip,
                                            notification,
                                        }),
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end
