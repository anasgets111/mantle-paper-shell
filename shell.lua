-- Paper shell: a desk of torn paper, pencil, marker, highlighter and washi tape, laid out like
-- GNOME with Dash to Panel and ArcMenu. Run with ./run.sh so fontconfig sees the bundled fonts.
--
-- lib/        node-free logic and the paper kit (lib/paper.lua)
-- components/ stateless paper widgets (controls, menu, modal)
-- modules/    surfaces: desktop, taskbar, startmenu, settings, notifications, osd, quick, lock
--
-- Bind every `require` to a local: in a table constructor it expands its second return value.
fonts { "Patrick Hand", "Noto Sans", "Noto Color Emoji" }

local desktop = require("modules.desktop")
local taskbar = require("modules.taskbar")
local modal_host = require("modules.modal_host")
local notifications = require("modules.notifications")
local osd = require("modules.osd")
local lock = require("modules.lock")
local quick = require("modules.quick")

local surfaces = { desktop.wallpaper, desktop.cards, modal_host }
for _, group in ipairs({ taskbar, notifications, osd, quick, lock }) do
    table.move(group.surfaces, 1, #group.surfaces, #surfaces + 1, surfaces)
end

return surfaces
