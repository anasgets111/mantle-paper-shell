-- The date menu's left page: a ruled notepad of notification history grouped by app, in urgent /
-- today / earlier sections, with dismiss per note, per app and for everything, and do-not-disturb.
-- Hover and tooltip names come from a row's position (at most 100 notes), never a notification id.
local theme = require("theme")
local k = require("lib.paper")
local controls = require("components.controls")
local util = require("lib.util")
local feed = require("modules.notifications.feed")
local history = require("modules.notifications.history")
local ui_state = require("lib.ui_state")
local glyphs = require("modules.notifications.glyphs")
local tips_mod = require("modules.notifications.tips")

local tips = tips_mod.menu

local M = {}

M.scroll = scroll("notifications.history")

local W, H = theme.notifications.notepad_w, theme.notifications.notepad_h
local LIST_H = theme.notifications.history_h
local MARGIN = theme.notifications.notepad_margin

-- A bare pencil cross with a finger-sized hit area, for one note.
local function cross(slot, label, on_click, size)
    return tips.wrap(rect {
        padding = theme.spacing.sm,
        align_v = "center",
        cursor = "pointer",
        accessible_name = label,
        on_click = on_click,
        children = { glyphs.doodle(glyphs.close, size, theme.INK_SOFT) },
    }, slot, label)
end

-- A live note with a default action opens its app; an archived one has nothing to open.
local function open(record)
    local n = history.live(record.key)
    if n and n.has_default_action then
        mantle.notifications:invoke_action(n.id, "default")
        ui_state.close_panel()
    end
end

local function item(record, now, slot)
    local critical = record.urgency == "critical"
    local name = "notifications.row." .. slot
    local summary = record.summary ~= "" and record.summary or record.app_name
    local lines = {
        row {
            width = "fill",
            spacing = theme.spacing.xs,
            children = {
                tips_mod.elided(tips, k.body(summary, theme.font.label, {
                    width = "fill", elide = "end", foreground = critical and theme.DEEP_RED or theme.INK,
                }), name .. ".summary", summary),
                tips.wrap(k.body(feed.age(now, record.timestamp), theme.font.version, { foreground = theme.INK_SOFT, align_v = "center" }),
                    name .. ".age", tips_mod.exact(record.timestamp)),
                cross(name .. ".dismiss", "Dismiss", function() history.dismiss({ record }) end, theme.notifications.clear_icon),
            },
        },
    }
    if (record.body or "") ~= "" then
        lines[2] = tips_mod.elided(tips, k.body(record.body, theme.font.xs, {
            foreground = theme.INK_SOFT, width = "fill", wrap = "word", max_lines = 2, elide = "end",
        }), name .. ".body", record.body)
    end
    -- Hover swipes yellow highlighter across the note, as a link does.
    local hovered = hover(name)
    return rect {
        width = "fill",
        cursor = "pointer",
        hover = hovered,
        accessible_name = record.summary,
        on_click = function() open(record) end,
        children = {
            rect {
                width = "fill",
                height = "fill",
                padding = { left = theme.spacing.xxl },
                opacity = hovered:map(function(v) return v and 1 or 0 end),
                animate = { opacity = { duration = 140 } },
                children = {
                    rect {
                        width = "fill", height = "fill", background = theme.HIGHLIGHT, blend = "multiply",
                        shape = k.tape_shape(nil, nil, slot),
                    },
                },
            },
            column { width = "fill", padding = { left = theme.spacing.page, right = theme.spacing.hairline }, children = lines },
        },
    }
end

