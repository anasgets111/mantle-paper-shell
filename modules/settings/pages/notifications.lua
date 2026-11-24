-- Notifications page: do not disturb, and a mute box per app that has sent something. Muted apps
-- live in `lib/store.lua` (`muted_apps`, a list of desktop ids or app names) for the notification
-- centre to read; the engine silences their sounds.
local c = require("components.controls")
local util = require("lib.util")
local rows = require("modules.settings.rows")
local icons = require("modules.settings.icons")
local store = require("lib.store")

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
local senders = computed({ notes, store.muted_apps }, function(n, muted)
    local seen, list = {}, {}
    local function add(key, name, icon)
        if key and key ~= "" and not seen[key] then
            seen[key] = true
            list[#list + 1] = { key = key, name = name, icon = icon }
        end
    end
    for _, item in ipairs(n and n.feed or {}) do
        add(item.desktop_entry or item.app_name, item.app_name ~= "" and item.app_name or item.desktop_entry, item.app_icon)
    end
    for _, key in ipairs(muted or {}) do add(key, key) end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end, {})

local function app_rows()
    local shape = senders:map(function(list) return rows.key(list, { "key", "name", "icon" }) end)
    return column {
        width = "fill",
        children = shape:map(function()
            local list = {}
            for _, app in ipairs(senders:get()) do
                list[#list + 1] = rows.line({
                    icons.glyph(app.icon or "app", 20),
                    rows.label(app.name),
                }, {
                    c.checkbox_row {
                        id = "settings.notifications.mute." .. app.key,
                        label = "mute",
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
        return {
            rows.heading("Interruptions"),
            rows.line({ rows.label("Do not disturb") }, {
                rows.caption(notes:map(function(n) return n.dnd and "only critical ones make a sound" or "" end, "")),
                c.toggle {
                    id = "settings.notifications.dnd",
                    value = notes:map(function(n) return n.dnd end, false),
                    on_toggle = function(on) notes:set_dnd(on) end,
                },
            }),
            rows.heading("Apps"),
            app_rows(),
        }
    end,
}
