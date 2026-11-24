-- Every icon the settings notebook draws, by role, so another icon set swaps in here alone.
local k = require("lib.paper")

local NAMES = {
    -- Tabs.
    wifi = "network-wireless-symbolic",
    bluetooth = "bluetooth-symbolic",
    sound = "audio-speakers-symbolic",
    displays = "video-display-symbolic",
    power = "battery-full-symbolic",
    appearance = "applications-graphics-symbolic",
    keyboard = "input-keyboard-symbolic",
    notifications = "preferences-system-notifications-symbolic",
    about = "help-about-symbolic",
    -- Rows.
    refresh = "view-refresh-symbolic",
    password = "dialog-password-symbolic",
    warning = "dialog-warning-symbolic",
    secure = "system-lock-screen-symbolic",
    vpn = "network-vpn-symbolic",
    brightness = "display-brightness-symbolic",
    battery = "battery-good-symbolic",
    peripheral = "battery-symbolic",
    speaker = "audio-volume-high-symbolic",
    microphone = "audio-input-microphone-symbolic",
    stream = "audio-x-generic-symbolic",
    app = "application-x-executable-symbolic",
    -- Bluetooth device categories.
    mouse = "input-mouse-symbolic",
    headphones = "audio-headphones-symbolic",
    headset = "audio-headset-symbolic",
    phone = "phone-symbolic",
    computer = "computer-symbolic",
    generic = "bluetooth-symbolic",
}

local I = {}

-- `role` names an entry above; anything else is an app's own theme icon, used as given.
function I.name(role)
    return NAMES[role] or role
end

function I.glyph(role, size, color)
    return k.glyph(I.name(role), size, color)
end

return I
