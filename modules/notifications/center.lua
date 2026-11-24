-- The date menu (GNOME's clock menu), hung above the taskbar clock: the history notepad on the left;
-- today's date, the month and the now-playing card on the right.
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local st = require("modules.notifications.state")
local history = require("modules.notifications.history")
local notepad = require("modules.notifications.notepad")
local calendar = require("modules.notifications.calendar")
local media = require("modules.notifications.media")
local tips = require("modules.notifications.tips")

local M = {}

local MS = 180

-- Unix time the menu opened: sections and ages read it, so they hold still while it is open.
local opened_at = state("notifications.opened_at", 0)
-- A click opens it with a grab, so an outside click closes it; a keybind has no press to grab with.
local grab = state("notifications.center_grab", true)
-- The compositor closed it: hidden at once, since a popup still `visible` through the exit fade would
-- reopen on the next press.
local dismissed = state("notifications.center_dismissed", false)
-- A click on the clock while the menu is open first dismisses it (the press lands outside the grab),
-- then arrives as a click: that click must not reopen it.
local dismissed_at = -1

local function open(rect, with_grab)
    if with_grab and mantle.clock:now() - dismissed_at < 0.5 then return end
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
        rect = { x = (screen and screen.width or 1920) - 140, y = 12, width = 120, height = 40 }
    end
    open(rect, false)
end)

local showing = st.center_open

local menu = column {
    padding = { top = 18, left = 18, right = 26, bottom = 30 },
    opacity = util.choose(showing, 1, 0),
    translate = showing:map(function(open_now) return { y = open_now and 0 or 12 } end),
    animate = {
        opacity = { duration = MS, easing = "out_cubic", from = 0 },
        translate = { duration = MS, easing = "out_cubic", from = { y = 12 } },
    },
    children = {
        row {
            spacing = 18,
            children = {
                notepad.page(opened_at),
                column {
                    spacing = 14,
                    padding = { top = 4 },
                    children = { calendar.card(opened_at), media.card() },
                },
            },
        },
    },
}

M.popup = popup {
    id = tips.MENU_ID,
    parent = "paper-taskbar",
    anchor_rect = ui_state.popup_anchor,
    anchor = "top",
    gravity = "top",
    offset = { y = 4 },
    constraint_adjustment = { "slide_x", "flip_y" },
    grab = grab,
    reset_on_close = { notepad.scroll },
    visible = computed({ util.linger(showing, MS), dismissed }, function(v, gone) return v and not gone end),
    on_dismiss = function()
        dismissed_at = mantle.clock:now()
        dismissed:set(true)
        if ui_state.panel_is("datemenu") then ui_state.close_panel() end
    end,
    on_escape = function() ui_state.close_panel() end,
    child = menu,
}

return M
