-- Screen recording with `gpu-screen-recorder`. Interface:
--   surfaces           popups to add to the shell (the setup card)
--   open(rect)         toggle the setup card anchored to `rect`, from an `on_click`
--   indicator(output)  the taskbar sticker shown while recording
-- Keybinds: `mantle call recorder.toggle` starts with the last choices or stops;
-- `mantle call recorder.toggle_popup` opens the card.
local popup = require("modules.recorder.popup")
local indicator = require("modules.recorder.indicator")

return {
    surfaces = { popup.surface, popup.keyboard_surface },
    open = popup.open,
    indicator = indicator.indicator,
}
