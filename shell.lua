-- Paper notebook shell: a throwaway study of how far Mantle's paint goes toward a torn-paper look.
-- Top bar, right-hand cards (clock, quote, todo, music, photo) and a bottom dock. App windows are
-- not shell and are not drawn. Run with ./run.sh so fontconfig sees the bundled fonts.

local DIR = mantle.config_dir
local PAPER = "#EEE3CB"
local OUTPUT = os.getenv("PAPER_OUTPUT") or "all"
-- PAPER_SHOT=1 lifts the bar to the overlay layer so another shell's bar cannot push it down.
local SHOT = os.getenv("PAPER_SHOT") == "1"

local INK = "#3A3631"
local INK_SOFT = "#6B6258"
local BLUE = "#3F74C7"
local RED = "#D9534F"
local HAND = "Caveat"

fonts { "Patrick Hand", "Noto Sans" }

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

-- The kit controls.lua builds its sheet from.
local kit = {
    DIR = DIR, PAPER = PAPER, INK = INK, INK_SOFT = INK_SOFT, BLUE = BLUE, RED = RED, HAND = HAND,
    rng = rng, torn = torn, torn_circle = torn_circle, paper_fx = paper_fx, tape = tape, tape_shape = tape_shape, sheet = sheet, card = card,
    stroke_path = stroke_path, squiggle = squiggle, sprig = sprig, star = star, heart = heart,
    wobble_box = wobble_box, checkbox = checkbox, hand = hand, body = body, glyph = glyph,
}

-- Live data -------------------------------------------------------------------------------------

local now = mantle.clock:map(function(s) return s.time end, os.time())

local function clock12(t)
    local s = os.date("%I:%M", t)
    return (s:gsub("^0", ""))
end

local battery = mantle.battery:map(function(b) return b.present and b or nil end, nil)
local wifi_icon = mantle.network:map(function(n)
    if not n.connected then return "network-offline-symbolic" end
    if n.ssid == "Ethernet" then return "network-wired-symbolic" end
    return "network-wireless-symbolic"
end, "network-wireless-symbolic")
local bt_icon = mantle.bluetooth:map(function(b)
    return b.enabled and "bluetooth-active-symbolic" or "bluetooth-disabled-symbolic"
end, "bluetooth-active-symbolic")
local volume_icon = mantle.audio:map(function(a)
    for _, s in ipairs(a.sinks) do
        if s.active then
            if s.muted then return "audio-volume-muted-symbolic" end
            local v = s.volume or 0
            return v > 66 and "audio-volume-high-symbolic" or v > 33 and "audio-volume-medium-symbolic"
                or "audio-volume-low-symbolic"
        end
    end
    return "audio-volume-high-symbolic"
end, "audio-volume-high-symbolic")

local player = mantle.mpris:map(function(m) return m.players[1] end, nil)

-- Top bar ---------------------------------------------------------------------------------------

local BAR_H = 46

local function workspace_button(n, active)
    local label = hand(tostring(n), 26, {
        foreground = active and "#24477F" or INK,
        font_weight = active and 700 or 500,
        align_h = "center",
        align_v = "center",
    })
    local children = { label }
    if active then
        -- A blue sticker square under the active numeral, shaded in pencil.
        table.insert(children, 1, sheet {
            width = 34,
            height = 34,
            seed = 40 + n,
            depth = 2,
            color = "#C9D8EA",
            shadows = { { blur = 4, offset = { x = 1, y = 2 }, color = "#00000045" } },
            fx = { rim = 1.5, hatch = 0.35, hatch_spacing = 3.5 },
        })
    end
    return rect {
        width = 34,
        height = 34,
        align_v = "center",
        on_click = function() mantle.workspaces:focus(tostring(n)) end,
        children = children,
    }
end

local function workspaces_for(output)
    return mantle.workspaces:map(function(w)
        local active
        for _, o in ipairs(w.outputs) do
            if o.name == output or not active then
                for _, e in ipairs(o.workspaces) do
                    if e.id == o.active_workspace then active = e.number end
                end
            end
        end
        local buttons = {}
        for n = 1, 4 do buttons[n] = workspace_button(n, n == active) end
        return buttons
    end, { workspace_button(1, true), workspace_button(2), workspace_button(3), workspace_button(4) })
