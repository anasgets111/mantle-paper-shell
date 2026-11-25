-- Quick settings' device chooser: a card-stock list that opens under the volume or mic row, one
-- line per output or input, the default ticked in blue. A click makes that device the default.
local theme = require("theme")
local k = require("lib.paper")
local util = require("lib.util")
local controls = require("components.controls")
local icons = require("components.icons")

local ROW, PAD = theme.quick.device_row_h, theme.quick.device_pad

local M = {}

--- The list's height for `n` devices, so the sheet around it can be cut to fit.
function M.height(n)
    return n * ROW + PAD * 2
end

local SET_DEFAULT = { sinks = "set_default_sink", sources = "set_default_source" }

local function device_row(kind, device, width, tips, index)
    local slot = "quick.device." .. kind .. "." .. device.id
    local hovered = hover(slot)
    local keyed = focus_visible(slot .. ".focus")
    local cut = elided(slot .. ".cut")
    local active = mantle.audio:map(function(a)
        for _, d in ipairs(a[kind] or {}) do
            if d.id == device.id then return d.active end
        end
        return false
    end, false)
    local ink = active:map(function(v) return v and theme.DEEP_BLUE or theme.INK end)
    return tips.wrap(rect {
        width = width,
        height = ROW,
        hover = hovered,
        focus_visible = keyed,
        focus_ring = false,
        accessible_name = device.name,
        cursor = "pointer",
        on_click = function() mantle.audio[SET_DEFAULT[kind]](mantle.audio, device.id) end,
        children = {
            -- Hover: a strip of blue stock under the line, opaque like every fill on the sheet.
            rect {
                width = "fill",
                height = ROW - theme.quick.device_highlight_inset,
                align_v = "center",
                shape = k.torn(width, ROW - theme.quick.device_highlight_inset, 120 + index, theme.paper.fine_tear),
                background = theme.STOCK.primary[1],
                opacity = util.choose(hovered, 1, 0),
                animate = { opacity = { duration = 120 } },
            },
            row {
                width = "fill",
                height = "fill",
                spacing = theme.spacing.snug,
                padding = { left = theme.spacing.snug, right = theme.spacing.snug },
                children = {
                    rect {
                        width = theme.quick.device_mark,
                        height = theme.quick.device_mark,
                        align_v = "center",
                        opacity = util.choose(active, 1, 0),
                        children = { icons.doodle("check", theme.icon.md, theme.DEEP_BLUE) },
                    },
                    k.body(device.name, theme.font.label, { width = "fill", elide = "end", elided = cut, align_v = "center", foreground = ink }),
                },
            },
            rect {
                opacity = util.choose(keyed, 1, 0),
                children = { controls.pencil_loop(width, ROW, 70 + index, theme.quick.device_loop_inset) },
            },
        },
    }, slot, function()
        return cut:get() and device.name or ""
    end)
end

--- The list of `kind` ("sinks" or "sources") from `audio`, `width` wide. `tips` wraps the names,
--- which elide.
function M.build(kind, audio, width, tips)
    local devices = audio and audio[kind] or {}
    local rows = {}
    for i, device in ipairs(devices) do rows[i] = device_row(kind, device, width - PAD * 2, tips, i) end
    return k.sheet {
        width = width,
        height = M.height(#devices),
        seed = kind == "sinks" and 931 or 937,
        depth = theme.paper.light_tear,
        color = theme.CARD_LIGHT,
        shadows = theme.SHADOW.rest,
        fx = { rim = 0 },
        child = column { width = "fill", padding = PAD, children = rows },
    }
end

return M
