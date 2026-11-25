-- The desktop picture: a path and a fit kept in `lib/store.lua`, drawn by `modules/desktop.lua` and
-- picked on Settings > Appearance. An unset path, or a file that is missing or fails to decode,
-- shows the paper default. `FOLDER` is listed live through `mantle.folders`; nothing scans it.
local k = require("lib.paper")
local util = require("lib.util")
local store = require("lib.store")

local W = {}

W.DEFAULT = k.DIR .. "/img/wallpaper.jpg"
W.FOLDER = "/mnt/Work/1Wallpapers/Main"
-- `image.fit` values with the picker's labels.
W.FITS = { { "cover", "Fill" }, { "contain", "Fit" }, { "stretch", "Stretch" } }

mantle.folders:watch(W.FOLDER, { "jpg", "jpeg", "png", "webp", "gif", "bmp" })

-- The listing: `nil` until the first push, then `{ entries, error?, ready }`.
W.folder = mantle.folders:map(function(f) return f.watched and f.watched[W.FOLDER] end)

-- The wallpaper image's load; a failed decode marks its path broken until something else is picked.
W.status = image_status("paper.wallpaper")
local broken = state("paper.wallpaper.broken", "")

W.path = computed({ store.wallpaper_path, broken }, function(path, bad)
    if path == "" or path == bad then return W.DEFAULT end
    return path
end, W.DEFAULT)

W.status:map(function(s) return s.state end, "empty"):on_change(function(now)
    local path = W.path:get()
    if now == "failed" and path ~= W.DEFAULT then broken:set(path) end
end)

W.fit = store.wallpaper_fit:map(function(fit)
    return util.find(W.FITS, function(f) return f[1] == fit end) and fit or "cover"
end, "cover")

function W.set(path)
    broken:set("")
    store:set("wallpaper_path", path == W.DEFAULT and "" or path)
end

function W.set_fit(fit)
    store:set("wallpaper_fit", fit)
end

return W
