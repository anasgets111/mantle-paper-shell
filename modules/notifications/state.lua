-- Popup interaction state: the seen set, quiet hours (lock, screen share), the reply draft and the
-- swipe in progress. Adapted from ~/.config/mantle/lib/notification_state.lua.
local feed = require("modules.notifications.feed")
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local store = require("lib.store")

local M = {}

-- Keyed by id + timestamp so replaced content pops again. A table, so ids never grow the registry.
M.seen = state("notifications.seen", {})

function M.hide(notification)
    M.seen:set(util.with(M.seen:get(), feed.key(notification), true))
end

function M.mark_all_seen()
    local seen = {}
    for _, n in ipairs((mantle.notifications:get() or {}).feed or {}) do seen[feed.key(n)] = true end
    M.seen:set(seen)
end

-- The lock and privacy capabilities may never push; `computed` would hold every popup back.
M.locked = mantle.lock:map(function(lock) return lock.active end, false)
M.sharing = mantle.privacy:map(function(privacy) return #privacy.screencast_users > 0 end, false)

-- A popup over the lock screen is readable without a password, and a screen share is DND for its
-- length: both mute sounds too.
computed({ M.locked, M.sharing }, function(locked, sharing) return locked or sharing end, false)
    :on_change(function(quiet) mantle.notifications:set_quiet(quiet) end)

M.center_open = ui_state.panel_showing("datemenu")

-- Apps muted from a note's menu or the settings page: no popups (history still keeps them). The
-- settings page owns `muted_apps` and applies it to sounds through `set_app_muted`.
M.muted = store.muted_apps

function M.mute(app)
    local list = util.filter(store.muted_apps:get(), function(key) return key ~= app end)
    list[#list + 1] = app
    store:set("muted_apps", list)
end

-- One draft at a time; the key keeps a draft typed on one note from holding the keyboard for another.
M.draft = state("notifications.reply_draft", { key = "", text = "" })

M.reply_pending = computed({ M.draft, mantle.notifications }, function(draft, inbox)
    return draft.text:find("%S") ~= nil
        and util.find(inbox.feed, function(n) return feed.key(n) == draft.key end) ~= nil
end, false)

function M.send_reply(notification, text)
    if not (text or ""):find("%S") then return end
    mantle.notifications:reply(notification.id, text)
    M.draft:set({ key = "", text = "" })
end

-- The note being dragged sideways and how far.
M.swipe = state("notifications.swipe", { key = "", dx = 0 })

-- Prune departed notifications without writing unchanged maps.
mantle.notifications:on_change(function(inbox)
    local live = {}
    for _, n in ipairs((inbox and inbox.feed) or {}) do live[feed.key(n)] = true end
    local kept, changed = {}, false
    for key, value in pairs(M.seen:get()) do
        if live[key] then kept[key] = value else changed = true end
    end
    if changed then M.seen:set(kept) end
end)

return M
