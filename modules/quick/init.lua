-- Quick settings (GNOME system menu): owned by the OSD/quick builder. Interface the taskbar relies on:
--   surfaces      list of popups to add to the shell
--   open(rect)    toggle the quick-settings popup anchored to the clicked status icons
local M = {}
M.surfaces = {}
function M.open(_) end
return M
