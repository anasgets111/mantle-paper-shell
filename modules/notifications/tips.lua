-- The shared tooltip note, one per surface this module owns.
local tooltip = require("components.tooltip")

local M = {}

M.POPUPS_ID = "paper-notifications"
M.MENU_ID = "paper-notifications-datemenu"

M.popups = tooltip.new { id = "paper-notifications-tip", parent = M.POPUPS_ID, side = "left" }
M.menu = tooltip.new { id = "paper-notifications-datemenu-tip", parent = M.MENU_ID, side = "top" }

-- Arrival as "Tue 08:42 PM", for a relative age's tooltip.
function M.exact(timestamp)
    return os.date("%a %I:%M %p", timestamp or 0)
end

-- A text node that shows its full content in a tooltip only while `elide` cut it.
function M.elided(tips, node, slot, full)
    local cut = elided(slot .. ".elided")
    node.elided = cut
    return tips.wrap(node, slot, function() return cut:get() and full or "" end)
end

return M
