-- Default apps page: which installed app opens links, mail, folders, text, music, video and photos,
-- and which terminal opens. `mantle.applications` carries no MimeType, so `gio mime` lists the apps
-- registered for each type (desktop entries plus mimeapps.list associations) and the current
-- default; `xdg-settings` sets the browser and `xdg-mime default` the rest. The terminal follows
-- the proposed XDG Default Terminal spec (`xdg-terminal-exec`, `xdg-terminals.list`), the only
-- standard there is; without `xdg-terminal-exec` the row says so.
local util = require("lib.util")
local rows = require("modules.settings.rows")
local apps = require("lib.apps")

-- A category's candidates are the apps registered for its first type; a pick is set for every
-- type of the category that app is registered for, so a music player never claims a video type.
local CATEGORIES = {
    { key = "web", label = "Web browser", types = { "x-scheme-handler/http", "x-scheme-handler/https", "text/html" }, browser = true },
    { key = "mail", label = "Mail", types = { "x-scheme-handler/mailto" } },
    { key = "files", label = "Files", types = { "inode/directory" } },
    { key = "text", label = "Text editor", types = { "text/plain", "text/markdown", "application/x-shellscript" } },
    { key = "music", label = "Music", types = { "audio/mpeg", "audio/flac", "audio/ogg", "audio/x-vorbis+ogg", "audio/x-wav", "audio/mp4" } },
    { key = "video", label = "Video", types = { "video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo" } },
    { key = "photos", label = "Photos", types = { "image/jpeg", "image/png", "image/gif", "image/webp", "image/bmp" } },
}

-- `types[type] = { default = id?, registered = { id... } }`, `terminal = { default = id?, ids = {...}, missing? }`.
-- Ids keep their `.desktop` suffix, as xdg-mime wants them.
local known = state("settings.default_apps", { types = {}, loaded = false })

