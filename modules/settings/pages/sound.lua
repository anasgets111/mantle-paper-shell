-- Sound page under four tabs: the default output and the default input (a dropdown each, with
-- volume and mute), every app's stream with its own level, and each sound card's profile and ports.
local theme = require("theme")
local c = require("components.controls")
local util = require("lib.util")
local rows = require("modules.settings.rows")
local tips = require("modules.settings.tips")
local icons = require("modules.settings.icons")

local audio = mantle.audio

local function device(kind, id)
    return audio:map(function(a)
        return util.find(a[kind], function(d) return d.id == id end)
    end)
end

local function active(a, kind)
    return util.find(a and a[kind], function(d) return d.active end)
end

-- One wheel notch is 5%, as on the taskbar's volume icon; the slider tops out at 100%.
local function nudge(volume, steps)
    return math.max(0, math.min(100, math.floor((volume or 0) + steps * 5 + 0.5)))
end

-- Volume and mute of whichever device is the default: one row that follows the radio choice.
local function level_row(kind, icon)
    local function current() return active(audio:get(), kind) end
    return rows.line({
        tips.wrap(c.disc_button {
            id = "settings.sound.mute." .. kind,
            icon = icon,
            size = theme.control.slider,
            ink = theme.INK,
            tooltip = "Mute",
            on_click = function()
                local d = current()
                if d then audio:toggle_mute(d.id) end
            end,
        }, "paper.disc.settings.sound.mute." .. kind, function()
            local d = current()
            return d and (d.muted and "Unmute " or "Mute ") .. d.name or ""
        end),
        c.slider {
            id = "settings.sound.level." .. kind,
            width = theme.settings.sound_level_w,
            value = audio:map(function(a)
                local d = active(a, kind)
                return d and math.min(1, (d.volume or 0) / 100) or 0
            end, 0),
            on_change = function(v)
                local d = current()
                if d then audio:set_volume(d.id, math.floor(v * 100 + 0.5)) end
            end,
            on_wheel = function(_, steps)
                local d = current()
                if d then audio:set_volume(d.id, nudge(d.volume, steps)) end
            end,
        },
    }, {
        rows.caption(audio:map(function(a)
            local d = active(a, kind)
            return d and d.muted and "muted" or ""
        end, ""), { foreground = theme.DEEP_RED }),
    })
end

