-- Appearance > Background: the desktop picture as a wall of photo cuts, the paper default first and
-- then every picture in `wallpaper.FOLDER`, plus its fit. A click or Enter applies a picture; the
-- applied one has a hatched border and a tick, the keyboard's one a pencil loop. Arrows move
-- between photos. The choice lives in `lib/wallpaper.lua`.
local k = require("lib.paper")
local c = require("components.controls")
local util = require("lib.util")
local rows = require("modules.settings.rows")
local tips = require("modules.settings.tips")
local icons = require("components.icons")
local wallpaper = require("lib.wallpaper")

-- Four photos to a 672 px row: 152 px cells 14 px apart. A cell is four rules tall.
local COLUMNS, CELL_W, GAP = 4, 152, 14
local IMG_W, IMG_H, BORDER = 124, 70, 6
local CUT_W, CUT_H = IMG_W + 2 * BORDER, IMG_H + 2 * BORDER
local CELL_H = rows.PITCH * 4

local function slot(path) return "settings.wallpaper." .. path end

-- Left and Right step one photo, Up and Down one row; focus follows, so the pencil loop moves.
local function step(paths, i, key)
    local by = ({ Left = -1, Right = 1, Up = -COLUMNS, Down = COLUMNS })[key.name]
    if not by then return false end
    local to = paths[i + by]
    if to then focus_target(slot(to)):request() end
    return true
end

local function photo(entry, i, paths)
    local name = slot(entry.path)
    local hovered = hover(name)
    local keyed = focus_visible(name)
    local chosen = wallpaper.path:map(function(p) return p == entry.path end, false)
    local r = k.rng(#entry.name + i)
    local cut = elided(name .. ".label")
    local label = tips.wrap(k.body(entry.label, 16, {
        width = CELL_W - 12,
        elide = "end",
        elided = cut,
        text_align = "center",
        foreground = k.INK_SOFT,
    }), "settings.tip.wallpaper." .. entry.path, function()
        return cut:get() and entry.label or ""
    end)
    return column {
        width = CELL_W,
        height = CELL_H,
        spacing = 2,
        children = {
            rect {
                width = CELL_W,
                padding = { left = (CELL_W - CUT_W) / 2, top = 12, bottom = 8 },
                hover = hovered,
                accessible_name = entry.label,
                cursor = "pointer",
                on_click = function() wallpaper.set(entry.path) end,
                focus_target = focus_target(name),
                focus_visible = keyed,
                focus_ring = false,
                on_key = function(key) return step(paths, i, key) end,
                children = {
                    rect {
                        rotate = (r() - 0.5) * 4,
                        translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
                        animate = { translate = { duration = 140, easing = "out_cubic" } },
                        children = {
                            -- Card-stock mount, hatched blue while it is the desktop's picture.
                            rect {
                                width = CUT_W,
                                height = CUT_H,
                                shape = k.torn(CUT_W, CUT_H, 300 + i, 2),
                                background = k.CARD_LIGHT,
                                shadows = k.lift(hovered),
                                animate = { shadows = { duration = 160 } },
                                effect = chosen:map(function(on)
                                    return k.paper_fx { rim = 1.2, hatch = on and 1 or 0, hatch_spacing = 3.2 }
                                end),
                            },
                            rect {
                                padding = BORDER,
                                children = {
                                    image {
                                        source = entry.path,
                                        width = IMG_W,
                                        height = IMG_H,
                                        fit = "cover",
                                        async = true,
                                    },
                                },
                            },
                            k.tape { width = 44, height = 14, translate = { y = -7 }, rotate = (r() - 0.5) * 10, seed = i },
                            -- The tick: a punched disc on the corner, so "chosen" never rests on colour.
                            rect {
                                align_h = "end",
                                translate = { x = 9, y = -9 },
                                children = chosen:map(function(on)
                                    if not on then return {} end
                                    return {
                                        k.sheet {
                                            width = 24,
                                            height = 24,
                                            shape = k.torn_circle(24, i),
                                            color = k.CARD,
                                            shadows = k.SHADOW.rest,
                                            child = util.with(icons.doodle("check", 16, k.BLUE), "align_h", "center"),
                                        },
                                    }
                                end),
                            },
                        },
                    },
                    -- Built when shown: 60 tiles' hidden loops and ticks cost more than the photos.
                    rect {
                        translate = { x = -8, y = -8 },
                        children = keyed:map(function(on)
                            return on and { c.pencil_loop(CUT_W + 16, CUT_H + 16, 70 + i) } or {}
                        end),
                    },
                },
            },
            label,
        },
    }
end

-- The default first, then the folder's pictures; rebuilt only when the listing's paths change.
local function entries(folder)
    local list = { { path = wallpaper.DEFAULT, name = "wallpaper.jpg", label = "Paper desk" } }
    local stems = {}
    for _, e in ipairs(folder and folder.entries or {}) do
        local stem = e.name:gsub("%.[^.]+$", "")
        stems[stem] = (stems[stem] or 0) + 1
        list[#list + 1] = { path = e.path, name = e.name, label = stem }
    end
    -- Two files that differ only by extension keep it, so their labels differ.
    for _, e in ipairs(list) do
        if stems[e.label] and stems[e.label] > 1 then e.label = e.name end
    end
    return list
end

local function grid()
    local shape = wallpaper.folder:map(function(f)
        return (f.ready and "r" or "") .. (f.error or "") .. "#" .. rows.key(f.entries, { "path" })
    end, "")
    return column {
        width = "fill",
        children = shape:map(function()
            local folder = wallpaper.folder:get()
            local list = entries(folder)
            local paths, cells = {}, {}
            for i, e in ipairs(list) do paths[i] = e.path end
            for i, e in ipairs(list) do cells[i] = photo(e, i, paths) end
            local out = { row { width = "fill", wrap = true, spacing = GAP, children = cells } }
            local empty
            if not folder or not folder.ready then
                empty = "Reading " .. wallpaper.FOLDER .. "…"
            elseif folder.error then
                empty = "Can't open " .. wallpaper.FOLDER .. ": " .. folder.error
            elseif #folder.entries == 0 then
                empty = "No pictures in " .. wallpaper.FOLDER .. " yet."
            end
            if empty then out[#out + 1] = rows.note(empty, 1) end
            return out
        end),
    }
end

return function()
    return {
        rows.heading("Background"),
        rows.line({
            rows.label("Scale", { width = 90 }),
            c.radio_group {
                id = "settings.appearance.fit",
                options = wallpaper.FITS,
                value = wallpaper.fit,
                on_select = wallpaper.set_fit,
            },
        }),
        grid(),
        rows.note("Every screen shows the same picture.", 1),
    }
end
