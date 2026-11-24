-- Rows written on the settings page's ruled lines: every row is a multiple of the rule pitch, so
-- text and controls sit on a line. Controls come from `components/controls.lua`.
local k = require("lib.paper")
local c = require("components.controls")
local util = require("lib.util")

local R = {}

R.PITCH = 34
-- Centred text floats 11 px over its rule; handwriting sits about 4 px over it.
R.SINK = 6
-- Page content width: an 800 px page less the red margin and the right gutter.
R.WIDTH = 680

-- Callers write `cond and node or false`; a `false` entry is dropped.
local function compact(list)
    local out = {}
    for _, node in ipairs(list) do
        if node then out[#out + 1] = node end
    end
    return out
end

local function centred(nodes)
    for _, node in ipairs(nodes) do node.align_v = "center" end
    return nodes
end

-- Pads a vertical radio list (24 px circles, 10 px apart) so each option sits on a rule.
function R.list(child)
    return rect { padding = { left = 4, top = 5 + R.SINK }, children = { child } }
end

-- One ruled row: `left` fills, `right` hugs the right edge. `lines` rows of the pitch tall.
function R.line(left, right, lines)
    return row {
        width = "fill",
        height = R.PITCH * (lines or 1),
        spacing = 12,
        children = {
            row {
                width = "fill", spacing = 10, align_v = "center", translate = { y = R.SINK },
                children = centred(compact(left)),
            },
            row { spacing = 10, align_v = "center", translate = { y = R.SINK }, children = centred(compact(right or {})) },
        },
    }
end

-- A section heading in blue Caveat, two rules tall so it breathes above its rows.
function R.heading(title, right)
    return row {
        width = "fill",
        height = R.PITCH * 2,
        children = {
            k.hand(title, 30, {
                font_weight = 700, foreground = k.BLUE, align_v = "end", width = "fill", translate = { y = R.SINK },
            }),
            row {
                spacing = 10, align_v = "end", padding = { bottom = 2 }, translate = { y = R.SINK },
                children = centred(compact(right or {})),
            },
        },
    }
end

function R.label(content, props)
    local t = { width = "fill", elide = "end" }
    for key, v in pairs(props or {}) do t[key] = v end
    return k.body(content, 21, t)
end

function R.caption(content, props)
    local t = { foreground = k.INK_SOFT }
    for key, v in pairs(props or {}) do t[key] = v end
    return k.body(content, 17, t)
end

-- A note in pencil: soft caption text that wraps across the page.
function R.note(content, lines)
    return rect {
        width = "fill",
        height = R.PITCH * (lines or 1),
        children = {
            k.body(content, 18, {
                foreground = k.INK_SOFT, width = "fill", wrap = "word", align_v = "center", line_height = R.PITCH / 18,
                translate = { y = R.SINK },
            }),
        },
    }
end

-- A short card-stock button that fits a ruled row.
function R.button(id, label, kind, on_click)
    return c.button {
        id = "settings." .. id, label = label, kind = kind, height = 32, size = 22, on_click = on_click,
        width = math.max(84, #label * 11 + 34),
    }
end

-- A row action as a deep-blue link: lighter than a button where a list has one per row.
function R.action(id, label, on_click)
    return c.link { id = "settings." .. id, label = label, size = 24, on_click = on_click }
end

-- Signal strength as four pencil bars; the filled ones are hatched blue marker.
function R.bars(strength)
    return rect {
        width = 26,
        height = 22,
        children = util.lift(strength, function(s)
            local lit = s >= 75 and 4 or s >= 50 and 3 or s >= 25 and 2 or s > 0 and 1 or 0
            local bars = {}
            for i = 1, 4 do
                local h = 4 + i * 4.5
                bars[i] = path {
                    width = 26,
                    height = 22,
                    fill = i <= lit and "#3F74C7CC" or nil,
                    stroke = i <= lit and k.DEEP_BLUE or "#3A363180",
                    stroke_width = 1.3,
                    stroke_join = "round",
                    commands = {
                        { op = "M", points = { (i - 1) * 6.5 + 1, 21 } },
                        { op = "L", points = { (i - 1) * 6.5 + 1.4, 21 - h } },
                        { op = "L", points = { (i - 1) * 6.5 + 5, 21 - h + 0.6 } },
                        { op = "L", points = { (i - 1) * 6.5 + 5.2, 21 } },
                        { op = "Z", points = {} },
                    },
                }
            end
            return bars
        end),
    }
end

-- A key for `:map` so a list rebuilds only when its shape changes, not on every push.
function R.key(list, fields)
    local parts = {}
    for _, item in ipairs(list or {}) do
        for _, f in ipairs(fields) do parts[#parts + 1] = tostring(item[f]) end
        parts[#parts + 1] = "|"
    end
    return table.concat(parts, ",")
end

-- Lua strings are bytes: cut at a codepoint boundary.
function R.clip(s, n)
    if utf8.len(s) == nil or utf8.len(s) <= n then return s end
    return s:sub(1, utf8.offset(s, n) - 1) .. "…"
end

return R
