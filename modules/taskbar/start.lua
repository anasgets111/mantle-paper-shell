-- The start button and the desk chips at the left end of the taskbar.
local theme = require("theme")
local k = require("lib.paper")
local apps = require("lib.apps")
local icons = require("modules.taskbar.icons")
local ui_state = require("lib.ui_state")
local tips = require("modules.taskbar.tips")
local press = require("modules.taskbar.press")

local M = {}

local menu_open = ui_state.modal_showing("startmenu")

-- A 3 x 3 grid of pencil squares, each corner nudged a little, as an app grid sketched in a margin.
local function app_grid(size, color)
    local r = k.rng(919)
    local cell, gap, inset = size * 0.2, size * 0.13, size * 0.11
    local c = {}
    for row_i = 0, 2 do
        for col = 0, 2 do
            local x, y = inset + col * (cell + gap), inset + row_i * (cell + gap)
            local function j() return (r() - 0.5) * 1.2 end
            c[#c + 1] = { op = "M", points = { x + j(), y + j() } }
            c[#c + 1] = { op = "L", points = { x + cell + j(), y + j() } }
            c[#c + 1] = { op = "L", points = { x + cell + j(), y + cell + j() } }
            c[#c + 1] = { op = "L", points = { x + j(), y + cell + j() } }
            c[#c + 1] = { op = "Z", points = {} }
        end
    end
    return k.stroke_path(size, size, c, color, 1.7)
end

-- A tab of blue card stock with a sketched app grid; it stays hatched while the start menu is open.
function M.button(output)
    local name = "taskbar.start." .. output
    local hovered = hover(name)
    local W, H = theme.bar.start_w, theme.bar.start_h
    return tips.wrap(rect {
        width = W + theme.bar.start_pad,
        height = "fill",
        hover = hovered,
        accessible_name = "Start menu",
        cursor = "pointer",
        on_click = function() ui_state.toggle_modal("startmenu") end,
        on_drag = press.track(name),
        children = {
            rect {
                width = W,
                height = H,
                align_h = "center",
                align_v = "center",
                translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
                rotate = hovered:map(function(v) return v and -2 or -0.6 end),
                scale = press.scale(name),
                animate = {
                    scale = { duration = 80, easing = "out_cubic" },
                    translate = { duration = 140, easing = "out_cubic" },
                    rotate = { spring = { stiffness = 300, damping = 16 } },
                },
                children = {
                    rect {
                        width = W,
                        height = H,
                        children = menu_open:map(function(open)
                            return {
                                k.sheet {
                                    width = W,
                                    height = H,
                                    seed = 808,
                                    depth = theme.paper.control_tear,
                                    color = theme.STOCK.primary[1],
                                    shadows = k.lift(hovered),
                                    animate = { shadows = { duration = 160, easing = "out_cubic" } },
                                    fx = { rim = 0, hatch = open and 0.4 or 0, hatch_spacing = theme.paper.hatch },
                                },
                            }
                        end),
                    },
                    rect {
                        align_h = "center",
                        align_v = "center",
                        rotate = 4,
                        children = { app_grid(theme.bar.start_icon, theme.DEEP_BLUE) },
                    },
                },
            },
        },
    }, name, "Start")
end

-- App stickers per desk chip; the tooltip names the rest.
local ICON, MAX_ICONS, PAD, GAP = theme.bar.desk_icon, 3, theme.bar.desk_pad, theme.bar.desk_gap

-- Desks on `output` worth showing: those holding windows, plus the one on screen. Empty desks stay
-- hidden, so a click or a wheel notch never lands somewhere that looks like every app vanished.
-- Plain data without window titles, so a retitling window rebuilds nothing.
-- Per output: the shown desks, and the "+" node, for drop hit tests.
local lists, plus_nodes = {}, {}
local function desks(output)
    lists[output] = computed({ mantle.workspaces, mantle.windows, mantle.applications }, function(workspaces, windows, applications)
        local out = {}
        for _, o in ipairs(workspaces and workspaces.outputs or {}) do
            if o.name == output then
                for _, ws in ipairs(o.workspaces) do
                    local active = ws.id == o.active_workspace
                    if ws.populated or active then
                        local desk = { key = ws.id, active = active, icons = {}, names = {} }
                        local seen = {}
                        for _, win in ipairs(windows and windows.windows or {}) do
                            local entry = win.workspace_id == ws.id and apps.entry(applications, win.app_id)
                            local key = entry and entry.id or win.app_id
                            if win.workspace_id == ws.id and not seen[key] then
                                seen[key] = true
                                desk.names[#desk.names + 1] = entry and entry.name or (key ~= "" and key or "Window")
                                if #desk.icons < MAX_ICONS then
                                    desk.icons[#desk.icons + 1] = entry and entry.icon or "application-x-executable"
                                end
                            end
                        end
                        out[#out + 1] = desk
                    end
                end
            end
        end
        -- One desk is no choice to offer: only "+" shows until a second one is in use.
        return #out > 1 and out or {}
    end, {})
    return lists[output]
end

local function plus_slot(output) return "taskbar.desk.new." .. output end
local function chip_slot(output, key) return "taskbar.desk." .. output .. "." .. key end

-- Hover lift and press squash shared by the chips and "+"; a task icon dragged over one lifts it too.
local function tab(output, slot, drop_key, label, on_click, children)
    local hovered = computed({ hover(slot), state("taskbar.drag." .. output, false) }, function(h, d)
        return h or (d and d.desk == drop_key) or false
    end)
    return rect {
        geometry = geometry(slot),
        height = theme.control.slider,
        align_v = "center",
        hover = hover(slot),
        accessible_name = label,
        cursor = "pointer",
        rotate = hovered:map(function(v) return v and -4 or 0 end),
        translate = hovered:map(function(v) return { y = v and -2 or 0 } end),
        scale = press.scale(slot),
        animate = {
            rotate = { spring = { stiffness = 300, damping = 16 } },
            translate = { duration = 140, easing = "out_cubic" },
            scale = { duration = 80, easing = "out_cubic" },
        },
        on_click = on_click,
        on_drag = press.track(slot),
        children = children,
    }
end

-- A card-stock tab holding the stickers of the apps on one desk; the desk on screen is blue and
-- hatched, the old active-numeral sticker.
local function chip(output, desk)
    local slot = chip_slot(output, desk.key)
    local n = #desk.icons
    local width = math.max(theme.bar.desk_min_w, n * icons.app_box(ICON) + math.max(n - 1, 0) * GAP + 2 * PAD)
    local stickers = {}
    for i, name in ipairs(desk.icons) do stickers[i] = icons.app(name, ICON) end
    local apps_text = table.concat(desk.names, ", ")
    local label = desk.active and (apps_text ~= "" and "This desk: " .. apps_text or "This desk, empty")
        or "Desk with " .. apps_text
    return tips.wrap(tab(output, slot, desk.key, label, function() mantle.workspaces:focus(desk.key) end, {
        k.sheet {
            width = width,
            height = theme.control.chip,
            seed = 40 + #desk.key,
            depth = theme.paper.light_tear,
            color = desk.active and theme.TAB_BLUE or theme.STOCK.plain[1],
            shadows = theme.SHADOW.light_disc,
            fx = { rim = 1.5, hatch = desk.active and 0.35 or 0, hatch_spacing = theme.paper.hatch },
        },
        row { spacing = GAP, padding = { left = PAD, right = PAD }, align_v = "center", children = stickers },
    }), slot, label)
end

-- The first empty desk on `output`, else a fresh number on Hyprland, which creates a workspace on
-- focus or move; niri always keeps an empty one listed.
local function empty_desk(output)
    local ws_state = mantle.workspaces:get() or {}
    local top = 0
    for _, o in ipairs(ws_state.outputs or {}) do
        for _, ws in ipairs(o.workspaces) do
            if o.name == output and not ws.populated and ws.id ~= o.active_workspace then return ws.id end
            top = math.max(top, ws.number or 0)
        end
    end
    if ws_state.compositor == "hyprland" then return tostring(top + 1) end
end

local function inside(r, x, y)
    return r.width > 0 and x >= r.x and x < r.x + r.width and y >= r.y and y < r.y + r.height
end

-- The drop target under surface point (x, y) on `output`'s panel: a desk id, `"new"` for "+", or nil.
function M.desk_at(output, x, y)
    for _, desk in ipairs(lists[output] and lists[output]:get() or {}) do
        if inside(geometry(chip_slot(output, desk.key)):get(), x, y) then return desk.key end
    end
    local plus_node = plus_nodes[output]
    if plus_node and plus_node.visible:get() and inside(geometry(plus_slot(output)):get(), x, y) then
        return "new"
    end
end

-- Moves windows to a desk from `desk_at`; they go without the view following.
function M.move_to(output, key, wins)
    local id = key == "new" and empty_desk(output) or key
    if not id then return end
    for _, win in ipairs(wins) do mantle.windows:move_to_workspace(win, id) end
end

-- "+" while the desk on screen holds windows; on an empty one it would go nowhere new.
local function plus(output)
    local slot = plus_slot(output)
    local node = tab(output, slot, "new", "New desk", function()
        local id = empty_desk(output)
        if id then mantle.workspaces:focus(id) end
    end, {
        rect {
            width = theme.bar.desk_min_w,
            height = theme.control.chip,
            align_v = "center",
            border_width = 1.5,
            border_color = theme.INK_SOFT,
            border_dash = { theme.bar.dash_length, theme.bar.dash_gap },
            radius = theme.radius.md,
            children = { k.hand("+", theme.font.xl, { foreground = theme.INK, align_h = "center", align_v = "center" }) },
        },
    })
    node.visible = mantle.workspaces:map(function(w)
        for _, o in ipairs(w and w.outputs or {}) do
            if o.name == output then
                for _, ws in ipairs(o.workspaces) do
                    if ws.id == o.active_workspace then return ws.populated end
                end
            end
        end
        return false
    end, false)
    plus_nodes[output] = node
    return tips.wrap(node, slot, "New desk")
end

-- Wheel over the desks: the previous or next shown desk on this output, one per notch.
local wheel = 0
local function step_desk(output, steps)
    wheel = wheel + steps
    if math.abs(wheel) < 1 then return end
    local dir = wheel > 0 and -1 or 1
    wheel = 0
    for _, o in ipairs((mantle.workspaces:get() or {}).outputs or {}) do
        if o.name == output then
            local shown = {}
            for _, ws in ipairs(o.workspaces) do
                if ws.populated or ws.id == o.active_workspace then shown[#shown + 1] = ws end
            end
            for i, ws in ipairs(shown) do
                local next_ws = ws.id == o.active_workspace and shown[i + dir]
                if next_ws then
                    mantle.workspaces:focus(next_ws.id)
                    return
                end
            end
        end
    end
end

function M.workspaces(output)
    return row {
        spacing = theme.spacing.xxs,
        align_v = "center",
        on_wheel = function(_, steps) step_desk(output, steps) end,
        children = {
            list {
                direction = "horizontal",
                spacing = theme.spacing.xxs,
                items = desks(output),
                key = function(desk) return desk.key end,
                each = function(desk) return chip(output, desk) end,
            },
            plus(output),
        },
    }
end

return M
