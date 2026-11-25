-- Quick settings' "In use" strip: which apps hold the microphone, camera or screen right now.
-- A card-stock strip headed in red marker, one row per sensor in use; shown only while something
-- is. The taskbar's privacy stickers open quick settings on it with `open(rect, "privacy")`.
local theme = require("theme")
local k = require("lib.paper")
local util = require("lib.util")
local controls = require("components.controls")
local icons = require("components.icons")
local G = require("modules.quick.glyphs")

local ROW_H, HEAD_H, PAD = theme.quick.privacy_row_h, theme.quick.privacy_head_h, theme.quick.privacy_pad

local SENSORS = {
    { key = "microphone_users", kind = "mic", icon = G.mic },
    { key = "camera_users", kind = "camera", icon = G.camera },
    { key = "screencast_users", kind = "screen", icon = G.screen },
}

local function names(users)
    local seen, out = {}, {}
    for _, user in ipairs(users or {}) do
        if not seen[user.app_name] then
            seen[user.app_name] = true
            out[#out + 1] = user.app_name
        end
    end
    return table.concat(out, ", ")
end

local M = {}

--- The sensors in use, in a fixed order: `{ { kind, icon, apps }, ... }`.
M.in_use = mantle.privacy:map(function(p)
    local list = {}
    for _, sensor in ipairs(SENSORS) do
        local apps = names(p[sensor.key])
        if apps ~= "" then list[#list + 1] = { kind = sensor.kind, icon = sensor.icon, apps = apps } end
    end
    return list
end, {})

--- Strip height for `n` rows, so the sheet around it can be cut to fit.
function M.height(n)
    return n == 0 and 0 or HEAD_H + n * ROW_H + PAD * 2
end

local function source_of(audio)
    for _, source in ipairs(audio and audio.sources or {}) do
        if source.active then return source end
    end
end

local mic_muted = mantle.audio:map(function(a)
    local s = source_of(a)
    return s ~= nil and s.muted
end, false)

local function action(kind)
    if kind == "mic" then
        return controls.toggle {
            id = "quick.privacy.mute",
            label = "Mute",
            value = mic_muted,
            on_toggle = function(on)
                local s = source_of(mantle.audio:get())
                if s then mantle.audio:set_muted(s.id, on) end
            end,
        }
    end
    -- No engine action stops someone else's screen capture.
    if kind == "screen" then
        return k.body("stop it in the app", theme.font.xs, { foreground = theme.INK_SOFT, align_v = "center" })
    end
    return rect {}
end

--- The strip for `list` (one `in_use` value), `width` wide. `tips` wraps the app names, which
--- elide; `flagged` (signal) circles the heading in blue pencil when opened from a sticker.
function M.build(list, width, tips, flagged)
    local rows = {}
    for i, sensor in ipairs(list) do
        rows[i] = row {
            width = "fill",
            height = ROW_H,
            spacing = theme.spacing.md,
            children = {
                icons.doodle(sensor.icon, theme.icon.control, theme.RED),
                tips.wrap(k.body(sensor.apps, theme.font.label, { width = "fill", elide = "end", align_v = "center" }),
                    "quick.privacy." .. sensor.kind, sensor.apps),
                action(sensor.kind),
            },
        }
    end
    local height = M.height(#list)
    return k.sheet {
        width = width,
        height = height,
        seed = 905,
        depth = theme.paper.light_tear,
        color = theme.STOCK.danger[1],
        shadows = theme.SHADOW.rest,
        fx = { rim = 0 },
        child = column {
            width = "fill",
            height = "fill",
            padding = { left = theme.spacing.lg, right = theme.spacing.inset, top = PAD - theme.spacing.xxs, bottom = PAD },
            children = util.concat({
                rect {
                    height = HEAD_H,
                    children = {
                        k.hand("In use", theme.font.title, { font_weight = theme.BOLD, foreground = theme.RED, align_v = "center" }),
                        rect {
                            translate = { x = -theme.spacing.snug, y = -2 },
                            opacity = util.choose(flagged, 1, 0),
                            animate = { opacity = { duration = 160, easing = "out_cubic" } },
                            children = { controls.pencil_loop(theme.quick.privacy_loop_w, HEAD_H + theme.quick.privacy_loop_inset, 41) },
                        },
                    },
                },
            }, rows),
        },
    }
end

return M
