-- Start menu (ArcMenu's default layout) as an open notebook: apps and search on the left page,
-- the user, places and power on the right, index tabs down the left edge. Returns a
-- `components.modal` entry plus `surfaces` for its right-click note.
local k = require("lib.paper")
local controls = require("components.controls")
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local modal = require("components.modal")
local model = require("modules.startmenu.model")
local context = require("modules.startmenu.context")
local power = require("modules.startmenu.power")
local tabs = require("modules.startmenu.tabs")
local left = require("modules.startmenu.left")
local right = require("modules.startmenu.right")

local H = left.HEIGHT
local BOOK_W = left.WIDTH + right.WIDTH
-- Tabs reach this far under the left page.
local OVERLAP = 22
-- Rules line up with the 40 px rows that start under the page title.
local RULES = { top = 172, pitch = 40 }

-- The gutter: the fold darkens toward the middle, a pencil-thin crease at its centre.
local function spine()
    return rect {
        width = 64,
        height = H - 12,
        translate = { x = left.WIDTH - 32, y = 6 },
        background = { gradient = "linear", angle = 90, stops = {
            { 0, "#00000000" }, { 0.42, "#2A20150F" }, { 0.5, "#2A201530" }, { 0.58, "#2A20150F" }, { 1, "#00000000" },
        } },
        blend = "multiply",
        children = {
            rect { width = 1, height = "fill", translate = { x = 31.5 }, background = "#3A363140" },
        },
    }
end

local function book()
    local left_rules = controls.ruled(left.WIDTH - 6, H, { top = RULES.top, pitch = RULES.pitch, margin = 54 })
    local right_rules = controls.ruled(right.WIDTH - 10, H, { top = RULES.top, pitch = RULES.pitch, margin = false })
    return k.sheet {
        width = BOOK_W,
        height = H,
        seed = 41,
        depth = 5,
        fx = { rim = 2.2 },
        child = rect {
            width = "fill",
            height = "fill",
            children = {
                rect { translate = { x = 4 }, children = left_rules },
                rect { translate = { x = left.WIDTH + 4 }, children = right_rules },
                spine(),
                row { children = { left.page(), right.page() } },
            },
        },
    }
end

local entry = modal {
    kind = model.KIND,
    scrim = false,
    align_h = "start",
    align_v = "end",
    margin = { left = 12, bottom = 64 },
    reset_on_close = util.concat(model.reset, power.reset),
    card = rect {
        -- A click on bare paper cancels an armed power action.
        on_click = function() power.disarm() end,
        cursor = "default",
        -- Laid down from the start button's corner: it lands a little turned and settles flat,
        -- under the host's slide and fade. The card is rebuilt per open, so `from` runs each time.
        origin = { x = 0, y = 1 },
        rotate = 0,
        scale = { x = 1, y = 1 },
        animate = {
            rotate = { duration = 260, easing = "out_cubic", from = -1.6 },
            scale = { duration = 220, easing = "out_cubic", from = { x = 0.985, y = 0.985 } },
        },
        children = {
            row {
                spacing = -OVERLAP,
                children = { tabs.column(), rect { z = 1, children = { book() } } },
            },
        },
    },
}

entry.surfaces = context.surfaces
-- The note belongs to the open menu.
ui_state.on_modal_close(model.KIND, context.close)

return entry
