-- What the left page lists: pinned tiles, app rows, the calculator answer, recent-file index cards
-- and category headings. Ink on the page and a highlighter, no paper shader per row: each shader
-- costs two offscreen passes.
local k = require("lib.paper")
local icons = require("modules.startmenu.icons")
local controls = require("components.controls")
local apps = require("lib.apps")
local model = require("modules.startmenu.model")
local context = require("modules.startmenu.context")
local grid = require("modules.startmenu.grid")
local recent = require("modules.startmenu.recent")
local tips = require("modules.startmenu.tips")

local M = {}

M.CELL_W, M.CELL_H = 112, 112
M.ROW_H = 40
-- Two cards and their 8 px slots plus a 4 px gap span the left page's 456 px content width.
M.CARD_W, M.CARD_H = 218, 66

local function is_selected(i)
    return model.selected:map(function(s) return s == i end)
end

-- A 1 px rect at the pointer, so the note hangs from where the click landed.
local function at_pointer(r, p)
    return { x = r.x + p.x, y = r.y + p.y, width = 1, height = 1 }
end

-- A highlighter swipe the width of whatever it sits behind.
local function swipe(h, seed, visible)
    return rect {
        width = "fill",
        height = h,
        align_v = "center",
        background = k.HIGHLIGHT,
        blend = "multiply",
        shape = k.tape_shape(nil, nil, seed),
        opacity = visible:map(function(v) return v and 1 or 0 end),
        animate = { opacity = { duration = 110 } },
    }
end

-- A name cut by `elide` shows whole in the shared tooltip; uncut, the tooltip stays away. Each
-- target wraps itself with `tips.wrap(node, slot, ...)` reading its own `elided` signal.
local function cut_of(slot)
    return elided(slot .. ".cut")
end

local function app_click(app)
    return function(r, button, p)
        if button == "right" then
            context.open(at_pointer(r, p), app)
        elseif button == "left" then
            model.launch(app.id)
        end
    end
end

