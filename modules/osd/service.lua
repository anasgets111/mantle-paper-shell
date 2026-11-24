-- What the OSD shows, from capability pushes: volume, mic mute, brightness, keyboard backlight,
-- caps/num lock and layout. Ported from ~/.config/mantle/modules/osd/service.lua. A less important
-- entry is dropped while a more important one shows, so a held volume key cannot swallow caps lock.
local osd = {}

-- Every icon the OSD draws: doodle names, or a theme name where no doodle exists.
local G = {
    muted = "volume-muted",
    low = "volume-low",
    medium = "volume-medium",
    high = "volume-high",
    mic = "mic",
    mic_off = "mic-off",
    brightness = "brightness",
    keyboard = "keyboard",
    backlight = "keyboard-brightness-symbolic",
}

-- Lower is more important; toggles a key press asked for outrank levels. Unlisted kinds are last.
local PRIORITY = { mic = 1, locks = 2, layout = 2, volume = 3, brightness = 3, backlight = 3 }

-- A sink's ceiling: `set_volume` clamps there, so 150 fills the bar.
local MAX_VOLUME = 150

osd.entry = state("osd.entry", { kind = "", icon = "", text = "" })
-- Each `show` writes a fresh table, which `pulse` counts as a change, so every entry restarts the
-- two seconds. Starts false: an entry up at reload hides rather than lingering with no timer.
osd.visible = pulse(osd.entry, 2000)

-- `entry` = { icon, text, level? (0..100), off? }: `level` selects the bar layout, `off` dims it.
function osd.show(kind, entry)
    local current = osd.entry:get()
    if osd.visible:get() and current.kind ~= kind and (PRIORITY[kind] or 9) > (PRIORITY[current.kind] or 9) then
        return
    end
    entry.kind = kind
    osd.entry:set(entry)
end

local function active(devices)
    for _, device in ipairs(devices or {}) do
        if device.active then return device end
    end
end

local function volume_icon(sink)
    if sink.muted or (sink.volume or 0) <= 0 then return G.muted end
    if sink.volume < 34 then return G.low end
    if sink.volume < 67 then return G.medium end
    return G.high
end

local function toggle(kind, on, what, icon)
    osd.show(kind, { icon = icon, text = what .. (on and " on" or " off"), off = not on })
end

-- Every handler skips the first push (`previous == nil`): it reports learned state, not a change.

mantle.audio:on_change(function(audio, previous)
    if previous == nil then return end
    local sink, was = active(audio.sinks), active(previous.sinks)
    if sink and was and sink.id == was.id and sink.volume and was.volume then
        local percent, before = math.floor(sink.volume + 0.5), math.floor(was.volume + 0.5)
        if percent ~= before or sink.muted ~= was.muted then
            -- Muted keeps the level and dims it: the volume is still set, only silenced.
            osd.show("volume", {
                icon = volume_icon(sink),
                text = sink.muted and "Muted" or percent .. "%",
                level = math.min(100, percent / MAX_VOLUME * 100),
                off = sink.muted,
            })
        end
    end
    -- No event exists for the mic-mute key, so the source's mute flag is diffed instead.
    local source, source_was = active(audio.sources), active(previous.sources)
    if source and source_was and source.id == source_was.id and source.muted ~= source_was.muted then
        osd.show("mic", {
            icon = source.muted and G.mic_off or G.mic,
            text = source.muted and "Mic muted" or "Mic on",
            off = source.muted,
        })
    end
end)

mantle.brightness:on_change(function(brightness, previous)
    if previous and brightness.percent ~= previous.percent then
        osd.show("brightness", {
            icon = G.brightness, text = brightness.percent .. "%", level = brightness.percent,
        })
    end
end)

mantle.keyboard:on_change(function(keyboard, previous)
    if previous == nil then return end
    if keyboard.active_layout ~= previous.active_layout and keyboard.active_layout ~= "" then
        osd.show("layout", { icon = G.keyboard, text = keyboard.active_layout })
    end
    if keyboard.caps_lock ~= previous.caps_lock then
        toggle("locks", keyboard.caps_lock, "Caps lock", G.keyboard)
    end
    if keyboard.num_lock ~= previous.num_lock then
        toggle("locks", keyboard.num_lock, "Num lock", G.keyboard)
    end
    if keyboard.backlight_percent and keyboard.backlight_percent ~= previous.backlight_percent then
        osd.show("backlight", {
            icon = G.backlight,
            text = keyboard.backlight_percent .. "%",
            level = keyboard.backlight_percent,
        })
    end
end)

return osd