end

local window_title = mantle.workspaces:map(function(w)
    local c = w.active_client
    if not c or c.title == "" then return "Desktop" end
    local t = c.app_id ~= "" and c.app_id:match("([^.]+)$") or c.title
    return (t:gsub("^%l", string.upper))
end, "Desktop")

local function bar(output)
    return sheet {
        width = "fill",
        height = BAR_H,
        shape = torn_bottom(BAR_H, 11),
        fx = { rim = 2.2 },
        child = row {
            width = "fill",
            height = "fill",
            padding = { left = 24, right = 28, bottom = 4 },
            spacing = 18,
            children = {
                row { spacing = 6, align_v = "center", children = workspaces_for(output) },
                row {
                    spacing = 8,
                    align_v = "center",
                    padding = { left = 18 },
                    children = {
                        glyph("utilities-terminal-symbolic", 18),
                        body(window_title, 19, { align_v = "center" }),
                    },
                },
                rect { width = "fill" },
                row {
                    spacing = 18,
                    align_v = "center",
                    children = {
                        glyph(wifi_icon, 20),
                        glyph(bt_icon, 20),
                        glyph(volume_icon, 20),
                        row {
                            spacing = 6,
                            visible = battery:map(function(b) return b ~= nil end),
                            children = {
                                glyph(battery:map(function(b)
                                    if not b then return "battery-good-symbolic" end
                                    local level = b.percent > 80 and "full" or b.percent > 40 and "good" or b.percent > 15 and "low" or "caution"
                                    return "battery-" .. level .. (b.state == "charging" and "-charging" or "") .. "-symbolic"
                                end), 20),
                                body(battery:map(function(b) return b and (b.percent .. "%") or "" end), 19,
                                    { align_v = "center" }),
                            },
                        },
                        body(now:map(function(t) return os.date("%a, %d %b", t) end), 19,
                            { align_v = "center", padding = { left = 10 } }),
                        body(now:map(function(t) return clock12(t) .. os.date(" %p", t) end), 19,
                            { align_v = "center" }),
                    },
                },
            },
        },
    }
end

-- Right-hand cards ------------------------------------------------------------------------------

local CARD_W = 370

local clock_card = card {
    width = CARD_W,
    height = 210,
    seed = 101,
    rotate = 0.6,
    tapes = { { color = "#A9C3E3B8", width = 300, height = 20, align_v = "end", translate = { y = 10 }, rotate = -1.5, seed = 9 } },
    child = rect {
        width = "fill",
        height = "fill",
        padding = { left = 30, right = 22, top = 14, bottom = 26 },
        children = {
            column {
                spacing = 0,
                children = {
                    row {
                        spacing = 6,
                        children = {
                            hand(now:map(clock12), 104, { font_weight = 400, line_height = 1.0 }),
                            hand(now:map(function(t) return os.date("%p", t) end), 30,
                                { align_v = "end", padding = { bottom = 18 } }),
                        },
                    },
                    rect {
                        children = {
                            body(now:map(function(t) return os.date("%a, %d %b %Y", t) end), 24),
                            rect { align_v = "end", translate = { y = 9 }, children = { squiggle(210) } },
                        },
                    },
                },
            },
            rect { align_h = "end", align_v = "end", translate = { x = 4, y = 6 }, rotate = 12, children = { sprig(58) } },
        },
    },
}

local quote_card = card {
    width = CARD_W,
    height = 170,
    seed = 202,
    rotate = -0.8,
    child = rect {
        width = "fill",
        height = "fill",
        padding = { left = 34, right = 24, top = 26, bottom = 18 },
        children = {
            body("\u{201C}A little progress\nevery day\u{2026}\nadds up to\nbig results.", 25, {
                foreground = INK_SOFT,
                line_height = 1.25,
            }),
            rect { align_h = "end", align_v = "end", children = { star(24, INK) } },
        },
    },
}

local todo_items = {
    { "Study for the exam", false },
    { "Rust crash course", true },
    { "Work on project", false },
    { "Workout", false },
    { "Read something new", false },
}

