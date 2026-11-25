-- Every icon the settings notebook draws, by role: pencil doodles for symbols, die-cut stickers for
-- apps (`components/icons.lua`). A role without a doodle falls back to its theme icon.
local kit = require("components.icons")
local util = require("lib.util")

local DOODLES = {
    -- Tabs.
    wifi = "wifi",
    bluetooth = "bluetooth",
    sound = "volume-high",
    displays = "display",
    power = "power",
    appearance = "image",
    default_apps = "check",
    keyboard = "keyboard",
    notifications = "bell",
    updates = "download",
    about = "user",
    -- Rows.
    password = "lock",
    secure = "lock",
    brightness = "brightness",
    battery = "battery",
    peripheral = "battery",
    computer = "display",
    generic = "bluetooth",
}

-- Theme names for roles with no doodle.
local THEME = {
    warning = "dialog-warning-symbolic",
    vpn = "network-vpn-symbolic",
    mouse = "input-mouse-symbolic",
    headphones = "audio-headphones-symbolic",
    headset = "audio-headset-symbolic",
    phone = "phone-symbolic",
}

local I = {}

function I.glyph(role, size, color)
    if DOODLES[role] then return kit.doodle(DOODLES[role], size, color) end
    return kit.doodle_for(THEME[role] or role, size, color)
end

-- An app's own icon as a sticker; a 22 px sticker fits a 34 px ruled row.
function I.app(name, size)
    return kit.sticker(name, size or 22)
end

-- Wi-Fi strength (0 to 100, plain or a signal) as the doodle with that many arcs.
function I.signal(strength, size)
    return kit.doodle(util.lift(strength, function(s)
        return "wifi-" .. (s >= 80 and 4 or s >= 60 and 3 or s >= 40 and 2 or s >= 20 and 1 or 0)
    end), size or 22)
end

return I
