-- One popup: a taped sticky note with the app, a Caveat title, the body, a pinned photo, action
-- scraps and an inline reply line. Critical notes are pink stock, ruled down the margin in red marker.
-- Hover, focus and button names come from `slot` (stack position 1..4), never the notification id,
-- so live notifications never grow the signal registry.
local k = require("lib.paper")
local controls = require("components.controls")
local apps = require("lib.apps")
local feed = require("modules.notifications.feed")
local note = require("modules.notifications.note")
local glyphs = require("modules.notifications.glyphs")
local st = require("modules.notifications.state")
local tips_mod = require("modules.notifications.tips")
local menu_mod = require("components.menu")

local tips = tips_mod.popups

local WIDTH = 380
local PINK, PINK_FOLD = k.STOCK.danger[1], "#D9A9A0"
-- Cards alternate their turn; one holding a text field turns at most 1 degree.
local TURN = { -1.4, 1.1, -0.7, 1.5 }

local M = { WIDTH = WIDTH }

-- Right click on a note: mute its app or dismiss it.
local menu = menu_mod.new { id = "paper-notifications-menu", parent = tips_mod.POPUPS_ID }
M.menu_surfaces = menu.surfaces

local REST = { { blur = 10, offset = { x = 2, y = 6 }, color = "#00000055" } }
local LIFT = { { blur = 16, offset = { x = 3, y = 10 }, color = "#00000055" } }

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
                background = k.CARD_LIGHT,
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
            tips_mod.elided(tips, k.body(name, 17, {
                foreground = ink_soft, width = "fill", elide = "end", align_v = "center",
            }), "notifications.pop." .. slot .. ".app", name),
            tips.wrap(k.body(mantle.clock:map(function(clock) return feed.age(clock.time, n.timestamp) end), 16, {
                foreground = ink_soft, align_v = "center",
            }), "notifications.pop." .. slot .. ".age", tips_mod.exact(n.timestamp)),
            tips.wrap(glyphs.disc {
                id = "notifications.pop." .. slot .. ".close",
                icon = glyphs.close,
                size = 30,
                seed = slot + 40,
                tooltip = "Dismiss",
                on_click = function() mantle.notifications:dismiss(n.id) end,
            }, "paper.disc.notifications.pop." .. slot .. ".close", "Dismiss"),
        },
    }
end

local function title_and_body(n, slot, ink)
    local runs, images = feed.body(n.body, k.DEEP_BLUE)
    local title = n.summary ~= "" and n.summary or n.app_name
    local children = {
        tips_mod.elided(tips, k.hand(title, 28, {
            font_weight = 700, foreground = ink, width = "fill", wrap = "word", max_lines = 2, elide = "end",
        }), "notifications.pop." .. slot .. ".title", title),
    }
    if #runs > 0 then
        children[#children + 1] = tips_mod.elided(tips, k.body(runs, 19, {
            foreground = ink,
            width = "fill",
            wrap = "word",
            max_lines = 4,
            elide = "end",
            on_link = function(href) mantle.applications:open_url(href) end,
        }), "notifications.pop." .. slot .. ".body", feed.record(n).body)
    end
    return column { width = "fill", spacing = 2, children = children }, images
end

-- The primary action: a card-stock scrap sized to its label, torn at both ends; it peels up on hover.
-- `controls.button` takes a fixed width, and an action label can be anything.
local function scrap(id, label, kind, on_click, seed)
    local stock = k.STOCK[kind]
    local hovered = hover(id)
    return rect {
        hover = hovered,
        accessible_name = label,
        cursor = "pointer",
        on_click = on_click,
        rotate = hovered:map(function(v) return v and -2 or (seed % 3 - 1) * 0.6 end),
        translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
        animate = {
            rotate = { spring = { stiffness = 300, damping = 16 } },
            translate = { duration = 140, easing = "out_cubic" },
        },
        children = {
            rect {
                width = "fill",
                height = "fill",
                background = stock[1],
                shape = k.tape_shape(nil, nil, seed),
                shadows = k.lift(hovered),
                animate = { shadows = { duration = 160, easing = "out_cubic" } },
                effect = k.paper_fx { rim = 0 },
            },
            k.hand(label, 24, {
                font_weight = 700, foreground = stock[2], padding = { top = 2, bottom = 4, left = 16, right = 20 },
            }),
        },
    }
end

