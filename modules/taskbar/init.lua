-- Taskbar (Dash to Panel): owned by the taskbar builder. Returns { surfaces = { panel, popups... } }.
local k = require("lib.paper")
local ui_state = require("lib.ui_state")

local bar = panel {
    id = "paper-taskbar",
    layer = "top",
    anchor = { bottom = true, left = true, right = true },
    width = "fill",
    height = 64,
    exclusive_zone = 52,
    child = k.sheet {
        width = "fill",
        height = 52,
        shape = k.torn_top(52, 12),
        fx = { rim = 2.2 },
        child = row {
            align_v = "center",
            padding = { left = 16 },
            children = {
                rect {
                    on_click = function() ui_state.toggle_modal("startmenu") end,
                    children = { k.hand("menu", 28, { font_weight = 700 }) },
                },
            },
        },
    },
}

return { surfaces = { bar } }
