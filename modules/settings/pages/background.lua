-- Appearance > Background: the desktop picture as a wall of photo cuts, the paper default first and
-- then every picture in `wallpaper.FOLDER`, plus its fit. A click or Enter applies a picture; the
-- applied one has a hatched border and a tick, the keyboard's one a pencil loop. Arrows move
-- between photos. With more than one screen a Display dropdown picks whose picture the grid sets:
-- one output, or all of them. The choices live in `lib/wallpaper.lua`.
local k = require("lib.paper")
local c = require("components.controls")
local util = require("lib.util")
local rows = require("modules.settings.rows")
local tips = require("modules.settings.tips")
local icons = require("components.icons")
local wallpaper = require("lib.wallpaper")
local ui_state = require("lib.ui_state")

-- Four photos to a 672 px row: 152 px cells 14 px apart. A cell is four rules tall; the grid shows
-- three rows and scrolls the rest.
local COLUMNS, CELL_W, GAP = 4, 152, 14
local IMG_W, IMG_H, BORDER = 124, 70, 6
local CUT_W, CUT_H = IMG_W + 2 * BORDER, IMG_H + 2 * BORDER
local CELL_H, VISIBLE_ROWS = rows.PITCH * 4, 3
local GRID = scroll("settings.wallpaper.grid")
-- The grid opens at its top, as every page does, and again whenever Appearance's tab changes.
ui_state.modal_showing("settings"):on_change(function(open)
    if open then GRID:scroll_to(0) end
end)
state("settings.appearance.tab", 1):on_change(function() GRID:scroll_to(0) end)

local function slot(path) return "settings.wallpaper." .. path end

-- The display the grid and fit act on: an output name, or "" for every display. A name that is not
-- a connected screen, or a single screen, means every display, so nothing is set out of sight.
local picked = state("settings.wallpaper.target", "")
local target = computed({ picked, mantle.screens }, function(name, screens)
    if #(screens or {}) < 2 then return "" end
    return util.find(screens, function(s) return s.name == name end) and name or ""
end, "")
local function target_name()
    local t = target:get()
    return t ~= "" and t or nil
end
local shown = wallpaper.shown(target)
local shown_path = shown:map(function(s) return s:match("^(.-)\n") end, wallpaper.DEFAULT)
local shown_fit = shown:map(function(s) return s:match("\n(.*)$") end, "cover")

