-- What the OSD shows, from capability pushes: volume, mic mute, brightness, keyboard backlight,
-- caps/num lock and layout. Ported from ~/.config/mantle/modules/osd/service.lua. A less important
-- entry is dropped while a more important one shows, so a held volume key cannot swallow caps lock.
local osd = {}

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
    if sink.muted or (sink.volume or 0) <= 0 then return "audio-volume-muted-symbolic" end
    if sink.volume < 34 then return "audio-volume-low-symbolic" end
    if sink.volume < 67 then return "audio-volume-medium-symbolic" end
    return "audio-volume-high-symbolic"
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
            icon = source.muted and "microphone-disabled-symbolic" or "microphone-sensitivity-high-symbolic",
            text = source.muted and "Mic muted" or "Mic on",
            off = source.muted,
        })
    end
end)

mantle.brightness:on_change(function(brightness, previous)
    if previous and brightness.percent ~= previous.percent then
        osd.show("brightness", {
            icon = "display-brightness-symbolic", text = brightness.percent .. "%", level = brightness.percent,
        })
    end
end)

mantle.keyboard:on_change(function(keyboard, previous)
    if previous == nil then return end
    if keyboard.active_layout ~= previous.active_layout and keyboard.active_layout ~= "" then
        osd.show("layout", { icon = "input-keyboard-symbolic", text = keyboard.active_layout })
    end
    if keyboard.caps_lock ~= previous.caps_lock then
        toggle("locks", keyboard.caps_lock, "Caps lock", "input-keyboard-symbolic")
    end
    if keyboard.num_lock ~= previous.num_lock then
        toggle("locks", keyboard.num_lock, "Num lock", "input-keyboard-symbolic")
    end
    if keyboard.backlight_percent and keyboard.backlight_percent ~= previous.backlight_percent then
        osd.show("backlight", {
            icon = "keyboard-brightness-symbolic",
            text = keyboard.backlight_percent .. "%",
            level = keyboard.backlight_percent,
        })
    end
end)

return osd
