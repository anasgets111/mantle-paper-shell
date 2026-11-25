-- The desk: the wallpaper and the cards pinned to it (clock, quote, todo, music, photo). Cards drag
-- anywhere and remember where they were dropped; double-click puts one back. Right-click on the
-- wallpaper offers "Change background…".
local k = require("lib.paper")
local menu_component = require("components.menu")
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
    -- The panel covers the output so a card can be dropped anywhere; only the cards take input.
    anchor = { top = true, bottom = true, left = true, right = true },
    width = "fill",
    height = "fill",
    child = column {
        width = "fill",
        padding = { left = 24, right = 24, top = 18, bottom = 24 },
        spacing = 4,
        children = {
            draggable("clock", clock_card),
            draggable("quote", quote_card),
            draggable("todo", todo_card),
            draggable("music", music_card),
            draggable("photo", photo_card),
        },
    },
}

return M
