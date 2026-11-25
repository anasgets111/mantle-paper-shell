-- The lock screen's content for one output: a closed notebook lying on the desk. Blue card-stock
-- cover bound with cloth tape, a red ribbon bookmark, the time written large, and a label sticker
-- holding the owner's name and the password line. `preview` draws the same cover with a picture of
-- the field, so it can be looked at without locking.
local k = require("lib.paper")
local icons = require("components.icons")
local util = require("lib.util")
local controls = require("components.controls")
local identity = require("lib.identity")
local password = require("modules.lock.password")
local media = require("modules.lock.media")
local G = require("modules.lock.glyphs")

local CW, CH = 600, 800
local LABEL_W, LABEL_H = 460, 270

local now = mantle.clock:map(function(c) return c.time end, os.time())

-- "Locking…" while the compositor has not confirmed, "Opening…" once PAM said yes.
local function lock_status(s)
    if s == nil or not s.active then return "locking\u{2026}" end
    return s.unlocking and "opening\u{2026}" or nil
end

local function ribbon()
    local w, h = 28, 150
    -- Cloth: the paper grain reads as weave at this size. The tail is cut in a deep V.
    return rect {
        width = w,
        height = h,
        align_h = "end",
        align_v = "end",
        translate = { x = -96, y = 104 },
        rotate = 4,
        background = "#C8463F",
        shadows = { { blur = 4, offset = { x = 1, y = 2 }, color = "#00000055" } },
        effect = k.paper_fx { grain = 0.3, mottle = 0.18, rim = 0 },
        shape = { commands = {
            { op = "M", points = { 0, 0 } }, { op = "L", points = { w, 0 } }, { op = "L", points = { w, h } },
            { op = "L", points = { w / 2, h - 24 } }, { op = "L", points = { 0, h } }, { op = "Z", points = {} },
        } },
    }
end

local function status_line(source)
    local battery = row {
        spacing = 6,
        visible = mantle.battery:map(function(b) return b.present end, false),
        children = {
            icons.doodle(G.battery, 20, k.DEEP_BLUE),
            k.body(mantle.battery:map(function(b) return b.percent .. "%" end, ""), 20, {
                foreground = k.DEEP_BLUE, align_v = "center",
            }),
        },
    }
    local layout = row {
        spacing = 6,
        visible = mantle.keyboard:map(function(kb) return kb.active_layout ~= "" end, false),
        children = {
            icons.doodle(G.keyboard, 20, k.DEEP_BLUE),
            k.body(mantle.keyboard:map(function(kb) return kb.active_layout end, ""), 20, {
                foreground = k.DEEP_BLUE, align_v = "center",
            }),
        },
    }
    local attempts = k.body(source:map(function(s)
        return (s.attempts or 0) > 0 and string.format("%d wrong %s", s.attempts, s.attempts == 1 and "try" or "tries") or ""
    end, ""), 20, { foreground = k.DEEP_RED, align_v = "center" })
    return row { align_h = "center", spacing = 26, children = { battery, layout, attempts } }
end

local function label(output, opts)
    local field = password {
        id = "lock.password." .. output,
        capability = "lock",
        source = opts.source,
        preview = opts.preview,
        width = LABEL_W - 70,
        idle = "press Enter to unlock",
        status = not opts.preview and lock_status or nil,
    }
    return k.card {
        width = LABEL_W,
        height = LABEL_H,
        seed = 917,
        rotate = -1,
        align_h = "center",
        color = k.CARD_LIGHT,
        fx = { rim = 1.6 },
        tapes = { { width = 120, height = 24, rotate = 2.5, seed = 31, color = "#E9D9A6" } },
        child = rect {
            width = "fill",
            height = "fill",
            padding = { left = 34, right = 30, top = 30, bottom = 20 },
            children = {
                column {
                    width = "fill",
                    spacing = 4,
                    children = {
                        row {
                            width = "fill",
                            spacing = 12,
                            children = {
                                k.body("Name", 18, { foreground = k.INK_SOFT, align_v = "end", padding = { bottom = 10 } }),
                                rect {
                                    width = "fill",
                                    children = {
                                        k.hand(identity.full_name, 44, { font_weight = 700, elide = "end", width = "fill" }),
                                        rect { align_v = "end", children = { controls.divider(LABEL_W - 130, false, 3) } },
                                    },
                                },
                            },
                        },
                        row {
                            spacing = 6,
                            padding = { left = 54, bottom = 18 },
                            children = {
                                icons.doodle(G.user, 16, k.INK_SOFT),
                                k.body(identity.account, 17, { foreground = k.INK_SOFT, width = LABEL_W - 150, elide = "end" }),
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
        translate = util.lift(up, function(on) return { y = on and 0 or 24 } end),
        animate = { opacity = { duration = 240, easing = "out_cubic", from = 0 },
            translate = { duration = 300, easing = "out_cubic", from = { y = 24 } } },
        children = {
            ribbon(),
            k.sheet {
                width = CW,
                height = CH,
                seed = 4242,
                depth = 3,
                color = k.STOCK.primary[1],
                fx = { rim = 1.2, grain = 0.16 },
                shadows = { { blur = 30, offset = { x = 6, y = 14 }, color = "#00000088" } },
            },
            -- Cloth binding tape down the spine.
            rect {
                width = 46,
                height = CH + 8,
                translate = { x = -6, y = -4 },
                background = "#33528A",
                shape = k.tape_shape(46, CH + 8, 5),
                shadows = k.SHADOW.tape,
                effect = k.paper_fx { grain = 0.4, mottle = 0.25, rim = 0 },
            },
            column {
                width = "fill",
                height = "fill",
                align_h = "center",
                padding = { left = 46, top = 48, bottom = 40 },
                spacing = 10,
                children = {
                    util.with(icons.doodle(G.lock, 30, k.DEEP_BLUE), "align_h", "center"),
                    k.hand(now:map(function(t) return (os.date("%I:%M", t):gsub("^0", "")) end), 110, {
                        foreground = k.DEEP_BLUE, align_h = "center", line_height = 1.0,
                    }),
                    k.body(now:map(function(t)
                        return os.date("%A, ", t) .. os.date("*t", t).day .. os.date(" %B", t)
                    end), 26, { foreground = k.DEEP_BLUE, align_h = "center" }),
                    rect { height = 50 },
                    label(output, { preview = opts.preview, source = source }),
                    rect { height = 14 },
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
        background = "#1C1A24",
        children = {
            image { source = k.DIR .. "/img/wallpaper.jpg", width = "fill", height = "fill", fit = "cover", async = true },
            cover,
        },
    }
end
