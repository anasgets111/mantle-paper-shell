-- Start menu (ArcMenu's default layout) as an open notebook: apps and search on the left page,
-- the user, places and power on the right, index tabs down the left edge. Returns a
-- `components.modal` entry plus `surfaces` for its right-click note and tooltip.
local theme = require("theme")
local k = require("lib.paper")
local controls = require("components.controls")
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local modal = require("components.modal")
local model = require("modules.startmenu.model")
local context = require("modules.startmenu.context")
local tips = require("modules.startmenu.tips")
local power = require("modules.startmenu.power")
local tabs = require("modules.startmenu.tabs")
local left = require("modules.startmenu.left")
local right = require("modules.startmenu.right")

local H = left.HEIGHT
local BOOK_W = left.WIDTH + right.WIDTH
-- Rules line up with the 40 px rows that start under the page title.
local RULES = { top = theme.startmenu.rule_top, pitch = theme.startmenu.rule_pitch }

-- The gutter: the fold darkens toward the middle, a pencil-thin crease at its centre.
local function spine()
    return rect {
        width = theme.startmenu.spine_w,
        height = H - theme.startmenu.spine_tall_extra,
        translate = { x = left.WIDTH - theme.spacing.xxxl, y = theme.spacing.xs },
        background = { gradient = "linear", angle = 90, stops = {
            { 0, "#00000000" }, { 0.42, theme.PHOTO_WASH }, { 0.5, theme.PHOTO_EDGE }, { 0.58, theme.PHOTO_WASH }, { 1, "#00000000" },
        } },
        blend = "multiply",
        children = {
            rect { width = 1, height = "fill", translate = { x = theme.startmenu.spine_seam_x }, background = theme.INK_FAINT },
        },
    }
end

local function book()
    local left_rules = controls.ruled(left.WIDTH - theme.startmenu.rule_left_inset, H, { top = RULES.top, pitch = RULES.pitch, margin = theme.startmenu.rule_left_margin })
    local right_rules = controls.ruled(right.WIDTH - theme.startmenu.rule_right_inset, H, { top = RULES.top, pitch = RULES.pitch, margin = false })
    return k.sheet {
        width = BOOK_W,
        height = H,
        seed = 41,
        depth = theme.paper.bar_tear,
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
    align_h = "start",
    align_v = "end",
    -- The host already ends at the taskbar; 20 px holds the sheet's shadow.
    margin = { left = theme.spacing.md, bottom = theme.spacing.xl },
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
                spacing = -tabs.OVERLAP,
                children = { tabs.column(), rect { z = 1, children = { book() } } },
            },
            tabs.bridge(),
        },
    },
}

entry.surfaces = util.concat(context.surfaces, { tips.surface })
-- The note belongs to the open menu.
ui_state.on_modal_close(model.KIND, context.close)

return entry