-- The default device as a dropdown of every device of the kind.
local function device_row(kind, label, set_default, empty)
    local shape = audio:map(function(a) return rows.key(a[kind], { "id", "name" }) end, "")
    return column {
        width = "fill",
        children = shape:map(function()
            local a = audio:get()
            local options = {}
            for _, d in ipairs(a and a[kind] or {}) do
                options[#options + 1] = { d.id, rows.clip(d.name, 60) }
            end
            if #options == 0 then return { rows.note(empty) } end
            return {
                rows.line({ rows.label(label) }, {
                    rows.dropdown {
                        id = "sound." .. kind,
                        label = label,
                        width = theme.settings.sound_device_w,
                        options = options,
                        value = audio:map(function(now)
                            local d = active(now, kind)
                            return d and d.id
                        end),
                        on_select = function(id) set_default(id) end,
                    },
                }),
            }
        end),
    }
end

-- One card: its name and its profile (available ones only, plus the active one), then, under that
-- profile, the ports it can route to. A choice of one has nothing to pick and is left out. The
-- wheel never steps these: scrolling past would cut the sound.
local function card_rows(card)
    local list = {
        rows.line({ icons.glyph("sound", theme.icon.md), rows.label(card.name, { tip = "sound.card." .. card.device, font_weight = theme.BOLD }) }),
    }
    local profiles = {}
    for _, p in ipairs(card.profiles) do
        if p.available or p.index == card.active then
            profiles[#profiles + 1] = { p.index, rows.clip(p.description, 56) }
        end
    end
    if #profiles > 1 then
        list[#list + 1] = rows.line({ rows.label("Profile", { width = theme.settings.sound_profile_label_w }) }, {
            rows.dropdown {
                id = "sound.profile." .. card.device,
                label = card.name .. " profile",
                width = theme.settings.sound_device_w,
                wheel = false,
                options = profiles,
                value = audio:map(function(a)
                    local now = util.find(a.cards, function(x) return x.device == card.device end)
                    return now and now.active
                end),
                on_select = function(index) audio:set_card_profile(card.device, index) end,
            },
        })
    end
    local ports = {}
    for _, p in ipairs(card.ports) do
        if p.available and util.index_of(p.profiles, card.active) then
            ports[#ports + 1] = { p.index, rows.clip(p.description, 40), p.direction }
        end
    end
    for _, dir in ipairs({ "output", "input" }) do
        local options = util.filter(ports, function(p) return p[3] == dir end)
        if #options > 1 then
            list[#list + 1] = rows.line({ rows.label(dir == "output" and "Plays through" or "Listens on", { width = theme.settings.sound_profile_label_w }) }, {
                rows.dropdown {
                    id = "sound.port." .. card.device .. "." .. dir,
                    label = dir == "output" and "Plays through" or "Listens on",
                    width = theme.settings.sound_device_w,
                    wheel = false,
                    options = options,
                    value = audio:map(function(a)
                        local now = util.find(a.cards, function(x) return x.device == card.device end)
                        local on = now and util.find(now.ports, function(p) return p.active and p.direction == dir end)
                        return on and on.index
                    end),
                    on_select = function(index) audio:set_port(card.device, index) end,
                },
            })
        end
    end
    return list
end

local function card_list()
    local shape = audio:map(function(a)
        local parts = {}
        for _, card in ipairs(a.cards or {}) do
            parts[#parts + 1] = card.device .. ":" .. tostring(card.active) .. ":"
                .. rows.key(card.profiles, { "index", "available" }) .. rows.key(card.ports, { "index", "available" })
        end
        return table.concat(parts, ";")
    end, "")
    return column {
        width = "fill",
        children = shape:map(function()
            local list = {}
            for _, card in ipairs(audio:get() and audio:get().cards or {}) do
                for _, node in ipairs(card_rows(card)) do list[#list + 1] = node end
            end
            if #list == 0 then list[1] = rows.note("No sound cards reported.") end
            return list
        end),
    }
end

local function app_name(app)
    local name = app.name or app.process_name or app.binary or ("pid " .. app.pid)
    if app.media_name and app.media_name ~= "" and app.media_name ~= name then
        return name .. " — " .. app.media_name
    end
    return name
end

local function app_rows()
    local shape = audio:map(function(a)
        return rows.key(util.filter(a.apps, function(s) return not s.recording end), { "id", "name", "media_name" })
    end, "")
    return column {
        width = "fill",
        children = shape:map(function()
            local list = {}
            for _, app in ipairs(audio:get() and audio:get().apps or {}) do
                if not app.recording then
                    local live = device("apps", app.id)
                    list[#list + 1] = rows.line({
                        app.icon and icons.app(app.icon) or icons.glyph("sound", theme.icon.control),
                        rows.label(app_name(app), { width = theme.settings.sound_app_name_w, tip = "sound.app." .. app.id }),
                        c.slider {
                            id = "settings.sound.app." .. app.id,
                            width = theme.settings.sound_app_level_w,
                            value = live:map(function(s) return s and (s.volume or 0) / 100 or 0 end),
                            on_change = function(v) audio:set_app_volume(app.id, math.floor(v * 100 + 0.5)) end,
                            on_wheel = function(_, steps)
                                local now = live:get()
                                if now then audio:set_app_volume(app.id, nudge(now.volume, steps)) end
                            end,
                        },
                    }, {
                        c.checkbox_row {
                            id = "settings.sound.appmute." .. app.id,
                            label = "mute",
                            value = live:map(function(s) return s ~= nil and s.muted end),
                            on_toggle = function(on) audio:set_app_muted(app.id, on) end,
                        },
                    })
                end
            end
            if #list == 0 then list[1] = rows.note("Nothing is playing.") end
            return list
        end),
    }
end

return {
    key = "sound",
    title = "Sound",
    build = function()
        local strip, tab = rows.tabs("sound", { "Output", "Input", "Apps", "Cards" }, theme.settings.sound_tab_w)
        return {
            strip,
            rows.pane(tab, 1, {
                rows.heading("Output"),
                device_row("sinks", "Play sound through", function(id) audio:set_default_sink(id) end, "No output devices."),
                level_row("sinks", "volume-high"),
            }),
            rows.pane(tab, 2, {
                rows.heading("Input"),
                device_row("sources", "Record from", function(id) audio:set_default_source(id) end, "No microphones."),
                level_row("sources", "mic"),
            }),
            rows.pane(tab, 3, { rows.heading("Applications"), app_rows() }),
            rows.pane(tab, 4, { rows.heading("Sound cards"), card_list() }),
        }
    end,
}
