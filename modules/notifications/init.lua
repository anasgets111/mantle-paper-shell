-- Notification popups and the date menu (calendar + notification history): owned by the
-- notifications builder. Interface the taskbar relies on, keep it:
--   surfaces           list of surfaces/popups to add to the shell
--   open_center(rect)  toggle the date menu anchored to the clicked clock (rect in the taskbar surface)
--   unread             signal: number of unread notifications (taskbar badge), by app in `unread_by_app`
--   unread_by_app      signal: { [desktop_entry or app_name] = count }
local M = {}
M.surfaces = {}
M.unread = state("notifications.unread", 0)
M.unread_by_app = state("notifications.unread_by_app", {})
function M.open_center(_) end
return M
