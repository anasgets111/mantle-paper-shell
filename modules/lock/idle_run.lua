-- Runs the idle stages: one idle threshold, then the clock tick walks the plan, arms the first
-- stage not yet done, and fires it after its delay. Ported from
-- ~/.config/mantle/modules/global/idle.lua. Nothing registers while `idle.ENABLED` is false.
-- Returns the dim overlay panel.
local util = require("lib.util")
local compositor = require("lib.compositor")
local idle = require("modules.lock.idle")

local since = state("lock.idle.since", 0)
-- Arming stamp per stage key (at most one), the stamp each stage fired for, and the profile the
-- stamp was taken under.
local armed_at = state("lock.idle.armed_at", {})
local fired_at = state("lock.idle.fired_at", {})
local armed_profile = state("lock.idle.armed_profile", "")

local function set_displays_powered(powered)
    if idle.blanked:get() == (not powered) then return end
    -- `blanked` is the dpms stage's `done`: setting it on a no-op would arm the next stage over a
    -- lit screen.
    if not compositor.detach(powered and "displays_on" or "displays_off") then return end
    idle.blanked:set(not powered)
end

local ACTIONS = {
    dim = function() idle.dimmed:set(true) end,
    lock = function() mantle.lock:lock() end,
    dpms = function() set_displays_powered(false) end,
    suspend = function() process.detach("systemctl", { "suspend" }) end,
}

if idle.ENABLED then
    mantle.idle:register_threshold(idle.TICK, function()
        -- Back-dated, so the countdown runs from the last input, not from this push.
        since:set(mantle.clock:now() - idle.TICK)
    end, function(cause)
        idle.dimmed:set(false)
        if cause == "input" then set_displays_powered(true) end
        since:set(0)
        armed_at:set({})
        fired_at:set({})
    end)

    mantle.clock:on_change(function(clock)
        local started = since:get()
        if started == 0 then return end
        local settings = idle.settings:get()
        if not settings.enabled or idle.sleep_held(settings, mantle.idle:get()) then
            if next(armed_at:get()) ~= nil or next(fired_at:get()) ~= nil then
                armed_at:set({})
                fired_at:set({})
            end
            return
        end
        local profile = idle.profile_of(mantle.power:get())
        local armed = idle.armed(idle.plan(settings, profile))
        -- A profile switch re-stamps: the old stamp was measured against the other profile's timeout.
        local switched = armed_profile:get() ~= profile
        armed_profile:set(profile)
        local stamps = (not switched and armed_at:get()) or {}
        local next_stamps = {}
        if armed then
            next_stamps[armed.key] = stamps[armed.key] or math.max(clock.monotonic, started)
        end
        armed_at:set(next_stamps)
        if armed and clock.monotonic - next_stamps[armed.key] >= armed.delay
            and fired_at:get()[armed.key] ~= next_stamps[armed.key] then
            -- Once per arming: a terminal stage stays armed after acting.
            fired_at:set({ [armed.key] = next_stamps[armed.key] })
            ACTIONS[armed.key]()
        end
    end)
end

-- Dimming is a shade over every output rather than the backlight, so it works on an external
-- monitor too. It takes no input: the next keystroke or move resumes and lifts it.
return panel {
    id = "paper-idle-dim",
    layer = "overlay",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive_zone = "ignore",
    width = "fill",
    height = "fill",
    visible = util.linger(idle.dimmed, 600),
    child = rect {
        width = "fill",
        height = "fill",
        background = "#000000",
        opacity = util.choose(idle.dimmed, 0.55, 0),
        animate = { opacity = { duration = 600, easing = "out_cubic", from = 0 } },
    },
}
