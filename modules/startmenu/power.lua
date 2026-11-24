-- The power row: torn card-stock stubs for lock, log out, suspend, restart and shut down. Log out,
-- restart and shut down arm on the first click, show a 10 s countdown in red marker, and run only
-- on a second click inside it. Expiry, Escape, closing the menu or any other click disarms.
--
-- The pending + deadline pair comes from ~/.config/mantle/modules/bar/indicators/power_menu.lua,
-- with one change: there the deadline runs the action, here it only disarms, so nothing runs
-- without a second click. `run` has one call site, behind a live `mantle.clock:now()` check, so a
-- stale `pending` left by a reload is harmless.
local k = require("lib.paper")
local icons = require("modules.startmenu.icons")
local controls = require("components.controls")
local tips = require("modules.startmenu.tips")
local model = require("modules.startmenu.model")
local compositor = require("lib.compositor")
local ui_state = require("lib.ui_state")

local M = {}

local COUNTDOWN = 10
local W, H = 52, 50

local pending = state("startmenu.power_pending", "")
local deadline = state("startmenu.power_deadline", 0)
M.reset = { pending, deadline }

local ACTIONS = {
    { key = "lock", label = "Lock", icon = "lock", stock = "plain",
        run = function() mantle.lock:lock() end },
    { key = "logout", label = "Log out", icon = "logout", stock = "danger", confirm = true,
        run = function() compositor.detach("logout") end },
    { key = "suspend", label = "Suspend", icon = "suspend", stock = "plain",
        run = function() process.detach("systemctl", { "suspend" }) end },
    { key = "reboot", label = "Restart", icon = "reboot", stock = "danger", confirm = true,
        run = function() process.detach("systemctl", { "reboot" }) end },
    { key = "poweroff", label = "Shut down", icon = "poweroff", stock = "danger", confirm = true,
        run = function() process.detach("systemctl", { "poweroff" }) end },
}
for _, a in ipairs(ACTIONS) do ACTIONS[a.key] = a end

-- The armed key, or "" once its deadline has passed.
local function armed_now()
    local key = pending:get()
    if key ~= "" and mantle.clock:now() < deadline:get() then return key end
    return ""
end

-- Seconds left on the armed action, ticking with the clock's once-a-second push. Read live: the
-- pushed value can be a second old, which would open the count at 11.
local left = computed({ mantle.clock, pending, deadline }, function(_, key, at)
    local now = mantle.clock:now()
    if key == "" or now >= at then return { key = "", seconds = 0 } end
    return { key = key, seconds = math.ceil(at - now) }
end, { key = "", seconds = 0 })

function M.disarm()
    if pending:get() ~= "" then pending:set("") end
end

ui_state.on_modal_close("startmenu", M.disarm)

local function press(a)
    local armed = armed_now()
    if a.confirm and armed == "" then
        deadline:set(mantle.clock:now() + COUNTDOWN)
        pending:set(a.key)
        return
    end
    M.disarm()
    -- A click on another stub while one is armed only cancels.
    if armed ~= "" and armed ~= a.key then return end
    ui_state.close_modal("startmenu")
    a.run()
end

-- Icon-only, so each stub names itself in a tooltip.
local function stub(a, i)
    local slot = "startmenu.power." .. a.key
    local hovered = hover(slot)
    local focus = focus_visible(slot .. ".focus")
    local lit = computed({ hovered, focus }, function(h, f) return h or f end)
    local stock = k.STOCK[a.stock]
    local face = left:map(function(l) return l.key == a.key and l.seconds or 0 end)
    return tips.wrap(rect {
        width = W,
        height = H,
        hover = hovered,
        focus_visible = focus,
        focus_ring = false,
        accessible_name = a.label,
        cursor = "pointer",
        on_click = function() press(a) end,
        on_drag = model.track(slot),
        scale = model.sink(slot, 0.92),
        rotate = lit:map(function(v) return v and -2 or ((i % 3) - 1) * 0.6 end),
        translate = lit:map(function(v) return { y = v and -3 or 0 } end),
        animate = {
            rotate = { spring = { stiffness = 300, damping = 16 } },
            translate = { duration = 140, easing = "out_cubic" },
            scale = { duration = 90, easing = "out_cubic" },
        },
        children = {
            k.sheet {
                width = W,
                height = H,
                seed = 200 + i * 13,
                depth = 3,
                color = stock[1],
                shadows = k.lift(lit),
                animate = { shadows = { duration = 160, easing = "out_cubic" } },
                fx = { rim = 0 },
                child = rect {
                    width = "fill",
                    height = "fill",
                    children = face:map(function(n)
                        if n > 0 then
                            return { k.hand(tostring(n), 34, {
                                font_weight = 700, foreground = k.DEEP_RED, align_h = "center", align_v = "center",
                            }) }
                        end
                        return { icons.glyph(a.icon, 24, stock[2]) }
                    end),
                },
            },
            rect {
                translate = { x = -3, y = -3 },
                children = focus:map(function(f)
                    return f and { controls.pencil_loop(W + 6, H + 6, 30 + i) } or {}
                end),
            },
        },
    }, slot, a.label)
end

-- The armed countdown under the row, in deep red: readable text, where RED is for marks.
local function caption()
    return left:map(function(l)
        if l.key == "" then return {} end
        return { k.hand(string.format("%s in %d… click again", ACTIONS[l.key].label, l.seconds), 26, {
            font_weight = 700, foreground = k.DEEP_RED, align_h = "center",
        }) }
    end)
end

function M.row()
    local stubs = {}
    for i, a in ipairs(ACTIONS) do stubs[i] = stub(a, i) end
    return column {
        width = "fill",
        spacing = 6,
        children = {
            -- Five 52 px stubs and four 6 px gaps span the right page's 284 px content width.
            row { spacing = 6, children = stubs },
            rect { width = "fill", height = 36, children = caption() },
        },
    }
end

return M
