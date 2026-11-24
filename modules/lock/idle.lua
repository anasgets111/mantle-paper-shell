-- Idle settings, stages and the keep-awake hold, ported from ~/.config/mantle/lib/idle.lua.
-- Loading this fires nothing; `modules/lock/idle_run.lua` runs the stages, and only when
-- `idle.ENABLED` is true.
--
-- Stages arm one after another: each stage's seconds count from the one before it, and a stage
-- arms only once its predecessor reports `done`. Profiles: `ac` and `battery`.
local util = require("lib.util")
local G = require("modules.lock.glyphs")

-- Off until the paper shell is finished: no threshold is registered, so nothing dims, locks,
-- blanks or suspends, and no automatic (camera/mic) hold is taken. The settings page still edits
-- and saves every timer, and the manual keep-awake hold still works. Flip to true to switch on.
local IDLE_ENABLED = false

local idle = {}

idle.ENABLED = IDLE_ENABLED

idle.TICK = 1

local store = persistent_table {
    path = mantle.config_dir .. "/state-lock.json",
    defaults = { idle = {} },
}

--- Whether the screen is dimmed / the displays are off because a stage did it.
idle.dimmed = state("lock.idle.dimmed", false)
idle.blanked = state("lock.idle.blanked", false)

local STAGES = {
    {
        key = "dim", title = "Dim the screen", detail = "Any input brings it back",
        icon = G.dim, options = { 30, 60, 90, 120, 180, 240, 300, 600 },
        done = function() return idle.dimmed:get() end,
    },
    {
        key = "lock", title = "Lock the screen", detail = "Needs your password to come back",
        icon = G.lock, options = { 15, 30, 60, 120, 300, 600, 1800 },
        done = function()
            local lock = mantle.lock:get()
            return lock ~= nil and lock.active
        end,
    },
    {
        key = "dpms", title = "Turn off displays", detail = "Until input comes back",
        icon = G.display, options = { 15, 30, 60, 120, 300, 600, 900 },
        done = function() return idle.blanked:get() end,
    },
    -- Terminal: no `done`, so nothing waits behind it.
    {
        key = "suspend", title = "Suspend", detail = "Sleeps the machine",
        icon = G.suspend, options = { 300, 600, 900, 1800, 3600, 7200 },
    },
}

function idle.stage(key)
    return util.find(STAGES, function(stage) return stage.key == key end)
end

-- Seconds count from the stage before, so lowering the dim timeout cannot shorten the lock gap.
local DEFAULTS = {
    ac = {
        dim_on = true, dim_sec = 240, lock_on = true, lock_sec = 60,
        dpms_on = true, dpms_sec = 60, suspend_on = false, suspend_sec = 1800,
    },
    battery = {
        dim_on = true, dim_sec = 90, lock_on = true, lock_sec = 30,
        dpms_on = true, dpms_sec = 30, suspend_on = true, suspend_sec = 600,
    },
}

