-- While recording: a red marker loop on the taskbar round a dot and the elapsed time. A click stops,
-- a right click pauses or resumes. Nothing shows, and nothing takes space, while idle.
local k = require("lib.paper")
local util = require("lib.util")
local controls = require("components.controls")
local tips = require("modules.taskbar.tips")
local press = require("modules.taskbar.press")
local svc = require("modules.recorder.service")
local marks = require("modules.recorder.marks")

local M = {}

local H = 36
local shown = svc.recording:map(function(up) return up and { { key = "rec" } } or {} end, {})

local function tip()
    local verb = svc.paused:get() and "Paused at " or "Recording "
    local undo = svc.paused:get() and "resume" or "pause"
    return string.format("%s%s \u{00B7} click to stop, right-click to %s", verb, svc.elapsed:get(), undo)
end

-- The loop fits the time: "0:42" and "1:02:03" draw different widths. Rebuilt only when the
-- character count changes, once a minute at most.
local function loop(width)
    local node = controls.pencil_loop(width, H, 47)
    node.stroke = k.RED
    return node
end

local function sticker(output)
    local slot = "recorder.sticker." .. output
    local hovered = hover(slot)
    local width = svc.elapsed:map(function(t) return 40 + #t * 10 end, 80)
    return tips.wrap(rect {
        height = "fill",
        padding = { left = 4, right = 4 },
        hover = hovered,
        accessible_name = "Stop recording",
        cursor = "pointer",
        on_click = function(_, button)
            if button == "right" then svc.toggle_pause() elseif button == "left" then svc.stop() end
        end,
        on_drag = press.track(slot),
        animate = { exit = { duration = 160, easing = "in_cubic", opacity = 0, translate = { y = -10 }, scale = 1.1 } },
        children = {
            rect {
                align_v = "center",
                rotate = hovered:map(function(v) return v and 2 or -2 end),
                translate = hovered:map(function(v) return { y = v and -2 or 0 } end),
                scale = press.scale(slot),
                animate = {
                    scale = { spring = { stiffness = 520, damping = 20 }, from = 1.3 },
                    rotate = { spring = { stiffness = 420, damping = 18 }, from = 12 },
                    translate = { duration = 140, easing = "out_cubic" },
                },
                children = {
                    rect { children = width:map(function(w) return { loop(w) } end) },
                    row {
                        height = H,
                        padding = { left = 14 },
                        spacing = 7,
                        children = {
                            rect { align_v = "center", children = marks.state(svc.paused, 13) },
                            k.hand(svc.elapsed, 24, {
                                font_weight = 700, align_v = "center",
                                foreground = util.choose(svc.paused, k.INK_SOFT, k.DEEP_RED),
                            }),
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
        -- Held past the stop so the exit can play; hidden it takes no gap.
        visible = util.linger(svc.recording, 200),
        items = shown,
        key = function(item) return item.key end,
        each = function() return sticker(output) end,
    }
end

return M
