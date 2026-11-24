-- The task list's data: pinned apps first, then running ones not pinned, one entry per app, filtered
-- by the isolate options. No nodes and no window titles, so a retitling terminal rebuilds nothing.
local apps = require("lib.apps")
local store = require("lib.store")
local notifications = require("modules.notifications")

local M = {}

-- Window id -> focus order. Hyprland reports which window has focus, not the history.
local recency, tick = {}, 0
mantle.windows:on_change(function(w)
    local kept = {}
    for _, win in ipairs(w and w.windows or {}) do
        kept[win.id] = recency[win.id]
        if win.focused then
            tick = tick + 1
            kept[win.id] = tick
        end
    end
    recency = kept
end)

local function lower(s)
    return string.lower(s or "")
end

local function active_workspace(workspaces, output)
    for _, o in ipairs(workspaces and workspaces.outputs or {}) do
        if o.name == output then return o.active_workspace end
    end
end

-- Notification counts are keyed by desktop entry or app name; match both, case-folded.
local function unread_for(unread, item)
    local n = 0
    for name, count in pairs(unread or {}) do
        local l = lower(name)
        if l == lower(item.key) or l == lower(item.name) or l == lower(item.app_id) then n = n + count end
    end
    return n
end

-- Items: { key, id (desktop id or nil), app_id, name, icon, pinned, pin_index, wins (window ids),
-- focused (index into wins or false), urgent, unread, slot (position in the list), npinned }.
local function build(output, windows, applications, pinned, unread, workspaces, iso_ws, iso_out)
    local items, by_key, pin_of = {}, {}, {}
    for i, pin in ipairs(pinned or {}) do
        local entry = apps.by_id(applications, pin)
        local item = {
            key = pin,
            id = entry and entry.id or pin,
            app_id = pin,
            name = entry and entry.name or pin,
            icon = entry and entry.icon or "application-x-executable",
            pinned = true,
            pin_index = i,
            wins = {},
            focused = false,
            urgent = false,
        }
        items[i], by_key[pin] = item, item
        -- A window joins a pin by its app_id or by the entry both resolve to.
        pin_of[lower(pin)] = item
        if entry then pin_of[lower(entry.id)] = item end
    end

    local ws = iso_ws and active_workspace(workspaces, output)
    for _, win in ipairs(windows and windows.windows or {}) do
        local shown = (not iso_out or win.output == nil or win.output == output)
            and (not iso_ws or win.workspace_id == ws)
        if shown then
            local entry = apps.entry(applications, win.app_id)
            local item = pin_of[lower(win.app_id)] or (entry and pin_of[lower(entry.id)])
            local key = entry and entry.id or (win.app_id ~= "" and win.app_id or win.id)
            item = item or by_key[key]
            if not item then
                item = {
                    key = key,
                    id = entry and entry.id or nil,
                    app_id = win.app_id,
                    name = entry and entry.name or (win.app_id ~= "" and win.app_id or "Window"),
                    icon = entry and entry.icon or "application-x-executable",
                    pinned = false,
                    pin_index = false,
                    wins = {},
                    focused = false,
                    urgent = false,
                }
                items[#items + 1], by_key[key] = item, item
            end
            item.wins[#item.wins + 1] = win.id
            if win.focused then item.focused = #item.wins end
            item.urgent = item.urgent or win.urgent
        end
    end
    for i, item in ipairs(items) do
        item.unread, item.slot, item.npinned = unread_for(unread, item), i, #(pinned or {})
    end
    return items
end

-- The task list for one output's panel.
-- ponytail: a mapped table counts as unchanged only up to 256 entries in all (about 18 apps), so past
-- that every window retitle rebuilds every icon. Upgrade: key the list by app and give each icon its
-- own mapped signal.
function M.for_output(output)
    return computed({
        mantle.windows, mantle.applications, apps.pinned, notifications.unread_by_app, mantle.workspaces,
        store.taskbar_isolate_workspace, store.taskbar_isolate_output,
    }, function(windows, applications, pinned, unread, workspaces, iso_ws, iso_out)
        return build(output, windows, applications, pinned, unread, workspaces, iso_ws, iso_out)
    end, {})
end

-- The window a click should focus: the next one after the focused window, else the most recent.
function M.next_window(item, step)
    local wins = item.wins
    if #wins == 0 then return nil end
    if item.focused then
        return wins[(item.focused - 1 + (step or 1)) % #wins + 1]
    end
    local best, best_tick = wins[1], -1
    for _, id in ipairs(wins) do
        local t = recency[id] or 0
        if t > best_tick then best, best_tick = id, t end
    end
    return best
end

-- Full window entries (titles included) for a list of ids, in that order. `windows` defaults to now.
function M.windows_of(ids, windows)
    local want, out = {}, {}
    for i, id in ipairs(ids or {}) do want[id] = i end
    for _, win in ipairs((windows or mantle.windows:get() or {}).windows or {}) do
        if want[win.id] then out[want[win.id]] = win end
    end
    local packed = {}
    for i = 1, #(ids or {}) do
        if out[i] then packed[#packed + 1] = out[i] end
    end
    return packed
end

function M.activate(item)
    if #item.wins == 0 then
        if item.id then apps.launch(item.id) end
        return
    end
    local id = M.next_window(item, 1)
    if id then mantle.windows:focus(id) end
end

return M
