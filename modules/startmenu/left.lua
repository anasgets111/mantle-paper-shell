-- The left page: the search line at the top, the page title with its "All apps" link, then the
-- pinned grid, an app list, the apps by category, or recent-file cards. Arrow keys move the
-- selection from the search field; Enter opens it; Escape clears, then closes.
local k = require("lib.paper")
local icons = require("modules.startmenu.icons")
local controls = require("components.controls")
local util = require("lib.util")
local model = require("modules.startmenu.model")
local items = require("modules.startmenu.items")
local power = require("modules.startmenu.power")

local M = {}

local W, H = 560, 660
local PAD_L, PAD_R = 74, 30
local CONTENT_H = H - 150
M.WIDTH, M.HEIGHT = W, H

-- Where each item sits among the scroll column's children: `row` for `scroll:reveal` (headings
-- count) and `col` within its row, so arrows can move by row and column in any layout.
local placed = {}

local function note(text)
    return k.body(text, 18, {
        foreground = k.INK_SOFT,
        wrap = "word",
        width = "fill",
        padding = { left = 8, right = 8, top = 10, bottom = 10 },
    })
end

local function cell(item, i, pins, layout)
    if item.kind == "file" then return items.file_card(item, i) end
    if item.kind == "calc" then return items.calc_row(item, i) end
    if layout == "grid" then return items.tile(item, i, pins) end
    return items.app_row(item, i)
end

local function build(page)
    local list = page.items
    local children = {}
    placed = {}
    -- Pins lead the favourites page, so a tile's index is also its place among the pins.
    local pins = {}
    for _, item in ipairs(list) do
        if item.pin_index then pins[#pins + 1] = item end
    end
    if #list == 0 or (page.layout == "grid" and #pins == 0) then children[1] = note(page.empty) end
    local i, group = 1, nil
    while i <= #list do
        local first = list[i]
        if first.group and first.group ~= group then
            group = first.group
            children[#children + 1] = items.heading(group)
        end
        local per = first.kind == "file" and 2 or (page.layout == "grid" and first.kind == "app") and model.COLUMNS or 1
        local cells = {}
        while i <= #list and #cells < per and list[i].kind == first.kind and list[i].group == first.group do
            cells[#cells + 1] = cell(list[i], i, pins, page.layout)
            placed[i] = { row = #children + 1, col = #cells }
            i = i + 1
        end
        children[#children + 1] = per == 1 and cells[1]
            or row { spacing = first.kind == "file" and 4 or 0, children = cells }
    end
    return column {
        width = "fill",
        height = CONTENT_H,
        spacing = 0,
        scroll = model.scroll,
        padding = { bottom = 24 },
        -- Rows fade out above the page's torn foot instead of being cut by it.
        mask = { gradient = "linear", stops = { { 0, "#000000FF" }, { 0.9, "#000000FF" }, { 1, "#00000000" } } },
        children = children,
    }
end

-- Left and Right stay in their row; Up and Down go to the nearest column of the next row that
-- holds items, skipping headings.
local function step(now, key)
    local here = placed[now]
    if key == "Left" or key == "Right" then
        local t = now + (key == "Left" and -1 or 1)
        return (placed[t] and placed[t].row == here.row) and t or now
    end
    local dir = key == "Up" and -1 or 1
    local best, target_row
    local j = now + dir
    while placed[j] do
        local p = placed[j]
        if p.row ~= here.row then
            target_row = target_row or p.row
            if p.row ~= target_row then break end
            if not best or math.abs(p.col - here.col) < math.abs(placed[best].col - here.col) then best = j end
        end
        j = j + dir
    end
    return best or now
end

local function move(key)
    if key ~= "Up" and key ~= "Down" and key ~= "Left" and key ~= "Right" then return false end
    local count = #model.page:get().items
    if count == 0 then return false end
    power.disarm()
    local now = model.selected:get()
    local target = (now == 0 or not placed[now]) and 1 or step(now, key)
    model.selected:set(target)
    if placed[target] then model.scroll:reveal(placed[target].row) end
    return true
end

local function search_line()
    return row {
        spacing = 10,
        children = {
            rect { padding = { top = 8 }, children = { icons.glyph("search", 22, k.INK_SOFT) } },
            controls.field {
                id = "startmenu.search",
                placeholder = "Type to search apps, or sums…",
                -- The content width less the glyph and gap, so the line ends at the right margin.
                width = W - PAD_L - PAD_R - 32,
                size = 28,
                autofocus = true,
                focus_target = model.search_focus,
                on_change = function(text)
                    power.disarm()
                    model.query:set(text)
                end,
                -- Only a highlighted item: a bare Enter on the pinned page must not launch the first pin.
                on_submit = function()
                    local chosen = model.selected:get()
                    if chosen > 0 then model.activate(model.page:get().items[chosen]) end
                end,
                -- The engine clears the text and drops focus on Escape; a clear keeps the menu open.
                on_cancel = function(cleared)
                    power.disarm()
                    if cleared then
                        model.search_focus:request()
                    else
                        model.close()
                    end
                end,
                on_key = function(press)
                    local key = press.name
                    if (key == "Left" or key == "Right") and model.query:get() ~= "" then return false end
                    return move(key)
                end,
            },
        },
    }
end

local function header()
    local browsing_all = model.view:map(function(v) return v ~= "favourites" end)
    return row {
        width = "fill",
        height = 48,
        children = {
            -- Bottom-aligned so the title and the link share a baseline.
            k.hand(model.page:map(function(p) return p.title end), 36, {
                font_weight = 700, foreground = k.BLUE, align_v = "end",
            }),
            rect { width = "fill" },
            rect {
                align_v = "end",
                padding = { right = 6, bottom = 4 },
                children = browsing_all:map(function(all)
                    return {
                        controls.link {
                            id = all and "startmenu.back" or "startmenu.all",
                            label = all and "‹ Pinned" or "All apps ›",
                            size = 26,
                            on_click = function()
                                power.disarm()
                                model.show(all and "favourites" or "all")
                            end,
                        },
                    }
                end),
            },
        },
    }
end

function M.page()
    return column {
        width = W,
        height = H,
        padding = { left = PAD_L, right = PAD_R, top = 26 },
        spacing = 10,
        children = {
            search_line(),
            header(),
            rect { width = "fill", children = util.lift(model.page, function(p) return { build(p) } end) },
        },
    }
end

return M
