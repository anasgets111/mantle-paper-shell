-- The notebook's tooltips: one sticky note on the modal host, shared by every page.
local tooltip = require("components.tooltip")

return tooltip.new { id = "settings-tip", parent = "paper-modal-host", side = "top" }
