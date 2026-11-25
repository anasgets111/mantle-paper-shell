-- Rows written on the settings page's ruled lines: every row is a multiple of the rule pitch, so
-- text and controls sit on a line. Controls come from `components/controls.lua`.
local k = require("lib.paper")
local c = require("components.controls")
local util = require("lib.util")
local tips = require("modules.settings.tips")
local icons = require("modules.settings.icons")
local menu = require("components.menu")

local R = {}

-- Every page's dropdowns open this one note on the modal host; `init.lua` lists its surfaces.
R.menu = menu.new { id = "settings-dropdown", parent = "paper-modal-host" }

R.PITCH = 34
-- Centred text floats 11 px over its rule; handwriting sits about 4 px over it.
R.SINK = 6
-- Content width: the notebook's 700 px index card less its 14 px side margins.
R.WIDTH = 672

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

-- Pads a vertical radio list (24 px circles, 10 px apart) so each option sits on a rule; `n`
-- options fill exactly `n` pitches.
function R.list(child, n)
    return rect {
        height = n and R.PITCH * n,
        padding = { left = 4, top = 5 + R.SINK },
        children = { child },
    }
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

-- A row's label, cut with "…" when it runs out of room. With `tip`, a hover name unique to the
-- row, a cut label shows its full text in a tooltip.
function R.label(content, props)
    local t = { width = "fill", elide = "end" }
    local tip
    for key, v in pairs(props or {}) do
        if key == "tip" then tip = v else t[key] = v end
    end
    if not tip then return k.body(content, 21, t) end
    local cut = elided("settings.cut." .. tip)
    t.elided = cut
    return tips.wrap(k.body(content, 21, t), "settings.tip." .. tip, function()
        return cut:get() and util.get(content) or ""
    end)
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
    }
end

-- A dropdown sized for a ruled row; `o` as `controls.dropdown`, without `menu`. A value cut with
-- "…" shows in full in a tooltip.
function R.dropdown(o)
    o.id = "settings." .. o.id
    o.menu = R.menu
    local cut = elided("settings.cut." .. o.id)
    o.elided = cut
    return tips.wrap(c.dropdown(o), "paper.dropdown." .. o.id, function()
        if not cut:get() then return "" end
        local now = util.get(o.value)
        local opt = util.find(o.options, function(x) return x[1] == now end)
        return opt and opt[2] or ""
    end)
end

-- Index tabs standing on a ruled line at the top of a page, two pitches tall, for a page with
-- distinct parts. Returns the strip and the chosen index (`settings.<page>.tab`); `R.pane` shows a
-- part only under its tab. Choosing a tab scrolls the page back to its top. Put the strip first in
-- the page's list: the notebook finds it in `R.strips` and pins it above the scrolling rows.
R.tab_states = {}
R.strips = setmetatable({}, { __mode = "k" })
function R.tabs(page, names, width)
    local chosen = state("settings." .. page .. ".tab", 1)
    R.tab_states[page] = chosen
    local strip = rect {
        width = "fill",
        height = R.PITCH * 2,
        children = {
            rect { width = "fill", align_v = "end", translate = { y = 3 }, children = { c.divider(R.WIDTH, false, #page) } },
            rect {
                align_v = "end",
                translate = { y = -6 },
                children = {
                    c.tabs {
                        id = "settings." .. page,
                        names = names,
                        value = chosen,
                        width = width or 150,
                        on_select = function(i)
                            chosen:set(i)
                            scroll("settings.scroll." .. page):scroll_to(0)
                        end,
                    },
                },
            },
        },
    }
    R.strips[strip] = true
    return strip, chosen
end

function R.pane(chosen, i, children)
    return column { width = "fill", visible = chosen:map(function(v) return v == i end), children = children }
end

-- A collapsed section for rarely used rows: a link that shows or hides them (`settings.<id>.more`).
-- `hide` labels the link while open, "Hide <label>" by default. Returns the column and the state.
function R.more(id, label, children, hide)
    local open = state("settings." .. id .. ".more", false)
    return column {
        width = "fill",
        children = {
            R.line({
                rect {
                    children = open:map(function(on)
                        return { R.action(id .. ".more", on and (hide or ("Hide " .. label)) or (label .. "…"), function() open:set(not on) end) }
                    end),
                },
            }),
            column { width = "fill", visible = open, children = children },
        },
    }, open
end

-- A row action as a deep-blue link: lighter than a button where a list has one per row.
function R.action(id, label, on_click)
    return c.link { id = "settings." .. id, label = label, size = 24, on_click = on_click }
end

-- Signal strength as a Wi-Fi doodle; `tip` names the hover slot of a tooltip giving the percentage.
function R.bars(strength, tip)
    return tips.wrap(rect { children = { icons.signal(strength) } }, "settings.tip." .. tip, function()
        return "Signal " .. util.get(strength) .. "%"
    end)
end

-- A sticky note that fits its content: deckled top, dog-eared corner, taped on. The shared
-- `controls.sticky` takes a fixed size; this one's outline is percents and edge anchors.
function R.sticky(child, seed)
    local r = k.rng(seed)
    local c = { { op = "M", points = { 0, 0 } } }
    for i = 1, 20 do c[#c + 1] = { op = "L", points = { string.format("%d%%", i * 5), r() * 2.5 } } end
    c[#c + 1] = { op = "L", points = { "100%", { from = "bottom", px = -12 } } }
    c[#c + 1] = { op = "L", points = { { from = "right", px = -12 }, "100%" } }
    c[#c + 1] = { op = "L", points = { 0, "100%" } }
    c[#c + 1] = { op = "Z", points = {} }
    return rect {
        rotate = -1,
        padding = { top = 10, left = 4, bottom = 8 },
        children = {
            rect {
                children = {
                    rect {
                        width = "fill",
                        height = "fill",
                        shape = { commands = c },
                        background = k.STICKY,
                        shadows = { { blur = 10, offset = { x = 2, y = 6 }, color = "#00000055" } },
                        effect = k.paper_fx { rim = 0, grain = 0.18 },
                    },
                    rect { padding = { top = 16, left = 18, right = 26, bottom = 18 }, children = { child } },
                    path {
                        width = 12, height = 12, align_h = "end", align_v = "end", fill = k.STICKY_FOLD,
                        shadows = { { blur = 3, offset = { x = -1, y = -1 }, color = "#00000040" } },
                        commands = {
                            { op = "M", points = { 0, 12 } }, { op = "L", points = { 12, 0 } },
                            { op = "L", points = { 2, 2 } }, { op = "Z", points = {} },
                        },
                    },
                },
            },
            k.tape { width = 64, height = 20, translate = { y = -8 }, rotate = 3, seed = seed },
        },
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
