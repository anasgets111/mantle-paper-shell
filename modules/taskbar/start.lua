-- The start button and the workspace numerals at the left end of the taskbar.
local k = require("lib.paper")
local ui_state = require("lib.ui_state")

local M = {}

local menu_open = ui_state.modal_showing("startmenu")

-- A tab of blue card stock with a marker star; it stays hatched while the start menu is open.
function M.button(output)
    local hovered = hover("taskbar.start." .. output)
    local W, H = 48, 40
    return rect {
        width = W + 8,
        height = "fill",
        hover = hovered,
        accessible_name = "Start menu",
        cursor = "pointer",
        on_click = function() ui_state.toggle_modal("startmenu") end,
        children = {
            rect {
                width = W,
                height = H,
                align_h = "center",
                align_v = "center",
                translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
                rotate = hovered:map(function(v) return v and -2 or -0.6 end),
                animate = {
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
                        rotate = 8,
                        children = { k.star(26, k.DEEP_BLUE, false) },
                    },
                },
            },
        },
    }
end

local function numeral(ws, active)
    local label = k.hand(tostring(ws.number or ws.name or "?"), 26, {
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
    return rect {
        width = 32,
        height = 32,
        align_v = "center",
        accessible_name = "Workspace " .. tostring(ws.number or ws.name),
        cursor = "pointer",
        rotate = active and -3 or 0,
        on_click = function() mantle.workspaces:focus(ws.id) end,
        children = children,
    }
end

function M.workspaces(output)
    return row {
        spacing = 4,
        align_v = "center",
        children = mantle.workspaces:map(function(w)
            local out = {}
            for _, o in ipairs(w.outputs or {}) do
                if o.name == output then
                    for _, ws in ipairs(o.workspaces) do out[#out + 1] = numeral(ws, ws.id == o.active_workspace) end
                end
            end
            return out
        end, {}),
    }
end

return M
