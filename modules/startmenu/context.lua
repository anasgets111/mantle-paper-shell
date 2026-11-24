-- The right-click sticky note on an app: open it, pin or unpin it on the taskbar and in the menu.
local apps = require("lib.apps")
local menu = require("components.menu")
local model = require("modules.startmenu.model")
local icons = require("modules.startmenu.icons")
local power = require("modules.startmenu.power")

local note = menu.new { id = "paper-startmenu-menu", parent = "paper-modal-host" }

local M = { surfaces = note.surfaces, close = note.close }

-- `rect`: a surface-local box to hang the note from (the pointer, from `on_click`).
function M.open(rect, app)
    power.disarm()
    local id = app.id
    local function item(label, role, fn) return { label = label, icon = icons.name(role), on_click = fn } end
    note.open(rect, {
        item("Open", "open", function() model.launch(id) end),
        { separator = true },
        apps.is_pinned(id) and item("Unpin from taskbar", "pin", function() apps.unpin(id) end)
            or item("Pin to taskbar", "pin", function() apps.pin(id) end),
        apps.is_menu_pinned(id) and item("Unpin from menu", "menu_unpin", function() apps.menu_unpin(id) end)
            or item("Pin to menu", "menu_pin", function() apps.menu_pin(id) end),
    }, { anchor = "bottom_right", gravity = "bottom_right", title = app.name })
end

return M
