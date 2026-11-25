-- The lock screen's content for one output: a closed notebook lying on the desk. Blue card-stock
-- cover bound with cloth tape, a red ribbon bookmark, the time written large, and a label sticker
-- holding the owner's name and the password line. `preview` draws the same cover with a picture of
-- the field, so it can be looked at without locking.
local theme = require("theme")
local k = require("lib.paper")
local icons = require("components.icons")
local util = require("lib.util")
local controls = require("components.controls")
local identity = require("lib.identity")
local password = require("modules.lock.password")
local media = require("modules.lock.media")
local wallpaper = require("lib.wallpaper")
local G = require("modules.lock.glyphs")

local CW, CH = theme.lock.cover_w, theme.lock.cover_h
local LABEL_W, LABEL_H = theme.lock.label_w, theme.lock.label_h

local now = mantle.clock:map(function(c) return c.time end, os.time())

-- "Locking…" while the compositor has not confirmed, "Opening…" once PAM said yes.
local function lock_status(s)
    if s == nil or not s.active then return "locking\u{2026}" end
    return s.unlocking and "opening\u{2026}" or nil
end

local function ribbon()
    local w, h = theme.lock.bookmark_w, theme.lock.bookmark_h
    -- Cloth: the paper grain reads as weave at this size. The tail is cut in a deep V.
    return rect {
        width = w,
        height = h,
        align_h = "end",
        align_v = "end",
        translate = { x = -theme.lock.bookmark_x, y = theme.lock.bookmark_y },
        rotate = 4,
        background = theme.LOCK_BOOKMARK,
        shadows = theme.SHADOW.pin,
        effect = k.paper_fx { grain = 0.3, mottle = 0.18, rim = 0 },
        shape = { commands = {
            { op = "M", points = { 0, 0 } }, { op = "L", points = { w, 0 } }, { op = "L", points = { w, h } },
            { op = "L", points = { w / 2, h - theme.lock.bookmark_notch } }, { op = "L", points = { 0, h } }, { op = "Z", points = {} },
        } },
    }
end

local function status_line(source)
    local battery = row {
        spacing = theme.spacing.xs,
        visible = mantle.battery:map(function(b) return b.present end, false),
        children = {
            icons.doodle(G.battery, theme.icon.md, theme.DEEP_BLUE),
            k.body(mantle.battery:map(function(b) return b.percent .. "%" end, ""), theme.font.md, {
                foreground = theme.DEEP_BLUE, align_v = "center",
            }),
        },
    }
    local layout = row {
        spacing = theme.spacing.xs,
        visible = mantle.keyboard:map(function(kb) return kb.active_layout ~= "" end, false),
        children = {
            icons.doodle(G.keyboard, theme.icon.md, theme.DEEP_BLUE),
            k.body(mantle.keyboard:map(function(kb) return kb.active_layout end, ""), theme.font.md, {
                foreground = theme.DEEP_BLUE, align_v = "center",
            }),
        },
    }
    local attempts = k.body(source:map(function(s)
        return (s.attempts or 0) > 0 and string.format("%d wrong %s", s.attempts, s.attempts == 1 and "try" or "tries") or ""
    end, ""), theme.font.md, { foreground = theme.DEEP_RED, align_v = "center" })
    -- Hidden when empty, so its share of the spacing does not pull the row off centre.
    attempts.visible = source:map(function(s) return (s.attempts or 0) > 0 end, false)
    return row { align_h = "center", spacing = theme.spacing.tab, children = { battery, layout, attempts } }
end

