-- Paper shell: a desk of torn paper, pencil, marker, highlighter and washi tape, laid out like
-- GNOME with Dash to Panel and ArcMenu. Run with ./run.sh so fontconfig sees the bundled fonts.
--
-- lib/        node-free logic and the paper kit (lib/paper.lua)
-- components/ stateless paper widgets (controls, menu, modal)
-- modules/    surfaces: desktop, taskbar, startmenu, settings, notifications, osd, quick, lock, updates
--
-- Bind every `require` to a local: in a table constructor it expands its second return value.
-- Read once at startup: a change here needs a shell restart. `k.body` names Kalam itself.
fonts { "Kalam", "Noto Sans", "Noto Color Emoji" }

local desktop = require("modules.desktop")
local taskbar = require("modules.taskbar")
local modal_host = require("modules.modal_host")
local notifications = require("modules.notifications")
local osd = require("modules.osd")
local lock = require("modules.lock")
local quick = require("modules.quick")
-- Also a modal_host entry; listed here for its right-click popups.
local startmenu = require("modules.startmenu")
-- Also a modal_host entry; listed here for its tooltip popup.
local settings = require("modules.settings")
-- Its widget lives in the taskbar; listed here for its popups.
local updates = require("modules.updates")

local surfaces = { desktop.wallpaper, desktop.cards, modal_host }
for _, group in ipairs({ taskbar, notifications, osd, quick, lock, startmenu, settings, updates }) do
    table.move(group.surfaces, 1, #group.surfaces, #surfaces + 1, surfaces)
end

return surfaces
