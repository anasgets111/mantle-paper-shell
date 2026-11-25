-- Light or dark for apps. Ported from the old config's `lib/app_colours.lua`, preset path only: the
-- Catppuccin pair (Latte light, Mocha dark) with the mauve accent fills `templates/` for the same
-- targets that code wrote: the alternating `Mantle-A`/`Mantle-B` GTK theme and KDE colour scheme
-- (with qt6ct pointed at it), libadwaita's `gtk-4.0/mantle-colours.css`, and gsettings
-- `color-scheme` for the portal. Loading this writes nothing; only `scheme.set` does.
--
-- An app reloads a GTK3 theme or KDE scheme only when its name changes, so each switch fills the
-- copy not in use and points at it. Writes skip unchanged bytes.
local store = require("lib.store")

local scheme = {}

local HOME = os.getenv("HOME") or ""
local TEMPLATES = mantle.config_dir .. "/templates/"
local INTERFACE = "org.gnome.desktop.interface"
local QT6CT = "~/.config/qt6ct/qt6ct.conf"
local SCHEMES = HOME .. "/.local/share/color-schemes/"
local THEMES = HOME .. "/.local/share/themes/"
local GTK4_COLOURS = "~/.config/gtk-4.0/mantle-colours.css"
-- GTK4 re-parses `gtk.css` and its imports when a portal preference changes. Reduced motion is the
-- one whose 50 ms flip shows nothing; detached, so a shell reload cannot strand the user's value.
local LIBADWAITA_REFRESH = [[k="org.gnome.desktop.a11y.interface reduced-motion"; v=$(gsettings get $k)
gsettings set $k "$([ "$v" = "'reduce'" ] && echo no-preference || echo reduce)"; sleep 0.05; gsettings set $k "$v"]]

-- Catppuccin Mocha and Latte, catppuccin/palette v1.8.0.
local PALETTE = {
    dark = { base = "#1e1e2e", mantle = "#181825", crust = "#11111b", surface0 = "#313244", surface1 = "#45475a", overlay0 = "#6c7086", subtext0 = "#a6adc8", text = "#cdd6f4", red = "#f38ba8", yellow = "#f9e2af", green = "#a6e3a1", mauve = "#cba6f7", pink = "#f5c2e7" },
    light = { base = "#eff1f5", mantle = "#e6e9ef", crust = "#dce0e8", surface0 = "#ccd0da", surface1 = "#bcc0cc", overlay0 = "#9ca0b0", subtext0 = "#6c6f85", text = "#4c4f69", red = "#d20f39", yellow = "#df8e1d", green = "#40a02b", mauve = "#8839ef", pink = "#ea76cb" },
}

--- What apps get now: the portal's answer, else the stored choice (the portal may say "default").
scheme.current = computed({ mantle.appearance, store.colour_scheme }, function(a, stored)
    return (a and a.color_scheme ~= "default") and a.color_scheme or stored
end, "light")

