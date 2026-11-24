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

-- Seconds left on the armed action, ticking with the clock's once-a-second push.
local left = computed({ mantle.clock, pending, deadline }, function(clock, key, at)
    local now = (clock and clock.monotonic) or 0
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

local function stub(a, i)
    local hovered = hover("startmenu.power." .. a.key)
    local stock = k.STOCK[a.stock]
    local face = left:map(function(l) return l.key == a.key and l.seconds or 0 end)
    return rect {
        width = W,
        height = H,
        hover = hovered,
        accessible_name = a.label,
        cursor = "pointer",
        on_click = function() press(a) end,
        rotate = hovered:map(function(v) return v and -2 or ((i % 3) - 1) * 0.6 end),
        translate = hovered:map(function(v) return { y = v and -3 or 0 } end),
        animate = {
            rotate = { spring = { stiffness = 300, damping = 16 } },
            translate = { duration = 140, easing = "out_cubic" },
        },
        children = {
            k.sheet {
                width = W,
                height = H,
                seed = 200 + i * 13,
                depth = 3,
                color = stock[1],
                shadows = k.lift(hovered),
                animate = { shadows = { duration = 160, easing = "out_cubic" } },
                fx = { rim = 0 },
                child = rect {
                    width = "fill",
                    height = "fill",
                    children = face:map(function(n)
                        if n > 0 then
                            return { k.hand(tostring(n), 34, {
                                font_weight = 700, foreground = k.RED, align_h = "center", align_v = "center",
                            }) }
                        end
                        return { icons.glyph(a.icon, 24, stock[2], { align_h = "center" }) }
                    end),
                },
            },
        },
    }
end

-- The caption under the row: the hovered stub's name in pencil, or the armed countdown in red.
local function caption()
    local hovers = {}
    for i, a in ipairs(ACTIONS) do hovers[i] = hover("startmenu.power." .. a.key) end
    local deps = { left }
    for _, h in ipairs(hovers) do deps[#deps + 1] = h end
    return computed(deps, function(l, ...)
        if l.key ~= "" then
            return { k.hand(string.format("%s in %d… click again", ACTIONS[l.key].label, l.seconds), 26, {
                font_weight = 700, foreground = k.RED, align_h = "center",
            }) }
        end
        for i = 1, #ACTIONS do
            if select(i, ...) then
                return { k.body(ACTIONS[i].label, 18, {
                    foreground = k.INK_SOFT, align_h = "center", padding = { top = 6 },
                }) }
            end
        end
        return {}
    end)
end

function M.row()
    local stubs = {}
    for i, a in ipairs(ACTIONS) do stubs[i] = stub(a, i) end
    return column {
        width = "fill",
        spacing = 6,
        children = {
            row { spacing = 8, align_h = "center", children = stubs },
            rect { width = "fill", height = 36, children = caption() },
        },
    }
end

return M
