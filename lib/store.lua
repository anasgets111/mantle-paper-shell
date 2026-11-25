-- Restart-persistent user choices in one file under ~/.local/state/paper-shell. Write with
-- `store:set(key, util.with(store[key]:get(), k, v))`, never by mutating a read table.
local paths = require("lib.paths")
return persistent_table {
    path = paths.state("state.json"),
    defaults = {
        -- Desktop ids pinned to the taskbar, in order. Shared with the start menu's "Pin to taskbar".
        pinned = { "kitty", "zen", "org.gnome.Nautilus", "dev.zed.Zed", "com.t3tools.T3Code" },
        -- Desktop ids pinned in the start menu's Pinned grid, in order.
        menu_pinned = { "zen", "kitty", "org.gnome.Nautilus", "dev.zed.Zed" },
        -- Launches by desktop id: `{ count = n, last = os.time() }`. Ranks search and "Frequent".
        app_usage = {},
        -- Taskbar: show only windows on the current workspace / this output.
        taskbar_isolate_workspace = false,
        taskbar_isolate_output = true,
        -- `"light"` or `"dark"`, pushed to apps through gsettings.
        colour_scheme = "light",
        -- Notification centre: apps muted by desktop entry or name.
        muted_apps = {},
        -- Notification history kept across restarts (newest first, at most 100).
        notification_history = {},
        -- Desktop pictures (`lib/wallpaper.lua`): `{ default = { path, fit }, [output] = { path?, fit? } }`,
        -- a path `""` for the paper default.
        wallpapers = {},
        -- The single picture and fit from before per-output pictures, read once into `wallpapers.default`.
        wallpaper_path = "",
        wallpaper_fit = "cover",
        -- The Background picker's folder; `""` for `$PAPER_WALLPAPERS`, else ~/Pictures/Wallpapers.
        wallpaper_folder = "",
    },
}