local function channels(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

-- The ink with the higher WCAG contrast on the opaque `hex`.
local function text_contrast(hex, dark_text, light_text)
    local function luminance(r, g, b)
        local function linear(byte)
            local c = byte / 255
            return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
        end
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    end
    local fill = luminance(channels(hex))
    local function ratio(ink)
        local own = luminance(channels(ink))
        return (math.max(own, fill) + 0.05) / (math.min(own, fill) + 0.05)
    end
    return ratio(dark_text) >= ratio(light_text) and dark_text or light_text
end

-- Light mode caps a text colour at tone 55: Latte's yellow and green read under 3:1 on a light ground.
local function readable(hex, dark)
    local hct = palette.hct(hex)
    if dark or hct.tone <= 55 then return hex end
    return palette.from_hct { hue = hct.hue, chroma = hct.chroma, tone = 55 }
end

-- The roles the three templates use, as the old `theme.preset_roles` and `derive` gave them.
local function roles_for(dark)
    local p = PALETTE[dark and "dark" or "light"]
    local roles = {
        primary = readable(p.mauve, dark),
        tertiary = readable(p.pink, dark),
        surface = p.base,
        surface_container_lowest = dark and p.mantle or p.base,
        surface_container_low = p.mantle,
        surface_container = p.mantle,
        surface_container_high = dark and p.surface0 or p.crust,
        surface_container_highest = dark and p.surface1 or p.surface0,
        on_surface = p.text,
        on_surface_variant = p.subtext0,
        outline = readable(p.overlay0, dark),
        red = readable(p.red, dark),
        yellow = readable(p.yellow, dark),
        green = readable(p.green, dark),
        adw = dark and "adw-gtk3-dark" or "adw-gtk3",
    }
    roles.on_primary = text_contrast(roles.primary, dark and p.base or p.text, dark and p.text or p.base)
    for _, name in ipairs({ "red", "yellow", "green" }) do
        roles["on_" .. name] = text_contrast(roles[name], dark and roles.surface or roles.on_surface,
            dark and roles.on_surface or roles.surface)
    end
    return roles
end

-- `{{role}}` is `#RRGGBB`, `{{role.rgb}}` is `r, g, b` (KDE). A role that is not a colour is inserted as is.
local function render(template, roles)
    return (template:gsub("{{%s*([%w_]+)%.?(%w*)%s*}}", function(role, format)
        local hex = roles[role]
        if not hex or hex:sub(1, 1) ~= "#" then return hex end
        if format == "rgb" then return string.format("%d, %d, %d", channels(hex)) end
        return hex
    end))
end

--- Every file's text for `mode`, from the three templates' texts: `{ gtk3, gtk4, colours, qt }`.
--- Pure, so a test can compare it with what is on disk.
function scheme.render(mode, templates)
    local roles = roles_for(mode == "dark")
    local colours = render(templates["gtk4-colours.css"], roles)
    local defines = {}
    for name, value in colours:gmatch("%-%-([%w-]+): ([^;]+);") do
        defines[#defines + 1] = string.format("@define-color %s %s;", (name:gsub("-", "_")), value)
    end
    roles.adw_colours = table.concat(defines, "\n")
    roles.gtk = "gtk-3.0"
    local gtk3 = render(templates["gtk-theme.css"], roles)
    roles.gtk = "gtk-4.0"
    local gtk4 = render(templates["gtk-theme.css"], roles)
    return { gtk3 = gtk3, gtk4 = gtk4, colours = colours, qt = render(templates["mantle.colors"], roles) }
end

-- Writes only a changed value: every write makes Electron apps redraw.
local function gsettings(key, value, after)
    process.capture("gsettings", { "get", INTERFACE, key }, function(current)
        if current and current:match("^'(.*)'") == value then return after() end
        process.capture("gsettings", { "set", INTERFACE, key, value }, after)
    end)
end

-- Writes `{ path, text }` pairs in order, then `done(true)`; a failed write stops with `done(false)`,
-- so nothing is pointed at a half-written copy.
local function write_files(files, done, index)
    index = index or 1
    if not files[index] then return done(true) end
    file.write(files[index][1], files[index][2], nil, function(_, err)
        if err then
            log.warn("scheme:", err)
            return done(false)
        end
        write_files(files, done, index + 1)
    end)
end

-- `in_use` names the copy apps hold; when `path_of(that copy)` already holds `text` it stays, else
-- `write(other, done)` fills the other. `done(name)` gets the copy to point at, or nil on failure.
local function alternate(in_use, path_of, text, write, done)
    local current = in_use and in_use:match("Mantle%-[AB]")
    local other = current == "Mantle-A" and "Mantle-B" or "Mantle-A"
    local function switch(old)
        if old == text then return done(current) end
        write(other, function(ok) done(ok and other or nil) end)
    end
    if current then file.read(path_of(current), switch) else switch() end
end

local function write_gtk_theme(out, done)
    process.capture("gsettings", { "get", INTERFACE, "gtk-theme" }, function(in_use)
        alternate(in_use, function(name) return THEMES .. name .. "/gtk-3.0/gtk.css" end, out.gtk3, function(name, written)
            local dir = THEMES .. name
            -- `gtk-3.0/gtk.css` last: it is the file a later run compares.
            write_files({
                { dir .. "/gtk-3.0/gtk-dark.css", out.gtk3 },
                { dir .. "/gtk-4.0/gtk-dark.css", out.gtk4 },
                { dir .. "/gtk-4.0/gtk.css", out.gtk4 },
                { dir .. "/gtk-3.0/gtk.css", out.gtk3 },
            }, written)
        end, function(name)
            if name then gsettings("gtk-theme", name, done) else done() end
        end)
    end)
end

-- qt6ct's directory watch sees the atomic rewrite of its config.
local function write_qt_scheme(text, done)
    file.read(QT6CT, function(conf, err)
        if not conf and not tostring(err):match("No such file") then
            log.warn("scheme:", err)
            return done()
        end
        conf = conf or ""
        alternate(conf:match("color_scheme_path=[^\n]*"), function(name) return SCHEMES .. name .. ".colors" end, text,
            function(name, written)
                local path = "color_scheme_path=" .. SCHEMES .. name .. ".colors"
                local updated, count = conf:gsub("color_scheme_path=[^\n]*", path, 1)
                -- Breeze paints with the palette; a Kvantum theme keeps its own colours.
                updated = updated:gsub("\nstyle=kvantum[^\n]*", "\nstyle=Breeze"):gsub("custom_palette=false", "custom_palette=true")
                if count == 0 then
                    updated = updated .. "\n[Appearance]\n" .. path .. "\ncustom_palette=true\nstyle=Breeze\n"
                end
                write_files({ { SCHEMES .. name .. ".colors", text }, { QT6CT, updated } }, written)
            end, done)
    end)
end

local function read_templates(done)
    local names, texts = { "gtk-theme.css", "gtk4-colours.css", "mantle.colors" }, {}
    local function next_one(i)
        if not names[i] then return done(texts) end
        file.read(TEMPLATES .. names[i], function(text, err)
            if not text then
                log.warn("scheme:", err)
                return done(nil)
            end
            texts[names[i]] = text
            next_one(i + 1)
        end)
    end
    next_one(1)
end

-- One run at a time; a `set` during a run is applied after it.
local running, wanted = false, nil

local function apply(mode)
    running = true
    local function finish()
        running = false
        if wanted and wanted ~= mode then apply(wanted) end
    end
    read_templates(function(templates)
        if not templates then return finish() end
        local out = scheme.render(mode, templates)
        local pending, gtk4_changed = 3, false
        local function settle()
            pending = pending - 1
            if pending > 0 then return end
            gsettings("color-scheme", "prefer-" .. mode, function()
                if gtk4_changed then process.detach("sh", { "-c", LIBADWAITA_REFRESH }) end
                finish()
            end)
        end
        write_gtk_theme(out, settle)
        write_qt_scheme(out.qt, settle)
        file.write(GTK4_COLOURS, out.colours, nil, function(changed, err)
            if err then log.warn("scheme:", err) end
            gtk4_changed = changed == true
            settle()
        end)
    end)
end

--- Switch apps to `mode` ("light" or "dark") and remember it.
function scheme.set(mode)
    if mode ~= "light" and mode ~= "dark" then return end
    store:set("colour_scheme", mode)
    wanted = mode
    if not running then apply(mode) end
end

-- `mantle call scheme.set dark` for a keybind.
action("scheme.set", function(mode) scheme.set(mode) end)

return scheme
