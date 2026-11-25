-- Keep awake: a blue-pencil sticker left of the privacy stickers while the screen is held awake.
-- A coffee cup for the quick-settings "Keep awake" hold, which a click releases; an open eye when
-- only other apps hold it (a video, a game), named in the tooltip. Nothing shows, and nothing takes
-- space, while nothing holds it.
local theme = require("theme")
local util = require("lib.util")
local controls = require("components.controls")
local idle = require("modules.lock.idle")
local icons = require("modules.taskbar.icons")
local tips = require("modules.taskbar.tips")
local press = require("modules.taskbar.press")

local M = {}

-- One item at most, keyed by mode so a switch between cup and eye stamps the new sticker on.
local mode = computed({ idle.manual, idle.others }, function(manual, others)
    if manual then return "manual" end
    return #others > 0 and "others" or nil
end)
local shown = mode:map(function(m) return m and { { key = m } } or {} end)
local any = mode:map(function(m) return m ~= nil end)

local function tip()
    if idle.manual:get() then return "Keep awake is on \u{00B7} click to let the screen sleep" end
    return "Kept awake by " .. table.concat(idle.others:get() or {}, ", ")
end

local function sticker(output, manual)
    local slot = "taskbar.awake." .. output
    local hovered = hover(slot)
    return tips.wrap(rect {
        -- The loop's ink sits 10 px in from each side, as the privacy stickers' do.
        width = theme.bar.indicator_w,
        height = "fill",
        hover = hovered,
        accessible_name = manual and "Keep awake is on" or "Kept awake by another app",
        cursor = manual and "pointer" or nil,
        on_click = manual and function() idle.set_manual(false) end or nil,
        on_drag = manual and press.track(slot) or nil,
        animate = { exit = { duration = 160, easing = "in_cubic", opacity = 0, translate = { y = -theme.spacing.snug }, scale = 1.1 } },
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
                    controls.pencil_loop(theme.bar.indicator_loop_w, theme.bar.indicator_loop_h, 29),
                    rect {
                        width = theme.bar.indicator_loop_w,
                        height = theme.control.tab,
                        children = {
                            rect {
                                align_h = "center",
                                align_v = "center",
                                children = { icons.doodle(manual and "coffee" or "eye", icons.STATUS, theme.DEEP_BLUE) },
                            },
                        },
                    },
                },
            },
        },
    }, slot, tip)
end

function M.indicator(output)
    return list {
        direction = "horizontal",
        height = "fill",
        -- Held past the hold ending so the exit can play; hidden it takes no gap.
        visible = util.linger(any, 200),
        items = shown,
        key = function(item) return item.key end,
        each = function(item) return sticker(output, item.key == "manual") end,
    }
end

return M
