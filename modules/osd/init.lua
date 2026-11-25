-- OSD: a strip of washi tape stuck just above the taskbar, with an icon, a highlighter level bar
-- and a Caveat label. `service.lua` decides what to show; this only draws.
local theme = require("theme")
local k = require("lib.paper")
local util = require("lib.util")
local icons = require("components.icons")
local osd = require("modules.osd.service")

local H = theme.osd.height
local BAR = theme.osd.track_w
local SLIDE = theme.osd.slide
local RISE_MS, FALL_MS = 160, 120

local entry = osd.entry
local has_level = entry:map(function(e) return e.level ~= nil end)
-- Off dims the icon and the fill; the words stay in ink, they are the message.
local icon_ink = entry:map(function(e) return e.off and theme.INK_SOFT or theme.INK end)

local line = { { op = "M", points = { theme.osd.track_inset, theme.osd.track_start_y } }, { op = "Q", points = { BAR / 2, theme.osd.track_bend_y, BAR - theme.osd.track_inset, theme.osd.track_end_y } } }

local bar = rect {
    width = BAR,
    height = theme.control.chip,
    align_v = "center",
    visible = has_level,
    children = {
        k.stroke_path(BAR, theme.osd.track_h, line, theme.TRACK_INK, 1.5),
        -- A highlighter swipe with ragged ends, as wide as the level.
        rect {
            width = entry:map(function(e) return math.floor((e.level or 0) / 100 * (BAR - theme.osd.track_trim) + 0.5) end),
            height = theme.osd.fill_h,
            align_v = "center",
            translate = { x = 4, y = -1 },
            background = entry:map(function(e) return e.off and theme.OSD_OFF or theme.OSD_ON end),
            blend = "multiply",
            shape = k.tape_shape(nil, nil, 29),
            -- A held key retargets every few frames; a spring keeps its velocity where a tween restarts.
            animate = { width = { spring = { stiffness = 260, damping = 26 } } },
        },
        rect {
            visible = entry:map(function(e) return e.mark ~= nil end),
            translate = entry:map(function(e) return { x = 4 + (e.mark or 0) * (BAR - theme.spacing.sm) - theme.spacing.xs / 2 } end),
            children = {
                k.stroke_path(theme.osd.mark_w, theme.osd.track_h, { { op = "M", points = { theme.osd.mark_start_x, theme.osd.mark_top } }, { op = "L", points = { theme.osd.mark_end_x, theme.osd.mark_bottom } } }, theme.INK, 1.6),
            },
        },
    },
}

-- The tape is cut to whatever its row needs: the level layout's label has a fixed slot, so a held
-- key never moves the torn ends.
local strip = rect {
    height = H,
    align_h = "center",
    align_v = "start",
    rotate = -1.2,
    background = theme.OSD_PAPER,
    shape = k.tape_shape(nil, nil, 17),
    shadows = theme.SHADOW.osd,
    effect = k.paper_fx { grain = 0.35, mottle = 0.2, rim = 0 },
    translate = osd.visible:map(function(shown) return { y = shown and 0 or SLIDE } end),
    opacity = util.choose(osd.visible, 1, 0),
    animate = osd.visible:map(function(shown)
        local ms = shown and RISE_MS or FALL_MS
        return {
            opacity = { duration = ms, from = 0 },
            translate = { duration = ms, easing = shown and "out_cubic" or "in_quad", from = { y = SLIDE } },
        }
    end),
    children = {
        row {
            align_h = "center",
            align_v = "center",
            spacing = theme.spacing.lg,
            padding = { left = theme.spacing.tab, right = theme.spacing.xl },
            children = {
                icons.doodle(entry:map(function(e) return e.icon end), theme.icon.badge, icon_ink),
                bar,
                -- A fixed slot beside the bar, so "5%" and "150%" leave the same margin.
                k.hand(entry:map(function(e) return e.text or "" end), theme.font.banner, {
                    font_weight = theme.BOLD, align_v = "center", width = util.choose(has_level, theme.osd.value_w, nil),
                }),
            },
        },
    },
}

return {
    surfaces = {
        panel {
            id = "paper-osd",
            namespace = "paper-osd",
            output = "active",
            layer = "overlay",
            -- Spans the output so a new entry's width never resizes the layer surface.
            anchor = { bottom = true, left = true, right = true },
            margin = { bottom = theme.spacing.wide },
            height = H + SLIDE + theme.osd.popup_extra_h,
            visible = util.linger(osd.visible, FALL_MS),
            child = rect { width = "fill", height = "fill", padding = { top = theme.spacing.xs }, children = { strip } },
        },
    },
}
