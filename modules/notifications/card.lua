-- One popup: a taped sticky note with the app, a Caveat title, the body, a pinned photo, action
-- scraps and an inline reply line. Critical notes are pink stock, underlined in red marker.
-- Hover, focus and button names come from `slot` (stack position 1..4), never the notification id,
-- so live notifications never grow the signal registry.
local k = require("lib.paper")
local controls = require("components.controls")
local apps = require("lib.apps")
local feed = require("modules.notifications.feed")
local note = require("modules.notifications.note")
local glyphs = require("modules.notifications.glyphs")
local st = require("modules.notifications.state")

local WIDTH = 380
local PINK, PINK_FOLD = "#F2CFC8", "#D9A9A0"
-- Cards alternate their turn; one holding a text field turns at most 1 degree.
local TURN = { -1.4, 1.1, -0.7, 1.5 }

local M = { WIDTH = WIDTH }

-- The installed entry's name and icon when the sender names its desktop id.
local function app_of(n)
    local entry = apps.entry(mantle.applications:get(), n.desktop_entry)
    return (entry and entry.name) or (n.app_name ~= "" and n.app_name) or "Notification",
        (entry and entry.icon) or n.app_icon
end

-- A photo pinned on the note: white border, turned, a strip of tape across its corner.
local function photo(path, slot)
    return rect {
        rotate = slot % 2 == 0 and -3 or 3,
        align_v = "start",
        padding = { top = 4 },
        children = {
            rect {
                padding = 4,
                background = "#FBF8F0",
                shadows = k.SHADOW.rest,
                children = { image { source = path, fit = "cover", width = 72, height = 72 } },
            },
            k.tape {
                width = 34, height = 14, translate = { x = -10, y = -6 }, rotate = -28, align_h = "start", seed = slot,
            },
        },
    }
end

local function header(n, slot, ink_soft)
    local name, icon_name = app_of(n)
    return row {
        width = "fill",
        spacing = 8,
        children = {
            glyphs.app(icon_name, 22),
            k.body(name, 17, {
                foreground = ink_soft, width = "fill", elide = "end", align_v = "center",
            }),
            k.body(mantle.clock:map(function(clock) return feed.age(clock.time, n.timestamp) end), 16, {
                foreground = ink_soft, align_v = "center",
            }),
            controls.disc_button {
                id = "notifications.pop." .. slot .. ".close",
                icon = glyphs.close,
                size = 28,
                seed = slot + 40,
                tooltip = "Dismiss",
                on_click = function() mantle.notifications:dismiss(n.id) end,
            },
        },
    }
end

local function title_and_body(n, ink, critical)
    local runs, images = feed.body(n.body, k.DEEP_BLUE)
    local children = {
        k.hand(n.summary ~= "" and n.summary or n.app_name, 28, {
            font_weight = 700, foreground = ink, width = "fill", wrap = "word", max_lines = 2, elide = "end",
        }),
    }
    if critical then
        children[#children + 1] = rect { translate = { y = -6 }, children = { k.squiggle(150, k.RED) } }
    end
    if #runs > 0 then
        children[#children + 1] = k.body(runs, 19, {
            foreground = ink,
            width = "fill",
            wrap = "word",
            max_lines = 4,
            elide = "end",
            on_link = function(href) mantle.applications:open_url(href) end,
        })
    end
    return column { width = "fill", spacing = 2, children = children }, images
end

local function actions(n, slot, critical)
    local buttons = {}
    for i, action in ipairs(n.actions or {}) do
        if i > 3 then break end
        local label = action.label ~= "" and action.label or action.key
        buttons[i] = controls.button {
            id = "notifications.pop." .. slot .. ".act." .. i,
            label = label,
            -- `controls.button` sizes for 25 px labels; these are 22 px.
            width = math.max(80, utf8.len(label) * 10 + 38),
            kind = i == 1 and (critical and "danger" or "primary") or "plain",
            size = 22,
            height = 36,
            on_click = function() mantle.notifications:invoke_action(n.id, action.key) end,
        }
    end
    return row { spacing = 10, wrap = true, line_spacing = 8, children = buttons }
