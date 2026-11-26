-- The desk: the wallpaper and the cards pinned to it (clock, quote, to-do, sticky note, music). Cards drag
-- anywhere and remember where they were dropped; double-click puts one back. Right-click on the
-- wallpaper offers "Change background…".
local paths = require("lib.paths")
local theme = require("theme")
local k = require("lib.paper")
local menu_component = require("components.menu")
local controls = require("components.controls")
local util = require("lib.util")
local settings = require("modules.settings")
local wallpaper = require("lib.wallpaper")
local ui_state = require("lib.ui_state")
local DIR, INK, INK_SOFT, RED = k.DIR, theme.INK, theme.INK_SOFT, theme.RED
local hand, body, glyph, card = k.hand, k.body, k.glyph, k.card
local squiggle, sprig, star, heart, checkbox = k.squiggle, k.sprig, k.star, k.heart, k.checkbox

local now = mantle.clock:map(function(s) return s.time end, os.time())

local function clock12(t)
    local s = os.date("%I:%M", t)
    return (s:gsub("^0", ""))
end

local player = mantle.mpris:map(function(m) return m.players[1] end, nil)
-- With nothing playing the music card says so: no stand-in track, an empty line, controls that do
-- nothing. A player with no track (playerctld's proxy, a closed tab) counts as nothing.
local has_player = player:map(function(p) return p ~= nil and p.title ~= "" end)

-- Right-hand cards ------------------------------------------------------------------------------

local CARD_W = theme.desk.card_w
local CLOCK_H, QUOTE_H, NOTE_H, MUSIC_H = theme.desk.clock_h, theme.desk.quote_h, theme.desk.note_h, theme.desk.music_h
local TODO_H = theme.desk.todo_h
local TOP, BOTTOM, GAP = theme.desk.top, theme.desk.bottom, theme.desk.gap

local clock_card = card {
    width = CARD_W,
    height = CLOCK_H,
    seed = 101,
    rotate = 0.6,
    tapes = { { color = theme.DESK_TAPE, width = theme.desk.clock_tape_w, height = theme.desk.clock_tape_h, align_v = "end", translate = { y = theme.spacing.snug }, rotate = -1.5, seed = 9 } },
    child = rect {
        width = "fill",
        height = "fill",
        padding = { left = theme.spacing.page, right = theme.spacing.wide, top = theme.spacing.inset, bottom = theme.spacing.tab },
        children = {
            column {
                spacing = 0,
                children = {
                    row {
                        spacing = theme.spacing.xs,
                        children = {
                            hand(now:map(clock12), theme.desk.clock_font, { font_weight = theme.REGULAR, line_height = 1.0 }),
                            hand(now:map(function(t) return os.date("%p", t) end), theme.font.xxl,
                                { align_v = "end", padding = { bottom = theme.spacing.roomy } }),
                        },
                    },
                    rect {
                        children = {
                            body(now:map(function(t) return os.date("%a, %d %b %Y", t) end), theme.font.xl),
                            rect { align_v = "end", translate = { y = theme.desk.clock_underline_y }, children = { squiggle(theme.desk.clock_underline_w) } },
                        },
                    },
                },
            },
            rect { align_h = "end", align_v = "end", translate = { x = 4, y = theme.spacing.xs }, rotate = 12, children = { sprig(theme.desk.clock_sprig) } },
        },
    },
}

-- What the desk remembers between restarts: the to-do list and the sticky note.
local desk = persistent_table { path = paths.state("state-desk.json"), defaults = { todo = {}, note = "" } }

-- Typing on the desk: niri's focus-follows-mouse moves focus off a surface the pointer leaves, so
-- while a desk field is focused the panel claims the whole output; a click on bare desk ends it.
local note_focus = focused("desk.note")
local editing = computed({ note_focus, focused("paper.field.desk.todo.add") }, function(a, b) return a or b end)
-- For one pass: both fields disabled (a disabled field drops focus) and the panel off the keyboard,
-- so the compositor hands it back to a window.
local release = state("desk.release", false)
-- The cards with a field arm the panel's keyboard on hover: niri hands an `on_demand` layer the
-- keyboard whenever it maps (shell start, a new output), so the panel maps with none.
local field_cards = { note = hover("paper.card.note"), todo = hover("paper.card.todo") }
local function release_keyboard()
    release:set(true)
    timer(50, function() release:set(false) end)
end
-- A workspace switch while typing would otherwise leave the keyboard on the desk.
mantle.workspaces:map(function(w)
    local active = {}
    for _, o in ipairs(w and w.outputs or {}) do active[#active + 1] = o.active_workspace end
    return table.concat(active, ",")
end, ""):on_change(function()
    if editing:get() then release_keyboard() end
end)

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
    height = QUOTE_H,
    seed = 202,
    rotate = -0.8,
    child = rect {
        width = "fill",
        height = "fill",
        padding = { left = theme.spacing.page, right = theme.desk.quote_pad_right, top = theme.spacing.wide, bottom = theme.spacing.roomy },
        children = {
            body(quote:map(function(q) return "\u{201C}" .. q .. "\u{201D}" end), theme.font.xl, {
                width = "fill",
                wrap = "word",
                max_lines = 4,
                elide = "end",
                foreground = INK_SOFT,
                line_height = 1.25,
            }),
            rect { align_h = "end", align_v = "end", translate = { x = theme.spacing.page }, children = { star(theme.icon.lg, INK) } },
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
    local label = body(item.text, theme.font.control, {
        max_width = CARD_W - theme.desk.task_text_w,
        elide = "end",
        foreground = item.done and INK_SOFT or INK,
        align_v = "center",
    })
    return row {
        width = "fill",
        spacing = theme.spacing.snug,
        hover = hovered,
        children = {
            rect {
                cursor = "pointer",
                accessible_name = (item.done and "Mark not done: " or "Mark done: ") .. item.text,
                on_click = function() edit_todo(function(l) l[i].done = not l[i].done end) end,
                children = { checkbox(theme.icon.label, item.done) },
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
                padding = { left = theme.spacing.xxs, right = theme.spacing.xxs },
                on_click = function() edit_todo(function(l) table.remove(l, i) end) end,
                children = { body("\u{00D7}", theme.font.xl, { foreground = INK_SOFT, align_v = "center" }) },
            },
        },
    }
end

-- The sheet is sized from the measured header, list and field, so rows of any height fit; past
-- `max_height` the list scrolls and the field stays on the card.
local function todo_card(output, max_height)
    local id = "desk.todo." .. output
    local header_g, rows_g, add_g = geometry(id .. ".header"), geometry(id .. ".rows"), geometry(id .. ".add")
    local pad = { left = theme.spacing.tab, right = theme.spacing.wide, top = theme.spacing.lg, bottom = theme.spacing.inset }
    local gap = theme.spacing.xs
    local chrome = computed({ header_g, add_g }, function(h, a)
        return pad.top + pad.bottom + h.height + a.height + 2 * gap
    end, 0)
    local view_h = computed({ chrome, rows_g }, function(c, r)
        return math.max(1, math.min(r.height, max_height - c))
    end, 1)
    local rows = desk.todo:map(function(items)
        local out = {}
        for i, item in ipairs(items or {}) do out[i] = todo_row(i, item) end
        return out
    end)
    -- Built once, outside the mapped rows, so it holds focus while the list grows.
    local add = controls.field {
        id = "desk.todo.add",
        disabled = release,
        placeholder = "Add a task\u{2026}",
        width = CARD_W - theme.desk.todo_field_inset,
        size = theme.font.lg,
        on_submit = function(text)
            text = util.trim(text)
            if text ~= "" then edit_todo(function(l) l[#l + 1] = { text = text, done = false } end) end
        end,
    }
    return rect {
        padding = theme.paper.card_pad,
        rotate = 0.4,
        children = {
            rect {
                children = computed({ chrome, view_h }, function(c, v)
                    return { k.sheet { width = CARD_W, height = math.ceil(c + v), seed = 303, fx = { rim = 2.2 } } }
                end),
            },
            column {
                width = CARD_W,
                padding = pad,
                spacing = gap,
                children = {
                    row {
                        geometry = header_g,
                        spacing = theme.spacing.md,
                        children = { checkbox(theme.icon.badge, true), hand("To do", theme.font.section, { font_weight = theme.BOLD, align_v = "center" }) },
                    },
                    column {
                        width = "fill",
                        height = view_h,
                        scroll = scroll(id .. ".scroll"),
                        children = {
                            column {
                                geometry = rows_g,
                                width = "fill",
                                spacing = gap,
                                padding = { left = theme.spacing.xxs },
                                children = rows,
                            },
                        },
                    },
                    rect { geometry = add_g, children = { add } },
                },
            },
        },
    }
end

-- A yellow sticky note she types straight onto; saved a second after the last key.
local note_card = card {
    width = CARD_W,
    height = NOTE_H,
    seed = 404,
    rotate = -0.5,
    color = theme.TAB_PEACH,
    child = rect {
        width = "fill",
        height = "fill",
        padding = { left = theme.spacing.tab, right = theme.spacing.wide, top = theme.spacing.roomy, bottom = theme.spacing.lg },
        children = {
            textfield {
                width = "fill",
                height = "fill",
                multiline = true,
                initial_text = desk.note,
                placeholder = "Write a note\u{2026}",
                placeholder_color = theme.PENCIL,
                font = theme.HAND,
                font_size = theme.font.xl,
                foreground = INK,
                caret = { color = theme.BLUE, width = 2 },
                selection = { background = theme.SELECTION },
                accessible_name = "Sticky note",
                focused = note_focus,
                disabled = release,
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

local TRACK_W = theme.desk.track_w

local music_card = card {
    width = CARD_W,
    height = MUSIC_H,
    seed = 404,
    rotate = -0.6,
    child = column {
        width = "fill",
        height = "fill",
        padding = { left = theme.spacing.wide, right = theme.spacing.wide, top = theme.spacing.xl, bottom = theme.spacing.inset },
        spacing = theme.spacing.snug,
        children = {
            row {
                spacing = theme.spacing.lg,
                width = "fill",
                children = {
                    image {
                        width = theme.desk.music_art,
                        height = theme.desk.music_art,
                        radius = theme.radius.sm,
                        shadows = theme.SHADOW.deep_note,
                        opacity = has_player:map(function(v) return v and 1 or 0.45 end),
                        source = player:map(function(p)
                            return p and p.album_art_path ~= "" and p.album_art_path or DIR .. "/img/cover.png"
                        end),
                    },
                    column {
                        spacing = theme.spacing.hairline,
                        width = "fill",
                        padding = { top = theme.spacing.xs },
                        children = {
                            hand(player:map(function(p)
                                return p and p.title ~= "" and p.title or "Nothing playing"
                            end),
                                theme.font.display, { font_weight = theme.BOLD, elide = "end", width = "fill" }),
                            body(player:map(function(p) return p and p.title ~= "" and p.artist or "" end),
                                theme.font.md, { foreground = INK_SOFT, elide = "end", width = "fill" }),
                        },
                    },
                },
            },
            row {
                spacing = theme.spacing.snug,
                width = "fill",
                children = {
                    body(progress:map(function(p) return p.len and fmt_us(p.pos) or "" end), theme.font.caption,
                        { align_v = "center", width = theme.desk.music_value_w }),
                    rect {
                        width = TRACK_W,
                        height = theme.desk.meter_h,
                        align_v = "center",
                        children = {
                            rect { width = "fill", height = 2, align_v = "center", background = theme.INK_FADED },
                            rect {
                                width = progress:map(function(p) return math.floor(p.at * TRACK_W) end),
                                height = 3,
                                align_v = "center",
                                background = RED,
                            },
                            rect {
                                width = theme.desk.meter_pin,
                                height = theme.desk.meter_pin,
                                radius = theme.radius.inset,
                                align_v = "center",
                                background = RED,
                                visible = progress:map(function(p) return p.len ~= nil end),
                                translate = progress:map(function(p) return { x = math.floor(p.at * TRACK_W) - theme.desk.meter_pin_center } end),
                            },
                        },
                    },
                    body(progress:map(function(p) return p.len and fmt_us(p.len) or "" end), theme.font.caption, { align_v = "center" }),
                },
            },
            row {
                width = "fill",
                spacing = theme.spacing.binding,
                padding = { left = theme.spacing.section },
                hittable = has_player,
                opacity = has_player:map(function(v) return v and 1 or 0.35 end),
                children = {
                    rect {
                        on_click = function() local p = player:get(); if p then mantle.mpris:control(p.id, "previous") end end,
                        children = { glyph("media-skip-backward-symbolic", theme.icon.lg) },
                    },
                    rect {
                        on_click = function() local p = player:get(); if p then mantle.mpris:control(p.id, "play_pause") end end,
                        children = {
                            glyph(player:map(function(p)
                                return p and p.play_state == "playing" and "media-playback-pause-symbolic"
                                    or "media-playback-start-symbolic"
                            end), theme.icon.badge),
                        },
                    },
                    rect {
                        on_click = function() local p = player:get(); if p then mantle.mpris:control(p.id, "next") end end,
                        children = { glyph("media-skip-forward-symbolic", theme.icon.lg) },
                    },
                    rect { width = "fill" },
                    rect { align_v = "center", children = { heart(theme.icon.control, RED) } },
                },
            },
        },
    },
}

-- Dragging cards: each card keeps an offset from its slot in the column. The live offset is a
-- state while the pointer holds the card; on release it is saved to positions.json, so a card
-- stays where it was dropped across restarts. Double-click puts it back in its slot.
local positions = persistent_table { path = paths.state("positions.json"), defaults = {} }

local function draggable(name, node)
    -- `live` holds the card's offset from press until the saved value catches up: the file write
    -- is asynchronous, and dropping `live` on release would flash the old position for a frame.
    ---@type StateSignal<{ x: number, y: number }|false>
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
                hover = field_cards[name],
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
            background = theme.DESK_BACKDROP,
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
    keyboard_interactivity = computed({ release, editing, field_cards.note, field_cards.todo }, function(r, e, a, b)
        return not r and (e or a or b) and "on_demand" or "none"
    end),
    -- The panel covers the output so a card can be dropped anywhere; only the cards take input.
    anchor = { top = true, bottom = true, left = true, right = true },
    width = "fill",
    height = "fill",
    child = function(output)
        local available = ui_state.screen_height(output) - ui_state.BAR_H - TOP - BOTTOM
        local max_height = math.max(TODO_H, available - 2 * theme.paper.card_pad)
        -- The to-do card grows into the room left in the stack, wraps to a new column when it no
        -- longer fits there, and scrolls only past a full column.
        local stack = column {
            width = "fill",
            height = "fill",
            padding = { left = theme.spacing.xxl, right = theme.spacing.xxl, top = TOP, bottom = BOTTOM },
            spacing = GAP,
            wrap = true,
            line_spacing = theme.spacing.sm,
            align_h = "end",
            children = {
                draggable("clock", clock_card),
                draggable("quote", quote_card),
                draggable("note", note_card),
                draggable("music", music_card),
                draggable("todo", todo_card(output, max_height)),
            },
        }
        return rect {
            width = "fill",
            height = "fill",
            children = {
                rect {
                    width = "fill",
                    height = "fill",
                    background = "#00000000",
                    visible = editing,
                    on_click = release_keyboard,
                },
                stack,
            },
        }
    end,
}

return M
