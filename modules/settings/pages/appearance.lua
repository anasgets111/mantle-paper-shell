-- Appearance page under two tabs: light or dark for apps, and the desktop background
-- (`pages/background.lua`).
-- `lib/scheme.lua` switches apps' light/dark pair (GTK, libadwaita, Qt, the portal). The paper shell
-- stays light.
local k = require("lib.paper")
local c = require("components.controls")
local rows = require("modules.settings.rows")
local scheme = require("lib.scheme")
local background = require("modules.settings.pages.background")

local SCHEMES = {
    { "light", "Light", k.CARD, k.INK },
    { "dark", "Dark", "#3B3732", "#E9E1CF" },
}

local current = scheme.current
local choose = scheme.set

-- A small sheet showing a window in that scheme: a title bar and a few lines of text.
local function swatch(s, i)
    local key, name, paper, ink = s[1], s[2], s[3], s[4]
    local hovered = hover("settings.appearance." .. key)
    local lines = {}
    for n = 0, 3 do
        lines[#lines + 1] = { op = "M", points = { 18, 44 + n * 14 } }
        lines[#lines + 1] = { op = "L", points = { 18 + (n % 2 == 0 and 110 or 80), 44 + n * 14 } }
    end
    return rect {
        hover = hovered,
        accessible_name = name,
        cursor = "pointer",
        on_click = function() choose(key) end,
        padding = 10,
        translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
        animate = { translate = { duration = 140, easing = "out_cubic" } },
        children = {
            rect {
                rotate = i == 1 and -1.2 or 1,
                children = {
                    k.sheet {
                        width = 170,
                        height = 112,
                        seed = 60 + i,
                        depth = 3,
                        color = paper,
                        shadows = k.lift(hovered),
                        child = rect {
                            children = {
                                k.stroke_path(170, 112, {
                                    { op = "M", points = { 10, 26 } }, { op = "L", points = { 160, 26 } },
                                }, ink, 1.3),
                                k.stroke_path(170, 112, lines, ink, 2),
                                rect { padding = { left = 12, top = 3 }, children = { k.hand(name, 24, { foreground = ink }) } },
                            },
                        },
                    },
                },
            },
            rect {
                visible = current:map(function(v) return v == key end),
                -- 12 px of loop round the 170 x 112 sheet, which sits 10 px inside this box.
                translate = { x = -12, y = -12 },
                children = { c.pencil_loop(194, 136, 20 + i) },
            },
        },
    }
end

return {
    key = "appearance",
    title = "Appearance",
    build = function()
        local options = {}
        for i, s in ipairs(SCHEMES) do options[i] = { s[1], s[2] } end
        local strip, tab = rows.tabs("appearance", { "Style", "Background" })
        local style = {
            rows.heading("Style for apps"),
            row { height = rows.PITCH * 5, spacing = 40, padding = { top = 10, left = 6 }, children = { swatch(SCHEMES[1], 1), swatch(SCHEMES[2], 2) } },
            rows.line({
                c.radio_group {
                    id = "settings.appearance.scheme",
                    options = options,
                    value = current,
                    on_select = choose,
                },
            }),
            rows.note("GTK and libadwaita apps follow this through the desktop portal. The paper shell keeps "
                .. "its light desk for now.", 2),
        }
        return { strip, rows.pane(tab, 1, style), rows.pane(tab, 2, background()) }
    end,
}
