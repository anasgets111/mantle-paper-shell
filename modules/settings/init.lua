-- Settings modal (GNOME Settings pages): owned by the settings builder. Returns a `components.modal` entry.
local k = require("lib.paper")
local modal = require("components.modal")

return modal {
    kind = "settings",
    card = k.sheet { width = 1000, height = 680, child = k.hand("Settings", 44, { padding = 30 }) },
}
