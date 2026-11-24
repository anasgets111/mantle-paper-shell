-- Tooltips: one small taped sticky note per parent surface, shared by every hover target on it.
-- Shows after 500 ms of hover; moving straight to a neighbour swaps it instantly; a click hides it.
--
--   local tips = require("components.tooltip").new { id = "paper-taskbar-tip", parent = "paper-taskbar", side = "top" }
--   surfaces: add `tips.surface` to your module's surface list
--   node = tips.wrap(node, "taskbar.start", "Start menu")      -- text: string | signal | function() -> string
--
-- `wrap` reuses the node's own `hover` signal when it has one (pass its hover name as `slot`), or
-- binds `hover(slot)` itself. It sets `on_hover` and wraps `on_click`, so don't set those after.
-- Where: icon-only controls, live values (battery %, volume), elided text, pinned-but-closed
-- taskbar icons, the clock. Not on labelled buttons, menu rows, running taskbar icons (the window
-- preview is their tooltip) or the lock screen (a lock can't parent a popup).
local k = require("lib.paper")

local M = {}

local SHOW_MS, HIDE_MS = 500, 120
local NONE = { x = 0, y = 0, width = 1, height = 1 }

-- side: where the note hangs from the target: "top" (above, for the bottom taskbar), "bottom", "left", "right".
function M.new(o)
    local side = o.side or "top"
    local current = state(o.id .. ".slot", "")
    local visible = state(o.id .. ".visible", false)
    local texts = {}
    local show_timer, hide_timer

    local function cancel(t) if t then t:cancel() end end

    local function enter(slot)
        cancel(hide_timer); hide_timer = nil
        if visible:get() then
            current:set(slot)
            return
        end
        cancel(show_timer)
        current:set(slot)
        show_timer = timer(SHOW_MS, function()
            show_timer = nil
            if current:get() == slot then visible:set(true) end
        end)
    end

    local function leave(slot)
        if current:get() ~= slot then return end
        cancel(show_timer); show_timer = nil
        cancel(hide_timer)
        hide_timer = timer(HIDE_MS, function()
            hide_timer = nil
            visible:set(false)
            current:set("")
        end)
    end

    local tips = {}

    function tips.hide()
        cancel(show_timer); show_timer = nil
        visible:set(false)
    end

    function tips.wrap(node, slot, text)
        texts[slot] = text
        node.hover = node.hover or hover(slot)
        node.on_hover = function(on)
            if on then enter(slot) else leave(slot) end
        end
        local click = node.on_click
        if click then
            node.on_click = function(...)
                tips.hide()
                return click(...)
            end
        end
        return node
    end

    local function resolve(slot)
        local t = texts[slot]
        if type(t) == "function" then t = t() end
        if type(t) == "userdata" then t = t:get() end
        return t ~= nil and tostring(t) or ""
    end

    local anchor = ({ top = "top", bottom = "bottom", left = "left", right = "right" })[side]
    local gap = 6

    tips.surface = popup {
        id = o.id,
        parent = o.parent,
        grab = false,
        visible = computed({ visible, current }, function(v, slot) return v and slot ~= "" and resolve(slot) ~= "" end),
        anchor_rect = current:map(function(slot)
            if slot == "" then return NONE end
            local r = hover_rect(slot):get()
            return (r and r.width > 0) and r or NONE
        end),
        anchor = anchor,
        gravity = anchor,
        constraint_adjustment = { "flip_x", "flip_y", "slide_x", "slide_y" },
        offset = ({ top = { y = -gap }, bottom = { y = gap }, left = { x = -gap }, right = { x = gap } })[side],
        -- The clock ticks once a second, so live values (battery, time) stay current while shown.
        child = computed({ current, mantle.clock }, function(slot)
            return rect {
                padding = { top = 12, left = 12, right = 14, bottom = 16 },
                children = {
                    rect {
                        rotate = 1.5,
                        background = k.STICKY,
                        padding = { top = 7, bottom = 6, left = 11, right = 11 },
                        shadows = { { blur = 6, offset = { x = 1, y = 3 }, color = "#00000050" } },
                        effect = k.paper_fx { rim = 0, grain = 0.16 },
                        children = {
                            k.body(resolve(slot), 17),
                        },
                    },
                    k.tape { width = 34, height = 12, translate = { y = -7 }, rotate = -4, seed = #slot },
                },
            }
        end),
    }

    return tips
end

return M
