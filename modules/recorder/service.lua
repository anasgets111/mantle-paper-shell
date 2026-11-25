-- One `gpu-screen-recorder` on a region or the focused output, pausable, announced with a
-- notification offering to play the file or show it in its folder. Ported from
-- ~/.config/mantle/lib/screen_recording.lua: `session_process` holds the child across reloads and
-- `mantle.processes` reports it, so there is no launch script, lock file or poll.
local paths = require("lib.paths")
local util = require("lib.util")

local M = {}

local NAME = "paper-recorder"
local FALLBACK_DIRECTORY = (os.getenv("HOME") or "") .. "/Videos"

-- `SIGINT` makes it write the container's index on the way out; `SIGTERM` would leave an unplayable
-- file. The Supervisor uses it too when the session ends under a live recording.
local recorder = session_process { name = NAME, stop_signal = "INT" }

-- The popup's choices, kept across restarts.
M.settings = persistent_table {
    path = paths.state("state-recorder.json"),
    defaults = { target = "screen", audio = "desktop", quality = "high" },
}

-- The popup's three words are not the encoder's five levels.
local QUALITY = { low = "medium", medium = "high", high = "very_high" }

-- `default_output|default_input` is one argument: the recorder mixes both sources itself.
local AUDIO = {
    off = {},
    desktop = { "-a", "default_output", "-ac", "aac" },
    mic = { "-a", "default_output|default_input", "-ac", "aac" },
}

-- Region needs `slurp`; without it the popup offers the whole screen only.
M.has_slurp = state("recorder.has_slurp", false)
process.capture("sh", { "-c", "command -v slurp" }, function(_, code) M.has_slurp:set(code == 0) end)

-- What this capture is called ("DP-1", "Region 1280x720") and the file being written: facts the
-- Supervisor cannot know, having been handed an argv.
M.label = state("recorder.label", "")
local output_path = state("recorder.path", "")

-- Between asking for a capture and the recorder answering; `slurp` is a whole interaction.
local starting = state("recorder.starting", false)
-- The `slurp` in flight, so `stop` can cancel it. Not `state`: a handle belongs to this generation.
local selecting = nil
-- A stop asked for while `starting`: `slurp` may still exit with a region after the kill, and the
-- Supervisor may not have reported `running` yet.
local cancelled = state("recorder.cancelled", false)

-- Pause arithmetic, which no process reports: `paused_total` banks finished pauses, `paused_at`
-- stamps an open one. Every stamp is `mantle.clock:now()`; `state`, so they survive a reload.
local paused_total = state("recorder.paused_total", 0)
local paused_at = state("recorder.paused_at", 0)
local began_at = state("recorder.began_at", 0)

M.recording = recorder.running:map(function(up) return up == true end, false)
M.paused = paused_at:map(function(at) return at > 0 end)

-- The focused output: only it carries `focused_workspace`.
local monitor = mantle.workspaces:map(function(workspaces)
    for _, out in ipairs((workspaces and workspaces.outputs) or {}) do
        if out.focused_workspace ~= nil then return out.name end
    end
    return ""
end, "")

-- A config has no XDG lookup, so ask once. Watching the folder lets a new file's number count past
-- the ones already there.
M.directory = state("recorder.directory", "")
local function use_directory(dir)
    dir = dir:gsub("/$", "")
    M.directory:set(dir)
    -- The recorder does not create its output folder.
    process.run("mkdir", { "-p", dir }, function() end, function(code)
        if code == 0 then mantle.folders:watch(dir) end
    end)
end
if M.directory:get() == "" then
    process.capture("xdg-user-dir", { "VIDEOS" }, function(out, code)
        local dir = util.trim(out or "")
        use_directory((code == 0 and dir ~= "") and dir or FALLBACK_DIRECTORY)
    end)
else
    use_directory(M.directory:get())
end

-- `<output>_<day>-<n>`: one past the highest `n` this output already has today.
local function file_stem(dir, output)
    local prefix = string.format("%s_%s-", output, os.date("%Y%m%d"))
    local pattern = "^" .. prefix:gsub("%p", "%%%0") .. "(%d+)%."
    local highest = 0
    local listing = ((mantle.folders:get() or {}).watched or {})[dir]
    for _, entry in ipairs((listing and listing.entries) or {}) do
        highest = math.max(highest, tonumber(entry.name:match(pattern)) or 0)
    end
    return prefix .. (highest + 1)
end

local function format_elapsed(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hours, minutes = seconds // 3600, seconds // 60 % 60
    if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, seconds % 60) end
    return string.format("%d:%02d", minutes, seconds % 60)
end

local function elapsed_at(now)
    local began = began_at:get()
    if began <= 0 then return 0 end
    local open_since = paused_at:get()
    return now - began - paused_total:get() - (open_since > 0 and now - open_since or 0)
end

-- Ticks with the clock's one-second push.
M.elapsed = computed({ mantle.clock, M.recording, paused_at, paused_total }, function(_, up)
    return up and format_elapsed(elapsed_at(mantle.clock:now())) or ""
end, "")

local function notify(args)
    process.detach("notify-send", util.concat({ "-a", "Screen Recorder", "-i", "media-record" }, args))
end