-- The first action on stock, the rest as ink links (DESIGN 5: primary button, secondary links).
local function actions(n, slot, critical)
    local items = {}
    for i, action in ipairs(n.actions or {}) do
        if i > 3 then break end
        local id = "notifications.pop." .. slot .. ".act." .. i
        local label = action.label ~= "" and action.label or action.key
        local function run() mantle.notifications:invoke_action(n.id, action.key) end
        items[i] = i == 1 and scrap(id, label, critical and "danger" or "primary", run, slot * 7)
            or controls.link { id = id, label = label, size = 24, on_click = run }
    end
    return row {
        spacing = 18, wrap = true, line_spacing = 8, align_v = "center", padding = { top = 2 }, children = items,
    }
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
            tips.wrap(glyphs.disc {
                id = "notifications.pop." .. slot .. ".send",
                icon = glyphs.send,
                size = 32,
                seed = slot + 50,
                tooltip = "Send",
                on_click = function()
                    local draft = st.draft:get()
                    if draft.key == key then st.send_reply(n, draft.text) end
                end,
            }, "paper.disc.notifications.pop." .. slot .. ".send", "Send reply"),
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
    local content, images = title_and_body(n, slot, ink)
    local picture = n.image_path or images[1]
    local main = picture and row { width = "fill", spacing = 12, children = { photo(picture, slot), content } }
        or content
    local rows = { header(n, slot, ink_soft), main }
    if #(n.actions or {}) > 0 then rows[#rows + 1] = actions(n, slot, critical) end
    if n.has_reply then rows[#rows + 1] = reply(n, slot) end
    local turn = TURN[(n.id or 0) % #TURN + 1]
    if n.has_reply then turn = math.max(-1, math.min(1, turn)) end

    local dx = st.swipe:map(function(s) return s.key == key and s.dx or 0 end)
    local hovered = hover("notifications.pop." .. slot)
    local start_x = 0
    -- Input sits on an outer box that never moves, so a drag reads the pointer against a fixed frame;
    -- the note inside turns, lifts and slides.
    return rect {
        width = WIDTH,
        cursor = "pointer",
        accessible_name = n.summary,
        hover = hovered,
        animate = {
            move = { duration = 220, easing = "out_cubic" },
            -- Drops away: falls and turns while it fades, gone before the surface's bottom edge.
            exit = { duration = 240, easing = "in_cubic", translate = { x = 10, y = 34 }, rotate = 10, opacity = 0 },
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
        on_click = function(r, button, p)
            if dragged == key then
                dragged = nil
                return
            end
            if button == "right" then
                local app = feed.app_key(n)
                menu.open({ x = r.x + p.x, y = r.y + p.y, width = 1, height = 1 }, {
                    {
                        label = "Mute " .. (app_of(n)),
                        icon = "notifications-disabled-symbolic",
                        on_click = function() st.mute(app) end,
                    },
                    {
                        label = "Dismiss",
                        icon = "window-close-symbolic",
                        on_click = function() mantle.notifications:dismiss(n.id) end,
                    },
                }, { anchor = "top_left", gravity = "bottom_left" })
            elseif button == "middle" or not n.has_default_action then
                mantle.notifications:dismiss(n.id)
            else
                mantle.notifications:invoke_action(n.id, "default")
            end
        end,
        children = {
            rect {
                rotate = dx:map(function(x) return turn + x / 40 end),
                -- Hover peels the note up off the stack; a drag carries it sideways.
                translate = computed({ dx, hovered }, function(x, up) return { x = x, y = up and -3 or 0 } end),
                opacity = dx:map(function(x) return math.max(0.25, 1 - math.abs(x) / 260) end),
                animate = {
                    rotate = { spring = { stiffness = 260, damping = 18 }, from = turn + 9 },
                    -- Peels in from just above and right, within the surface's padding so nothing is cut.
                    translate = { spring = { stiffness = 420, damping = 30 }, from = { x = 18, y = -16 } },
                    opacity = { duration = 160, easing = "out_cubic", from = 0 },
                },
                children = {
                    note {
                        width = WIDTH,
                        seed = (n.id or 1) * 13 + slot,
                        color = critical and PINK or nil,
                        fold_color = critical and PINK_FOLD or nil,
                        tape_rotate = -turn * 2.5,
                        shadows = hovered:map(function(up) return up and LIFT or REST end),
                        child = rect {
                            width = "fill",
                            children = {
                                column {
                                    width = "fill",
                                    spacing = 8,
                                    padding = { top = 16, left = 18, right = 16, bottom = 18 },
                                    children = rows,
                                },
                                critical and rect {
                                    height = "fill",
                                    padding = { top = 18, bottom = 20, left = 7 },
                                    children = { glyphs.margin_rule(k.RED, n.id) },
                                } or nil,
                            },
                        },
                    },
                },
            },
        },
    }
end

return M