end

local function reply(n, slot)
    local key = feed.key(n)
    return row {
        width = "fill",
        spacing = 8,
        children = {
            controls.field {
                id = "notifications.reply." .. slot,
                width = 270,
                size = 24,
                placeholder = n.reply_placeholder or "Reply…",
                on_change = function(t) st.draft:set({ key = key, text = t }) end,
                on_submit = function(t) st.send_reply(n, t) end,
            },
            controls.disc_button {
                id = "notifications.pop." .. slot .. ".send",
                icon = glyphs.send,
                size = 32,
                seed = slot + 50,
                tooltip = "Send",
                on_click = function()
                    local draft = st.draft:get()
                    if draft.key == key then st.send_reply(n, draft.text) end
                end,
            },
        },
    }
end

-- A swipe past this many px, or a flick this fast, throws the note away.
local THROW_PX, THROW_SPEED = 110, 900
-- The note under a drag that moved: its release must not also click it.
local dragged = nil

function M.build(n, slot)
    local key = feed.key(n)
    local critical = n.urgency == "critical"
    local ink, ink_soft = critical and k.DEEP_RED or k.INK, critical and k.DEEP_RED or k.INK_SOFT
    local content, images = title_and_body(n, ink, critical)
    local picture = n.image_path or images[1]
    local main = picture and row { width = "fill", spacing = 12, children = { photo(picture, slot), content } }
        or content
    local rows = { header(n, slot, ink_soft), main }
    if #(n.actions or {}) > 0 then rows[#rows + 1] = actions(n, slot, critical) end
    if n.has_reply then rows[#rows + 1] = reply(n, slot) end
    local turn = TURN[(n.id or 0) % #TURN + 1]
    if n.has_reply then turn = math.max(-1, math.min(1, turn)) end

    local dx = st.swipe:map(function(s) return s.key == key and s.dx or 0 end)
    local start_x = 0
    return rect {
        width = WIDTH,
        cursor = "pointer",
        accessible_name = n.summary,
        rotate = dx:map(function(x) return turn + x / 40 end),
        translate = dx:map(function(x) return { x = x } end),
        opacity = dx:map(function(x) return math.max(0.25, 1 - math.abs(x) / 260) end),
        animate = {
            rotate = { spring = { stiffness = 260, damping = 18 }, from = turn + 9 },
            translate = { spring = { stiffness = 420, damping = 30 }, from = { x = 60, y = 24 } },
            opacity = { duration = 160, easing = "out_cubic", from = 0 },
            move = { duration = 220, easing = "out_cubic" },
            exit = {
                duration = 260, easing = "in_cubic", translate = { x = 24, y = 140 }, rotate = turn + 16, opacity = 0,
            },
        },
        on_drag = function(_, p, phase, _, velocity)
            if phase == "start" then
                start_x, dragged = p.x, nil
                return
            end
            local moved = p.x - start_x
            if phase == "move" then
                if math.abs(moved) > 6 then dragged = key end
                st.swipe:set({ key = key, dx = moved })
                return
            end
            st.swipe:set({ key = "", dx = 0 })
            if math.abs(moved) > THROW_PX or math.abs(velocity.x) > THROW_SPEED then
                mantle.notifications:dismiss(n.id)
            end
        end,
        on_click = function()
            if dragged == key then
                dragged = nil
                return
            end
            if n.has_default_action then
                mantle.notifications:invoke_action(n.id, "default")
            else
                -- Off the screen, still in the date menu's history.
                st.hide(n)
            end
        end,
        children = {
            note {
                width = WIDTH,
                seed = (n.id or 1) * 13 + slot,
                color = critical and PINK or nil,
                fold_color = critical and PINK_FOLD or nil,
                tape_rotate = -turn * 2.5,
                child = column {
                    width = "fill",
                    spacing = 8,
                    padding = { top = 16, left = 18, right = 16, bottom = 18 },
                    children = rows,
                },
            },
        },
    }
end

return M
