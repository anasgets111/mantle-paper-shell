-- One app on the task list: a die-cut sticker of the app icon (on a hatched blue patch while
-- focused), ink ticks for its windows, an urgent dot and an unread badge. The slot never moves, so
-- hover and drag stay steady; an inner node slides during a drag and a further one peels up on hover.
local k = require("lib.paper")
local apps = require("lib.apps")
local tasks = require("modules.taskbar.tasks")
local icons = require("modules.taskbar.icons")
local press = require("modules.taskbar.press")
local start = require("modules.taskbar.start")

local M = {}

M.SLOT_W, M.SPACING = 50, 4
M.PITCH = M.SLOT_W + M.SPACING
M.DIV = 22 -- the pencil divider's width plus its spacing
local ICON = 30
local BOX = icons.app_box(ICON)
local THRESHOLD = 6

-- Where a dragged item lands and how far every other item moves to make room.
-- d = { key, kind = "pinned"|"running", from (pin index or slot), to, dx, crossed, settle }
function M.offset(item, d)
    if not d or not d.to then return 0 end
    if d.key == item.key then
        if not d.settle then return d.dx end
        if d.kind == "pinned" then return (d.to - d.from) * M.PITCH end
        return (d.to - item.slot) * M.PITCH - M.DIV
    end
    if d.kind == "pinned" then
        local i = item.pin_index
        if not i then return 0 end
        if d.from < d.to and i > d.from and i <= d.to then return -M.PITCH end
        if d.to < d.from and i >= d.to and i < d.from then return M.PITCH end
        return 0
    end
    if not d.crossed then return 0 end
    if item.pinned then return item.pin_index >= d.to and M.PITCH or 0 end
    return item.slot < d.from and M.PITCH or 0
end

-- The divider moves with the running items left of a dragged one when it crosses.
function M.divider_offset(d)
    return (d and d.kind == "running" and d.crossed) and M.PITCH or 0
end

local function target(item, dx)
    local P = item.npinned
    if item.pinned then
        local to = math.max(1, math.min(P, item.pin_index + math.floor(dx / M.PITCH + 0.5)))
        return to, false
    end
    local centre = (item.slot - 1) * M.PITCH + M.DIV + M.SLOT_W / 2 + dx
    if item.id and centre < P * M.PITCH + M.DIV / 2 then
        return math.max(1, math.min(P + 1, math.floor(centre / M.PITCH) + 1)), true
    end
    return item.slot, false
end

