-- What the left page lists: pinned tiles, app rows, the calculator answer, recent-file index cards
-- and category headings. Ink on the page and a highlighter, no paper shader per row: each shader
-- costs two offscreen passes.
local theme = require("theme")
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

M.CELL_W, M.CELL_H = theme.startmenu.cell_w, theme.startmenu.cell_h
M.ROW_H = theme.startmenu.row_h
-- Two cards and their 8 px slots plus a 4 px gap span the left page's 456 px content width.
M.CARD_W, M.CARD_H = theme.startmenu.recent_w, theme.startmenu.recent_h

local function is_selected(i)
    return model.selected:map(function(s) return s == i end)
end

-- Tab focus lights a target the way the arrow-key selection does; the engine's square outline is off.
local function lit_by(hovered, i, focus)
    return computed({ hovered, is_selected(i), focus }, function(h, s, f) return h or s or f end)
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
        background = theme.HIGHLIGHT,
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
    local focus = focus_visible(slot .. ".focus")
    local looped = computed({ is_selected(i), focus }, function(s, f) return s or f end)
    local lit = lit_by(hovered, i, focus)
    local moving = model.drag:map(function(d) return d.id == app.id end)
    local press, dragged = { x = 0, y = 0 }, false
    local click = app_click(app)
    return tips.wrap(rect {
        width = M.CELL_W,
        height = M.CELL_H,
        hover = hovered,
        focus_visible = focus,
        focus_ring = false,
        accessible_name = app.name,
        cursor = moving:map(function(m) return m and "grabbing" or "pointer" end),
        z = moving:map(function(m) return m and 5 or 0 end),
        on_click = function(r, button, p)
            -- A drag that comes to rest on its own cell still releases here; it is not a launch.
            if dragged then
                dragged = false
                return
            end
            click(r, button, p)
        end,
        on_drag = function(_, p, phase)
            model.track(slot)(nil, nil, phase)
            if phase == "start" then
                press, dragged = p, false
                return
            end
            local dx, dy = p.x - press.x, p.y - press.y
            if phase == "move" then
                if dragged or dx * dx + dy * dy > theme.startmenu.tile_loop_inset_x ^ 2 then
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
                        children = looped:map(function(s)
                            return s and { controls.pencil_loop(M.CELL_W - theme.startmenu.tile_loop_inset_x, M.CELL_H - theme.startmenu.tile_loop_inset_y, 40 + i) } or {}
                        end),
                    },
                    column {
                        width = "fill",
                        spacing = theme.spacing.xs,
                        padding = { top = theme.spacing.md },
                        children = {
                            -- The lift sits on a parent: the sticker's shadow layers redraw on each move.
                            rect {
                                align_h = "center",
                                translate = lit:map(function(v) return { y = v and -3 or 0 } end),
                                scale = model.sink(slot, 0.9),
                                animate = {
                                    translate = { duration = 140, easing = "out_cubic" },
                                    scale = { duration = 90, easing = "out_cubic" },
                                },
                                children = { icons.app(app, theme.icon.tile) },
                            },
                            -- Sized by the name, so the swipe covers the ink and no more.
                            rect {
                                align_h = "center",
                                children = {
                                    swipe(theme.startmenu.tile_swipe_h, i, hovered),
                                    k.body(app.name, theme.font.sm, {
                                        align_h = "center",
                                        elide = "end",
                                        max_width = M.CELL_W,
                                        elided = cut,
                                        padding = { left = theme.spacing.compact, right = theme.spacing.compact },
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
    local focus = focus_visible(slot .. ".focus")
    local lit = lit_by(hovered, i, focus)
    local children = {
        icons.app(app, theme.icon.lg),
        k.body(app.name, theme.font.md, { align_v = "center", elide = "end", max_width = theme.startmenu.app_name_w, elided = cut }),
    }
    if app.generic_name and app.generic_name ~= "" and app.generic_name ~= app.name then
        children[3] = k.body(app.generic_name, theme.font.xs, {
            foreground = theme.INK_SOFT, align_v = "center", elide = "end", width = "fill", text_align = "end",
        })
    end
    return tips.wrap(rect {
        width = "fill",
        height = M.ROW_H,
        hover = hovered,
        focus_visible = focus,
        focus_ring = false,
        accessible_name = app.name,
        cursor = "pointer",
        on_click = app_click(app),
        on_drag = model.track(slot),
        scale = model.sink(slot, 0.98),
        animate = { scale = { duration = 90, easing = "out_cubic" } },
        children = {
            swipe(M.ROW_H - theme.startmenu.app_swipe_trim, i + 7, lit),
            row {
                width = "fill", height = "fill", spacing = theme.spacing.md, padding = { left = theme.spacing.sm, right = theme.spacing.md }, children = children,
            },
        },
    }, slot, function() return cut:get() and app.name or "" end)
end

-- The calculator's answer in blue marker; Enter or a click copies it.
function M.calc_row(item, i)
    local hovered = hover("startmenu.calc")
    local focus = focus_visible("startmenu.calc.focus")
    local lit = lit_by(hovered, i, focus)
    return rect {
        width = "fill",
        height = theme.control.tile,
        hover = hovered,
        focus_visible = focus,
        focus_ring = false,
        accessible_name = "Copy " .. item.value,
        cursor = "pointer",
        on_click = function() model.activate(item) end,
        on_drag = model.track("startmenu.calc"),
        scale = model.sink("startmenu.calc", 0.98),
        animate = { scale = { duration = 90, easing = "out_cubic" } },
        children = {
            swipe(theme.startmenu.calc_swipe_h, 5, lit),
            row {
                width = "fill",
                height = "fill",
                spacing = theme.spacing.md,
                padding = { left = theme.spacing.sm, right = theme.spacing.md },
                children = {
                    icons.glyph("calc", theme.icon.lg),
                    k.hand("= " .. item.value, theme.font.display, {
                        font_weight = theme.BOLD, foreground = theme.BLUE, align_v = "center", elide = "end",
                    }),
                    k.body("Enter copies", theme.font.xs, {
                        foreground = theme.INK_SOFT, align_v = "center", width = "fill", text_align = "end",
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
    local focus = focus_visible(slot .. ".focus")
    local lit = lit_by(hovered, i, focus)
    local w, h = M.CARD_W, M.CARD_H
    return tips.wrap(rect {
        width = w + theme.startmenu.recent_shadow_pad,
        height = h + theme.startmenu.recent_shadow_pad,
        hover = hovered,
        focus_visible = focus,
        focus_ring = false,
        accessible_name = f.name,
        cursor = "pointer",
        on_click = function() model.open_uri(f.uri) end,
        on_drag = model.track(slot),
        children = {
            rect {
                width = w,
                height = h,
                rotate = ((i % 3) - 1) * 0.6,
                translate = lit:map(function(v) return { y = v and -3 or 0 } end),
                scale = model.sink(slot, 0.96),
                animate = {
                    translate = { duration = 140, easing = "out_cubic" },
                    scale = { duration = 90, easing = "out_cubic" },
                    shadows = { duration = 160, easing = "out_cubic" },
                },
                background = theme.CARD_LIGHT,
                shape = k.torn(w, h, 70 + i, theme.paper.light_tear),
                shadows = k.lift(lit),
                children = {
                    path {
                        width = w, height = h, stroke = theme.FILE_RULE, stroke_width = 1.2,
                        commands = { { op = "M", points = { 4, theme.startmenu.recent_margin_y } }, { op = "L", points = { w - 4, theme.startmenu.recent_margin_y } } },
                    },
                    path {
                        width = w, height = h, stroke = theme.RULE_BLUE, stroke_width = 1,
                        commands = { { op = "M", points = { 4, theme.startmenu.recent_rule_y } }, { op = "L", points = { w - 4, theme.startmenu.recent_rule_y } } },
                    },
                    row {
                        width = "fill",
                        height = "fill",
                        spacing = theme.spacing.snug,
                        padding = { left = theme.spacing.md, right = theme.spacing.snug, top = theme.spacing.inset },
                        children = {
                            icons.glyph(f.icon, theme.icon.control),
                            column {
                                width = "fill",
                                align_v = "center",
                                children = {
                                    k.body(f.name, theme.font.sm, { elide = "middle", width = "fill", elided = cut }),
                                    k.body(recent.when(f.at, os.time()), theme.font.xs, { foreground = theme.INK_SOFT }),
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
        spacing = theme.spacing.snug,
        padding = { left = theme.spacing.xxs },
        children = {
            k.hand(name, theme.font.heading, { font_weight = theme.BOLD, foreground = theme.BLUE, align_v = "end" }),
            -- A pencil rule out to the margin, as long as the heading leaves room for.
            rect {
                width = "fill",
                height = 3,
                align_v = "center",
                margin = { top = theme.spacing.snug, right = theme.spacing.md },
                background = theme.PENCIL,
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
