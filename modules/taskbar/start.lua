-- The start button and the workspace numerals at the left end of the taskbar.
local k = require("lib.paper")
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
    local W, H = 48, 40
    return tips.wrap(rect {
        width = W + 8,
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
                                    depth = 3,
                                    color = k.STOCK.primary[1],
                                    shadows = k.lift(hovered),
                                    animate = { shadows = { duration = 160, easing = "out_cubic" } },
                                    fx = { rim = 0, hatch = open and 0.4 or 0, hatch_spacing = 3.5 },
                                },
                            }
                        end),
                    },
                    rect {
                        align_h = "center",
                        align_v = "center",
                        rotate = 4,
                        children = { app_grid(22, k.DEEP_BLUE) },
                    },
                },
            },
        },
    }, name, "Start")
end

local function window_count(id)
    local n = 0
    for _, w in ipairs((mantle.windows:get() or {}).windows or {}) do
        if w.workspace_id == id then n = n + 1 end
    end
    return n
end

local function numeral(output, ws, active)
    local label_text = tostring(ws.number or ws.name or "?")
    local label = k.hand(label_text, 26, {
        foreground = active and k.DEEP_BLUE or (ws.populated and k.INK or k.INK_SOFT),
        font_weight = active and 700 or 500,
        align_h = "center",
        align_v = "center",
        padding = { right = 3 },
    })
    local children = { label }
    if active then
        -- A blue sticker square under the active numeral, shaded in pencil.
        table.insert(children, 1, k.sheet {
            width = 32,
            height = 32,
            seed = 40 + (ws.number or 0),
            depth = 2,
            color = "#C9D8EA",
            shadows = { { blur = 4, offset = { x = 1, y = 2 }, color = "#00000045" } },
            fx = { rim = 1.5, hatch = 0.35, hatch_spacing = 3.5 },
        })
    end
    local slot = "taskbar.ws." .. output .. "." .. ws.id
    local hovered = hover(slot)
    return tips.wrap(rect {
        min_width = 32,
        height = 32,
        align_v = "center",
        hover = hovered,
        accessible_name = "Workspace " .. label_text,
        cursor = "pointer",
        rotate = hovered:map(function(v) return v and -5 or (active and -3 or 0) end),
        translate = hovered:map(function(v) return { y = v and -2 or 0 } end),
        scale = press.scale(slot),
        animate = {
            rotate = { spring = { stiffness = 300, damping = 16 } },
            translate = { duration = 140, easing = "out_cubic" },
            scale = { duration = 80, easing = "out_cubic" },
        },
        on_click = function() mantle.workspaces:focus(ws.id) end,
        on_drag = press.track(slot),
        children = children,
    }, slot, function()
        local n = window_count(ws.id)
        return "Workspace " .. label_text .. ": " .. n .. (n == 1 and " window" or " windows")
    end)
end

-- Wheel over the numerals: the previous or next workspace on this output, one per notch.
local wheel = 0
local function step_workspace(output, steps)
    wheel = wheel + steps
    if math.abs(wheel) < 1 then return end
    local dir = wheel > 0 and -1 or 1
    wheel = 0
    for _, o in ipairs((mantle.workspaces:get() or {}).outputs or {}) do
        if o.name == output then
            for i, ws in ipairs(o.workspaces) do
                local next_ws = ws.id == o.active_workspace and o.workspaces[i + dir]
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
        spacing = 4,
        align_v = "center",
        on_wheel = function(_, steps) step_workspace(output, steps) end,
        children = mantle.workspaces:map(function(w)
            local out = {}
            for _, o in ipairs(w.outputs or {}) do
                if o.name == output then
                    for _, ws in ipairs(o.workspaces) do
                        out[#out + 1] = numeral(output, ws, ws.id == o.active_workspace)
                    end
                end
            end
            return out
        end, {}),
    }
end

return M
