-- Keyboard layout: the active layout's short code ("EN", "AR") left of the status group, shown
-- only with two or more layouts. Click or wheel cycles; right-click lists them by name. Names and
-- codes come from `lib/layouts.lua`.
local theme = require("theme")
local k = require("lib.paper")
local icons = require("modules.taskbar.icons")
local status = require("modules.taskbar.status")
local menus = require("modules.taskbar.menus")

local M = {}

local kbd = mantle.keyboard
local data = require("lib.layouts")

local multi = kbd:map(function(s) return (s.layout_count or 0) >= 2 end, false)

local code = computed({ kbd, data.shorts }, function(s, map)
    local name = s and s.active_layout or ""
    return map[name] or (name:gsub("[^%a]", ""):sub(1, 2)):upper()
end, "")

local function cycle(step)
    local s = kbd:get()
    if not s or s.layout_count < 2 then return end
    kbd:switch_layout((s.active_layout_index + step) % s.layout_count)
end

function M.widget(output)
    local wheel = 0
    local node = status.button {
        name = "taskbar.layout." .. output,
        label = "Keyboard layout",
        seed = 47,
        -- Lettering carries its own side bearing, so less padding keeps its gaps equal to the doodles'.
        pad = theme.bar.layout_pad,
        on_click = function(r, button)
            if button == "right" then
                menus.open_layouts(r, data.list())
            elseif button ~= "middle" then
                cycle(1)
            end
        end,
        tip = function()
            local name = kbd:get().active_layout
            return name ~= "" and ("Keyboard: " .. name) or "Keyboard layout"
        end,
        -- Caveat's capitals at this size stand as tall as the status doodles' ink.
        children = { k.hand(code, icons.STATUS + theme.bar.layout_label_extra, { font_weight = theme.BOLD, align_v = "center" }) },
    }
    node.visible = multi
    -- One layout per notch; up goes back, as on the workspace numerals.
    node.on_wheel = function(_, steps)
        wheel = wheel + steps
        if math.abs(wheel) < 1 then return end
        cycle(wheel > 0 and -1 or 1)
        wheel = 0
    end
    return node
end

return M