-- One shell for every query: a block per type, `@@type` then `gio mime`'s C-locale answer; then the
-- terminal's `--print-id` and every entry whose Categories name TerminalEmulator.
local QUERY = [[
for t; do echo "@@$t"; LC_ALL=C gio mime "$t" 2>/dev/null; done
echo "@@terminal"
if command -v xdg-terminal-exec >/dev/null; then echo "default $(xdg-terminal-exec --print-id 2>/dev/null)"; else echo missing; fi
for d in "${XDG_DATA_HOME:-$HOME/.local/share}" $(printf %s "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr : ' '); do
  grep -l '^Categories=.*TerminalEmulator' "$d"/applications/*.desktop 2>/dev/null
done
]]

local function parse(out)
    local result = { types = {}, terminal = { ids = {} }, loaded = true }
    local current, block, seen = nil, 0, {}
    for line in (out or ""):gmatch("[^\n]+") do
        local header = line:match("^@@(.+)$")
        if header then
            current, block = header, 0
            if header ~= "terminal" then result.types[header] = { registered = {} } end
        elseif current == "terminal" then
            if line == "missing" then
                result.terminal.missing = true
            elseif line:match("^default ") then
                local id = line:match("^default (%S+%.desktop)")
                result.terminal.default = id
            else
                local id = line:match("([^/]+%.desktop)$")
                if id and not seen[id] then
                    seen[id] = true
                    result.terminal.ids[#result.terminal.ids + 1] = id
                end
            end
        elseif current then
            local entry = result.types[current]
            local id = line:match("^\t(%S+%.desktop)$")
            if id then
                -- The first indented block is "Registered applications".
                if block == 1 then entry.registered[#entry.registered + 1] = id end
            elseif line:match(":$") then
                -- A section header ("Registered applications:", "Recommended applications:").
                block = block + 1
            else
                entry.default = entry.default or line:match("^Default application for .-: (%S+%.desktop)$")
            end
        end
    end
    return result
end

local loading = false
local function load()
    if loading then return end
    loading = true
    local types = { "-c", QUERY, "sh" }
    for _, cat in ipairs(CATEGORIES) do
        for _, t in ipairs(cat.types) do types[#types + 1] = t end
    end
    process.capture("sh", types, function(out)
        loading = false
        if out then known:set(parse(out)) end
    end)
end

-- The terminal list: the picked id first, every other line kept in order.
local function terminal_list_path(done)
    local desktop = (os.getenv("XDG_CURRENT_DESKTOP") or ""):match("^[^:]+")
    local own = desktop and ("~/.config/" .. desktop:lower() .. "-xdg-terminals.list")
    if not own then return done("~/.config/xdg-terminals.list", nil) end
    file.read(own, function(text)
        if text then return done(own, text) end
        file.read("~/.config/xdg-terminals.list", function(generic) done("~/.config/xdg-terminals.list", generic) end)
    end)
end

local function set_terminal(id)
    terminal_list_path(function(path, text)
        local lines, placed = {}, false
        -- A missing or empty file has no lines, so the pick is not written under a blank one.
        for line in (text and text ~= "" and text .. "\n" or ""):gmatch("([^\n]*)\n") do
            if line ~= id then
                -- The pick goes above the first entry, under any leading comments.
                if not placed and line ~= "" and not line:match("^#") then
                    lines[#lines + 1] = id
                    placed = true
                end
                lines[#lines + 1] = line
            end
        end
        if not placed then lines[#lines + 1] = id end
        while lines[#lines] == "" do lines[#lines] = nil end
        file.write(path, table.concat(lines, "\n") .. "\n", nil, function() load() end)
    end)
end

local function set_default(cat, id)
    if cat.browser then
        return process.capture("xdg-settings", { "set", "default-web-browser", id }, function() load() end)
    end
    local args = { "default", id }
    local types = known:get().types
    for i, t in ipairs(cat.types) do
        local entry = types[t]
        if i == 1 or (entry and util.index_of(entry.registered, id)) then args[#args + 1] = t end
    end
    process.capture("xdg-mime", args, function() load() end)
end

-- An app's name from its desktop entry, else its id; two apps of one name show their ids.
local function names(ids)
    local applications = mantle.applications:get()
    local out, count = {}, {}
    for i, id in ipairs(ids) do
        local entry = apps.by_id(applications, (id:gsub("%.desktop$", "")))
        out[i] = entry and entry.name or id:gsub("%.desktop$", "")
        count[out[i]] = (count[out[i]] or 0) + 1
    end
    for i, id in ipairs(ids) do
        if count[out[i]] > 1 then out[i] = out[i] .. " (" .. id:gsub("%.desktop$", "") .. ")" end
        out[i] = rows.clip(out[i], 44)
    end
    return out
end

-- One ruled row: the category on the left, a dropdown of its apps on the right.
local function chooser(id, label, current, ids, on_pick, empty)
    if #ids == 0 then return rows.line({ rows.label(label) }, { rows.caption(empty) }) end
    local labels, options = names(ids), {}
    for i, app in ipairs(ids) do options[i] = { app, labels[i] } end
    return rows.line({ rows.label(label) }, {
        rows.dropdown {
            id = "default_apps." .. id,
            label = label,
            width = 320,
            options = options,
            value = current,
            empty = "no default set",
            on_select = on_pick,
        },
    })
end

local function category_rows(cat, data)
    local entry = data.types[cat.types[1]] or { registered = {} }
    local ids = util.concat({}, entry.registered)
    -- A default set by hand to an app that no longer registers the type still shows.
    if entry.default and not util.index_of(ids, entry.default) then ids[#ids + 1] = entry.default end
    return chooser(cat.key, cat.label, entry.default, ids, function(id) set_default(cat, id) end,
        "no installed app opens these")
end

local function terminal_rows(data)
    local t = data.terminal or { ids = {} }
    if t.missing then
        return rows.line({ rows.label("Terminal") }, { rows.caption("needs xdg-terminal-exec") })
    end
    -- NoDisplay helpers (kitty's "open with" entry) are not terminals to pick.
    local applications = mantle.applications:get()
    local ids = util.filter(t.ids, function(id)
        local e = apps.by_id(applications, (id:gsub("%.desktop$", "")))
        return not (e and e.no_display)
    end)
    if t.default and not util.index_of(ids, t.default) then ids[#ids + 1] = t.default end
    return chooser("terminal", "Terminal", t.default, ids, set_terminal, "no terminal emulator installed")
end

-- Rebuilt when the answers change; `mantle.applications` only names them.
local function body()
    return column {
        width = "fill",
        children = known:map(function(data)
            if not data.loaded then return { rows.note("Asking which apps open what…", 1) } end
            local list = {}
            for _, cat in ipairs(CATEGORIES) do list[#list + 1] = category_rows(cat, data) end
            list[#list + 1] = terminal_rows(data)
            return list
        end),
    }
end

return {
    key = "default_apps",
    title = "Default apps",
    on_open = load,
    build = function()
        return {
            rows.heading("Opens with"),
            body(),
            rows.note("Apps whose desktop entry lists the type are offered. A pick is saved in "
                .. "~/.config/mimeapps.list; the terminal goes first in xdg-terminals.list.", 2),
        }
    end,
}
