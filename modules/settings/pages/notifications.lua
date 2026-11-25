-- Notifications page under two tabs: do not disturb and a sound per urgency, then a mute box per
-- app that has sent something. Muted apps
-- live in `lib/store.lua` (`muted_apps`, a list of desktop ids or app names) for the notification
-- centre to read; the engine silences their sounds.
local c = require("components.controls")
local util = require("lib.util")
local rows = require("modules.settings.rows")
local icons = require("modules.settings.icons")
local store = require("lib.store")
local apps = require("lib.apps")

local notes = mantle.notifications

local function set_muted(key, muted)
    local list = util.filter(store.muted_apps:get(), function(app) return app ~= key end)
    if muted then list[#list + 1] = key end
    store:set("muted_apps", list)
end

-- The engine forgets mutes on restart and the file can change under us: apply the list, both ways.
local function apply(now, before)
    for _, key in ipairs(now or {}) do
        if not util.index_of(before, key) then notes:set_app_muted(key, true) end
    end
    for _, key in ipairs(before or {}) do
        if not util.index_of(now, key) then notes:set_app_muted(key, false) end
    end
end
store.muted_apps:on_change(apply)
apply(store.muted_apps:get(), {})

-- Senders seen in the feed plus anything already muted, so a muted app that has gone quiet stays listed.
-- Icon: the sender's own, else its desktop entry's, so a muted list reads as app icons.
local senders = computed({ notes, store.muted_apps, mantle.applications }, function(n, muted, applications)
    local seen, list = {}, {}
    local function add(key, name, icon)
        if key and key ~= "" and not seen[key] then
            seen[key] = true
            local entry = apps.entry(applications, key)
            list[#list + 1] = { key = key, name = name, icon = icon or (entry and entry.icon) }
        end
    end
    for _, item in ipairs(n and n.feed or {}) do
        add(item.desktop_entry or item.app_name, item.app_name ~= "" and item.app_name or item.desktop_entry, item.app_icon)
    end
    for _, key in ipairs(muted or {}) do add(key, key) end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end, {})

-- A sound per urgency tier, from the freedesktop sound theme. The engine plays nothing for a tier
-- until one is set and keeps no record of it, so the choice lives here and is reapplied at load.
local SOUND_DIR = "/usr/share/sounds/freedesktop/stereo/"
local SOUNDS = { { "message", "Message" }, { "bell", "Bell" }, { "complete", "Chime" }, { "dialog-warning", "Alert" } }
local TIERS = { { "low", "Low" }, { "normal", "Normal" }, { "critical", "Critical" } }
local sounds = persistent_table {
    path = mantle.config_dir .. "/state-settings.json",
    defaults = { notification_sounds = {} },
}
local function sound_path(name) return SOUND_DIR .. name .. ".oga" end
for tier, name in pairs(sounds.notification_sounds:get()) do notes:set_sound(tier, sound_path(name)) end

local function sound_rows()
    local list = {}
    for _, tier in ipairs(TIERS) do
        list[#list + 1] = rows.line({ rows.label(tier[2] .. " urgency") }, {
            rows.dropdown {
                id = "notifications.sound." .. tier[1],
                label = tier[2] .. " urgency sound",
                width = 220,
                options = SOUNDS,
                empty = "silent",
                value = sounds.notification_sounds:map(function(t) return t[tier[1]] end),
                on_select = function(name)
                    sounds:set("notification_sounds", util.with(sounds.notification_sounds:get(), tier[1], name))
                    notes:set_sound(tier[1], sound_path(name))
                end,
            },
        })
    end
    -- ponytail: the engine has no call to clear a tier's sound, so there is no "None" choice; an
    -- unset tier stays silent until one is picked. Upgrade: offer "None" once set_sound takes "".
    list[#list + 1] = rows.note("Unset tiers stay silent; a picked sound stays until the shell restarts.", 1)
    return list
end

local function app_rows()
    local shape = senders:map(function(list) return rows.key(list, { "key", "name", "icon" }) end)
    return column {
        width = "fill",
        children = shape:map(function()
            local list = {}
            for _, app in ipairs(senders:get()) do
                list[#list + 1] = rows.line({
                    app.icon and icons.app(app.icon) or icons.glyph("notifications", 22),
                    rows.label(app.name, { tip = "notifications.app." .. app.key }),
                }, {
                    c.checkbox_row {
                        id = "settings.notifications.mute." .. app.key,
                        label = "mute sounds",
                        value = store.muted_apps:map(function(m) return util.index_of(m, app.key) ~= nil end),
                        on_toggle = function(on) set_muted(app.key, on) end,
                    },
                })
            end
            if #list == 0 then list[1] = rows.note("No app has sent a notification yet.") end
            return list
        end),
    }
end

return {
    key = "notifications",
    title = "Notifications",
    build = function()
        local strip, tab = rows.tabs("notifications", { "General", "Per app" })
        local general = {
            rows.heading("Interruptions"),
            rows.line({ rows.label("Do not disturb") }, {
                rows.caption(notes:map(function(n) return n.dnd and "only critical ones make a sound" or "" end, "")),
                c.toggle {
                    id = "settings.notifications.dnd",
                    value = notes:map(function(n) return n.dnd end, false),
                    on_toggle = function(on) notes:set_dnd(on) end,
                },
            }),
            rows.heading("Sounds"),
        }
        for _, node in ipairs(sound_rows()) do general[#general + 1] = node end
        return {
            strip,
            rows.pane(tab, 1, general),
            rows.pane(tab, 2, { rows.heading("Apps that have sent something"), app_rows() }),
        }
    end,
}
