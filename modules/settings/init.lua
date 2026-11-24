-- Settings modal: a ring-bound notebook with card-stock index tabs down its left edge, one per page.
-- Returns a `components.modal` entry for `modules/modal_host.lua`, plus:
--   page        state `settings.page`: the open page's key (`mantle set settings.page '"sound"'`)
--   open(key)   open the modal on that page
--   surfaces    the tooltip popup on the modal host, for shell.lua's surface list
local modal = require("components.modal")
local ui_state = require("lib.ui_state")
local notebook = require("modules.settings.notebook")
local tips = require("modules.settings.tips")

local wifi = require("modules.settings.pages.wifi")
local bluetooth = require("modules.settings.pages.bluetooth")
local sound = require("modules.settings.pages.sound")
local displays = require("modules.settings.pages.displays")
local power = require("modules.settings.pages.power")
local appearance = require("modules.settings.pages.appearance")
local keyboard = require("modules.settings.pages.keyboard")
local notifications = require("modules.settings.pages.notifications")
local about = require("modules.settings.pages.about")

local PAGES = { wifi, bluetooth, sound, displays, power, appearance, keyboard, notifications, about }

local page = state("settings.page", "wifi")
local showing = ui_state.modal_showing("settings")

-- Pages read files and run tools when the notebook opens, never while it is shut. Every page
-- opens at its top.
local function refresh()
    for _, p in ipairs(PAGES) do
        scroll("settings.scroll." .. p.key):scroll_to(0)
        if p.on_open then p.on_open() end
    end
end
showing:on_change(function(open)
    if open then refresh() end
end)
if showing:get() then refresh() end

ui_state.on_modal_close("settings", function()
    for _, p in ipairs(PAGES) do
        if p.on_close then p.on_close() end
    end
end)

local entry = modal {
    kind = "settings",
    card = notebook { pages = PAGES, page = page },
}

entry.page = page
entry.surfaces = { tips.surface }
function entry.open(key)
    page:set(key)
    ui_state.active_modal:set("settings")
end

return entry
