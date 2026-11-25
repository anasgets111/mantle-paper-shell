-- A sheet of every doodle and the pinned apps as stickers, for checking icons by screenshot.
-- `mantle set icons.preview true` shows it centred on the active output; it takes no keyboard.
local theme = require("theme")
local k = require("lib.paper")
local icons = require("components.icons")
local apps = require("lib.apps")

local W, H = theme.icon_preview.width, theme.icon_preview.height
local SIZES = { theme.icon.sm, theme.icon.md, theme.icon.lg, theme.icon.xl }

local preview = state("icons.preview", false)

local function cell(name)
    local marks = {}
    for _, size in ipairs(SIZES) do marks[#marks + 1] = icons.doodle(name, size) end
    return column {
        width = theme.icon_preview.label_w,
        spacing = theme.spacing.xxs,
        children = {
            row { spacing = theme.spacing.sm, height = theme.control.row, children = marks },
            k.body(name, theme.font.mono_small, { foreground = theme.INK_SOFT }),
        },
    }
end

local glyphs = {}
for _, name in ipairs(icons.names) do glyphs[#glyphs + 1] = cell(name) end

-- Theme names (Tela circle here) and raw files, so round and odd silhouettes both show.
local FILES = {
    "/usr/share/icons/hicolor/scalable/apps/kitty.svg",
    "/usr/share/icons/hicolor/64x64/apps/zen-browser.png",
    "/usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg",
    "/usr/share/icons/hicolor/512x512/apps/zed.png",
    "~/.local/share/icons/com.t3tools.T3Code.desktop.png",
}

local function sticker_row(names, size)
    local children = {}
    for _, n in ipairs(names) do children[#children + 1] = icons.sticker(n, size) end
    return row { spacing = theme.spacing.roomy, children = children }
end

local pinned_icons = computed({ apps.pinned, mantle.applications }, function(ids, applications)
    local names = {}
    for _, id in ipairs(ids or {}) do
        local e = apps.by_id(applications, id)
        names[#names + 1] = e and e.icon or id
    end
    return names
end)

-- Paths the plain grid does not take: a signal name, `doodle_for` with an unknown fallback,
-- grain off and a fixed turn, and small stickers.
local live = state("icons.preview_name", "wifi-2")
local probes = row {
    spacing = theme.spacing.roomy,
    children = {
        icons.doodle(live, theme.icon.lg),
        icons.doodle_for("network-wireless-symbolic", theme.icon.lg),
        icons.doodle_for("audio-volume-high-symbolic", theme.icon.lg),
        icons.doodle_for("battery-good-charging-symbolic", theme.icon.lg),
        icons.doodle_for("system-shutdown-symbolic", theme.icon.lg),
        icons.doodle_for("battery-level-50-symbolic", theme.icon.lg),
        icons.doodle_for("starred-symbolic", theme.icon.lg),
        icons.sticker("kitty", theme.icon.xxl, { comic = false }),
        icons.sticker("kitty", theme.icon.xxl),
        icons.sticker("zen-browser", theme.icon.xxl, { rotate = 0 }),
    },
}

local stickers = column {
    spacing = theme.spacing.inset,
    children = pinned_icons:map(function(names)
        return {
            probes,
            row { spacing = theme.spacing.section, children = { sticker_row(names, theme.icon.lg), sticker_row(FILES, theme.icon.lg) } },
            row { spacing = theme.spacing.section, children = { sticker_row(names, theme.icon.xl), sticker_row(FILES, theme.icon.xl) } },
            row { spacing = theme.spacing.section, children = { sticker_row(names, theme.icon.xxl), sticker_row(FILES, theme.icon.xxl) } },
        }
    end),
}

return {
    surfaces = {
        panel {
            id = "paper-icons-preview",
            namespace = "paper-icons-preview",
            output = "active",
            layer = "overlay",
            exclusive_zone = "ignore",
            visible = preview,
            child = rect {
                padding = theme.spacing.page,
                children = {
                    k.sheet {
                        width = W,
                        height = H,
                        child = column {
                            padding = theme.spacing.panel,
                            spacing = theme.spacing.roomy,
                            children = {
                                k.hand("Icons", theme.icon_preview.title, { font_weight = theme.BOLD }),
                                row { width = "fill", wrap = true, spacing = theme.spacing.xs, line_spacing = theme.spacing.md, children = glyphs },
                                stickers,
                            },
                        },
                    },
                },
            },
        },
    },
}
