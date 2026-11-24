-- Every icon quick settings draws, in one place. Doodle names from `components/icons.lua`; a
-- freedesktop name where no doodle exists (power profiles) falls back to the theme icon.
return {
    wifi = "wifi-4",
    wifi_off = "wifi-off",
    bluetooth = "bluetooth",
    bluetooth_off = "bluetooth-off",
    dnd = "bell-off",
    airplane = "airplane",
    profile = {
        ["power-saver"] = "power-profile-power-saver-symbolic",
        balanced = "power-profile-balanced-symbolic",
        performance = "power-profile-performance-symbolic",
    },
    ac = "power",
    settings = "settings",
    lock = "lock",
    power = "power",
    volume_muted = "volume-muted",
    volume_low = "volume-low",
    volume_high = "volume-high",
    brightness = "brightness",
    mic = "mic",
    mic_off = "mic-off",
    camera = "video",
    screen = "display",
}
