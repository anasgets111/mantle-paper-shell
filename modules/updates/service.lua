-- The update service around `mantle.updates`: saved settings, the run record and its effects
-- (persist the last check, notify once, recheck after an install, the developer tools), and the
-- signals the widget, popup and settings page draw. Logic from ~/.config/mantle/lib/updates.lua.
local util = require("lib.util")
local model = require("modules.updates.model")
local tools = require("modules.updates.tools")

local S = {}

local FILE = mantle.config_dir .. "/state-updates.json"
local APP = "Updates"
-- As many as the Supervisor's `install_log` tail.
local LOG_LINES = 200

local saved = persistent_table {
    path = FILE,
    defaults = {
        -- The last successful check, seeded into the capability so a restart need not recheck.
        checked_at = 0,
        packages = {},
        -- Package names already announced, newline-joined: a notification only names new ones.
        notified = "",
        -- Seconds between checks; 0 checks only on demand.
        interval = 3600,
        aur = true,
        notify = true,
        -- Developer tool name to `false` when unticked; absent counts as ticked.
        dev_tools = {},
        -- The last finished run: `{ at, ok, text }`.
        last_install = {},
    },
}
S.saved = saved

S.INTERVALS = { { 3600, "hourly" }, { 21600, "every 6 h" }, { 86400, "daily" }, { 0, "manual" } }

-- Test overlay, off by default: `mantle set updates.fake '{"installing":true,...}'` lays fields over
-- the real state, and its `run` over the run record, for the views only. No effect reads it, and
-- install, the tools and restart refuse to run while it is set. `mantle set updates.fake '{}'` ends it.
local fake = state("updates.fake", {})
function S.faking()
    return next(fake:get() or {}) ~= nil
end

-- The current or last run; see `model.lua`.
local run = state("updates.run", {})
-- The developer tools' log, apart from `run` so a line does not rerun every map of it.
local tool_log = state("updates.tool_log", {})
-- The popup is open: results are on screen, so no notification repeats them.
S.open = state("updates.open", false)

-- Views -----------------------------------------------------------------------------------------

S.updates = computed({ mantle.updates, fake }, function(u, f)
    if next(f or {}) == nil then return u end
    local merged = util.with(u or { packages = {}, install_log = {} }, "run", nil)
    for key, value in pairs(f) do
        if key ~= "run" then merged[key] = value end
    end
    return merged
end)
S.run = computed({ run, fake }, function(r, f) return (f or {}).run or r end, {})

