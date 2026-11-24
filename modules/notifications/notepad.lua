-- The date menu's left page: a ruled notepad of notification history grouped by app, in urgent /
-- today / earlier sections, with dismiss per note, per app and for everything, and do-not-disturb.
-- Hover and tooltip names come from a row's position (at most 100 notes), never a notification id.
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

local W, H = 450, 560
local LIST_H = 400
local MARGIN = 46

local function cross(slot, label, on_click, size)
    return tips.wrap(rect {
        padding = 4,
        align_v = "center",
        cursor = "pointer",
        accessible_name = label,
        on_click = on_click,
        children = { glyphs.glyph(glyphs.close, size, k.INK_SOFT) },
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
            spacing = 6,
            children = {
                tips_mod.elided(tips, k.body(summary, 19, {
                    width = "fill", elide = "end", foreground = critical and k.DEEP_RED or k.INK,
                }), name .. ".summary", summary),
                tips.wrap(k.body(feed.age(now, record.timestamp), 15, { foreground = k.INK_SOFT, align_v = "center" }),
                    name .. ".age", tips_mod.exact(record.timestamp)),
                cross(name .. ".dismiss", "Dismiss", function() history.dismiss({ record }) end, 14),
            },
        },
    }
    if (record.body or "") ~= "" then
        lines[2] = k.body(record.body, 16, {
            foreground = k.INK_SOFT, width = "fill", wrap = "word", max_lines = 2, elide = "end",
        })
    end
    return column {
        width = "fill",
        cursor = "pointer",
        accessible_name = record.summary,
        on_click = function() open(record) end,
        children = lines,
    }
end

local function group_row(group, now)
    local name = "notifications.group." .. group.slot
    local children = {
        row {
            width = "fill",
            spacing = 8,
            children = {
                glyphs.app(group.app_icon, 22),
                tips_mod.elided(tips, k.hand(group.app_name, 26, {
                    font_weight = 700, align_v = "center", elide = "end", max_width = 260,
                }), name .. ".app", group.app_name),
                k.body(#group.items > 1 and ("×" .. #group.items) or "", 16, {
                    foreground = k.INK_SOFT, align_v = "center",
                }),
                rect { width = "fill" },
                cross(name .. ".dismiss", "Dismiss all from " .. group.app_name, function()
                    history.dismiss(group.items)
                end, 18),
            },
        },
    }
    for i, record in ipairs(group.items) do children[#children + 1] = item(record, now, group.first + i - 1) end
    return column { width = "fill", spacing = 4, padding = { bottom = 10 }, children = children }
end

local function header_row(label)
    local ink = label == "urgent" and k.RED or k.BLUE
    return rect {
        padding = { top = 4, bottom = 4 },
        children = {
            k.hand(label:sub(1, 1):upper() .. label:sub(2), 26, { foreground = ink }),
            rect {
                width = "fill",
                align_v = "end",
                padding = { right = 4 },
                translate = { y = 2 },
                children = { glyphs.underline(ink, #label) },
            },
        },
    }
end

local function empty()
    return column {
        width = "fill",
        height = LIST_H,
        spacing = 6,
        children = {
            rect { height = 90 },
            rect { align_h = "center", rotate = -8, children = { k.sprig(56) } },
            k.hand("Nothing new", 32, { align_h = "center", foreground = k.INK_SOFT }),
            k.body("Notifications land here.", 17, { align_h = "center", foreground = k.INK_SOFT }),
        },
    }
end

-- `now` is a signal of Unix time, stamped when the menu opens.
function M.page(now)
    local rows = computed({ history.records, mantle.applications, now }, function(records, applications, t)
        -- Number groups and notes by position, for bounded hover names.
        local groups, count = 0, 0
        return util.map(feed.sections(feed.groups(records, applications), t), function(r)
            if r.kind ~= "header" then
                groups = groups + 1
                r.slot, r.first = groups, count + 1
                count = count + #r.items
            end
            return { row = r, now = t }
        end)
    end, {})
    local has_any = history.records:map(function(r) return #r > 0 end)
    local dnd = mantle.notifications:map(function(inbox) return inbox.dnd end, false)

    local content = column {
        width = "fill",
        height = "fill",
        spacing = 8,
        padding = { top = 18, left = MARGIN + 12, right = 22, bottom = 18 },
        children = {
            row {
                width = "fill",
                align_v = "center",
                children = {
                    k.hand("Notifications", 38, { font_weight = 700, width = "fill" }),
                    row {
                        visible = has_any,
                        spacing = 4,
                        align_v = "center",
                        children = {
                            glyphs.doodle(glyphs.trash, 20, k.DEEP_BLUE),
                            controls.link {
                                id = "notifications.clear_all", label = "clear all", size = 26,
                                on_click = history.dismiss_all,
                            },
                        },
                    },
                },
            },
            rect {
                width = "fill",
                visible = has_any,
                -- Rows scroll under a fade, not a hard cut through a line of ink.
                mask = M.scroll:map(function(offset)
                    local ink, clear = "#000000FF", "#00000000"
                    local stops = { { 0, offset > 0 and clear or ink }, { 0.06, ink }, { 0.94, ink }, { 1, clear } }
                    return { gradient = "linear", stops = stops }
                end),
                children = {
                    list {
                        width = "fill",
                        height = LIST_H,
                        scroll = M.scroll,
                        items = rows,
                        key = function(r) return r.row.key end,
                        each = function(r)
                            if r.row.kind == "header" then return header_row(r.row.label) end
                            return group_row(r.row, r.now)
                        end,
                    },
                },
            },
            rect { width = "fill", visible = has_any:map(function(v) return not v end), children = { empty() } },
            rect { height = "fill" },
            row {
                spacing = 12,
                align_v = "center",
                children = {
                    controls.toggle {
                        id = "notifications.dnd",
                        label = "Do not disturb",
                        value = dnd,
                        on_toggle = function(on) mantle.notifications:set_dnd(on) end,
                    },
                    glyphs.doodle(dnd:map(function(on) return on and glyphs.bell_off or glyphs.bell end), 22),
                },
            },
        },
    }

    return k.card {
        width = W,
        height = H,
        seed = 41,
        rotate = -0.6,
        tapes = { { width = 96, height = 24, rotate = 2.5, seed = 12 } },
        child = rect {
            width = "fill",
            height = "fill",
            children = util.concat(controls.ruled(W, H, { top = 78, pitch = 34, margin = MARGIN }), { content }),
        },
    }
end

return M
