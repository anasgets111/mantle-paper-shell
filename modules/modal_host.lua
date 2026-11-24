-- One surface for the scrim, the outside-click catcher and every modal (start menu, settings,
-- power confirm). One string `modal` state means one modal at a time, and
-- `mantle toggle modal startmenu` / `mantle toggle modal settings` are single keybinds.
local util = require("lib.util")
local ui_state = require("lib.ui_state")

-- Each entry is a `components.modal` result. Modules register by returning one.
-- Bound to locals first: `require` returns two values and a table constructor would keep both.
local startmenu = require("modules.startmenu")
local settings = require("modules.settings")
local modals = { startmenu, settings }

local any_modal = ui_state.active_modal:map(function(kind) return kind ~= "" end)
local wants_scrim = ui_state.active_modal:map(function(kind)
    for _, m in ipairs(modals) do
        if m.kind == kind then return m.scrim end
    end
    return false
end)

local lingering, reset = {}, {}
for _, modal in ipairs(modals) do
    lingering[#lingering + 1] = util.linger(ui_state.modal_showing(modal.kind), modal.ms)
    reset = util.concat(reset, modal.reset_on_close)
end

local shown = util.linger(any_modal, 200)

local function close()
    ui_state.close_modal(ui_state.active_modal:get())
end

local cards = computed(lingering, function(...)
    local open = {}
    for index, modal in ipairs(modals) do
        if select(index, ...) then open[#open + 1] = modal.node end
    end
    return open
end)

return panel {
    id = "paper-modal-host",
    on_escape = close,
    output = "active",
    layer = "top",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive_zone = false,
    width = "fill",
    height = "fill",
    visible = shown,
    reset_on_close = reset,
    -- `none` on a still-mapped host makes Hyprland refocus the last window.
    keyboard_interactivity = util.choose(shown, "exclusive", "none"),
    child = rect {
        width = "fill",
        height = "fill",
        children = {
            rect {
                width = "fill",
                height = "fill",
                background = "#2A201526",
                opacity = wants_scrim:map(function(s) return s and 1 or 0 end),
                animate = { opacity = { duration = 180, easing = "out_cubic" } },
            },
            rect {
                width = "fill",
                height = "fill",
                cursor = "default",
                on_click = close,
                children = cards,
            },
        },
    },
}
