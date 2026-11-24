-- Today's date over a hand-drawn month on a cream card: weeks ruled in pencil, today circled in red marker.
-- Weeks start on Sunday (en_US `first_weekday`). ponytail: fixed; read the locale's
-- `first_weekday` if another locale needs it.
local k = require("lib.paper")
local controls = require("components.controls")
local glyphs = require("modules.notifications.glyphs")
local tips = require("modules.notifications.tips").menu

local M = {}

local W, CELL, ROW = 300, 40, 34
local WEEKDAYS = { "S", "M", "T", "W", "T", "F", "S" }

-- Months away from today's; reset when the date menu opens.
M.offset = state("notifications.month_offset", 0)

local function month_of(now, offset)
    local t = os.date("*t", now)
    local m = t.month - 1 + offset
    return t.year + m // 12, m % 12 + 1
end

local function weeks(year, month)
    local first = os.date("*t", os.time({ year = year, month = month, day = 1, hour = 12 }))
    local days = os.date("*t", os.time({ year = year, month = month + 1, day = 0, hour = 12 })).day
    local grid, week = {}, {}
    for _ = 1, first.wday - 1 do week[#week + 1] = false end
    for day = 1, days do
        week[#week + 1] = day
        if #week == 7 then
            grid[#grid + 1] = week
            week = {}
        end
    end
    if #week > 0 then grid[#grid + 1] = week end
    return grid
end

local function day_cell(day, is_today)
    local children = {}
    if is_today then children[1] = controls.pencil_circle(CELL - 4, day, k.RED, 2.4) end
    if day then
        children[#children + 1] = k.body(tostring(day), 20, {
            align_h = "center", align_v = "center", foreground = is_today and k.DEEP_RED or k.INK,
        })
    end
    return rect { width = CELL, height = ROW, children = children }
end

-- A pencil rule under each week, wobbling a pixel.
local function rule(seed)
    local r = k.rng(seed)
    return k.stroke_path(W - 8, 4, {
        { op = "M", points = { 2, 2 + r() } },
        { op = "Q", points = { W / 2, 1 + r() * 2, W - 10, 2 + r() } },
    }, "#3A363155", 1.2)
end

local function grid(now, offset)
    local year, month = month_of(now, offset)
    local today = os.date("*t", now)
    local rows = {}
    local head = {}
    for i, d in ipairs(WEEKDAYS) do
        head[i] = k.body(d, 16, { width = CELL, text_align = "center", foreground = k.INK_SOFT })
    end
    rows[1] = row { children = head }
    for i, week in ipairs(weeks(year, month)) do
        local cells = {}
        for j = 1, 7 do
            local day = week[j] or false
            cells[j] = day_cell(day, day and offset == 0 and day == today.day)
        end
        rows[#rows + 1] = column { children = { row { children = cells }, rule(year * 100 + month * 7 + i) } }
    end
    local title = os.date("%B %Y", os.time({ year = year, month = month, day = 1 }))
    return column { spacing = 0, children = rows }, title, #rows - 1
end

-- `now` is a signal of Unix time, stamped when the menu opens.
function M.card(now)
    local month = computed({ now, M.offset }, function(t, offset)
        local days, title, nweeks = grid(t, offset)
        local content = column {
            width = "fill",
            spacing = 6,
            padding = { top = 18, left = 22, right = 22, bottom = 14 },
            children = {
                column {
                    spacing = -8,
                    padding = { left = 6, bottom = 6 },
                    children = {
                        k.hand(os.date("%A", t), 28, { foreground = k.BLUE }),
                        k.hand(os.date("%B ", t) .. tonumber(os.date("%d", t)) .. os.date(" %Y", t), 36, {
                            font_weight = 700,
                        }),
                    },
                },
                controls.divider(W - 10, false, 5),
                row {
                    width = "fill",
                    align_v = "center",
                    children = {
                        tips.wrap(glyphs.disc {
                            id = "notifications.cal.prev", icon = glyphs.prev_month, size = 30, seed = 61,
                            tooltip = "Previous month",
                            on_click = function() M.offset:set(M.offset:get() - 1) end,
                        }, "paper.disc.notifications.cal.prev", "Previous month"),
                        rect {
                            width = "fill",
                            cursor = "pointer",
                            accessible_name = "This month",
                            on_click = function() M.offset:set(0) end,
                            children = { k.hand(title, 26, { align_h = "center" }) },
                        },
                        tips.wrap(glyphs.disc {
                            id = "notifications.cal.next", icon = glyphs.next_month, size = 30, seed = 62,
                            tooltip = "Next month",
                            on_click = function() M.offset:set(M.offset:get() + 1) end,
                        }, "paper.disc.notifications.cal.next", "Next month"),
                    },
                },
                days,
            },
        }
        -- The card fits the month: five weeks or six.
        return {
            k.card {
                width = W + 28,
                height = 190 + nweeks * (ROW + 4),
                seed = 77,
                color = "#F4ECDA",
                rotate = 0.9,
                tapes = { { width = 72, height = 22, rotate = -3, seed = 8 } },
                child = content,
            },
        }
    end)
    return rect { children = month }
end

return M