local function launch(target, output, label)
    local settings = M.settings
    local dir = M.directory:get() ~= "" and M.directory:get() or FALLBACK_DIRECTORY
    local path = string.format("%s/%s.mp4", dir, file_stem(dir, output))
    local args = util.concat({
        "-w", target,
        "-o", path,
        "-q", QUALITY[settings.quality:get()] or "very_high",
        "-f", "60",
        "-cursor", "yes",
        -- Without a working VAAPI/NVENC driver it exits 52 instead of encoding on the CPU.
        "-fallback-cpu-encoding", "yes",
        -- Otherwise it logs fps once a second; errors still reach the log.
        "-v", "no",
    }, AUDIO[settings.audio:get()] or AUDIO.desktop)

    M.label:set(label or output)
    output_path:set(path)
    paused_total:set(0)
    paused_at:set(0)
    began_at:set(mantle.clock:now())
    starting:set(true)
    recorder:start("gpu-screen-recorder", args)
end

-- `region` puts `slurp` on screen first; `-o` lets a click take a whole output. Its stdout is the
-- output and box; a non-zero exit is Escape, a cancel rather than a failure.
function M.start(region)
    if M.recording:get() or starting:get() then return end
    cancelled:set(false)
    if not (region and M.has_slurp:get()) then
        local output = monitor:get()
        if output ~= "" then launch(output, output) end
        return
    end
    starting:set(true)
    selecting = process.capture("slurp", { "-o", "-f", "%o %wx%h+%x+%y" }, function(out, code)
        selecting = nil
        starting:set(false)
        local output, box = util.trim(out or ""):match("^(%S+) (%S+)$")
        -- Before the exit status: a killed `slurp` may still have exited cleanly with a region.
        if cancelled:get() then
            cancelled:set(false)
            return
        end
        if code ~= 0 or box == nil then return end
        -- A click is exactly an output's box; capture that output by name.
        for _, screen in ipairs(mantle.screens:get() or {}) do
            if box == string.format("%dx%d+%d+%d", screen.width, screen.height, screen.x, screen.y) then
                launch(output, output)
                return
            end
        end
        -- `-w <WxH+X+Y>`: this version deprecates `-w region -region ...` and writes nothing for it.
        launch(box, output, "Region " .. box:match("^[^+]*"))
    end)
end

function M.stop()
    if M.recording:get() then
        recorder:signal("INT")
    elseif starting:get() then
        -- Nothing is up yet: the selection callback and the `running` edge read the refusal.
        cancelled:set(true)
        if selecting then selecting:kill() end
    end
end

-- `SIGUSR2` either way; which edge it was is this module's bookkeeping.
function M.toggle_pause()
    if not M.recording:get() then return end
    recorder:signal("USR2")
    local open_since = paused_at:get()
    if open_since > 0 then
        paused_total:set(paused_total:get() + mantle.clock:now() - open_since)
        paused_at:set(0)
    else
        paused_at:set(mantle.clock:now())
    end
end

-- For a keybind: stop what runs, else start with the popup's last choices.
action("recorder.toggle", function()
    if M.recording:get() or starting:get() then
        M.stop()
        return "stopped"
    end
    M.start(M.settings.target:get() == "region")
    return "starting"
end)

-- `notify-send` blocks until the note closes and prints the chosen key. `default` arms a click on
-- the note's body; the capability lists only the two buttons.
local function announce_saved(exit_code)
    local path = output_path:get()
    if path == "" then return end
    if exit_code ~= nil and exit_code ~= 0 then
        notify({ "-u", "critical", "Recording failed",
            string.format("gpu-screen-recorder exited %d; see `mantle log`", exit_code) })
        return
    end
    local duration = format_elapsed(elapsed_at(mantle.clock:now()))
    process.capture("notify-send", {
        "-a", "Screen Recorder", "-i", "media-record", "-t", "8000",
        "-A", "default=Play", "-A", "play=Play", "-A", "folder=Show in folder",
        "Recording saved", string.format("%s · %s", duration, path:match("[^/]+$")),
    }, function(chosen)
        local key = util.trim(chosen or "")
        if key == "default" or key == "play" then
            process.detach("xdg-open", { path })
        elseif key == "folder" then
            -- The file manager selects the file; without one on the bus, open the folder.
            process.run("dbus-send", {
                "--session", "--dest=org.freedesktop.FileManager1", "--type=method_call",
                "/org/freedesktop/FileManager1", "org.freedesktop.FileManager1.ShowItems",
                "array:string:file://" .. path, "string:",
            }, function() end, function(code)
                if code ~= 0 then process.detach("xdg-open", { (path:match("^(.*)/[^/]+$")) }) end
            end)
        end
    end)
end

local function session_of(payload)
    return ((payload or {}).sessions or {})[NAME]
end

-- Both edges the Supervisor reports: it came up, or `start_error` says why it did not.
mantle.processes:on_change(function(current, previous)
    local was, now = session_of(previous), session_of(current)
    if now == nil then return end
    if now.running then
        starting:set(false)
        -- The press arrived before there was a process to signal; this is the first moment there is.
        if cancelled:get() then
            cancelled:set(false)
            recorder:signal("INT")
        end
        return
    end
    -- The edge, not the field: `start_error` stays set until the next `start`.
    if now.start_error ~= "" and now.start_error ~= ((was or {}).start_error or "") then
        starting:set(false)
        cancelled:set(false)
        notify({ "-u", "critical", "Recording didn't start", now.start_error })
    end
    if was ~= nil and was.running then
        announce_saved(now.exit_code)
        paused_total:set(0)
        paused_at:set(0)
    end
end)

function M.open_directory()
    local dir = M.directory:get()
    if dir ~= "" then process.detach("xdg-open", { dir }) end
end

return M