local function group_row(group, now)
    local name = "notifications.group." .. group.slot
    local children = {
        row {
            width = "fill",
            spacing = theme.spacing.sm,
            children = {
                glyphs.app(group.app_icon, theme.icon.control),
                tips_mod.elided(tips, k.hand(group.app_name, theme.font.heading, {
                    font_weight = theme.BOLD, align_v = "center", elide = "end", max_width = theme.notifications.group_name_w,
                }), name .. ".app", group.app_name),
                k.body(#group.items > 1 and ("×" .. #group.items) or "", theme.font.xs, {
                    foreground = theme.INK_SOFT, align_v = "center",
                }),
                rect { width = "fill" },
                -- The whole app's dismiss is a paper disc on the header, apart from each note's cross.
                tips.wrap(glyphs.disc {
                    id = name .. ".dismiss",
                    icon = glyphs.close,
                    size = theme.icon.task,
                    seed = group.slot + 20,
                    tooltip = "Dismiss all from " .. group.app_name,
                    on_click = function() history.dismiss(group.items) end,
                }, "paper.disc." .. name .. ".dismiss", "Dismiss all from " .. group.app_name),
            },
        },
    }
    for i, record in ipairs(group.items) do children[#children + 1] = item(record, now, group.first + i - 1) end
    children[#children + 1] = rect {
        padding = { top = theme.spacing.xs },
        children = { controls.divider(W - MARGIN - theme.notifications.group_rule_inset, false, group.slot) },
    }
    return column { width = "fill", spacing = theme.spacing.hairline, padding = { bottom = theme.spacing.xs }, children = children }
end

local function header_row(label)
    local urgent = label == "urgent"
    local ink, mark = urgent and theme.DEEP_RED or theme.BLUE, urgent and theme.RED or theme.BLUE
    return rect {
        padding = { top = theme.spacing.xxs, bottom = theme.spacing.xxs },
        children = {
            k.hand(label:sub(1, 1):upper() .. label:sub(2), theme.font.heading, { foreground = ink }),
            rect {
                width = "fill",
                align_v = "end",
                padding = { right = theme.spacing.xxs },
                translate = { y = 2 },
                children = { glyphs.underline(mark, #label) },
            },
        },
    }
end

local function empty()
    return column {
        width = "fill",
        height = LIST_H,
        spacing = theme.spacing.xs,
        children = {
            rect { height = theme.notifications.empty_h },
            rect { align_h = "center", rotate = -8, children = { k.sprig(theme.icon.hero) } },
            k.hand("Nothing new", theme.font.banner, { align_h = "center", foreground = theme.INK_SOFT }),
            k.body("Notifications land here.", theme.font.caption, { align_h = "center", foreground = theme.INK_SOFT }),
        },
    }
end

-- The wheel moves history a whole row at a time, so the top edge always starts a row and no fade
-- ever lands on a heading. Each row takes the wheel before the list does (the innermost wins).
local view = geometry("notifications.history.view")
local row_geo = {}
local function geo(i)
    row_geo[i] = row_geo[i] or geometry("notifications.history.row." .. i)
    return row_geo[i]
end
local rows, notches = nil, 0
local function snap(_, steps)
    notches = notches + steps
    if math.abs(notches) < 1 then return end
    local down = notches < 0
    notches = 0
    local top, offset = view:get().y, M.scroll:get()
    local target
    for i = 1, #(rows and rows:get() or {}) do
        local at = geo(i):get().y - top
        if down and at > 1 then
            target = at
            break
        end
        if not down and at < -1 then target = at end
    end
    if target then M.scroll:scroll_to(offset + target) end
end

-- `now` is a signal of Unix time, stamped when the menu opens.
function M.page(now)
    rows = computed({ history.records, mantle.applications, now }, function(records, applications, t)
        -- Number groups and notes by position, for bounded hover names.
        local groups, count = 0, 0
        return util.map(feed.sections(feed.groups(records, applications), t), function(r, index)
            if r.kind ~= "header" then
                groups = groups + 1
                r.slot, r.first = groups, count + 1
                count = count + #r.items
            end
            return { row = r, now = t, index = index }
        end)
    end, {})
    local has_any = history.records:map(function(r) return #r > 0 end)
    local dnd = mantle.notifications:map(function(inbox) return inbox.dnd end, false)
    -- Toggles sit at the right edge, as everywhere in the shell; the label is a sibling, so name it here.
    local dnd_toggle = controls.toggle {
        id = "notifications.dnd",
        value = dnd,
        on_toggle = function(on) mantle.notifications:set_dnd(on) end,
    }
    dnd_toggle.accessible_name = "Do not disturb"

    local content = column {
        width = "fill",
        height = "fill",
        spacing = theme.spacing.sm,
        padding = { top = theme.spacing.roomy, left = MARGIN + theme.spacing.md, right = theme.spacing.wide, bottom = theme.spacing.roomy },
        children = {
            row {
                width = "fill",
                align_v = "center",
                children = {
                    k.hand("Notifications", theme.font.feature, { font_weight = theme.BOLD, width = "fill" }),
                    row {
                        visible = has_any,
                        spacing = theme.spacing.xxs,
                        align_v = "center",
                        children = {
                            glyphs.doodle(glyphs.trash, theme.icon.md, theme.DEEP_BLUE),
                            controls.link {
                                id = "notifications.clear_all", label = "clear all", size = theme.font.heading,
                                on_click = history.dismiss_all,
                            },
                        },
                    },
                },
            },
            rect {
                width = "fill",
                visible = has_any,
                -- The row cut by the bottom edge fades out rather than being sliced through its ink.
                mask = {
                    gradient = "linear",
                    stops = { { 0, "#000000FF" }, { 0.9, "#000000FF" }, { 1, "#00000000" } },
                },
                children = {
                    list {
                        width = "fill",
                        height = LIST_H,
                        scroll = M.scroll,
                        geometry = view,
                        items = rows,
                        key = function(r) return r.row.key end,
                        each = function(r)
                            return rect {
                                width = "fill",
                                geometry = geo(r.index),
                                on_wheel = snap,
                                children = {
                                    r.row.kind == "header" and header_row(r.row.label) or group_row(r.row, r.now),
                                },
                            }
                        end,
                    },
                },
            },
            rect { width = "fill", visible = has_any:map(function(v) return not v end), children = { empty() } },
            rect { height = "fill" },
            row {
                width = "fill",
                spacing = theme.spacing.snug,
                align_v = "center",
                children = {
                    glyphs.doodle(dnd:map(function(on) return on and glyphs.bell_off or glyphs.bell end), theme.icon.control),
                    k.body("Do not disturb", theme.font.md, { align_v = "center" }),
                    rect { width = "fill" },
                    dnd_toggle,
                },
            },
        },
    }

    return k.card {
        width = W,
        height = H,
        seed = 41,
        rotate = -0.6,
        tapes = { { width = theme.notifications.notepad_tape_w, height = theme.control.xs, rotate = 2.5, seed = 12 } },
        child = rect {
            width = "fill",
            height = "fill",
            children = util.concat(controls.ruled(W, H, { top = theme.notifications.notepad_rule_top, pitch = theme.notifications.notepad_rule_pitch, margin = MARGIN }), { content }),
        },
    }
end

return M