local minute = mantle.clock:map(function(clock) return clock.time // 60 end, os.time() // 60)
S.minute = minute
local polkit = mantle.polkit:map(function(agent) return agent.active end, false)

S.phase = computed({ S.updates, S.run }, model.phase, "loading")
S.look = computed({ S.phase, S.updates, S.run, minute, polkit }, function(phase, u, r, at, agent)
    return model.look(phase, u, r, { now = at * 60, polkit = agent, bytes = util.bytes })
end, model.look("loading", nil, {}, { now = 0, bytes = util.bytes }))
S.view = S.phase:map(function(name) return model.VIEW[name] or "list" end)
S.shown = computed({ S.phase, S.look }, model.worth_showing, false)
S.busy = computed({ S.updates, S.run }, function(u, r)
    return u == nil or u.checking or model.phase(u, r) == "running"
end, true)
S.checking = S.updates:map(function(u) return u ~= nil and u.checking end, false)
S.progress = computed({ S.updates, S.run }, function(u, r) return model.progress(u, r) end, model.progress(nil, {}))
S.reboot = S.updates:map(function(u) return u ~= nil and u.reboot_required end, false)

-- Every install log line re-pushes `mantle.updates`, so the list rebuilds on a scalar the engine
-- compares: the check's stamp, the count and both ends of the list.
local package_key = S.updates:map(function(u)
    local list = (u and u.packages) or {}
    return string.format("%s:%d:%s:%s", tostring(u and u.last_successful_check), #list,
        list[1] and list[1].name or "", list[#list] and list[#list].name or "")
end, "")
S.groups = package_key:map(function()
    local u = S.updates:get()
    return model.groups(u and u.packages)
end)
S.count = S.updates:map(function(u) return u and #u.packages or 0 end, 0)

-- Pacman's output unless the run was tools only, then the tools'. yay colours even without a tty.
S.log_lines = computed({ S.updates, S.run, tool_log }, function(u, r, lines)
    local own = {}
    for index, line in ipairs(r.kind ~= "tools" and u and u.install_log or {}) do
        own[index] = model.strip_ansi(line)
    end
    return util.concat(own, lines)
end, {})

S.tools_runnable = computed({ saved.dev_tools, tools.present }, tools.runnable, {})

-- Effects: the real capability only ---------------------------------------------------------------

local function notify(urgency, title, body)
    process.detach("notify-send", { "-u", urgency, "-a", APP, "-i", "system-software-update", title, body })
end

local function finished(current)
    local outcome, u = model.outcome(current), mantle.updates:get()
    local look = model.look(outcome, u, current, { now = os.time(), bytes = util.bytes })
    local text = current.reason or model.summary(current) or look.title
    saved:set("last_install", { at = current.finished_at, ok = outcome == "done", text = text })
    tools.probe()
    if S.open:get() then return end
    local restart = outcome == "done" and u and u.reboot_required
    notify(outcome == "failed" and "critical" or "normal", look.title,
        (look.detail ~= "" and look.detail or text) .. (restart and "\nRestart to finish updating." or ""))
end

local advance

local function poll_tools()
    file.read(tools.LOG, function(text)
        local current = run:get()
        if current.stage ~= "tools" then return end
        local exited = tools.running:get() == false
        local report = tools.parse(text, current.plan, exited, tostring(current.started_at))
        if report == nil then
            -- Its script never wrote a line: it could not start.
            if exited and os.time() - current.started_at > 5 then
                advance(model.tools_progress(current, { done = true, tool = 1, failures = {
                    { name = current.plan[1] or "?", reason = "The tools' script didn't start" },
                } }, os.time()))
            else
                timer(1000, poll_tools)
            end
            return
        end
        local lines = report.lines
        tool_log:set({ table.unpack(lines, math.max(1, #lines - LOG_LINES + 1)) })
        advance(model.tools_progress(current, report, os.time()))
        if not report.done then timer(1000, poll_tools) end
    end)
end

function advance(new)
    if new == nil then return end
    local old = run:get()
    run:set(new)
    -- `packages` is stale after any install, failed or not; the capability does not recheck.
    if old.stage == "packages" and new.stage ~= "packages" then mantle.updates:check() end
    if new.finished_at and not old.finished_at then
        finished(new)
    elseif new.stage == "tools" and old.stage ~= "tools" then
        tool_log:set({})
        tools.start(new.plan, tostring(new.started_at))
        -- Polled from a second on, by when `running` has reported the start.
        timer(1000, poll_tools)
    end
end

local function reconcile()
    advance(model.on_push(run:get(), mantle.updates:get(), os.time()))
end

local function begin(kind, names)
    local u = mantle.updates:get()
    if S.faking() or u == nil or u.checking or model.phase(u, run:get()) == "running"
        or (kind == "tools" and #names == 0) then
        return
    end
    tool_log:set({})
    advance(model.start(kind, names, os.time(), u))
    if kind == "system" then
        mantle.updates:install()
        timer(model.WATCHDOG * 1000, reconcile)
    end
end

-- Everything pending, then the ticked tools. A failed install reruns even with nothing pending.
function S.install()
    local u = mantle.updates:get()
    if u == nil then return end
    local system = #u.packages > 0 or model.phase(u, run:get()) == "failed"
    begin(system and "system" or "tools", S.tools_runnable:get())
end

function S.update_tools()
    begin("tools", S.tools_runnable:get())
end

-- Only the tools that failed last time, ticked or not.
function S.retry_tools()
    local failed = {}
    for _, failure in ipairs(run:get().failures or {}) do failed[failure.name] = true end
    local names = {}
    for _, name in ipairs(tools.runnable({}, tools.present:get())) do
        if failed[name] then names[#names + 1] = name end
    end
    begin("tools", names)
end

function S.check()
    mantle.updates:check()
end
action("updates.check", S.check)

function S.dismiss()
    if S.faking() then return end
    advance(model.read(run:get()))
end

-- ponytail: no fake guard can stop the second click once the overlay is off, so tests only arm it.
function S.restart()
    if S.faking() then return end
    process.detach("systemctl", { "reboot" })
end

-- Settings ----------------------------------------------------------------------------------------

-- `saved` signals update on the next storage push, so the call takes the new value directly.
local function configure(changes)
    local c = {
        interval = saved.interval:get(),
        aur = saved.aur:get(),
        checked_at = saved.checked_at:get(),
        packages = saved.packages:get(),
    }
    for key, value in pairs(changes or {}) do c[key] = value end
    if (c.checked_at or 0) <= 0 then c.checked_at, c.packages = nil, nil end
    mantle.updates:configure(c)
end

function S.set_interval(seconds)
    saved:set("interval", seconds)
    configure({ interval = seconds })
end

function S.set_aur(on)
    if S.busy:get() then return end
    saved:set("aur", on)
    configure({ aur = on })
    S.check()
end

function S.set_notify(on)
    saved:set("notify", on)
end

function S.set_tool(name, on)
    saved:set("dev_tools", util.with(saved.dev_tools:get(), name, on))
end

-- Updates stay dormant until configured, and the seed must come from the loaded file, which the
-- first storage push may not carry yet; a missing file arrives once created from the defaults.
local configured = false
local function on_storage(storage)
    local contents = storage and storage.contents and storage.contents[FILE]
    if configured or contents == nil then return end
    configured = true
    configure({
        interval = contents.interval or 3600,
        aur = contents.aur ~= false,
        checked_at = contents.checked_at,
        packages = contents.packages,
    })
end
mantle.storage:on_change(on_storage)
on_storage(mantle.storage:get())

-- Announces names not announced before, even across a restart; the names are written before the
-- notification goes out, so one check sends at most one.
local function announce(u)
    local names = {}
    for index, package in ipairs(u.packages) do names[index] = package.name end
    table.sort(names)
    local announced = "\n" .. saved.notified:get() .. "\n"
    saved:set("notified", table.concat(names, "\n"))
    -- Anchored on newlines: a bare `find` counts a new `python` as announced beside `python-pip`.
    local fresh = #util.filter(names, function(name) return not announced:find("\n" .. name .. "\n", 1, true) end)
    if fresh == 0 or not saved.notify:get() or S.open:get() then return end
    local size = model.download_size(u.packages)
    notify("normal", model.plural(#names, "update") .. " available",
        (fresh == #names and "" or string.format("%d new · ", fresh))
        .. (size > 0 and (util.bytes(size) .. " to download") or "ready to install"))
end

mantle.updates:on_change(function(u, previous)
    if u == nil then return end
    -- Compare with the file, not the previous push: the first push after a restart carries the seed.
    if u.last_successful_check and u.last_successful_check ~= saved.checked_at:get() then
        saved:set("checked_at", u.last_successful_check)
        saved:set("packages", u.packages)
    end
    local current = run:get()
    -- An install this evaluation did not start, after the Renderer lost `run`.
    if u.installing and (current.started_at == nil or current.finished_at) then
        advance(model.start("system", {}, os.time(), u))
    end
    reconcile()
    if previous and previous.checking and not u.checking then
        advance(model.check_ended(run:get(), u))
        announce(u)
    end
end)

-- After a reload: probe the tools, pick a tools run back up, settle an install that ended meanwhile.
tools.probe()
if run:get().stage == "tools" then timer(1000, poll_tools) end
reconcile()

-- A closed popup reads a finished result, unless it failed: that stays until a retry or dismiss.
S.open:on_change(function(open)
    if open or S.faking() then return end
    local current = run:get()
    if model.outcome(current) ~= "failed" then advance(model.read(current)) end
end)

return S