-- A pinned app: its icon standing on the page and its name in hand. Drag to reorder.
function M.tile(item, i, items)
    local app = item.app
    local slot = "startmenu.tile." .. app.id
    local hovered, cut = hover(slot), cut_of(slot)
    local selected = is_selected(i)
    local lit = computed({ hovered, selected }, function(h, s) return h or s end)
    local moving = model.drag:map(function(d) return d.id == app.id end)
    local press, dragged = { x = 0, y = 0 }, false
    local click = app_click(app)
    return tips.wrap(rect {
        width = M.CELL_W,
        height = M.CELL_H,
        hover = hovered,
        accessible_name = app.name,
        cursor = moving:map(function(m) return m and "grabbing" or "pointer" end),
        z = moving:map(function(m) return m and 5 or 0 end),
        on_click = function(r, button, p, mods)
            -- A drag that comes to rest on its own cell still releases here; it is not a launch.
            if dragged then
                dragged = false
                return
            end
            click(r, button, p, mods)
        end,
        on_drag = function(_, p, phase)
            if phase == "start" then
                press, dragged = p, false
                return
            end
            local dx, dy = p.x - press.x, p.y - press.y
            if phase == "move" then
                if dragged or dx * dx + dy * dy > 64 then
                    dragged = true
                    model.drag:set { id = app.id, x = dx, y = dy }
                end
                return
            end
            model.drag:set { id = "", x = 0, y = 0 }
            if dragged then
                -- Cells count shown tiles; the store counts pins, unresolved ones included.
                local to = grid.target(i, dx, dy, #items, model.COLUMNS, M.CELL_W, M.CELL_H)
                if to ~= i then apps.move_menu_pin(item.pin_index, items[to].pin_index) end
            end
        end,
        children = {
            rect {
                width = "fill",
                height = "fill",
                translate = model.drag:map(function(d)
                    return d.id == app.id and { x = d.x, y = d.y } or { x = 0, y = 0 }
                end),
                rotate = moving:map(function(m) return m and -4 or 0 end),
                animate = { rotate = { spring = { stiffness = 300, damping = 16 } } },
                children = {
                    rect {
                        align_h = "center",
                        children = selected:map(function(s)
                            return s and { controls.pencil_loop(M.CELL_W - 8, M.CELL_H - 6, 40 + i) } or {}
                        end),
                    },
                    column {
                        width = "fill",
                        spacing = 6,
                        padding = { top = 12 },
                        children = {
                            -- The lift sits on a parent: the sticker's shadow layers redraw on each move.
                            rect {
                                align_h = "center",
                                translate = lit:map(function(v) return { y = v and -3 or 0 } end),
                                animate = { translate = { duration = 140, easing = "out_cubic" } },
                                children = { icons.app(app, 44) },
                            },
                            -- Sized by the name, so the swipe covers the ink and no more.
                            rect {
                                align_h = "center",
                                children = {
                                    swipe(24, i, hovered),
                                    k.body(app.name, 18, {
                                        align_h = "center",
                                        elide = "end",
                                        max_width = M.CELL_W - 8,
                                        elided = cut,
                                        padding = { left = 6, right = 6 },
                                    }),
                                },
                            },
                        },
                    },
                },
            },
        },
    }, slot, function() return cut:get() and app.name or "" end)
end

-- An app on one ruled line: icon, name, and its generic name in pencil.
function M.app_row(item, i)
    local app = item.app
    local slot = "startmenu.row." .. app.id
    local hovered, cut = hover(slot), cut_of(slot)
    local lit = computed({ hovered, is_selected(i) }, function(h, s) return h or s end)
    local children = {
        icons.app(app, 24),
        k.body(app.name, 20, { align_v = "center", elide = "end", max_width = 300, elided = cut }),
    }
    if app.generic_name and app.generic_name ~= "" and app.generic_name ~= app.name then
        children[3] = k.body(app.generic_name, 16, {
            foreground = k.INK_SOFT, align_v = "center", elide = "end", width = "fill", text_align = "end",
        })
    end
    return tips.wrap(rect {
        width = "fill",
        height = M.ROW_H,
        hover = hovered,
        accessible_name = app.name,
        cursor = "pointer",
        on_click = app_click(app),
        children = {
            swipe(M.ROW_H - 10, i + 7, lit),
            row {
                width = "fill", height = "fill", spacing = 12, padding = { left = 8, right = 12 }, children = children,
            },
        },
    }, slot, function() return cut:get() and app.name or "" end)
end

-- The calculator's answer in blue marker; Enter or a click copies it.
function M.calc_row(item, i)
    local hovered = hover("startmenu.calc")
    local lit = computed({ hovered, is_selected(i) }, function(h, s) return h or s end)
    return rect {
        width = "fill",
        height = 52,
        hover = hovered,
        accessible_name = "Copy " .. item.value,
        cursor = "pointer",
        on_click = function() model.activate(item) end,
        children = {
            swipe(38, 5, lit),
            row {
                width = "fill",
                height = "fill",
                spacing = 12,
                padding = { left = 8, right = 12 },
                children = {
                    icons.glyph("calc", 24),
                    k.hand("= " .. item.value, 34, {
                        font_weight = 700, foreground = k.BLUE, align_v = "center", elide = "end",
                    }),
                    k.body("Enter copies", 16, {
                        foreground = k.INK_SOFT, align_v = "center", width = "fill", text_align = "end",
                    }),
                },
            },
        },
    }
end

-- A recent file on a small index card: red header rule, mime glyph, name and date.
function M.file_card(item, i)
    local f = item.file
    local slot = "startmenu.file." .. i
    local hovered, cut = hover(slot), cut_of(slot)
    local lit = computed({ hovered, is_selected(i) }, function(h, s) return h or s end)
    local w, h = M.CARD_W, M.CARD_H
    return tips.wrap(rect {
        width = w + 8,
        height = h + 8,
        hover = hovered,
        accessible_name = f.name,
        cursor = "pointer",
        on_click = function() model.open_uri(f.uri) end,
        children = {
            rect {
                width = w,
                height = h,
                rotate = ((i % 3) - 1) * 0.6,
                translate = lit:map(function(v) return { y = v and -3 or 0 } end),
                animate = {
                    translate = { duration = 140, easing = "out_cubic" },
                    shadows = { duration = 160, easing = "out_cubic" },
                },
                background = "#FBF7EC",
                shape = k.torn(w, h, 70 + i, 2),
                shadows = k.lift(lit),
                children = {
                    path {
                        width = w, height = h, stroke = "#D9534F80", stroke_width = 1.2,
                        commands = { { op = "M", points = { 4, 15 } }, { op = "L", points = { w - 4, 15 } } },
                    },
                    path {
                        width = w, height = h, stroke = "#7FA3D040", stroke_width = 1,
                        commands = { { op = "M", points = { 4, 42 } }, { op = "L", points = { w - 4, 42 } } },
                    },
                    row {
                        width = "fill",
                        height = "fill",
                        spacing = 10,
                        padding = { left = 12, right = 10, top = 14 },
                        children = {
                            icons.glyph(f.icon, 22),
                            column {
                                width = "fill",
                                align_v = "center",
                                children = {
                                    k.body(f.name, 18, { elide = "middle", width = "fill", elided = cut }),
                                    k.body(recent.when(f.at, os.time()), 16, { foreground = k.INK_SOFT }),
                                },
                            },
                        },
                    },
                },
            },
        },
    }, slot, function() return cut:get() and f.name or "" end)
end

-- A category heading in blue hand, with a pencil rule out to the margin.
function M.heading(name)
    return row {
        width = "fill",
        height = M.ROW_H,
        spacing = 10,
        padding = { left = 4 },
        children = {
            k.hand(name, 26, { font_weight = 700, foreground = k.BLUE, align_v = "end" }),
            -- A pencil rule out to the margin, as long as the heading leaves room for.
            rect {
                width = "fill",
                height = 3,
                align_v = "center",
                margin = { top = 10, right = 12 },
                background = "#3A363170",
                shape = { commands = {
                    { op = "M", points = { 0, "35%" } },
                    { op = "Q", points = { "50%", "5%", "100%", "40%" } },
                    { op = "L", points = { "100%", "85%" } },
                    { op = "Q", points = { "50%", "55%", 0, "80%" } },
                    { op = "Z", points = {} },
                } },
            },
        },
    }
end

return M
