-- A sheet of every doodle and the pinned apps as stickers, for checking icons by screenshot.
-- `mantle set icons.preview true` shows it centred on the active output; it takes no keyboard.
local k = require("lib.paper")
local icons = require("components.icons")
local apps = require("lib.apps")

local W, H = 1560, 760
local SIZES = { 16, 20, 24, 32 }

local preview = state("icons.preview", false)

local function cell(name)
    local marks = {}
    for _, size in ipairs(SIZES) do marks[#marks + 1] = icons.doodle(name, size) end
    return column {
        width = 160,
        spacing = 4,
        children = {
            row { spacing = 8, height = 34, children = marks },
            k.body(name, 13, { foreground = k.INK_SOFT }),
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
    return row { spacing = 18, children = children }
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
    spacing = 18,
    children = {
        icons.doodle(live, 24),
        icons.doodle_for("network-wireless-symbolic", 24),
        icons.doodle_for("audio-volume-high-symbolic", 24),
        icons.doodle_for("battery-good-charging-symbolic", 24),
        icons.doodle_for("system-shutdown-symbolic", 24),
        icons.doodle_for("battery-level-50-symbolic", 24),
        icons.doodle_for("starred-symbolic", 24),
        icons.sticker("kitty", 48, { comic = false }),
        icons.sticker("kitty", 48),
        icons.sticker("zen-browser", 48, { rotate = 0 }),
    },
}

local stickers = column {
    spacing = 14,
    children = pinned_icons:map(function(names)
        return {
            probes,
            row { spacing = 40, children = { sticker_row(names, 24), sticker_row(FILES, 24) } },
            row { spacing = 40, children = { sticker_row(names, 32), sticker_row(FILES, 32) } },
            row { spacing = 40, children = { sticker_row(names, 48), sticker_row(FILES, 48) } },
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
                padding = 30,
                children = {
                    k.sheet {
                        width = W,
                        height = H,
                        child = column {
                            padding = 28,
                            spacing = 18,
                            children = {
                                k.hand("Icons", 40, { font_weight = 700 }),
                                row { width = "fill", wrap = true, spacing = 6, line_spacing = 12, children = glyphs },
                                stickers,
                            },
                        },
                    },
                },
            },
        },
    },
}
