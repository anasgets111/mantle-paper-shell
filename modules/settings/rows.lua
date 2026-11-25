-- Rows written on the settings page's ruled lines: every row is a multiple of the rule pitch, so
-- text and controls sit on a line. Controls come from `components/controls.lua`.
local theme = require("theme")
local k = require("lib.paper")
local c = require("components.controls")
local util = require("lib.util")
local tips = require("modules.settings.tips")
local icons = require("modules.settings.icons")
local menu = require("components.menu")

local R = {}

-- Every page's dropdowns open this one note on the modal host; `init.lua` lists its surfaces.
R.menu = menu.new { id = "settings-dropdown", parent = "paper-modal-host" }

R.PITCH = theme.settings.row_pitch
-- Centred text floats 11 px over its rule; handwriting sits about 4 px over it.
R.SINK = theme.settings.row_sink
-- Content width: the notebook's 700 px index card less its 14 px side margins.
R.WIDTH = theme.settings.row_w

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
        padding = { left = theme.spacing.xxs, top = theme.spacing.compact + R.SINK },
        children = { child },
    }
end

-- One ruled row: `left` fills, `right` hugs the right edge. `lines` rows of the pitch tall.
function R.line(left, right, lines)
    return row {
        width = "fill",
        height = R.PITCH * (lines or 1),
        spacing = theme.spacing.md,
        children = {
            row {
                width = "fill", spacing = theme.spacing.snug, align_v = "center", translate = { y = R.SINK },
                children = centred(compact(left)),
            },
            row { spacing = theme.spacing.snug, align_v = "center", translate = { y = R.SINK }, children = centred(compact(right or {})) },
        },
    }
end

-- A section heading in blue Caveat, two rules tall so it breathes above its rows.
function R.heading(title, right)
    return row {
        width = "fill",
        height = R.PITCH * 2,
        children = {
            k.hand(title, theme.font.xxl, {
                font_weight = theme.BOLD, foreground = theme.BLUE, align_v = "end", width = "fill", translate = { y = R.SINK },
            }),
            row {
                spacing = theme.spacing.snug, align_v = "end", padding = { bottom = theme.spacing.hairline }, translate = { y = R.SINK },
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
    if not tip then return k.body(content, theme.font.control, t) end
    local cut = elided("settings.cut." .. tip)
    t.elided = cut
    return tips.wrap(k.body(content, theme.font.control, t), "settings.tip." .. tip, function()
        return cut:get() and util.get(content) or ""
    end)
end

function R.caption(content, props)
    local t = { foreground = theme.INK_SOFT }
    for key, v in pairs(props or {}) do t[key] = v end
    return k.body(content, theme.font.caption, t)
end

-- A note in pencil: soft caption text that wraps across the page.
function R.note(content, lines)
    return rect {
        width = "fill",
        height = R.PITCH * (lines or 1),
        children = {
            k.body(content, theme.font.sm, {
                foreground = theme.INK_SOFT, width = "fill", wrap = "word", align_v = "center", line_height = R.PITCH / theme.settings.note_line_h,
                translate = { y = R.SINK },
            }),
        },
    }
end

-- A short card-stock button that fits a ruled row.
function R.button(id, label, kind, on_click)
    return c.button {
        id = "settings." .. id, label = label, kind = kind, height = theme.control.slider, size = theme.font.lg, on_click = on_click,
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
                translate = { y = -theme.spacing.xs },
                children = {
                    c.tabs {
                        id = "settings." .. page,
                        names = names,
                        value = chosen,
                        width = width or theme.settings.subtab_w,
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
    return c.link { id = "settings." .. id, label = label, size = theme.font.xl, on_click = on_click }
end

-- Signal strength as a Wi-Fi doodle; `tip` names the hover slot of a tooltip giving the percentage.
function R.bars(strength, tip)
    return tips.wrap(rect { children = { icons.signal(strength) } }, "settings.tip." .. tip, function()
        return "Signal " .. util.get(strength) .. "%"
    end)
end

-- A sticky note that fits its content: deckled top, dog-eared corner, taped on. Its outline is
-- percents and edge anchors. ponytail: `controls.sticky` now also fits its content without
-- `height`; fold this into it once the two look identical.
function R.sticky(child, seed)
    local r = k.rng(seed)
    local c = { { op = "M", points = { 0, 0 } } }
    for i = 1, 20 do c[#c + 1] = { op = "L", points = { string.format("%d%%", i * 5), r() * 2.5 } } end
    c[#c + 1] = { op = "L", points = { "100%", { from = "bottom", px = -theme.controls.sticky_fold } } }
    c[#c + 1] = { op = "L", points = { { from = "right", px = -theme.controls.sticky_fold }, "100%" } }
    c[#c + 1] = { op = "L", points = { 0, "100%" } }
    c[#c + 1] = { op = "Z", points = {} }
    return rect {
        rotate = -1,
        padding = { top = theme.spacing.snug, left = theme.spacing.xxs, bottom = theme.spacing.sm },
        children = {
            rect {
                children = {
                    rect {
                        width = "fill",
                        height = "fill",
                        shape = { commands = c },
                        background = theme.STICKY,
                        shadows = theme.SHADOW.notes_rest,
                        effect = k.paper_fx { rim = 0, grain = 0.18 },
                    },
                    rect { padding = { top = theme.spacing.lg, left = theme.spacing.roomy, right = theme.spacing.tab, bottom = theme.spacing.roomy }, children = { child } },
                    path {
                        width = theme.controls.sticky_fold, height = theme.controls.sticky_fold, align_h = "end", align_v = "end", fill = theme.STICKY_FOLD,
                        shadows = theme.SHADOW.fold,
                        commands = {
                            { op = "M", points = { 0, theme.controls.sticky_fold } }, { op = "L", points = { theme.controls.sticky_fold, 0 } },
                            { op = "L", points = { 2, 2 } }, { op = "Z", points = {} },
                        },
                    },
                },
            },
            k.tape { width = theme.controls.sticky_tape_w, height = theme.controls.sticky_tape_h, translate = { y = -theme.spacing.sm }, rotate = 3, seed = seed },
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