local function todo_row(i, item)
    local done = state("paper.todo." .. i, item[2])
    return row {
        spacing = 10,
        on_click = function() done:set(not done:get()) end,
        children = done:map(function(d)
            local label = body(item[1], 21, { foreground = d and INK_SOFT or INK, align_v = "center" })
            return {
                checkbox(18, d),
                d and rect {
                    align_v = "center",
                    children = {
                        label,
                        rect { width = "fill", height = 1.6, align_v = "center", translate = { y = 1 }, background = INK },
                    },
                } or label,
            }
        end),
    }
end

local todo_rows = {}
for i, item in ipairs(todo_items) do todo_rows[i] = todo_row(i, item) end

local todo_card = card {
    width = CARD_W,
    height = 270,
    seed = 303,
    rotate = 0.4,
    child = rect {
        width = "fill",
        height = "fill",
        padding = { left = 26, right = 22, top = 18, bottom = 18 },
        children = {
            column {
                spacing = 8,
                children = {
                    row {
                        spacing = 12,
                        padding = { bottom = 6 },
                        children = { checkbox(30, true), hand("Todo", 40, { font_weight = 700, align_v = "center" }) },
                    },
                    column { spacing = 6, padding = { left = 4 }, children = todo_rows },
                },
            },
            rect { align_h = "end", align_v = "start", translate = { y = 4 }, children = { star(26, RED, true) } },
        },
    },
}

