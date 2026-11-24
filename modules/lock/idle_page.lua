-- The idle settings page body (timers, profiles, inhibit): owned by the lock builder, shown by the
-- settings builder on its Power page. Returns a function building the page's node.
local k = require("lib.paper")
return function()
    return k.body("Idle settings: coming soon", 21, { foreground = k.INK_SOFT })
end
