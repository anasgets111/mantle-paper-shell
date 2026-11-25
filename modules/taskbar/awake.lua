-- Keep awake: a blue-pencil coffee cup left of the privacy stickers while the quick-settings
-- "Keep awake" hold is on. A click lets the screen sleep again. Nothing shows, and nothing takes
-- space, while the hold is off.
local k = require("lib.paper")
local util = require("lib.util")
local controls = require("components.controls")
local idle = require("modules.lock.idle")
local icons = require("modules.taskbar.icons")
local tips = require("modules.taskbar.tips")
local press = require("modules.taskbar.press")

local M = {}

local shown = idle.manual:map(function(on) return on and { { key = "awake" } } or {} end)

local function sticker(output)
    local slot = "taskbar.awake." .. output
    local hovered = hover(slot)
    return tips.wrap(rect {
        -- The loop's ink sits 10 px in from each side, as the privacy stickers' do.
        width = 56,
        height = "fill",
        hover = hovered,
        accessible_name = "Keep awake is on",
        cursor = "pointer",
        on_click = function() idle.set_manual(false) end,
        on_drag = press.track(slot),
        animate = { exit = { duration = 160, easing = "in_cubic", opacity = 0, translate = { y = -10 }, scale = 1.1 } },
        children = {
            rect {
                align_h = "center",
                align_v = "center",
                rotate = hovered:map(function(v) return v and 3 or -3 end),
                translate = hovered:map(function(v) return { y = v and -2 or 0 } end),
                scale = press.scale(slot),
                animate = {
                    scale = { spring = { stiffness = 520, damping = 20 }, from = 1.3 },
                    rotate = { spring = { stiffness = 420, damping = 18 }, from = 14 },
                    translate = { duration = 140, easing = "out_cubic" },
                },
                children = {
                    controls.pencil_loop(38, 36, 29),
                    rect {
                        width = 38,
                        height = 36,
                        children = {
                            rect {
                                align_h = "center",
                                align_v = "center",
                                children = { icons.doodle("coffee", icons.STATUS, k.DEEP_BLUE) },
                            },
                        },
                    },
                },
            },
        },
    }, slot, function() return "Keep awake is on \u{00B7} click to let the screen sleep" end)
end

function M.indicator(output)
    return list {
        direction = "horizontal",
        height = "fill",
        -- Held past the hold ending so the exit can play; hidden it takes no gap.
        visible = util.linger(idle.manual, 200),
        items = shown,
        key = function(item) return item.key end,
        each = function() return sticker(output) end,
    }
end

return M