local function label(output, opts)
    local field = password {
        id = "lock.password." .. output,
        capability = "lock",
        source = opts.source,
        preview = opts.preview,
        width = LABEL_W - theme.lock.password_inset,
        idle = "press Enter to unlock",
        status = not opts.preview and lock_status or nil,
    }
    return k.card {
        width = LABEL_W,
        height = LABEL_H,
        seed = 917,
        rotate = -1,
        align_h = "center",
        color = theme.CARD_LIGHT,
        fx = { rim = 1.6 },
        tapes = { { width = theme.lock.label_tape_w, height = theme.control.xs, rotate = 2.5, seed = 31, color = theme.LOCK_TAPE } },
        child = rect {
            width = "fill",
            height = "fill",
            padding = { left = theme.spacing.binding, right = theme.spacing.page, top = theme.spacing.page, bottom = theme.spacing.xl },
            children = {
                column {
                    width = "fill",
                    spacing = theme.spacing.xxs,
                    children = {
                        row {
                            width = "fill",
                            spacing = theme.spacing.md,
                            children = {
                                k.body("Name", theme.font.sm, { foreground = theme.INK_SOFT, align_v = "end", padding = { bottom = theme.spacing.snug } }),
                                rect {
                                    width = "fill",
                                    children = {
                                        k.hand(identity.full_name, theme.font.name, { font_weight = theme.BOLD, elide = "end", width = "fill" }),
                                        rect { align_v = "end", children = { controls.divider(LABEL_W - theme.lock.label_rule_inset, false, 3) } },
                                    },
                                },
                            },
                        },
                        row {
                            spacing = theme.spacing.xs,
                            padding = { left = theme.lock.account_x, bottom = theme.spacing.roomy },
                            children = {
                                icons.doodle(G.user, theme.icon.sm, theme.INK_SOFT),
                                k.body(identity.account, theme.font.caption, { foreground = theme.INK_SOFT, width = LABEL_W - theme.lock.account_inset, elide = "end" }),
                            },
                        },
                        field,
                    },
                },
            },
        },
    }
end

-- opts = { preview?, source?, player? }
return function(output, opts)
    opts = opts or {}
    local source = opts.source or mantle.lock
    local up = opts.preview and true or source:map(function(s) return s.active and not s.unlocking end, false)

    local cover = rect {
        width = CW,
        height = CH,
        align_h = "center",
        align_v = "center",
        rotate = 0.8,
        opacity = util.choose(up, 1, 0),
        translate = util.lift(up, function(on) return { y = on and 0 or theme.spacing.xxl } end),
        animate = { opacity = { duration = 240, easing = "out_cubic", from = 0 },
            translate = { duration = 300, easing = "out_cubic", from = { y = theme.spacing.xxl } } },
        children = {
            ribbon(),
            k.sheet {
                width = CW,
                height = CH,
                seed = 4242,
                depth = theme.paper.control_tear,
                color = theme.STOCK.primary[1],
                fx = { rim = 1.2, grain = 0.16 },
                shadows = theme.SHADOW.lock,
            },
            -- Cloth binding tape down the spine.
            rect {
                width = theme.lock.binding_w,
                height = CH + theme.spacing.sm,
                translate = { x = -theme.spacing.xs, y = -4 },
                background = theme.LOCK_BINDING,
                shape = k.tape_shape(theme.lock.binding_w, CH + theme.spacing.sm, 5),
                shadows = theme.SHADOW.tape,
                effect = k.paper_fx { grain = 0.4, mottle = 0.25, rim = 0 },
            },
            column {
                width = "fill",
                height = "fill",
                align_h = "center",
                padding = { left = theme.lock.binding_w, top = theme.lock.content_top, bottom = theme.spacing.section },
                spacing = theme.spacing.snug,
                children = {
                    util.with(icons.doodle(G.lock, theme.icon.task, theme.DEEP_BLUE), "align_h", "center"),
                    k.hand(now:map(function(t) return (os.date("%I:%M", t):gsub("^0", "")) end), theme.font.clock_large, {
                        foreground = theme.DEEP_BLUE, align_h = "center", line_height = 1.0,
                    }),
                    k.body(now:map(function(t)
                        return os.date("%A, ", t) .. os.date("*t", t).day .. os.date(" %B", t)
                    end), theme.font.heading, { foreground = theme.DEEP_BLUE, align_h = "center" }),
                    rect { height = theme.control.wide },
                    label(output, { preview = opts.preview, source = source }),
                    rect { height = theme.lock.password_gap },
                    media.card(opts.player),
                    rect { height = "fill" },
                    status_line(source),
                },
            },
        },
    }

    return rect {
        width = "fill",
        height = "fill",
        background = theme.LOCK_BACKDROP,
        children = {
            -- This output's desktop picture and fit; the dark ground shows in "contain"'s bars.
            image { source = wallpaper.path_of(output), fit = wallpaper.fit_of(output), width = "fill", height = "fill", async = true },
            cover,
        },
    }
end
