-- Right-click menus on the taskbar: an app's windows and pin actions, and a tray item's DBusMenu.
-- One sticky-note menu serves both, so only one is ever open.
local apps = require("lib.apps")
local menu_component = require("components.menu")
local tasks = require("modules.taskbar.tasks")

local M = {}

local menu = menu_component.new { id = "paper-taskbar-menu", parent = "paper-taskbar" }
M.surfaces = menu.surfaces
M.is_open = menu.is_open

function M.app_items(item)
    local list = {}
    for _, win in ipairs(tasks.windows_of(item.wins)) do
        list[#list + 1] = {
            label = win.title ~= "" and win.title or item.name,
            icon = win.focused and "go-next-symbolic" or nil,
            on_click = function() mantle.windows:focus(win.id) end,
        }
    end
    if #list > 0 then list[#list + 1] = { separator = true } end
    if item.id then
        list[#list + 1] = {
            label = #item.wins > 0 and "New window" or "Open",
            icon = "list-add-symbolic",
            on_click = function() apps.launch(item.id) end,
        }
        local pinned = apps.is_pinned(item.pinned and item.key or item.id)
        list[#list + 1] = {
            label = pinned and "Unpin from taskbar" or "Pin to taskbar",
            icon = "view-pin-symbolic",
            on_click = function()
                if pinned then apps.unpin(item.pinned and item.key or item.id) else apps.pin(item.id) end
            end,
        }
    end
    if #item.wins > 0 then
        list[#list + 1] = {
            label = #item.wins > 1 and "Close all windows" or "Close window",
            icon = "window-close-symbolic",
            on_click = function()
                for _, id in ipairs(item.wins) do mantle.windows:close(id) end
            end,
        }
    end
    return list
end

function M.open_app(item, rect_)
    menu.open(rect_, M.app_items(item), { title = item.name })
end

-- DBusMenu marks a mnemonic with `_` and escapes a real one as `__`; the note takes no keyboard.
local function strip_mnemonics(label)
    return ((label or ""):gsub("__", "\0"):gsub("_", ""):gsub("%z", "_"))
end

local function tray_items(tray_id, entries)
    local list = {}
    for _, e in ipairs(entries or {}) do
        if e.menu_type == "separator" then
            list[#list + 1] = { separator = true }
        else
            local children = #(e.children or {}) > 0 and tray_items(tray_id, e.children) or nil
            local icon_name = e.icon_name
            if icon_name == "" then icon_name = nil end
            local checked
            if e.toggle_type ~= nil then checked = e.toggle_state == 1 end
            list[#list + 1] = {
                label = strip_mnemonics(e.label),
                icon = icon_name,
                checked = checked,
                disabled = not e.enabled,
                children = children,
                on_click = function() mantle.tray:activate_menu_item(tray_id, e.id) end,
            }
            if children then
                -- Apps that fill submenus lazily answer this before the submenu shows.
                mantle.tray:menu_will_show(tray_id, e.id)
            end
        end
    end
    return list
end

-- SNI `Title` is often a widget id (`vesktop_status_icon_1`); drop that suffix.
function M.tray_label(item)
    local base = (item.name or ""):gsub("[_%-]?status[_%-]?icon[_%-]?%d*$", "")
    local entry = apps.entry(mantle.applications:get(), base)
    return (entry and entry.name) or (base ~= "" and base) or "Tray item"
end

-- ponytail: components/menu.lua draws one submenu level and snapshots the items when it opens, so a
-- deeper or lazily filled tray menu shows what the tray had at that moment. Upgrade: a menu that
-- reads `mantle.tray` live and nests popups per level.
function M.open_tray(item, rect_)
    mantle.tray:menu_will_show(item.id, 0)
    menu.open(rect_, tray_items(item.id, item.menu), { title = M.tray_label(item) })
end

return M
