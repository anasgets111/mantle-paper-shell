-- Desktop entries, launching and pins: the one place the taskbar, start menu and settings share.
local store = require("lib.store")
local util = require("lib.util")

local M = {}

-- Desktop ids, toplevel app ids and tray ids vary in case; the index keys are folded.
function M.entry(applications, app_id)
    local by_app_id = applications and applications.by_app_id
    if by_app_id == nil or app_id == nil or app_id == "" then return nil end
    local index = by_app_id[app_id] or by_app_id[string.lower(app_id)]
    return index and applications.entries[index]
end

-- The entry for a desktop id, looked up in `entries` (pins store desktop ids, not app ids).
function M.by_id(applications, id)
    for _, e in ipairs(applications and applications.entries or {}) do
        if e.id == id or e.id == id .. ".desktop" then return e end
    end
    return M.entry(applications, id)
end

-- `action`: a key from the entry's `actions`, launched instead of its main command.
function M.launch(id, action)
    if action then mantle.applications:launch_action(id, action) else mantle.applications:launch(id) end
    local usage = store.app_usage:get() or {}
    local was = usage[id] or { count = 0 }
    store:set("app_usage", util.with(usage, id, { count = was.count + 1, last = os.time() }))
end

-- The entry's own desktop actions ("New private window") as menu items; `launch` defaults to M.launch.
function M.action_items(id, launch)
    local entry, list = M.by_id(mantle.applications:get(), id), {}
    if not entry then return list end
    for _, a in ipairs(entry.actions) do
        list[#list + 1] = { label = a.name, icon = a.icon, on_click = function() (launch or M.launch)(entry.id, a.key) end }
    end
    return list
end

M.pinned = store.pinned
M.menu_pinned = store.menu_pinned

function M.is_pinned(id)
    return util.index_of(store.pinned:get() or {}, id) ~= nil
end

function M.pin(id)
    if M.is_pinned(id) then return end
    store:set("pinned", util.concat(store.pinned:get() or {}, { id }))
end

function M.unpin(id)
    store:set("pinned", util.filter(store.pinned:get() or {}, function(x) return x ~= id end))
end

function M.move_pin(from, to)
    store:set("pinned", util.move(store.pinned:get() or {}, from, to))
end

function M.is_menu_pinned(id)
    return util.index_of(store.menu_pinned:get() or {}, id) ~= nil
end

function M.menu_pin(id)
    if M.is_menu_pinned(id) then return end
    store:set("menu_pinned", util.concat(store.menu_pinned:get() or {}, { id }))
end

function M.menu_unpin(id)
    store:set("menu_pinned", util.filter(store.menu_pinned:get() or {}, function(x) return x ~= id end))
end

function M.move_menu_pin(from, to)
    store:set("menu_pinned", util.move(store.menu_pinned:get() or {}, from, to))
end

return M
