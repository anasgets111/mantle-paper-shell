-- Start menu (ArcMenu): owned by the start-menu builder. Returns a `components.modal` entry.
local k = require("lib.paper")
local modal = require("components.modal")

return modal {
    kind = "startmenu",
    scrim = false,
    align_h = "start",
    align_v = "end",
    margin = { left = 12, bottom = 64 },
    card = k.sheet { width = 640, height = 560, child = k.hand("Start menu", 40, { padding = 30 }) },
}
