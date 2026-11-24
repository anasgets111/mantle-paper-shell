-- Notification history that survives a restart, and the unread counts the taskbar badges read.
-- The server forgets its feed when the shell restarts (gap 23), so every notification history keeps
-- is snapshotted here, display fields only. A record leaves when its live notification leaves the
-- feed (dismissed, invoked, replied, closed by the app) or when the user dismisses it here.
local feed = require("modules.notifications.feed")
local util = require("lib.util")

local PATH = mantle.config_dir .. "/state-notifications.json"
local LIMIT = 100

local store = persistent_table {
    path = PATH,
    defaults = {
        -- `feed.record` tables, newest first, at most LIMIT.
        history = {},
        -- Unix time the date menu last opened; anything newer is unread.
        last_opened = 0,
    },
}

local M = {}
M.records = store.history
M.last_opened = store.last_opened

-- The table reads its defaults until the file's first push; writing before then would replace the
-- stored history with an empty one.
local function loaded()
    local storage = mantle.storage:get()
    return storage ~= nil and storage.contents ~= nil and storage.contents[PATH] ~= nil
end

-- `set` lands on the next push, so two writes before it would each start from the stale value.
local pending
M.records:on_change(function() pending = nil end)

local function rows()
    return pending or M.records:get() or {}
end

local function write(list)
    table.sort(list, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    for i = #list, LIMIT + 1, -1 do list[i] = nil end
    pending = list
    store:set("history", list)
end

-- The live notification behind a record, matched by id and timestamp.
function M.live(key)
    local inbox = mantle.notifications:get()
    return util.find(inbox and inbox.feed, function(n) return feed.key(n) == key end)
end

-- Add what the feed holds and history lacks; drop what left the feed since `before`.
local function sync(inbox, before)
    if not loaded() then return end
    local live = {}
    for _, n in ipairs(inbox and inbox.feed or {}) do live[feed.key(n)] = n end
    local gone = {}
    for _, n in ipairs(before and before.feed or {}) do
        if not live[feed.key(n)] then gone[feed.key(n)] = true end
    end
    local kept, have, changed = {}, {}, false
    for _, record in ipairs(rows()) do
        if gone[record.key] then
            changed = true
        else
            kept[#kept + 1] = record
            have[record.key] = true
        end
    end
    for key, n in pairs(live) do
        if not have[key] and feed.kept_in_history(n) then
            kept[#kept + 1] = feed.record(n)
            changed = true
        end
    end
    if changed then write(kept) end
end

mantle.notifications:on_change(sync)
-- Storage pushes for every table in the shell; `sync` writes only when something differs.
mantle.storage:on_change(function() sync(mantle.notifications:get(), nil) end)

local function remove(keys)
    for _, key in ipairs(keys) do
        local n = M.live(key)
        if n then mantle.notifications:dismiss(n.id) end
    end
    local drop = {}
    for _, key in ipairs(keys) do drop[key] = true end
    write(util.filter(rows(), function(r) return not drop[r.key] end))
end

-- The server has no dismiss-group (gap 23): one `dismiss` per live member.
function M.dismiss(records)
    remove(util.map(records, function(r) return r.key end))
end

function M.dismiss_all()
    M.dismiss(rows())
end

-- Opening the date menu reads everything and prunes what a day has made stale.
function M.mark_opened()
    local now = os.time()
    if loaded() then
        M.dismiss(util.filter(rows(), function(r) return feed.stale(r, now) end))
        store:set("last_opened", now)
    end
end

-- Interface states the taskbar reads, written here so `mantle set` can drive them too.
M.unread = state("notifications.unread", 0)
M.unread_by_app = state("notifications.unread_by_app", {})

local function refresh()
    local since = M.last_opened:get() or 0
    local total, by_app = 0, {}
    for _, record in ipairs(rows()) do
        if (record.timestamp or 0) > since then
            total = total + 1
            local app = feed.app_key(record)
            by_app[app] = (by_app[app] or 0) + 1
        end
    end
    M.unread:set(total)
    M.unread_by_app:set(by_app)
end

M.records:on_change(refresh)
M.last_opened:on_change(refresh)
if loaded() then
    sync(mantle.notifications:get(), nil)
    refresh()
end

return M
