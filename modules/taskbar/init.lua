-- Taskbar (Dash to Panel): a torn strip of notebook paper along the bottom of every output. Start
-- button, workspaces, pinned and running apps, tray, status icons, clock and a show-desktop strip.
local theme = require("theme")
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
local privacy = require("modules.taskbar.privacy")
local awake = require("modules.taskbar.awake")
local recorder = require("modules.recorder")
local layouts = require("modules.taskbar.layouts")
local tips = require("modules.taskbar.tips")
local ui_state = require("lib.ui_state")

-- The updater widget lives in another module that may not exist yet; without it, nothing shows.
local has_updates, updates = pcall(require, "modules.updates")
if not has_updates or type(updates) ~= "table" or not updates.widget then updates = nil end

local BAR_H = ui_state.BAR_H
-- Room above the strip for the torn edge's shadow and for an icon peeling up.
local HEADROOM = ui_state.BAR_HEADROOM

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
        children = { rect { align_h = "center", align_v = "center", children = { controls.divider(theme.bar.divider_h, true, 7) } } },
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
        tip = tips.wrap,
        hide_preview = function()
            previews.hide()
            tips.hide()
        end,
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
    end)
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

local function pencil_divider(seed)
    return rect {
        height = "fill",
        children = { rect { align_v = "center", children = { controls.divider(theme.bar.divider_h, true, seed) } } },
    }
end

-- True while the focused window on `output` is fullscreen: the strip slides off the screen.
local function fullscreen_on(output)
    return mantle.windows:map(function(w)
        for _, win in ipairs(w and w.windows or {}) do
            if win.focused and win.fullscreen and (win.output == nil or win.output == output) then return true end
        end
        return false
    end, false)
end

local function bar(output)
    local hidden = fullscreen_on(output)
    local right = {}
    if updates then right[#right + 1] = updates.widget(output) end
    right[#right + 1] = recorder.indicator(output)
    right[#right + 1] = awake.indicator(output)
    right[#right + 1] = privacy.indicators(output)
    right[#right + 1] = layouts.widget(output)
    right[#right + 1] = status.icons(output)
    right[#right + 1] = status.clock(output)
    right[#right + 1] = status.desktop_strip(output)
    return column {
        width = "fill",
        height = "fill",
        align_v = "end",
        hittable = hidden:map(function(h) return not h end),
        translate = hidden:map(function(h) return { y = h and BAR_H + HEADROOM or 0 } end),
        animate = { translate = { duration = 180, easing = "out_cubic" } },
        children = {
            k.sheet {
                width = "fill",
                height = BAR_H,
                shape = k.torn_top(BAR_H, 12),
                fx = { rim = 2.2 },
                child = row {
                    width = "fill",
                    height = "fill",
                    padding = { left = theme.spacing.snug, top = theme.spacing.xs },
                    spacing = theme.spacing.snug,
                    children = {
                        start.button(output),
                        start.workspaces(output),
                        pencil_divider(3),
                        task_list(output),
                        rect { width = "fill" },
                        tray.new(output),
                        pencil_divider(5),
                        row { height = "fill", spacing = theme.spacing.snug, children = right },
                    },
                },
            },
        },
    }
end

local panel_surface = panel {
    id = "paper-taskbar",
    -- Not `mantle-*`: the desktop's Hyprland rules frost that namespace's popups, and paper is opaque.
    namespace = "paper-taskbar",
    layer = "top",
    anchor = { bottom = true, left = true, right = true },
    width = "fill",
    height = BAR_H + HEADROOM,
    exclusive_zone = BAR_H,
    child = bar,
}

local surfaces = { panel_surface, previews.surface, previews.tip_surface, tips.surface, privacy.live_surface }
for _, s in ipairs(menus.surfaces) do surfaces[#surfaces + 1] = s end
for _, s in ipairs(recorder.surfaces) do surfaces[#surfaces + 1] = s end

return { surfaces = surfaces }
