-- One modal card and its motion, for `modules/modal_host.lua` to stack under one catcher.
-- The card slides up 12 px and fades in, out_cubic in and in_cubic out, like a sheet laid down.
--
-- opts = { kind, card, align_h?, align_v?, margin? }
local ui_state = require("lib.ui_state")
local util = require("lib.util")

local MS = 180

-- The host's outside catcher is every card's ancestor, so a press on the card's own ground walks
-- up to it and closes the modal. A handled box the size of the card ends that walk.
local function swallow_presses(card, opts)
    return rect {
        on_click = function() end,
        cursor = "default",
        align_h = opts.align_h or "center",
        align_v = opts.align_v or "center",
        children = { card },
    }
end

return function(opts)
    local showing = ui_state.modal_showing(opts.kind)
    local box = swallow_presses(opts.card, opts)
    box.opacity = util.choose(showing, 1, 0)
    box.translate = showing:map(function(open) return { y = open and 0 or 12 } end)
    box.animate = showing:map(function(open)
        local easing = open and "out_cubic" or "in_cubic"
        return {
            opacity = { duration = MS, easing = easing, from = 0 },
            translate = { duration = MS, easing = easing, from = { y = 12 } },
        }
    end)
    return {
        kind = opts.kind,
        ms = MS,
        node = rect {
            id = opts.kind,
            width = "fill",
            height = "fill",
            padding = opts.margin or 0,
            children = { box },
        },
        reset_on_close = opts.reset_on_close or {},
    }
end
