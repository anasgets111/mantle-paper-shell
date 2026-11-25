-- The desktop picture, per output: `store.wallpapers` holds a `default` entry for every display and
-- an override per output name, each `{ path?, fit? }`. A field an output leaves out comes from the
-- default, then from the single `wallpaper_path`/`wallpaper_fit` the shell kept before, then the
-- paper default. Drawn by `modules/desktop.lua` and the lock cover, picked on Settings > Appearance.
-- A missing file or a failed decode shows the paper default. The picker's folder (`W.folder_path`,
-- set on that page) is listed live through `mantle.folders`; nothing scans it.
local STORE = require("lib.paths").state("state.json")
local k = require("lib.paper")
local util = require("lib.util")
local store = require("lib.store")

local W = {}

W.DEFAULT = k.DIR .. "/img/wallpaper.jpg"
local HOME = os.getenv("HOME") or ""
-- The picker's folder until one is chosen: `$PAPER_WALLPAPERS`, else ~/Pictures/Wallpapers.
W.DEFAULT_FOLDER = os.getenv("PAPER_WALLPAPERS") or (HOME .. "/Pictures/Wallpapers")
-- `image.fit` values with the picker's labels.
W.FITS = { { "cover", "Fill" }, { "contain", "Fit" }, { "stretch", "Stretch" } }

W.folder_path = store.wallpaper_folder:map(function(f)
    return (f and f ~= "") and f or W.DEFAULT_FOLDER
end)

local watching
local function watch(path)
    if path == watching then return end
    if watching then mantle.folders:unwatch(watching) end
    watching = path
    mantle.folders:watch(path, { "jpg", "jpeg", "png", "webp", "gif", "bmp" })
end
W.folder_path:on_change(watch)
watch(W.folder_path:get())

-- The listing: `nil` until the first push, then `{ entries, error?, ready }`.
W.folder = computed({ mantle.folders, W.folder_path }, function(f, path)
    return f and f.watched and f.watched[path]
end)

-- Choose the picker's folder: absolute or `~/...`; `""` goes back to the default. False when refused.
function W.set_folder(path)
    path = (path or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if path == "~" or path:sub(1, 2) == "~/" then path = HOME .. path:sub(2) end
    if #path > 1 then path = path:gsub("/+$", "") end
    if path ~= "" and path:sub(1, 1) ~= "/" then return false end
    store:set("wallpaper_folder", path == W.DEFAULT_FOLDER and "" or path)
    return true
end

-- Paths that failed to decode, as `{ [path] = true }`, until that path is picked again.
local broken = state("paper.wallpaper.broken_paths", {})

local function is_fit(fit)
    return util.find(W.FITS, function(f) return f[1] == fit end) ~= nil
end

-- What an output shows: `output` nil (or unknown) reads the default entry. Pure, for the checks.
function W.resolve(all, legacy_path, legacy_fit, output, bad)
    all = all or {}
    local own, default = (output and all[output]) or {}, all.default or {}
    local path = own.path or default.path or legacy_path or ""
    local fit = own.fit or default.fit or legacy_fit
    if path == "" or (bad or {})[path] then path = W.DEFAULT end
    return path, is_fit(fit) and fit or "cover"
end

local inputs = { store.wallpapers, store.wallpaper_path, store.wallpaper_fit, broken }
local paths, fits = {}, {}

-- The picture and fit `output` shows; nil for every display's default.
function W.path_of(output)
    local key = output or ""
    paths[key] = paths[key] or computed(inputs, function(all, lp, lf, bad)
        return (W.resolve(all, lp, lf, output, bad))
    end, W.DEFAULT)
    return paths[key]
end

function W.fit_of(output)
    local key = output or ""
    fits[key] = fits[key] or computed(inputs, function(all, lp, lf)
        local _, fit = W.resolve(all, lp, lf, output, {})
        return fit
    end, "cover")
    return fits[key]
end

-- What `target` (a signal of an output name, `""` for every display) shows, as "path\nfit": a
-- string, so a map of it changes only when the answer does.
function W.shown(target)
    return computed({ target, store.wallpapers, store.wallpaper_path, store.wallpaper_fit, broken },
        function(t, all, lp, lf, bad)
            local path, fit = W.resolve(all, lp, lf, t ~= "" and t or nil, bad)
            return path .. "\n" .. fit
        end, W.DEFAULT .. "\ncover")
end

-- Each output's image load: a failed decode marks its path broken for every output showing it.
local statuses = {}
function W.status_of(output)
    if statuses[output] then return statuses[output] end
    local status = image_status("paper.wallpaper." .. output)
    status:map(function(s) return s.state end, "empty"):on_change(function(now)
        local path = W.path_of(output):get()
        if now == "failed" and path ~= W.DEFAULT then broken:set(util.with(broken:get(), path, true)) end
    end)
    statuses[output] = status
    return status
end

-- Output names with their own entry.
W.overrides = store.wallpapers:map(function(all)
    local list = {}
    for name in pairs(all or {}) do
        if name ~= "default" then list[#list + 1] = name end
    end
    table.sort(list)
    return list
end, {})

-- The table reads its defaults until the file's first push: a write before then would replace the
-- stored entries. Once loaded, the single pre-per-output choice moves into `default`.
local function loaded()
    local s = mantle.storage:get()
    return s ~= nil and s.contents ~= nil and s.contents[STORE] ~= nil
end
local function migrate()
    if not loaded() or (store.wallpapers:get() or {}).default then return end
    store:set("wallpapers", util.with(store.wallpapers:get() or {}, "default", {
        path = store.wallpaper_path:get() or "",
        fit = store.wallpaper_fit:get() or "cover",
    }))
end
mantle.storage:on_change(migrate)
migrate()

-- Set `field` for `target` (an output name), or for every display (nil): the default changes and
-- every output's own value of that field is dropped, so all displays agree.
local function write(target, field, value)
    local all = {}
    for name, entry in pairs(store.wallpapers:get() or {}) do all[name] = entry end
    if target then
        all[target] = util.with(all[target] or {}, field, value)
    else
        all.default = util.with(all.default or {}, field, value)
        for name, entry in pairs(all) do
            if name ~= "default" then
                local rest = util.with(entry, field, nil)
                all[name] = next(rest) and rest or nil
            end
        end
    end
    store:set("wallpapers", all)
end

function W.set(path, target)
    if (broken:get() or {})[path] then broken:set(util.with(broken:get(), path, nil)) end
    write(target, "path", path == W.DEFAULT and "" or path)
end

function W.set_fit(fit, target)
    if is_fit(fit) then write(target, "fit", fit) end
end

return W
