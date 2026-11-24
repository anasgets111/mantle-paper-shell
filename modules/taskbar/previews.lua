-- Window previews: hovering a task for 400 ms opens a sticky note above it holding one polaroid per
-- window, a live capture over an icon-and-title fallback, with a close disc. The note stays while
-- the pointer is on the icon or the note, and for 250 ms after it leaves both.
local k = require("lib.paper")
local util = require("lib.util")
local controls = require("components.controls")
local tasks = require("modules.taskbar.tasks")
local menus = require("modules.taskbar.menus")
local icons = require("modules.taskbar.icons")

local M = {}

local SHOT_W, SHOT_H, FRAME = 248, 140, 10
local CARD_W, CARD_H = SHOT_W + 2 * FRAME, SHOT_H + FRAME + 40

local hovered = state("taskbar.preview.hovered", "") -- the hovered slot's hover name
local settled = delay(hovered, 400)
local note_hovered = hover("taskbar.preview")
local shown = state("taskbar.preview.shown", "")
local anchor = state("taskbar.preview.anchor", { x = 0, y = 0, width = 1, height = 1 })

-- Slot hover name -> its item, refreshed each time the task list builds the slot.
local items = {}

function M.register(name, item)
    items[name] = item
end

function M.on_hover(name)
    return util.track_hover(hovered, name)
end

-- A click hides the note and keeps it away until the pointer leaves that icon.
local suppressed

function M.hide()
    suppressed = hovered:get()
    shown:set("")
end

hovered:on_change(function(name)
    if name ~= suppressed then suppressed = nil end
end)

-- Hovered and unchanged for 400 ms.
local target = computed({ hovered, settled }, function(h, s) return (h ~= "" and h == s) and h or "" end)
target:on_change(function(name)
    local item = items[name]
    if name == "" or name == suppressed or not item or #item.wins == 0 or menus.is_open:get() then return end
    local r = hover_rect(name):get()
    anchor:set({ x = r.x, y = r.y, width = math.max(1, r.width), height = math.max(1, r.height) })
    shown:set(name)
end)

local keep = computed({ hovered, note_hovered }, function(h, n) return h ~= "" or n end)
local held = delay(keep, 250)
local visible = computed({ shown, keep, held }, function(s, now, was) return s ~= "" and (now or was) end)
visible:on_change(function(v)
    if not v then shown:set("") end
end)

local function close_disc(win)
    local h = hover("taskbar.preview.close." .. win.id)
    return rect {
        width = 24,
        height = 24,
        align_h = "end",
        align_v = "start",
        translate = { x = 8, y = -8 },
        hover = h,
        accessible_name = "Close " .. win.title,
        cursor = "pointer",
        on_click = function() mantle.windows:close(win.id) end,
        children = {
            k.sheet {
                width = 24,
                height = 24,
                shape = k.torn_circle(24, #win.id + 3),
                color = h:map(function(v) return v and "#F2CFC8" or "#F4ECDA" end),
                shadows = k.lift(h),
                fx = { rim = 0 },
            },
            icons.glyph("window-close-symbolic", 12, h:map(function(v) return v and k.DEEP_RED or k.INK end)),
        },
    }
end

local function polaroid(win, item, i)
    local h = hover("taskbar.preview.card." .. win.id)
    return rect {
        hover = h,
        accessible_name = win.title,
        cursor = "pointer",
        rotate = h:map(function(v) return v and -1.5 or (i % 2 == 0 and 0.8 or -0.6) end),
        translate = h:map(function(v) return { y = v and -3 or 0 } end),
        animate = {
            rotate = { spring = { stiffness = 300, damping = 16 } },
            translate = { duration = 140, easing = "out_cubic" },
        },
        on_click = function()
            M.hide()
            mantle.windows:focus(win.id)
        end,
        children = {
            k.sheet {
                width = CARD_W,
                height = CARD_H,
                seed = i * 17 + #win.id,
                depth = 2,
                color = "#FBF7EE",
                shadows = k.lift(h),
                animate = { shadows = { duration = 160, easing = "out_cubic" } },
                fx = { rim = 0, grain = 0.08 },
                child = column {
                    padding = { top = FRAME, left = FRAME, right = FRAME },
                    spacing = 6,
                    children = {
                        rect {
                            width = SHOT_W,
                            height = SHOT_H,
                            background = "#3A363114",
                            border_width = 1,
                            border_color = "#3A363140",
                            children = {
                                -- A failed capture draws nothing, so the fallback sits underneath.
                                column {
                                    align_h = "center",
                                    align_v = "center",
                                    spacing = 6,
                                    children = {
                                        icons.app(item.icon, 48),
                                        k.body(item.name, 16, { foreground = k.INK_SOFT, align_h = "center" }),
                                    },
                                },
                                capture { window = win.id, live = 4, width = SHOT_W, height = SHOT_H, fit = "contain" },
                            },
                        },
                        row {
                            width = SHOT_W,
                            spacing = 6,
                            children = {
                                icons.app(item.icon, 18),
                                k.body(win.title ~= "" and win.title or item.name, 18, {
                                    width = "fill", elide = "end", align_v = "center",
                                    foreground = win.focused and k.DEEP_BLUE or k.INK,
                                }),
                            },
                        },
                    },
                },
            },
            close_disc(win),
        },
    }
end

local function note(name, windows)
    local item = items[name]
    if not item then return rect { width = 1, height = 1 } end
    local cards = {}
    for i, win in ipairs(tasks.windows_of(item.wins, windows)) do cards[i] = polaroid(win, item, i) end
    if #cards == 0 then return rect { width = 1, height = 1 } end
    local w = #cards * (CARD_W + 14) + 26
    return rect {
        -- The sticky's shadow needs 21 px below it; its tilt swings a wide note's ends a few px more.
        padding = { left = 16, right = 22, top = 8, bottom = 26 },
        hover = note_hovered,
        animate = {
            opacity = { duration = 140, easing = "out_cubic", from = 0 },
            translate = { duration = 160, easing = "out_cubic", from = { y = 8 } },
        },
        children = {
            -- Hyprland's `blur_popups` frosts a popup's whole rectangle unless the popup sends a blur
            -- region; this one pixel, hidden under the opaque note, is that region.
            rect { width = 1, height = 1, align_h = "center", align_v = "center", compositor_blur = true },
            controls.sticky {
                width = w,
                height = CARD_H + 44,
                seed = #name,
                rotate = -0.6,
                child = row {
                    padding = { left = 16, top = 22 },
                    spacing = 14,
                    children = cards,
                },
            },
        },
    }
end

M.surface = popup {
    id = "paper-taskbar-previews",
    -- ponytail: `parent` is static and an unarmed (grab = false) popup takes the panel's first
    -- instance (renderer/src/wayland/xdg_shell/popup.rs, parent_instance_index), so on a second
    -- monitor the note opens on the first one. Upgrade: a popup `output`, then one popup per output.
    parent = "paper-taskbar",
    grab = false,
    visible = visible,
    anchor_rect = anchor,
    anchor = "top",
    gravity = "top",
    constraint_adjustment = { "slide_x", "flip_y" },
    child = computed({ shown, mantle.windows }, note),
}

return M
