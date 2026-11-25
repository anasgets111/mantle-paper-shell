-- Privacy: a red-marker sticker per sensor in use (microphone, camera, screen sharing) left of the
-- status icons, each ringed by a quick red loop, and a strip of red tape reading LIVE across every
-- output's top-right corner while the screen is shared. Nothing shows, and nothing takes space,
-- while no sensor is in use.
local theme = require("theme")
local k = require("lib.paper")
local util = require("lib.util")
local controls = require("components.controls")
local quick = require("modules.quick")
local icons = require("modules.taskbar.icons")
local tips = require("modules.taskbar.tips")
local press = require("modules.taskbar.press")

local M = {}

local SENSORS = {
    { key = "mic", field = "microphone_users", glyph = "mic", label = "Microphone" },
    { key = "camera", field = "camera_users", glyph = "video", label = "Camera" },
    { key = "screen", field = "screencast_users", glyph = "display", label = "Sharing screen" },
}
local BY_KEY = {}
for _, s in ipairs(SENSORS) do BY_KEY[s.key] = s end

-- TEST-ONLY: `mantle set taskbar.privacy_fake '{"mic":["Discord"]}'` adds fake users per sensor key.
local fake = state("taskbar.privacy_fake", false)

local function users(p, f, s)
    local out = {}
    for _, u in ipairs(p and p[s.field] or {}) do out[#out + 1] = u.app_name end
    for _, name in ipairs(f and f[s.key] or {}) do out[#out + 1] = name end
    return out
end

-- Items hold only the sensor's key, so a second app on the same sensor re-stamps nothing.
local active = computed({ mantle.privacy, fake }, function(p, f)
    local out = {}
    for _, s in ipairs(SENSORS) do
        if #users(p, f, s) > 0 then out[#out + 1] = { key = s.key } end
    end
    return out
end, {})

local any = active:map(function(list) return #list > 0 end)
local sharing = active:map(function(list)
    for _, item in ipairs(list) do
        if item.key == "screen" then return true end
    end
    return false
end)

-- The first four apps by name, then a count of the rest.
local function names(s)
    local all, shown = users(mantle.privacy:get(), fake:get(), s), {}
    for i = 1, math.min(#all, 4) do shown[i] = all[i] end
    local text = table.concat(shown, ", ")
    return #all > 4 and (text .. " +" .. (#all - 4) .. " more") or text
end

local function sticker(output, s)
    local slot = "taskbar.privacy." .. output .. "." .. s.key
    local loop = controls.pencil_loop(theme.bar.indicator_loop_w, theme.bar.indicator_loop_h, #s.key * 7)
    loop.stroke = theme.RED
    loop.stroke_width = 1.6
    local hovered = hover(slot)
    return tips.wrap(rect {
        -- The loop's ink sits 10 px in from each side, as the updater's and the status group's do.
        width = theme.bar.indicator_w,
        height = "fill",
        hover = hovered,
        accessible_name = s.label .. " in use",
        cursor = "pointer",
        on_click = function(r) quick.open(r, "privacy", output) end,
        on_drag = press.track(slot),
        -- A quick lift away when the sensor goes quiet.
        animate = { exit = { duration = 160, easing = "in_cubic", opacity = 0, translate = { y = -theme.spacing.snug }, scale = 1.1 } },
        children = {
            rect {
                align_h = "center",
                align_v = "center",
                rotate = hovered:map(function(v) return v and 3 or -4 end),
                translate = hovered:map(function(v) return { y = v and -2 or 0 } end),
                scale = press.scale(slot),
                -- Stamped on: down from 1.3 with a turn, on a spring.
                animate = {
                    scale = { spring = { stiffness = 520, damping = 20 }, from = 1.3 },
                    rotate = { spring = { stiffness = 420, damping = 18 }, from = -16 },
                    translate = { duration = 140, easing = "out_cubic" },
                },
                children = {
                    loop,
                    rect {
                        width = theme.bar.indicator_loop_w,
                        height = theme.control.tab,
                        children = {
                            rect {
                                align_h = "center",
                                align_v = "center",
                                children = { icons.doodle(s.glyph, icons.STATUS, theme.RED) },
                            },
                        },
                    },
                },
            },
        },
    }, slot, function() return s.label .. ": " .. names(s) end)
end

function M.indicators(output)
    return list {
        direction = "horizontal",
        height = "fill",
        spacing = theme.spacing.snug,
        -- Held past the last sensor going quiet so its exit can play; hidden it takes no gap.
        visible = util.linger(any, 200),
        items = active,
        key = function(item) return item.key end,
        each = function(item) return sticker(output, BY_KEY[item.key]) end,
    }
end

-- The LIVE strip: opaque red washi tape across the corner, Caveat in deep red ink.
local TAPE_W, TAPE_H = theme.bar.live_tape_w, theme.bar.live_tape_h

local function live_tape()
    return rect {
        width = TAPE_W,
        height = TAPE_H,
        align_h = "end",
        align_v = "start",
        translate = { x = theme.bar.live_tape_x, y = theme.bar.live_tape_y },
        rotate = 38,
        background = theme.RECORDING_TAPE,
        shape = k.tape_shape(TAPE_W, TAPE_H, 61),
        shadows = theme.SHADOW.tape,
        effect = k.paper_fx { grain = 0.35, mottle = 0.2, rim = 0 },
        animate = {
            translate = { duration = 260, easing = "out_back", from = { x = theme.bar.live_tape_x, y = -theme.bar.live_enter_y } },
            exit = { duration = 220, easing = "in_cubic", opacity = 0, translate = { x = theme.bar.live_exit_x, y = -theme.bar.live_exit_y }, rotate = 52 },
        },
        children = {
            k.hand("LIVE", theme.font.xxl, { font_weight = theme.BOLD, foreground = theme.DEEP_RED, align_h = "center", align_v = "center" }),
        },
    }
end

M.live_surface = panel {
    id = "paper-privacy-live",
    namespace = "paper-privacy-live",
    layer = "overlay",
    anchor = { top = true, right = true },
    width = theme.bar.live_surface_w,
    height = theme.bar.live_surface_h,
    exclusive_zone = false,
    keyboard_interactivity = "none",
    visible = util.linger(sharing, 260),
    child = rect {
        width = "fill",
        height = "fill",
        -- Pointer-transparent: no node claims input, so clicks reach the window under the corner.
        hittable = false,
        children = sharing:map(function(on) return on and { live_tape() } or {} end),
    },
}

return M