local function ticks(item)
    local n = math.min(#item.wins, 4)
    if n == 0 then return rect { width = 1, height = 6 } end
    local w, gap = 7, 3
    local total = n * w + (n - 1) * gap
    local marks = {}
    local r = k.rng(#item.key * 13 + n)
    for i = 1, n do
        local x = (i - 1) * (w + gap)
        local focused = item.focused and math.min(item.focused, 4) == i
        marks[i] = path {
            width = w + 2,
            height = 6,
            translate = { x = x },
            stroke = focused and k.BLUE or k.INK,
            stroke_width = focused and 2.8 or 1.7,
            stroke_cap = "round",
            commands = {
                { op = "M", points = { 1, 3 + (r() - 0.5) * 1.6 } },
                { op = "L", points = { w + 1, 3 + (r() - 0.5) * 1.6 } },
            },
        }
    end
    return rect { width = total + 2, height = 6, align_h = "center", children = marks }
end

local function badge(count)
    local label = count > 9 and "9+" or tostring(count)
    return rect {
        width = 18,
        height = 18,
        align_h = "end",
        align_v = "start",
        translate = { x = 5, y = -4 },
        background = k.STOCK.danger[1],
        shape = k.torn_circle(18, count + 5, 1),
        shadows = { { blur = 3, offset = { x = 1, y = 1 }, color = "#00000050" } },
        effect = k.paper_fx { rim = 0 },
        children = { k.body(label, count > 9 and 11 or 13, {
            font_weight = 700, foreground = k.DEEP_RED, align_h = "center", align_v = "center",
        }) },
    }
end

local function urgent_dot()
    return rect {
        width = 10,
        height = 10,
        align_h = "start",
        align_v = "start",
        translate = { x = -3, y = -2 },
        background = k.RED,
        shape = k.torn_circle(10, 77, 0.8),
    }
end

-- ctx = { output, drag, snap, preview_hover(name, item) -> on_hover, tip(node, name, text) -> node,
-- hide_preview() (previews and tips), open_menu(item, rect), commit(item, d) }
function M.new(item, ctx)
    local name = "taskbar.slot." .. ctx.output .. "." .. item.key
    local hovered = hover(name)
    local grab, suppress_click, wheel = nil, false, 0
    local held = press.track(name)
    local face = {}
    if item.focused then
        -- The active workspace's sticker: blue card stock shaded in pencil.
        face[1] = rect {
            rotate = -3,
            children = {
                k.sheet {
                    width = BOX,
                    height = BOX,
                    seed = #item.key * 7 + 3,
                    depth = 2,
                    color = "#C9D8EA",
                    shadows = { { blur = 4, offset = { x = 1, y = 2 }, color = "#00000045" } },
                    fx = { rim = 1.5, hatch = 0.35, hatch_spacing = 3.5 },
                },
            },
        }
    end
    face[#face + 1] = icons.app(item.icon, ICON, hovered)
    if item.urgent then face[#face + 1] = urgent_dot() end
    if item.unread > 0 then face[#face + 1] = badge(item.unread) end

    local slot = rect {
        width = M.SLOT_W,
        height = "fill",
        hover = hovered,
        accessible_name = item.name,
        cursor = "pointer",
        on_click = function(rect_, button)
            -- A drag ends before the release clicks; only that left click is swallowed.
            local dragged = suppress_click
            suppress_click = false
            if dragged and button == "left" then return end
            ctx.hide_preview()
            if button == "right" then
                ctx.open_menu(item, rect_)
            elseif button == "middle" and item.id then
                apps.launch(item.id)
            elseif button == "left" then
                tasks.activate(item)
            end
        end,
        on_wheel = function(_, steps)
            -- Touchpads and high-resolution wheels send fractions: one window per whole notch.
            wheel = wheel + steps
            if math.abs(wheel) < 1 then return end
            local id = tasks.next_window(item, wheel > 0 and -1 or 1)
            wheel = 0
            if id then mantle.windows:focus(id) end
        end,
        on_drag = function(box, p, phase)
            held(nil, nil, phase)
            if phase == "start" then
                grab, suppress_click = { x = p.x, y = p.y, moved = false }, false
                return
            end
            if not grab then return end
            local dx = p.x - grab.x
            if not grab.moved and (math.abs(dx) > THRESHOLD or math.abs(p.y - grab.y) > THRESHOLD) then
                grab.moved = true
                ctx.hide_preview()
            end
            if not grab.moved or not (item.pinned or item.id or #item.wins > 0) then
                if phase == "end" then grab = nil end
                return
            end
            -- Over a desk chip or "+", a running app's windows move there instead of reordering.
            local desk = #item.wins > 0 and start.desk_at(ctx.output, box.x + p.x, box.y + p.y) or nil
            local from = item.pinned and item.pin_index or item.slot
            local to, crossed = from, false
            if not desk and (item.pinned or item.id) then to, crossed = target(item, dx) end
            local d = {
                key = item.key,
                kind = item.pinned and "pinned" or "running",
                from = from,
                to = to,
                dx = dx,
                crossed = crossed,
                desk = desk,
            }
            if phase == "end" then
                grab, suppress_click = nil, true
                if desk then start.move_to(ctx.output, desk, item.wins) end
                ctx.commit(item, d)
            else
                ctx.drag:set(d)
            end
        end,
        children = {
            rect {
                width = "fill",
                height = "fill",
                z = ctx.drag:map(function(d) return (d and d.key == item.key) and 5 or 0 end),
                translate = ctx.drag:map(function(d) return { x = M.offset(item, d) } end),
                animate = computed({ ctx.drag, ctx.snap }, function(d, snap)
                    if snap or (d and d.key == item.key and not d.settle) then return {} end
                    return { translate = { duration = 160, easing = "out_cubic" } }
                end),
                children = {
                    column {
                        align_h = "center",
                        spacing = 3,
                        children = {
                            rect {
                                width = BOX,
                                height = BOX,
                                translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
                                rotate = hovered:map(function(v) return v and -2 or 0 end),
                                scale = press.scale(name),
                                animate = {
                                    scale = { duration = 80, easing = "out_cubic" },
                                    translate = { duration = 140, easing = "out_cubic" },
                                    rotate = { spring = { stiffness = 300, damping = 16 } },
                                },
                                children = face,
                            },
                            ticks(item),
                        },
                    },
                },
            },
        },
    }
    -- A running app's tooltip is its window preview; a closed pinned one gets its name.
    if #item.wins == 0 then return ctx.tip(slot, name, item.name) end
    slot.on_hover = ctx.preview_hover(name, item)
    return slot
end

return M
