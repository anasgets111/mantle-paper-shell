-- The start menu's one tooltip note (components/tooltip.lua), shared by the power stubs and
-- elided names. Hangs above its target: the menu sits on the bottom edge.
local tooltip = require("components.tooltip")

return tooltip.new { id = "paper-startmenu-tip", parent = "paper-modal-host", side = "top" }