local function fmt_us(us)
    if not us then return "0:00" end
    local s = math.floor(us / 1e6)
    if s >= 3600 then return string.format("%d:%02d:%02d", s // 3600, s // 60 % 60, s % 60) end
    return string.format("%d:%02d", s // 60, s % 60)
end

-- Position: the last read plus wall time since, while playing.
local progress = computed({ player, mantle.clock }, function(p, _)
    if not p or not p.length or p.length <= 0 then return { at = 0.3, pos = nil, len = nil } end
    local pos = p.position or 0
    if p.play_state == "playing" then pos = pos + (mantle.clock:now() - p.position_updated_at / 1e6) * 1e6 end
    pos = math.min(pos, p.length)
    return { at = pos / p.length, pos = pos, len = p.length }
end, { at = 0.3 })

local TRACK_W = 196

local music_card = card {
    width = CARD_W,
    height = 200,
    seed = 404,
    rotate = -0.6,
    child = column {
        width = "fill",
        height = "fill",
        padding = { left = 22, right = 22, top = 20, bottom = 14 },
        spacing = 10,
        children = {
            row {
                spacing = 16,
                width = "fill",
                children = {
                    image {
                        width = 92,
                        height = 92,
                        radius = 4,
                        shadows = { { blur = 6, offset = { x = 1, y = 3 }, color = "#00000060" } },
                        source = player:map(function(p)
                            return p and p.album_art_path ~= "" and p.album_art_path or DIR .. "/img/cover.png"
                        end, DIR .. "/img/cover.png"),
                    },
                    column {
                        spacing = 2,
                        width = "fill",
                        padding = { top = 6 },
                        children = {
                            hand(player:map(function(p) return p and p.title ~= "" and p.title or "Lo-fi Paper" end, "Lo-fi Paper"),
                                34, { font_weight = 700, elide = "end", width = "fill" }),
                            body(player:map(function(p) return p and p.artist or "Notebook Radio" end, "Notebook Radio"),
                                20, { foreground = INK_SOFT, elide = "end", width = "fill" }),
                        },
                    },
                },
            },
            row {
                spacing = 10,
                width = "fill",
                children = {
                    body(progress:map(function(p) return fmt_us(p.pos) end), 17, { align_v = "center" }),
                    rect {
                        width = TRACK_W,
                        height = 14,
                        align_v = "center",
                        children = {
                            rect { width = "fill", height = 2, align_v = "center", background = "#3A363160" },
                            rect {
                                width = progress:map(function(p) return math.floor(p.at * TRACK_W) end),
                                height = 3,
                                align_v = "center",
                                background = RED,
                            },
                            rect {
                                width = 10,
                                height = 10,
                                radius = 5,
                                align_v = "center",
                                background = RED,
                                translate = progress:map(function(p) return { x = math.floor(p.at * TRACK_W) - 5 } end),
                            },
                        },
                    },
                    body(progress:map(function(p) return fmt_us(p.len) end), 17, { align_v = "center" }),
                },
            },
            row {
                width = "fill",
                spacing = 34,
                padding = { left = 40 },
                children = {
                    rect {
                        on_click = function() local p = player:get(); if p then mantle.mpris:control(p.id, "previous") end end,
                        children = { glyph("media-skip-backward-symbolic", 24) },
                    },
                    rect {
                        on_click = function() local p = player:get(); if p then mantle.mpris:control(p.id, "play_pause") end end,
                        children = {
                            glyph(player:map(function(p)
                                return p and p.play_state == "playing" and "media-playback-pause-symbolic"
                                    or "media-playback-start-symbolic"
                            end, "media-playback-pause-symbolic"), 26),
                        },
                    },
                    rect {
                        on_click = function() local p = player:get(); if p then mantle.mpris:control(p.id, "next") end end,
                        children = { glyph("media-skip-forward-symbolic", 24) },
                    },
                    rect { width = "fill" },
                    rect { align_v = "center", children = { heart(22, RED) } },
                },
            },
        },
    },
}

local photo_card = card {
    width = CARD_W,
    height = 170,
    seed = 505,
    rotate = 1.2,
    child = rect {
        width = "fill",
        height = "fill",
        padding = { left = 18, right = 18, top = 18, bottom = 18 },
        children = {
            rect {
                rotate = -4,
                align_v = "center",
                children = {
                    rect {
                        padding = 5,
                        background = "#F7F2E6",
                        shadows = { { blur = 6, offset = { x = 1, y = 2 }, color = "#00000050" } },
                        children = { image { source = DIR .. "/img/photo.png", width = 170, height = 112, fit = "cover" } },
                    },
                    tape { width = 50, height = 18, align_h = "start", translate = { x = -14, y = -6 }, rotate = -38, seed = 21 },
                },
            },
            hand("Same\nSky\nDifferent\nDay\u{2026}", 28, {
                align_h = "end",
                align_v = "center",
                text_align = "center",
                line_height = 1.0,
                rotate = 6,
                foreground = INK_SOFT,
            }),
        },
    },
}

-- Dock ------------------------------------------------------------------------------------------

local function launch(cmd, args)
    return function() process.detach(cmd, args or {}) end
end

local function dock_item(name, on_click, color)
    local hovered = hover("paper.dock." .. name)
    return rect {
        width = 56,
        height = 56,
        align_v = "center",
        hover = hovered,
        on_click = on_click,
        scale = hovered:map(function(h) return h and 1.12 or 1 end),
        animate = { scale = { duration = 140, easing = "out_cubic" } },
        children = { icon { name = name, size = 38, foreground = color or INK, align_h = "center", align_v = "center" } },
    }
end

local DOCK_W, DOCK_H = 820, 86

local dock = sheet {
    width = DOCK_W,
    height = DOCK_H,
    seed = 606,
    fx = { rim = 2.2 },
    child = row {
        width = "fill",
        height = "fill",
        padding = { left = 34, right = 34, top = 6 },
        spacing = 22,
        align_h = "center",
        children = {
            dock_item("utilities-terminal-symbolic", launch(os.getenv("TERMINAL") or "kitty")),
            dock_item("folder-symbolic", launch("xdg-open", { os.getenv("HOME") or "/" })),
            dock_item("web-browser-symbolic", launch("zen-browser")),
            dock_item("text-editor-symbolic", launch("zeditor"), BLUE),
            dock_item("audio-x-generic-symbolic", launch("spotify"), "#237A43"),
            dock_item("image-x-generic-symbolic", launch("xdg-open", { (os.getenv("HOME") or "") .. "/Pictures" })),
            dock_item("emblem-system-symbolic", launch("gnome-control-center")),
            rect { width = 2, height = 44, align_v = "center", background = "#3A363170" },
            dock_item("user-trash-symbolic", launch("xdg-open", { "trash:///" })),
        },
    },
}

local controls_sheet = require("controls")(kit)

-- Dragging cards: each card keeps an offset from its slot in the column. The live offset is a
-- state while the pointer holds the card; on release it is saved to positions.json, so a card
-- stays where it was dropped across restarts. Double-click puts it back in its slot.
local positions = persistent_table { path = DIR .. "/positions.json", defaults = {} }

local function draggable(name, node)
    -- `live` holds the card's offset from press until the saved value catches up: the file write
    -- is asynchronous, and dropping `live` on release would flash the old position for a frame.
    local live = state("paper.drag." .. name, false)
    local dragging = state("paper.dragging." .. name, false)
    local saved = positions[name]
    saved:on_change(function()
        if not dragging:get() then live:set(false) end
    end)
    local grab
    -- The handler sits on this unmoved slot: on_drag maps the pointer back through the node's own
    -- transform, so on the moving card each step would cancel itself and the card would slip.
    return rect {
        align_h = "end",
        z = live:map(function(l) return l and 10 or 0 end),
        cursor = dragging:map(function(d) return d and "grabbing" or "grab" end),
        on_drag = function(_, pointer, phase)
            if phase == "start" then
                local o = live:get() or saved:get() or {}
                grab = { px = pointer.x, py = pointer.y, x = o.x or 0, y = o.y or 0 }
                dragging:set(true)
                live:set({ x = grab.x, y = grab.y })
            elseif grab then
                local o = { x = math.floor(grab.x + pointer.x - grab.px), y = math.floor(grab.y + pointer.y - grab.py) }
                live:set(o)
                if phase == "end" then
                    grab = nil
                    dragging:set(false)
                    local was = saved:get() or {}
                    if (was.x or 0) == o.x and (was.y or 0) == o.y then
                        live:set(false) -- no move, so no write will come back to settle it
                    else
                        positions:set(name, o)
                    end
                end
            end
        end,
        on_double_click = function()
            live:set(false)
            positions:set(name, nil)
        end,
        children = {
            rect {
                translate = computed({ saved, live }, function(sv, l)
                    local o = l or sv or {}
                    return { x = o.x or 0, y = o.y or 0 }
                end, { x = 0, y = 0 }),
                scale = dragging:map(function(d) return d and 1.03 or 1 end),
                animate = { scale = { duration = 120, easing = "out_cubic" } },
                children = { node },
            },
        },
    }
end

-- Surfaces --------------------------------------------------------------------------------------

return {
    panel {
        id = "paper-wallpaper",
        layer = "background",
        output = OUTPUT,
        anchor = { top = true, bottom = true, left = true, right = true },
        width = "fill",
        height = "fill",
        exclusive_zone = "ignore",
        child = image { source = DIR .. "/img/wallpaper.jpg", width = "fill", height = "fill", fit = "cover" },
    },
    panel {
        id = "paper-bar",
        layer = SHOT and "overlay" or "top",
        output = OUTPUT,
        anchor = { top = true, left = true, right = true },
        width = "fill",
        height = BAR_H + 26,
        exclusive_zone = SHOT and "ignore" or BAR_H,
        child = function(output) return bar(output) end,
    },
    panel {
        id = "paper-cards",
        layer = "bottom",
        output = OUTPUT,
        -- The panel covers the output so a card can be dropped anywhere; only the cards take input.
        anchor = { top = true, bottom = true, left = true, right = true },
        width = "fill",
        height = "fill",
        margin = { top = SHOT and BAR_H + 4 or 4 },
        child = column {
            width = "fill",
            padding = { left = 24, right = 24, top = 12, bottom = 24 },
            spacing = 4,
            children = {
                draggable("clock", clock_card),
                draggable("quote", quote_card),
                draggable("todo", todo_card),
                draggable("music", music_card),
                draggable("photo", photo_card),
            },
        },
    },
    panel {
        id = "paper-controls",
        layer = "top",
        output = OUTPUT,
        visible = state("paper.controls", os.getenv("PAPER_CONTROLS") == "1"),
        keyboard_interactivity = "on_demand",
        child = rect { padding = 30, children = { controls_sheet } },
    },
    panel {
        id = "paper-dock",
        layer = "top",
        output = OUTPUT,
        anchor = { bottom = true },
        exclusive_zone = DOCK_H + 12,
        child = rect { padding = { top = 18, left = 24, right = 24, bottom = 26 }, children = { dock } },
    },
}
