-- Night light: warms the screen with hyprsunset. On is the user's switch; the schedule either keeps
-- it warm whenever on ("manual") or only between two fixed times ("times", sunset to sunrise by
-- default). hyprsunset runs as a session process, so a reload keeps the screen as it was; a new
-- warmth goes over its IPC socket. Without the binary, everything says "Install hyprsunset"; on
-- another compositor, where hyprsunset cannot warm anything, the tile and controls are hidden.
local paths = require("lib.paths")
local nightlight = {}

local MIN_K, MAX_K = 2500, 6000
nightlight.MIN_K, nightlight.MAX_K = MIN_K, MAX_K

local store = persistent_table {
    path = paths.state("state-nightlight.json"),
    -- `from`/`to`: minutes after midnight.
    defaults = { enabled = false, temperature = 4000, schedule = "manual", from = 20 * 60, to = 7 * 60 },
}
nightlight.store = store

--- Whether the compositor is Hyprland; `false` until `workspaces` answers.
nightlight.supported = mantle.workspaces:map(function(w) return w.compositor == "hyprland" end, false)

--- `nil` until checked, then whether `hyprsunset` is on PATH.
nightlight.installed = state("nightlight.installed", nil)

function nightlight.recheck()
    process.capture("sh", { "-c", "command -v hyprsunset" }, function(out, code)
        nightlight.installed:set(code == 0 and out ~= nil and out ~= "")
    end)
end
nightlight.recheck()
-- ponytail: polls PATH once a minute while hyprsunset is missing, so installing it needs no
-- reload; a pacman hook or inotify on /usr/bin would replace the poll.
interval(60000, function()
    if nightlight.supported:get() and nightlight.installed:get() == false then nightlight.recheck() end
end)

local sunset = session_process { name = "nightlight" }

local minute = mantle.clock:map(function(c)
    local t = os.date("*t", c.time)
    return t.hour * 60 + t.min
end, 0)

local function in_window(m, from, to)
    if from == to then return true end
    if from < to then return m >= from and m < to end
    return m >= from or m < to
end

--- "20:00".
function nightlight.format_time(m)
    return string.format("%02d:%02d", m // 60 % 24, m % 60)
end

--- Whether the screen should be warm right now.
nightlight.active = computed({ store.enabled, store.schedule, store.from, store.to, minute },
    function(on, schedule, from, to, m)
        return on == true and (schedule ~= "times" or in_window(m, from, to))
    end)

--- The quick-settings tile's line and the settings caption.
nightlight.status = computed({ nightlight.supported, nightlight.installed, store.enabled, store.schedule, store.from, store.to,
    store.temperature, nightlight.active, sunset.start_error }, function(supported, installed, on, schedule, from, to, kelvin, active, err)
    if not supported then return "Needs Hyprland" end
    if installed == false then return "Install hyprsunset" end
    if err and err ~= "" then return "hyprsunset failed" end
    if not on then return "Off" end
    if schedule ~= "times" then return kelvin .. " K" end
    if active then return kelvin .. " K until " .. nightlight.format_time(to) end
    return "From " .. nightlight.format_time(from)
end, "Off")

-- The temperature the running hyprsunset was last given, so a slider drag sends only changes.
local sent

local function sync()
    local want = nightlight.active:get() and nightlight.supported:get() and nightlight.installed:get() == true
    local kelvin = math.floor(store.temperature:get() or 4000)
    if not want then
        if sunset.running:get() then sunset:stop() end
        sent = nil
        return
    end
    if not sunset.running:get() then
        sunset:start("hyprsunset", { "-t", tostring(kelvin) })
        sent = kelvin
    elseif sent ~= kelvin then
        sent = kelvin
        process.capture("hyprctl", { "hyprsunset", "temperature", tostring(kelvin) }, function() end)
    end
end

nightlight.active:on_change(sync)
nightlight.installed:on_change(sync)
nightlight.supported:on_change(sync)
store.temperature:on_change(sync)
-- A run that ends on its own (killed outside the shell, or a second gamma client refused) is not
-- restarted, so a failing start cannot loop; the next switch or schedule edge starts it again.
sunset.running:on_change(function(running)
    if running == false then sent = nil end
end)

function nightlight.set_enabled(on) store:set("enabled", on == true) end

function nightlight.set_temperature(kelvin)
    store:set("temperature", math.floor(math.max(MIN_K, math.min(MAX_K, kelvin)) / 50 + 0.5) * 50)
end

--- 0 (coolest) to 1 (warmest), for a slider that warms to the right.
nightlight.warmth = store.temperature:map(function(kelvin)
    return (MAX_K - (kelvin or 4000)) / (MAX_K - MIN_K)
end, 0.5)

function nightlight.set_warmth(v)
    nightlight.set_temperature(MAX_K - v * (MAX_K - MIN_K))
end

return nightlight
