-- The taskbar's one tooltip note, shared by every hover target on the panel.
local tooltip = require("components.tooltip")

return tooltip.new { id = "paper-taskbar-tip", parent = "paper-taskbar", side = "top" }
