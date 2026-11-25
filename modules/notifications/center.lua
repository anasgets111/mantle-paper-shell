-- The date menu (GNOME's clock menu), hung above the taskbar clock: the history notepad on the left;
-- today's date, the month and the now-playing card on the right.
local theme = require("theme")
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local st = require("modules.notifications.state")
local history = require("modules.notifications.history")
local notepad = require("modules.notifications.notepad")
local calendar = require("modules.notifications.calendar")
local media = require("modules.notifications.media")
local tips = require("modules.notifications.tips")
local catcher = require("components.catcher")

local M = {}

local MS = 180

-- Unix time the menu opened: sections and ages read it, so they hold still while it is open.
local opened_at = state("notifications.opened_at", 0)
-- A click opens the grab popup, so an outside click closes it; a keybind has no press to grab with
-- and opens the keyboard catcher instead.
local grab = state("notifications.center_grab", true)
-- The compositor closed it: hidden at once, since a popup still `visible` through the exit fade would
-- reopen on the next press.
local dismissed = state("notifications.center_dismissed", false)
local function open(rect, with_grab)
    if ui_state.panel_is("datemenu") then
        ui_state.close_panel()
        return
    end
    grab:set(with_grab)
    dismissed:set(false)
    opened_at:set(os.time())
    calendar.offset:set(0)
    st.mark_all_seen()
    history.mark_opened()
    ui_state.open_panel("datemenu", rect)
end

function M.open(rect)
    open(rect, true)
end

-- `mantle call notifications.toggle_center`, for a keybind: anchors where the clock was last clicked,
-- or the right end of the first output's taskbar before any click.
action("notifications.toggle_center", function()
    local rect = ui_state.popup_anchor:get()
    if rect.x == 0 then
        local screen = mantle.screens:get()[1]
        rect = { x = (screen and screen.width or 1920) - theme.notifications.anchor_inset, y = theme.spacing.md, width = theme.notifications.anchor_w, height = theme.control.md }
    end
    open(rect, false)
end)

local showing = st.center_open

-- Built per surface: a node belongs to one.
local function menu()
    return column {
        padding = { top = theme.spacing.roomy, left = theme.spacing.roomy, right = theme.spacing.tab, bottom = theme.spacing.page },
        opacity = util.choose(showing, 1, 0),
        translate = showing:map(function(open_now) return { y = open_now and 0 or theme.spacing.md } end),
        animate = {
            opacity = { duration = MS, easing = "out_cubic", from = 0 },
            translate = { duration = MS, easing = "out_cubic", from = { y = theme.spacing.md } },
        },
        children = {
            row {
                spacing = theme.spacing.roomy,
                children = {
                    notepad.page(opened_at),
                    column {
                        spacing = theme.spacing.inset,
                        padding = { top = theme.spacing.xxs },
                        children = { calendar.card(opened_at), media.card() },
                    },
                },
            },
        },
    }
end

M.popup = popup {
    id = tips.MENU_ID,
    parent = "paper-taskbar",
    anchor_rect = ui_state.popup_anchor,
    anchor = "top",
    gravity = "top",
    offset = { y = theme.spacing.xxs },
    constraint_adjustment = { "slide_x", "flip_y" },
    grab = true,
    reset_on_close = { notepad.scroll },
    visible = computed({ util.linger(showing, MS), dismissed, grab }, function(v, gone, g)
        return v and g and not gone
    end),
    on_dismiss = function()
        dismissed:set(true)
        if ui_state.panel_is("datemenu") then ui_state.close_panel() end
    end,
    on_escape = function() ui_state.close_panel() end,
    child = menu(),
}

-- The keybind path: no press to grab with, so the same menu on a keyboard catcher.
M.keyboard_surface = catcher {
    id = "paper-notifications-datemenu-keys",
    visible = computed({ showing, grab }, function(v, g) return v and not g end),
    close = function() ui_state.close_panel() end,
    reset_on_close = { notepad.scroll },
    card = menu,
}

return M
