-- Notification popups and the date menu (calendar + notification history): owned by the
-- notifications builder. Interface the taskbar relies on, keep it:
--   surfaces           list of surfaces/popups to add to the shell
--   open_center(rect)  toggle the date menu anchored to the clicked clock (rect in the taskbar surface);
--                      call it from `on_click`, whose press the popup's grab needs
--   unread             signal: notifications that arrived since the date menu last opened
--   unread_by_app      signal: { [desktop_entry as sent, else app_name] = count }; desktop ids keep the
--                      sender's case, so compare folded
-- Keybind: `mantle call notifications.toggle_center` opens the date menu without a grab.
local history = require("modules.notifications.history")
local popups = require("modules.notifications.popups")
local center = require("modules.notifications.center")
local tips = require("modules.notifications.tips")

local M = {}
local card = require("modules.notifications.card")

M.surfaces = { popups, tips.popups.surface, center.popup, center.keyboard_surface, tips.menu.surface }
table.move(card.menu_surfaces, 1, #card.menu_surfaces, #M.surfaces + 1, M.surfaces)
M.unread = history.unread
M.unread_by_app = history.unread_by_app
M.open_center = center.open
return M
