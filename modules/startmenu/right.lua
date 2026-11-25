-- The right page: who is signed in (initials on a punched disc, no ~/.face here), the XDG places,
-- Settings and Terminal, and the power row at the foot of the page.
local k = require("lib.paper")
local icons = require("modules.startmenu.icons")
local controls = require("components.controls")
local identity = require("lib.identity")
local ui_state = require("lib.ui_state")
local model = require("modules.startmenu.model")
local power = require("modules.startmenu.power")
local tips = require("modules.startmenu.tips")

local M = {}

local W, H = 340, 660
M.WIDTH = W

local HOME = os.getenv("HOME") or ""

local PLACES = {
    { "Home", "", "home" },
    { "Documents", "/Documents", "documents" },
    { "Downloads", "/Downloads", "downloads" },
    { "Pictures", "/Pictures", "pictures" },
    { "Music", "/Music", "music" },
    { "Videos", "/Videos", "videos" },
}

local function terminal()
    local term = os.getenv("TERMINAL")
    -- An exported but empty $TERMINAL is truthy in Lua.
    process.detach((term and term ~= "") and term or "kitty", {})
    model.close()
end

-- A glyph and a label on one ruled line, underlined by highlighter on hover.
local function entry(id, label, glyph, on_click, width)
    local slot = "startmenu.right." .. id
    local hovered = hover(slot)
    local focus = focus_visible(slot .. ".focus")
    local lit = computed({ hovered, focus }, function(h, f) return h or f end)
    return rect {
        width = width,
        height = 40,
        hover = hovered,
        focus_visible = focus,
        focus_ring = false,
        accessible_name = label,
        cursor = "pointer",
        on_click = on_click,
        on_drag = model.track(slot),
        scale = model.sink(slot, 0.97),
        animate = { scale = { duration = 90, easing = "out_cubic" } },
        children = {
            rect {
                width = "fill",
                height = 28,
                align_v = "center",
                margin = { right = 6 },
                background = k.HIGHLIGHT,
                blend = "multiply",
                shape = k.tape_shape(nil, nil, #label),
                opacity = lit:map(function(v) return v and 1 or 0 end),
                animate = { opacity = { duration = 110 } },
            },
            row {
                height = "fill",
                spacing = 10,
                padding = { left = 6 },
                children = { icons.glyph(glyph, 20), k.body(label, 20, { align_v = "center" }) },
            },
        },
    }
end

local function avatar()
    local size = 96
    return rect {
        width = size + 8,
        height = size + 8,
        rotate = -4,
        children = {
            k.sheet {
                width = size,
                height = size,
                shape = k.torn_circle(size, 23, 2.4),
                color = k.STOCK.primary[1],
                fx = { rim = 1.6 },
                child = k.hand(identity.initials, 44, {
                    font_weight = 700, foreground = k.DEEP_BLUE, align_h = "center", align_v = "center",
                    padding = { right = 7, top = 2 },
                }),
            },
            k.tape { width = 58, height = 18, translate = { x = 22, y = -6 }, rotate = 28, seed = 11, align_h = "end" },
        },
    }
end

-- Beside the avatar, the name takes the largest hand from 34 px down to 24 px that fits, worked out
-- from its width at 34 px laid out unseen; a name too long even at 24 px elides and shows whole in
-- the tooltip.
local NAME_W, NAME_MAX, NAME_MIN = W - 170, 34, 24

local function name()
    local slot = "startmenu.name"
    local box, cut = geometry(slot .. ".measure"), elided(slot .. ".cut")
    local size = box:map(function(r)
        if r.width <= NAME_W then return NAME_MAX end
        return math.max(NAME_MIN, math.floor(NAME_MAX * NAME_W / r.width))
    end)
    return tips.wrap(rect {
        children = {
            rect {
                width = 0,
                height = 0,
                opacity = 0,
                hittable = false,
                children = { k.hand(identity.full_name, NAME_MAX, { font_weight = 700, geometry = box }) },
            },
            rect {
                children = size:map(function(px)
                    return {
                        k.hand(identity.full_name, px, {
                            font_weight = 700, elide = "end", max_width = NAME_W, elided = cut,
                        }),
                    }
                end),
            },
        },
    }, slot, function() return cut:get() and identity.full_name:get() or "" end)
end

local function pairs_of(list)
    local rows = {}
    for at = 1, #list, 2 do
        rows[#rows + 1] = row { children = { list[at], list[at + 1] } }
    end
    return column { children = rows }
end

function M.page()
    local half = (W - 56) / 2
    local places = {}
    for i, p in ipairs(PLACES) do
        places[i] = entry("place." .. i, p[1], p[3], function() model.open_uri(HOME .. p[2]) end, half)
    end
    return column {
        width = W,
        height = H,
        padding = { left = 30, right = 26, top = 28, bottom = 22 },
        spacing = 12,
        children = {
            row {
                spacing = 14,
                children = {
                    avatar(),
                    column {
                        align_v = "center",
                        spacing = 0,
                        children = {
                            name(),
                            k.body(identity.account, 16, {
                                foreground = k.INK_SOFT, elide = "end", max_width = NAME_W,
                            }),
                        },
                    },
                },
            },
            k.hand("Places", 28, { font_weight = 700, foreground = k.BLUE, padding = { top = 8, right = 5 } }),
            pairs_of(places),
            rect { padding = { top = 4, bottom = 4 }, children = { controls.divider(W - 60, false, 5) } },
            row {
                children = {
                    entry("settings", "Settings", "settings", function()
                        ui_state.active_modal:set("settings")
                    end, half),
                    entry("terminal", "Terminal", "terminal", terminal, half),
                },
            },
            rect { height = "fill" },
            power.row(),
        },
    }
end

return M
