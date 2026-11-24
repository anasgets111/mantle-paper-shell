-- Sound page: the default output and input (radio lists), their volume and mute, and every app's
-- stream with its own level.
local k = require("lib.paper")
local c = require("components.controls")
local util = require("lib.util")
local rows = require("modules.settings.rows")
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

-- Volume and mute of whichever device is the default: one row that follows the radio choice.
local function level_row(kind, icon)
    local function current() return active(audio:get(), kind) end
    return rows.line({
        c.disc_button {
            id = "settings.sound.mute." .. kind,
            icon = icons.name(icon),
            size = 32,
            ink = k.INK,
            tooltip = "Mute",
            on_click = function()
                local d = current()
                if d then audio:toggle_mute(d.id) end
            end,
        },
        c.slider {
            id = "settings.sound.level." .. kind,
            width = 420,
            value = audio:map(function(a)
                local d = active(a, kind)
                return d and math.min(1, (d.volume or 0) / 100) or 0
            end, 0),
            on_change = function(v)
                local d = current()
                if d then audio:set_volume(d.id, math.floor(v * 100 + 0.5)) end
            end,
        },
    }, {
        rows.caption(audio:map(function(a)
            local d = active(a, kind)
            return d and d.muted and "muted" or ""
        end, ""), { foreground = k.DEEP_RED }),
    })
end

-- Radio list of devices; picking one makes it the default.
local function device_list(kind, set_default, empty)
    local shape = audio:map(function(a) return rows.key(a[kind], { "id", "name", "active" }) end, "")
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
                rows.list(
                    c.radio_group {
                        id = "settings.sound." .. kind,
                        vertical = true,
                        options = options,
                        value = audio:map(function(now)
                            local d = active(now, kind)
                            return d and d.id
                        end),
                        on_select = function(id) set_default(id) end,
                    }
                ),
            }
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
                        icons.glyph(app.icon or "stream", 20),
                        rows.label(rows.clip(app_name(app), 40), { width = 230 }),
                        c.slider {
                            id = "settings.sound.app." .. app.id,
                            width = 260,
                            value = live:map(function(s) return s and (s.volume or 0) / 100 or 0 end),
                            on_change = function(v) audio:set_app_volume(app.id, math.floor(v * 100 + 0.5)) end,
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
        return {
            rows.heading("Output"),
            level_row("sinks", "speaker"),
            device_list("sinks", function(id) audio:set_default_sink(id) end, "No output devices."),
            rows.heading("Input"),
            level_row("sources", "microphone"),
            device_list("sources", function(id) audio:set_default_source(id) end, "No microphones."),
            rows.heading("Applications"),
            app_rows(),
        }
    end,
}
