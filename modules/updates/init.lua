-- The updater: a taskbar widget, a ledger popup and the settings "Updates" page over
-- `mantle.updates`. Interface for the taskbar and settings builders:
--   surfaces        popups to add to the shell's surface list
--   widget(output)  a taskbar node; shown only when updates are pending, installing, failed or a
--                   restart is due, and taking no space otherwise
--   open(rect)      toggle the popup anchored to `rect` (in the taskbar surface, from `on_click`)
--   page()          the settings page body: a list of ruled rows for the notebook's `build`
-- `mantle call updates.toggle` opens the popup without a click. Testing: `mantle set updates.fake`
-- (see service.lua) fakes any state for the views; install and restart refuse while it is set.
local k = require("lib.paper")
local icons = require("components.icons")
local tooltip = require("components.tooltip")
local ui_state = require("lib.ui_state")
local S = require("modules.updates.service")
local G = require("modules.updates.glyphs")
local bar_icons = require("modules.taskbar.icons")
local popup = require("modules.updates.popup")
local page = require("modules.updates.page")

local M = {}

local tips = tooltip.new { id = "paper-updates-widget-tip", parent = popup.PARENT, side = "top" }

-- The settings notebook's open page (modules/settings); its Updates page takes the key "updates".
local settings_page = state("settings.page", "wifi")

local glyph = S.look:map(function(l) return l.glyph end)
local fraction = S.progress:map(function(p) return p.total > 0 and p.done / p.total or 0 end)
local spinning = S.progress:map(function(p) return p.count == "" end)

-- A mark pinned to the doodle's top-right corner.
local function corner(node, x)
    return rect { align_h = "end", align_v = "start", translate = { x = x, y = -4 }, children = { node } }
end

-- The taskbar's status glyph size, so the package sits level with Wi-Fi and volume.
local SIZE = bar_icons.STATUS

local function face(name)
    if name == "installing" then
        return {
            G.ring(SIZE + 12, fraction, spinning),
            rect { align_h = "center", align_v = "center", children = { G.package(SIZE * 0.75) } },
        }
    elseif name == "restart" then
        return { rect { align_h = "center", align_v = "center", children = { icons.doodle("restart", SIZE, k.RED) } } }
    end
    local failed = name == "failed" or name == "warning"
    return {
        rect { align_h = "center", align_v = "center", children = { G.package(SIZE) } },
        failed and corner(G.exclamation(16), 0) or corner(G.badge(S.count), 8),
    }
end

local function tip_text()
    local look = S.look:get()
    if look.detail == "" then return look.title end
    return look.title .. " · " .. look.detail
end

function M.widget(output)
    local slot = "updates.widget." .. output
    local hovered = hover(slot)
    return tips.wrap(rect {
        height = "fill",
        visible = S.shown,
        hover = hovered,
        accessible_name = "Updates",
        cursor = "pointer",
        -- Left opens the popup, middle checks now, right opens the settings page.
        on_click = function(r, button)
            if button == "middle" then
                S.check()
            elseif button == "right" then
                settings_page:set("updates")
                ui_state.active_modal:set("settings")
            else
                popup.open(r)
            end
        end,
        children = {
            rect {
                width = "fill",
                height = 30,
                align_v = "center",
                background = k.HIGHLIGHT,
                blend = "multiply",
                shape = k.tape_shape(nil, nil, 17),
                opacity = hovered:map(function(v) return v and 1 or 0 end),
                animate = { opacity = { duration = 120 } },
            },
            rect {
                padding = { left = 10, right = 14 },
                align_v = "center",
                translate = hovered:map(function(v) return { y = v and -2 or 0 } end),
                animate = { translate = { duration = 140, easing = "out_cubic" } },
                children = { rect { width = SIZE + 12, height = SIZE + 12, children = glyph:map(face) } },
            },
        },
    }, slot, tip_text)
end

M.open = popup.open
M.page = page
M.surfaces = { popup.surface, popup.tips.surface, tips.surface }

return M
