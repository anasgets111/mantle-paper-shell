-- Taskbar (Dash to Panel): a torn strip of notebook paper along the bottom of every output. Start
-- button, workspaces, pinned and running apps, tray, status icons, clock and a show-desktop strip.
local k = require("lib.paper")
local apps = require("lib.apps")
local store = require("lib.store")
local util = require("lib.util")
local controls = require("components.controls")
local tasks = require("modules.taskbar.tasks")
local task_icon = require("modules.taskbar.task_icon")
local previews = require("modules.taskbar.previews")
local menus = require("modules.taskbar.menus")
local tray = require("modules.taskbar.tray")
local status = require("modules.taskbar.status")
local start = require("modules.taskbar.start")

local BAR_H = 56
-- Room above the strip for the torn edge's shadow and for an icon peeling up.
local HEADROOM = 16

-- Per output: the drag in flight, and `snap` to drop the slide tween for the pass that commits it.
local drags = {}

-- A committed reorder holds its preview until the pin list comes back from the store (written
-- asynchronously), then clears it in the same pass the list rebuilds, so nothing jumps.
local function settle_all()
    for _, d in pairs(drags) do
        local now = d.drag:get()
        if now and now.settle then
            d.snap:set(true)
            d.drag:set(false)
            timer(60, function() d.snap:set(false) end)
        end
    end
end
apps.pinned:on_change(settle_all)

local function commit(d, item, move)
    if move.kind == "pinned" and move.to ~= move.from then
        d.drag:set(util.with(move, "settle", true))
        apps.move_pin(move.from, move.to)
    elseif move.kind == "running" and move.crossed then
        d.drag:set(util.with(move, "settle", true))
        local pins = util.concat(store.pinned:get(), {})
        table.insert(pins, move.to, item.id)
        store:set("pinned", pins)
    else
        d.drag:set(false)
        return
    end
    -- A failed write never comes back; don't leave the icons parked.
    timer(1500, function()
        local now = d.drag:get()
        if now and now.settle then d.drag:set(false) end
    end)
end

local function divider_node(d)
    return rect {
        width = task_icon.DIV - task_icon.SPACING,
        height = "fill",
        translate = d.drag:map(function(v) return { x = task_icon.divider_offset(v) } end),
        animate = d.snap:map(function(s)
            return s and {} or { translate = { duration = 160, easing = "out_cubic" } }
        end),
        children = { rect { align_h = "center", align_v = "center", children = { controls.divider(34, true, 7) } } },
    }
end

local function task_list(output)
    local d = { drag = state("taskbar.drag." .. output, false), snap = state("taskbar.snap." .. output, false) }
    drags[output] = d
    local ctx = {
        output = output,
        drag = d.drag,
        snap = d.snap,
        preview_hover = function(name, item)
            previews.register(name, item)
            return previews.on_hover(name)
        end,
        hide_preview = previews.hide,
        open_menu = menus.open_app,
        commit = function(item, move) commit(d, item, move) end,
    }
    local items = tasks.for_output(output):map(function(list)
        local out = {}
        for i, item in ipairs(list) do
            if i == item.npinned + 1 and item.npinned > 0 then out[#out + 1] = { key = "|divider", divider = true } end
            out[#out + 1] = item
        end
        return out
    end, {})
    return list {
        direction = "horizontal",
        height = "fill",
        spacing = task_icon.SPACING,
        items = items,
        key = function(item) return item.key end,
        each = function(item)
            if item.divider then return divider_node(d) end
            return task_icon.new(item, ctx)
        end,
    }
end

local function bar(output)
    return column {
        width = "fill",
        height = "fill",
        align_v = "end",
        children = {
            k.sheet {
                width = "fill",
                height = BAR_H,
                shape = k.torn_top(BAR_H, 12),
                fx = { rim = 2.2 },
                child = row {
                    width = "fill",
                    height = "fill",
                    padding = { left = 10, top = 6 },
                    spacing = 10,
                    children = {
                        start.button(output),
                        start.workspaces(output),
                        rect { width = 6, height = "fill", children = { rect { align_v = "center", children = { controls.divider(34, true, 3) } } } },
                        task_list(output),
                        rect { width = "fill" },
                        tray.new(output),
                        rect { width = 6, height = "fill", children = { rect { align_v = "center", children = { controls.divider(34, true, 5) } } } },
                        status.icons(output),
                        status.clock(output),
                        status.desktop_strip(output),
                    },
                },
            },
        },
    }
end

local panel_surface = panel {
    id = "paper-taskbar",
    layer = "top",
    anchor = { bottom = true, left = true, right = true },
    width = "fill",
    height = BAR_H + HEADROOM,
    exclusive_zone = BAR_H,
    child = bar,
}

local surfaces = { panel_surface, previews.surface }
for _, s in ipairs(menus.surfaces) do surfaces[#surfaces + 1] = s end

return { surfaces = surfaces }
