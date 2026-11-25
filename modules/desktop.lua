-- The desk: the wallpaper and the cards pinned to it (clock, quote, to-do, sticky note, music). Cards drag
-- anywhere and remember where they were dropped; double-click puts one back. Right-click on the
-- wallpaper offers "Change background…".
local k = require("lib.paper")
local menu_component = require("components.menu")
local controls = require("components.controls")
local util = require("lib.util")
local settings = require("modules.settings")
local wallpaper = require("lib.wallpaper")
local DIR, INK, INK_SOFT, RED = k.DIR, k.INK, k.INK_SOFT, k.RED
local hand, body, glyph, card, tape = k.hand, k.body, k.glyph, k.card, k.tape
local squiggle, sprig, star, heart, checkbox = k.squiggle, k.sprig, k.star, k.heart, k.checkbox

local now = mantle.clock:map(function(s) return s.time end, os.time())

local function clock12(t)
    local s = os.date("%I:%M", t)
    return (s:gsub("^0", ""))
end

local player = mantle.mpris:map(function(m) return m.players[1] end, nil)
-- With nothing playing the music card says so: no stand-in track, an empty line, controls that do
-- nothing. A player with no track (playerctld's proxy, a closed tab) counts as nothing.
local has_player = player:map(function(p) return p ~= nil and p.title ~= "" end, false)

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

-- What the desk remembers between restarts: the to-do list and the sticky note.
local desk = persistent_table { path = DIR .. "/state-desk.json", defaults = { todo = {}, note = "" } }

-- One line a day, chosen by the date, so it changes at midnight and stays put through restarts.
local QUOTES = {
    "A little progress every day adds up to big results.",
    "Slow and steady wins the race.",
    "Well begun is half done.",
    "Do what you can, with what you have, where you are.",
    "One thing at a time.",
    "Small steps still move you forward.",
    "Rest is part of the work.",
    "Today is a good day to start.",
    "Be kind to yourself today.",
    "Done is better than perfect.",
    "Every day is a fresh page.",
    "Breathe in, breathe out, carry on.",
    "The best time to start was yesterday. The next best is now.",
    "Little by little, a little becomes a lot.",
    "Make today count.",
    "Keep going; you are doing fine.",
    "Start where you are.",
    "Good things take time.",
    "Tidy desk, tidy mind.",
    "A cup of tea solves most things.",
    "You have done hard things before.",
    "Focus on what you can change.",
    "Write it down, then let it go.",
    "Progress, not perfection.",
    "Enjoy the little things.",
    "Plan the day, then live it.",
    "Smile; it is contagious.",
    "One page at a time.",
    "Courage grows with every try.",
    "Finish what you start.",
    "Let today be gentle.",
}
local quote = mantle.clock:map(function(c)
    return QUOTES[tonumber(os.date("%j", c.time)) % #QUOTES + 1]
end, QUOTES[1])

local quote_card = card {
    width = CARD_W,
    height = 136,
    seed = 202,
    rotate = -0.8,
    child = rect {
        width = "fill",
        height = "fill",
        padding = { left = 30, right = 44, top = 22, bottom = 18 },
        children = {
            body(quote:map(function(q) return "\u{201C}" .. q .. "\u{201D}" end), 24, {
                width = "fill",
                wrap = "word",
                max_lines = 4,
                elide = "end",
                foreground = INK_SOFT,
                line_height = 1.25,
            }),
            rect { align_h = "end", align_v = "end", translate = { x = 30 }, children = { star(24, INK) } },
        },
    },
}

-- The list is a JSON array of { text, done }; every edit writes a fresh copy.
local function edit_todo(fn)
    local list = {}
    for i, t in ipairs(desk.todo:get() or {}) do list[i] = { text = t.text, done = t.done } end
    fn(list)
    desk:set("todo", list)
end

local function todo_row(i, item)
    local name = "paper.todo.row." .. i
    local hovered = hover(name)
    local label = body(item.text, 21, {
        max_width = CARD_W - 130,
        elide = "end",
        foreground = item.done and INK_SOFT or INK,
        align_v = "center",
    })
    return row {
        width = "fill",
        spacing = 10,
        hover = hovered,
        children = {
            rect {
                cursor = "pointer",
                accessible_name = (item.done and "Mark not done: " or "Mark done: ") .. item.text,
                on_click = function() edit_todo(function(l) l[i].done = not l[i].done end) end,
                children = { checkbox(18, item.done) },
            },
            item.done and rect {
                align_v = "center",
                children = {
                    label,
                    rect { width = "fill", height = 1.6, align_v = "center", translate = { y = 1 }, background = INK },
                },
            } or label,
            rect { width = "fill" },
            rect {
                cursor = "pointer",
                accessible_name = "Remove " .. item.text,
                opacity = hovered:map(function(v) return v and 1 or 0 end),
                animate = { opacity = { duration = 120, easing = "out_cubic" } },
                padding = { left = 4, right = 4 },
                on_click = function() edit_todo(function(l) table.remove(l, i) end) end,
                children = { body("\u{00D7}", 24, { foreground = INK_SOFT, align_v = "center" }) },
            },
        },
    }
end

-- ponytail: the card grows with the list (32 px a task) and the desk wraps it; past about 12 tasks
-- it outgrows a 864 px screen. Upgrade: a scrolling `list` capped at the screen's height.
local todo_card = rect {
    children = desk.todo:map(function(items)
        items = items or {}
        local rows = {}
        for i, item in ipairs(items) do rows[i] = todo_row(i, item) end
        -- The field keeps one place in the tree, so it holds focus while the list above it grows.
        local add = controls.field {
            id = "desk.todo.add",
            placeholder = "Add a task\u{2026}",
            width = CARD_W - 60,
            size = 22,
            on_submit = function(text)
                text = util.trim(text)
                if text ~= "" then edit_todo(function(l) l[#l + 1] = { text = text, done = false } end) end
            end,
        }
        return {
            card {
                width = CARD_W,
                height = 116 + #items * 32,
                seed = 303,
                rotate = 0.4,
                child = rect {
                    width = "fill",
                    height = "fill",
                    padding = { left = 26, right = 22, top = 16, bottom = 14 },
                    children = {
                        column {
                            width = "fill",
                            spacing = 6,
                            children = {
                                row {
                                    spacing = 12,
                                    children = { checkbox(26, true), hand("To do", 36, { font_weight = 700, align_v = "center" }) },
                                },
                                column { width = "fill", spacing = 6, padding = { left = 4 }, children = rows },
                                add,
                            },
                        },
                    },
                },
            },
        }
    end, {}),
}

-- A yellow sticky note she types straight onto; saved a second after the last key.
local note_card = card {
    width = CARD_W,
    height = 190,
    seed = 404,
    rotate = -0.5,
    color = "#F0DDB8",
    child = rect {
        width = "fill",
        height = "fill",
        padding = { left = 26, right = 22, top = 18, bottom = 16 },
        children = {
            textfield {
                width = "fill",
                height = "fill",
                multiline = true,
                initial_text = desk.note,
                placeholder = "Write a note\u{2026}",
                placeholder_color = "#3A363170",
                font = k.HAND,
                font_size = 24,
                foreground = INK,
                caret = { color = k.BLUE, width = 2 },
                selection = { background = "#F2C94C90" },
                accessible_name = "Sticky note",
                focus_ring = false,
                escape = "blur",
                on_change = function(text) desk:set("note", text) end,
            },
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
    if not p or p.title == "" or not p.length or p.length <= 0 then return { at = 0 } end
    local pos = p.position or 0
    if p.play_state == "playing" then pos = pos + (mantle.clock:now() - p.position_updated_at / 1e6) * 1e6 end
    pos = math.min(pos, p.length)
    return { at = pos / p.length, pos = pos, len = p.length }
end, { at = 0 })

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
                        opacity = has_player:map(function(v) return v and 1 or 0.45 end),
                        source = player:map(function(p)
                            return p and p.album_art_path ~= "" and p.album_art_path or DIR .. "/img/cover.png"
                        end, DIR .. "/img/cover.png"),
                    },
                    column {
                        spacing = 2,
                        width = "fill",
                        padding = { top = 6 },
                        children = {
                            hand(player:map(function(p)
                                return p and p.title ~= "" and p.title or "Nothing playing"
                            end, "Nothing playing"),
                                34, { font_weight = 700, elide = "end", width = "fill" }),
                            body(player:map(function(p) return p and p.title ~= "" and p.artist or "" end, ""),
                                20, { foreground = INK_SOFT, elide = "end", width = "fill" }),
                        },
                    },
                },
            },
            row {
                spacing = 10,
                width = "fill",
                children = {
                    body(progress:map(function(p) return p.len and fmt_us(p.pos) or "" end), 17,
                        { align_v = "center", width = 44 }),
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
                                visible = progress:map(function(p) return p.len ~= nil end),
                                translate = progress:map(function(p) return { x = math.floor(p.at * TRACK_W) - 5 } end),
                            },
                        },
                    },
                    body(progress:map(function(p) return p.len and fmt_us(p.len) or "" end), 17, { align_v = "center" }),
                },
            },
            row {
                width = "fill",
                spacing = 34,
                padding = { left = 40 },
                hittable = has_player,
                opacity = has_player:map(function(v) return v and 1 or 0.35 end),
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

local M = {}

-- Right-click on the bare wallpaper (the cards panel above claims only its cards).
local menu = menu_component.new { id = "paper-desktop-menu", parent = "paper-wallpaper" }
M.surfaces = menu.surfaces

local function open_menu(x, y)
    menu.open({ x = x, y = y, width = 1, height = 1 }, {
        {
            label = "Change background…",
            icon = "preferences-desktop-wallpaper-symbolic",
            on_click = function() settings.open("appearance", 2) end,
        },
    }, { anchor = "bottom_right", gravity = "bottom_right" })
end

-- One instance per output, each drawing that output's picture (`lib/wallpaper.lua`).
M.wallpaper = panel {
    id = "paper-wallpaper",
    namespace = "paper-wallpaper",
    layer = "background",
    anchor = { top = true, bottom = true, left = true, right = true },
    width = "fill",
    height = "fill",
    exclusive_zone = "ignore",
    -- The keyboard only while the menu is open, so Escape reaches it; the desktop never holds it.
    keyboard_interactivity = menu.is_open:map(function(open) return open and "exclusive" or "none" end),
    child = function(output)
        return rect {
            width = "fill",
            height = "fill",
            -- Fit leaves bars on a screen of another shape: dark desk, opaque.
            background = "#1E1B18",
            on_click = function(r, button, p)
                if button == "right" then open_menu(r.x + p.x, r.y + p.y) end
            end,
            children = {
                -- 4K files decode off-thread; a change cross-fades from the held picture.
                image {
                    id = "paper-wallpaper-image",
                    source = wallpaper.path_of(output),
                    fit = wallpaper.fit_of(output),
                    status = wallpaper.status_of(output),
                    async = true,
                    retain = true,
                    transition = { duration = 700, easing = "in_out_sine" },
                    width = "fill",
                    height = "fill",
                },
            },
        }
    end,
}

M.cards = panel {
    id = "paper-cards",
    namespace = "paper-cards",
    layer = "bottom",
    -- On demand: a click in the to-do field or the sticky note takes the keyboard, nothing else does.
    keyboard_interactivity = "on_demand",
    -- The panel covers the output so a card can be dropped anywhere; only the cards take input.
    anchor = { top = true, bottom = true, left = true, right = true },
    width = "fill",
    height = "fill",
    -- A screen too short for the stack (1920x1080 at 125% is 864 px) wraps it into a second column.
    child = column {
        width = "fill",
        height = "fill",
        padding = { left = 24, right = 24, top = 18, bottom = 24 },
        spacing = 4,
        wrap = true,
        line_spacing = 8,
        align_h = "end",
        children = {
            draggable("clock", clock_card),
            draggable("quote", quote_card),
            draggable("note", note_card),
            draggable("music", music_card),
            -- Last: the only card that grows, so a new task never pushes another card to a new column.
            draggable("todo", todo_card),
        },
    },
}

return M