-- The default first, then the folder's pictures, each with its place in the grid.
local function entries(folder)
    local list = { { path = wallpaper.DEFAULT, name = "wallpaper.jpg", label = "Paper desk" } }
    local stems = {}
    for _, e in ipairs(folder and folder.entries or {}) do
        local stem = e.name:gsub("%.[^.]+$", "")
        stems[stem] = (stems[stem] or 0) + 1
        list[#list + 1] = { path = e.path, name = e.name, label = stem }
    end
    for i, e in ipairs(list) do
        e.index = i
        -- Two files that differ only by extension keep it, so their labels differ.
        if stems[e.label] and stems[e.label] > 1 then e.label = e.name end
    end
    return list
end

local listed = wallpaper.folder:map(entries, entries(nil))

-- Left and Right step one photo, Up and Down one row. A request only counts inside the key
-- callback; the list keeps a viewport of rows built past each edge, so the neighbouring row
-- exists, and the reveal scrolls it into view on the same pass.
local function step(i, key)
    local by = ({ Left = -1, Right = 1, Up = -COLUMNS, Down = COLUMNS })[key.name]
    if not by then return false end
    local to = listed:get()[i + by]
    if to then
        GRID:reveal(math.ceil(to.index / COLUMNS))
        focus_target(slot(to.path)):request()
    end
    return true
end

-- Mount outlines by cell index: a rebuilt row reuses them instead of tearing new paper.
local MOUNTS = {}
local function mount(i)
    MOUNTS[i] = MOUNTS[i] or k.torn(CUT_W, CUT_H, 300 + i, 2)
    return MOUNTS[i]
end

local function photo(entry)
    local i = entry.index
    local name = slot(entry.path)
    local hovered = hover(name)
    local keyed = focus_visible(name)
    local chosen = shown_path:map(function(p) return p == entry.path end, false)
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
                on_click = function() wallpaper.set(entry.path, target_name()) end,
                focus_target = focus_target(name),
                focus_visible = keyed,
                focus_ring = false,
                on_key = function(key) return step(i, key) end,
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
                                shape = mount(i),
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
                    -- Built when shown: a hidden loop and tick on every photo cost more than the photo.
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

-- One keyed, scrolling list of rows: only rows near the viewport are built, and a row is rebuilt
-- only when its own paths change.
-- A 12 px fade at an edge only while photos lie past it: at the top the first row's tape and
-- tick show whole. Keyed by "top,bottom" so scrolling rebuilds the mask only at the ends.
local FADE = 12
local edges = computed({ GRID, listed }, function(offset, l)
    local rows_n = math.ceil(#l / COLUMNS)
    local max = math.max(0, rows_n - VISIBLE_ROWS) * CELL_H
    return ((offset or 0) > 1 and "1" or "0") .. ((offset or 0) < max - 1 and "1" or "0")
end, "00")
local fade = edges:map(function(e)
    local h = VISIBLE_ROWS * CELL_H
    local top, bottom = e:sub(1, 1) == "1", e:sub(2, 2) == "1"
    return {
        gradient = "linear",
        angle = 180,
        stops = {
            { 0, top and "#00000000" or "#000000" }, { FADE / h, "#000000" },
            { 1 - FADE / h, "#000000" }, { 1, bottom and "#00000000" or "#000000" },
        },
    }
end)

local function grid()
    local empty = wallpaper.folder:map(function(f)
        if not (f and f.ready) then return "Reading " .. wallpaper.FOLDER .. "…" end
        if f.error then return "Can't open " .. wallpaper.FOLDER .. ": " .. f.error end
        if #f.entries == 0 then return "No pictures in " .. wallpaper.FOLDER .. " yet." end
        return ""
    end, "")
    return column {
        width = "fill",
        children = {
            -- Rows scroll under the fade instead of a hard cut (a list takes no mask).
            rect {
                width = "fill",
                mask = fade,
                children = {
                    list {
                        width = "fill",
                        height = listed:map(function(l)
                            return math.min(VISIBLE_ROWS, math.ceil(#l / COLUMNS)) * CELL_H
                        end),
                        scroll = GRID,
                        items = listed:map(function(l) return util.chunk(l, COLUMNS) end),
                        key = function(cells)
                            local paths = {}
                            for j, e in ipairs(cells) do paths[j] = e.path end
                            return table.concat(paths, "\n")
                        end,
                        each = function(cells)
                            local out = {}
                            for j, e in ipairs(cells) do out[j] = photo(e) end
                            return row { spacing = GAP, children = out }
                        end,
                    },
                },
            },
            column {
                width = "fill",
                visible = empty:map(function(t) return t ~= "" end),
                children = { rows.note(empty, 1) },
            },
        },
    }
end

-- The Display row, shown only with two or more screens: "All displays" or one output. Under "All
-- displays", a hint names the outputs whose own picture or fit a pick will replace.
local function display_row()
    local options = mantle.screens:map(function(screens)
        local list = { { "", "All displays" } }
        for _, s in ipairs(screens or {}) do
            local model = s.model ~= "" and s.model or nil
            list[#list + 1] = { s.name, model and (s.name .. " · " .. model) or s.name }
        end
        return list
    end, { { "", "All displays" } })
    local hint = computed({ target, wallpaper.overrides }, function(t, names)
        if t ~= "" or #names == 0 then return "" end
        return "replaces " .. table.concat(names, ", ") .. "'s own"
    end, "")
    return column {
        width = "fill",
        visible = mantle.screens:map(function(screens) return #(screens or {}) > 1 end, false),
        children = options:map(function(list)
            return {
                rows.line({
                    rows.label("Display", { width = 70 }),
                    rows.dropdown {
                        id = "appearance.display",
                        label = "Display",
                        width = 260,
                        options = list,
                        value = target,
                        on_select = function(name) picked:set(name) end,
                    },
                }, { rows.caption(hint) }),
            }
        end),
    }
end

return function()
    -- Under its own tab, so no heading: the scale row and the grid fill the card exactly (one row
    -- more with the Display row, which only two or more screens show).
    return {
        display_row(),
        rows.line({
            rows.label("Scale", { width = 70 }),
            c.radio_group {
                id = "settings.appearance.fit",
                options = wallpaper.FITS,
                value = shown_fit,
                on_select = function(fit) wallpaper.set_fit(fit, target_name()) end,
            },
        }, {
            -- How many there are, since the grid shows twelve: the cue that it scrolls.
            rows.caption(listed:map(function(l)
                return #l .. " pictures" .. (#l > COLUMNS * VISIBLE_ROWS and ", scroll for more" or "")
            end, "")),
        }),
        grid(),
    }
end
