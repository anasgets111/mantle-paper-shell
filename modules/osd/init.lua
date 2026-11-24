-- OSD: a strip of washi tape stuck just above the taskbar, with an icon, a highlighter level bar
-- and a Caveat label. `service.lua` decides what to show; this only draws.
local k = require("lib.paper")
local util = require("lib.util")
local icons = require("components.icons")
local osd = require("modules.osd.service")

local H = 58
local BAR = 230
local SLIDE = 14
local RISE_MS, FALL_MS = 160, 120

local entry = osd.entry
local has_level = entry:map(function(e) return e.level ~= nil end)
local ink = entry:map(function(e) return e.off and k.INK_SOFT or k.INK end)


local line = { { op = "M", points = { 4, 15 } }, { op = "Q", points = { BAR / 2, 12, BAR - 4, 16 } } }

local bar = rect {
    width = BAR,
    height = 30,
    align_v = "center",
    visible = has_level,
    children = {
        k.stroke_path(BAR, 30, line, "#3A363199", 1.5),
        path {
            width = BAR,
            height = 30,
            stroke = entry:map(function(e) return e.off and "#6B625840" or "#86AEEAC8" end),
            stroke_width = 16,
            stroke_cap = "butt",
            blend = "multiply",
            trim_end = entry:map(function(e) return (e.level or 0) / 100 end),
            -- A held key retargets every few frames; a spring keeps its velocity where a tween restarts.
            animate = { trim_end = { spring = { stiffness = 260, damping = 26 } } },
            commands = line,
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
    background = "#EFE2B4",
    shape = k.tape_shape(nil, nil, 17),
    shadows = { { blur = 6, offset = { x = 1, y = 3 }, color = "#00000045" } },
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
            spacing = 16,
            padding = { left = 26, right = 20 },
            children = {
                icons.doodle(entry:map(function(e) return e.icon end), 26, ink),
                bar,
                -- A fixed slot beside the bar, so "5%" and "150%" leave the same margin.
                k.hand(entry:map(function(e) return e.text or "" end), 32, {
                    font_weight = 700, foreground = ink, align_v = "center", width = util.choose(has_level, 84, nil),
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
            margin = { bottom = 22 },
            height = H + SLIDE + 12,
            visible = util.linger(osd.visible, FALL_MS),
            child = rect { width = "fill", height = "fill", padding = { top = 6 }, children = { strip } },
        },
    },
}
