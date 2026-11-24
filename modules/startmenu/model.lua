-- The start menu's state and what it shows: the open tab, the query, the keyboard selection, and
-- the list of selectable items the left page draws for them.
local apps = require("lib.apps")
local store = require("lib.store")
local ui_state = require("lib.ui_state")
local search = require("modules.startmenu.search")
local recent = require("modules.startmenu.recent")

local M = {}

M.KIND = "startmenu"
M.COLUMNS = 4

-- "favourites", "frequent", "recent", "all", or a category name.
M.view = state("startmenu.view", "favourites")
M.query = state("startmenu.query", "")
-- 1-based index into `items`; 0 is no selection.
M.selected = state("startmenu.selected", 0)
-- The pinned tile under the pointer's drag and how far it has moved.
M.drag = state("startmenu.drag", { id = "", x = 0, y = 0 })
-- The target held under the left button, "" when none: `on_drag` brackets a press, "start" on
-- press and "end" on release or when the pointer leaves, before the click.
M.pressed = state("startmenu.pressed", "")
M.search_focus = focus_target("startmenu.search")
M.scroll = scroll("startmenu.list")

M.reset = { M.view, M.query, M.selected, M.drag, M.pressed, M.scroll }

local index = mantle.applications:map(search.index, {})

-- What the page shows. `items` are the selectable rows in order; `layout` is "grid", "list",
-- "groups" (headed by category) or "cards" (recent files); `empty` is the note shown without pins
-- or items. Each item: { kind = "app"|"file"|"calc", ... }.
M.page = computed({ index, M.query, store.app_usage, M.view, apps.menu_pinned, recent.files, mantle.applications },
    function(idx, query, usage, view, pins, files, applications)
        usage = usage or {}
        local text = query:match("^%s*(.-)%s*$")
        local items = {}
        local function add_apps(list)
            for _, app in ipairs(list) do items[#items + 1] = { kind = "app", app = app } end
        end
        if text ~= "" then
            local answer = search.calc(text)
            if answer then items[1] = { kind = "calc", value = answer, expression = text } end
            add_apps(search.rank(idx, text, usage, 30))
            return { title = "Results", layout = "list", items = items, empty = "No apps match “" .. text .. "”." }
        end
        if view == "favourites" then
            for n, id in ipairs(pins or {}) do
                local app = apps.by_id(applications, id)
                if app then items[#items + 1] = { kind = "app", app = app, pin_index = n } end
            end
            -- Under the pins, so the page is not bare: the four newest files.
            for i = 1, math.min(4, #files) do
                items[#items + 1] = { kind = "file", file = files[i], group = "Recent files" }
            end
            return {
                title = "Pinned",
                layout = "grid",
                items = items,
                empty = "Nothing pinned yet. Right-click an app and choose Pin to menu.",
            }
        elseif view == "frequent" then
            add_apps(search.frequent(idx, usage, 12))
            return {
                title = "Frequent", layout = "list", items = items, empty = "Apps you open often will gather here.",
            }
        elseif view == "recent" then
            for _, f in ipairs(files) do items[#items + 1] = { kind = "file", file = f } end
            return { title = "Recent files", layout = "cards", items = items, empty = "No recent files yet." }
        elseif view == "all" then
            local groups = search.by_category(idx)
            for _, g in ipairs(groups) do
                for _, app in ipairs(g.apps) do items[#items + 1] = { kind = "app", app = app, group = g.name } end
            end
            return { title = "All apps", layout = "groups", items = items, empty = "No apps installed." }
        end
        for _, g in ipairs(search.by_category(idx)) do
            if g.name == view then add_apps(g.apps) end
        end
        return { title = view, layout = "list", items = items, empty = "No apps filed under " .. view .. "." }
    end, { title = "", layout = "list", items = {} })

-- A new query or tab selects its first result when typing, nothing when browsing.
M.page:on_change(function()
    M.selected:set(M.query:get():match("%S") and 1 or 0)
end)

function M.close()
    ui_state.close_modal(M.KIND)
end

function M.launch(id)
    apps.launch(id)
    M.close()
end

function M.open_uri(uri)
    process.detach("xdg-open", { uri })
    M.close()
end

function M.activate(item)
    if not item then return end
    if item.kind == "app" then
        M.launch(item.app.id)
    elseif item.kind == "file" then
        M.open_uri(item.file.uri)
    elseif item.kind == "calc" then
        -- `process.detach`: a reaped child would take the clipboard selection with it.
        process.detach("wl-copy", { item.value })
        M.close()
    end
end

function M.show(view)
    M.view:set(view)
    if M.query:get() ~= "" then
        M.query:set("")
        M.search_focus:set_text("")
    end
    M.search_focus:request()
end

-- The host resets these when it hides; switching straight to another modal must reset them too.
ui_state.on_modal_close(M.KIND, function()
    M.view:set("favourites")
    M.query:set("")
    M.selected:set(0)
    M.drag:set { id = "", x = 0, y = 0 }
end)

-- The `on_drag` handler that marks `slot` held, and its reader.
function M.track(slot)
    return function(_, _, phase) M.pressed:set(phase == "end" and "" or slot) end
end

function M.held(slot)
    return M.pressed:map(function(p) return p == slot end)
end

-- Scale for a target that sinks while held.
function M.sink(slot, by)
    return M.held(slot):map(function(h) return h and by or 1 end)
end

-- The recent-files list is read fresh on every open.
ui_state.active_modal:on_change(function(kind)
    if kind == M.KIND then recent.refresh() end
end)

return M
