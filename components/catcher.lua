-- A card opened from a keybind, on a clear full-output layer that takes the keyboard. A grab popup
-- needs a click to grab from, so a keybind-opened one never closed on an outside click and never got
-- Escape; here a click off the card closes it, and Escape and Tab reach it.
-- o = { id, visible = signal, close = fn, card = fn() -> node, bottom? = px above the output's foot,
--       reset_on_close? }
-- ponytail: the card sits at the active output's bottom-right, not under its opener, and tooltips
-- parented to the click path's popup don't show here. Upgrade: a popup `parent` that can change.
local theme = require("theme")
return function(o)
    return panel {
        id = o.id,
        -- Not `mantle-*`: the desktop's Hyprland rules frost that namespace, and paper is opaque.
        namespace = o.id,
        output = "active",
        layer = "overlay",
        anchor = { top = true, bottom = true, left = true, right = true },
        width = "fill",
        height = "fill",
        exclusive_zone = "ignore",
        keyboard_interactivity = "exclusive",
        visible = o.visible,
        on_escape = o.close,
        reset_on_close = o.reset_on_close,
        child = rect {
            width = "fill",
            height = "fill",
            cursor = "default",
            on_click = o.close,
            children = {
                rect {
                    align_h = "end",
                    align_v = "end",
                    padding = { right = theme.spacing.sm, bottom = o.bottom or theme.catcher.bottom_pad },
                    -- Clicks on the card's bare paper stop here instead of closing it.
                    children = { rect { cursor = "default", on_click = function() end, children = { o.card() } } },
                },
            },
        },
    }
end