-- Each stage exactly once: drop unknown and duplicate keys, append missing ones in default order.
local function resolve_order(stored)
    local seen, out = {}, {}
    for _, key in ipairs(type(stored) == "table" and stored or {}) do
        if type(key) == "string" and not seen[key] and idle.stage(key) then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    for _, stage in ipairs(STAGES) do
        if not seen[stage.key] then out[#out + 1] = stage.key end
    end
    return out
end

--- Every key filled: a hand-edited or older file may lack some.
function idle.read(stored)
    stored = type(stored) == "table" and stored or {}
    local out = {
        enabled = stored.enabled == true,
        privacy_auto_inhibit = stored.privacy_auto_inhibit ~= false,
        sleep_holds_keep_awake = stored.sleep_holds_keep_awake ~= false,
        order = resolve_order(stored.order),
    }
    for name, fallback in pairs(DEFAULTS) do
        local held = type(stored[name]) == "table" and stored[name] or {}
        local profile = {}
        for key, default in pairs(fallback) do
            local value = held[key]
            profile[key] = type(value) == type(default) and value or default
        end
        out[name] = profile
    end
    return out
end

idle.settings = store.idle:map(idle.read)

function idle.write(patch)
    local current = idle.read(store.idle:get())
    for key, value in pairs(patch) do current[key] = value end
    store:set("idle", current)
end

--- "Off", "45s", "5m", "1m 30s", "2h".
function idle.format(sec)
    if sec == nil or sec <= 0 then return "Off" end
    if sec < 60 then return string.format("%ds", sec) end
    if sec % 3600 == 0 then return string.format("%dh", sec // 3600) end
    if sec % 60 == 0 then return string.format("%dm", sec // 60) end
    return string.format("%dm %ds", sec // 60, sec % 60)
end

function idle.profile_of(power)
    return (power ~= nil and power.on_battery == true) and "battery" or "ac"
end

--- No UPower means AC: a machine that cannot say it is on battery is plugged in.
idle.active_profile = mantle.power:map(idle.profile_of, "ac")

--- Runnable stages in order with their delays; `at` is the running total, for display.
function idle.plan(settings, profile)
    local numbers = settings[profile]
    local list, from = {}, 0
    for _, key in ipairs(settings.order) do
        local stage = idle.stage(key)
        local delay = stage and numbers[key .. "_sec"] or 0
        if stage and numbers[key .. "_on"] and delay > 0 then
            from = from + delay
            list[#list + 1] = { key = key, title = stage.title, at = from, delay = delay }
        end
    end
    return { list = list, total = from }
end

--- The first stage of `plan` not yet `done`; a stage without `done` ends the chain.
function idle.armed(plan)
    for _, entry in ipairs(plan.list) do
        local stage = idle.stage(entry.key)
        if not (stage and stage.done and stage.done() == true) then return entry end
    end
end

--- Move stage `key` to position `to` (1-based), keeping the others in order.
function idle.move(key, to)
    local order = idle.read(store.idle:get()).order
    local at = util.index_of(order, key)
    if at == nil or to == at or to < 1 or to > #order then return end
    idle.write({ order = util.move(order, at, to) })
end

idle.schedule = computed({ idle.settings, idle.active_profile }, idle.plan)

-- Keep-awake ------------------------------------------------------------------------------------

--- The page's own "keep awake now" hold.
idle.manual = state("lock.idle.manual", false)
-- Whether a logind hold is out in our name. Calls are counted, so a wrong count leaks one.
local holding = state("lock.idle.holding", false)

local PRIVACY = { { "camera_users", "camera" }, { "microphone_users", "microphone" }, { "screencast_users", "screen capture" } }

-- Reasons this config would hold the session awake for. Camera/mic/screen holds are automatic
-- actions, so they wait for `idle.ENABLED`; the manual hold is a direct request and does not.
local function own_reasons(privacy, settings, manual)
    local reasons = manual and { "you asked" } or {}
    if idle.ENABLED and settings.enabled and settings.privacy_auto_inhibit then
        for _, source in ipairs(PRIVACY) do
            if #((privacy or {})[source[1]] or {}) > 0 then reasons[#reasons + 1] = source[2] end
        end
    end
    return reasons
end

--- Whether a foreign logind `sleep` hold should keep the session awake under `settings`.
function idle.sleep_held(settings, foreign)
    return settings.sleep_holds_keep_awake and foreign ~= nil and foreign.sleep_inhibited == true
end

--- Everything named as holding the session awake, ours and other apps'.
idle.reasons = computed({ mantle.privacy, idle.settings, idle.manual, mantle.idle }, function(privacy, settings, manual, foreign)
    local reasons, seen = own_reasons(privacy, settings, manual), {}
    local function add(list)
        for _, holder in ipairs(list or {}) do
            local name = holder.who ~= "" and holder.who or holder.why ~= "" and holder.why or "another app"
            if not seen[name] then
                seen[name] = true
                reasons[#reasons + 1] = name
            end
        end
    end
    add(foreign and foreign.inhibitors)
    if settings.sleep_holds_keep_awake then add(foreign and foreign.sleep_inhibitors) end
    return reasons
end, {})

--- Make our logind hold match our reasons. The one writer, so the take/release count stays right.
function idle.sync_inhibit()
    local want = #own_reasons(mantle.privacy:get(), idle.read(store.idle:get()), idle.manual:get()) > 0
    if want == holding:get() then return end
    holding:set(want)
    if want then
        mantle.idle:inhibit("paper shell: keep awake")
    else
        mantle.idle:release_inhibit()
    end
end

function idle.set_manual(on)
    idle.manual:set(on)
    idle.sync_inhibit()
end

mantle.privacy:on_change(idle.sync_inhibit)
store.idle:on_change(idle.sync_inhibit)

return idle
