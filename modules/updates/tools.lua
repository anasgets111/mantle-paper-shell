-- Developer tools updated after the packages, ported from ~/.config/mantle/config/dev_tools.lua.
-- Each has a name (its key in the saved `dev_tools` flags), the binary that must be on `PATH`, and
-- argv commands run in order until the first non-zero exit. Everything runs as the user: `composer
-- global update` under `pkexec` would leave `~/.config/composer` owned by root.
--
-- One `session_process` runs the whole plan as a generated `sh` script that writes its own log, so a
-- run survives the reloads that would kill a `process.run` child. `parse` reads that log back.
local model = require("modules.updates.model")

local M = {}

M.LIST = {
    { name = "Composer", requires = "composer", run = { { "composer", "global", "update" } } },
    {
        name = "Node.js",
        requires = "fnm",
        -- Install the LTS and default to it, bring every installed major to its latest release, then
        -- prune the older releases within each major.
        run = {
            { "fnm", "install", "--use", "lts-latest" },
            { "fnm", "default", "lts-latest" },
            { "bash", "-c",
                "fnm ls | awk '$2 ~ /^v/ { sub(/\\..*/, \"\", $2); print $2 }' | sort -u | xargs -r -n1 fnm install" },
            { "bash", "-c",
                "fnm ls | awk '$2 ~ /^v/ { print $2 }' | sort -Vr | awk -F. 'seen[$1]++' | xargs -r -n1 fnm uninstall" },
        },
    },
    -- fnm doesn't carry npm globals across versions: reinstall into the (possibly new) default Node.
    { name = "mudslide", requires = "fnm", run = { { "npm", "i", "-g", "mudslide@0.38.1" } } },
    { name = "pnpm globals", requires = "pnpm", run = { { "pnpm", "update", "-g" } } },
    { name = "Playwright", requires = "playwright-cli", run = { { "playwright-cli", "install-browser", "chromium" } } },
    { name = "Bun globals", requires = "bun", run = { { "bun", "update", "-g" } } },
    { name = "uv tools", requires = "uv", run = { { "uv", "tool", "upgrade", "--all" } } },
    { name = "tldr pages", requires = "tldr", run = { { "tldr", "--update" } } },
    { name = "Rust binaries", requires = "cargo-install-update", run = { { "cargo", "install-update", "-a" } } },
    { name = "Rust toolchain", requires = "rustup", run = { { "rustup", "update" } } },
}

local by_name = {}
for _, tool in ipairs(M.LIST) do by_name[tool.name] = tool end

-- Which `requires` binaries are on `PATH`; named state keeps the last answer while a reload re-probes.
M.present = state("updates.tools_present", {})

local runner = session_process { name = "paper-updates-tools" }
M.running = runner.running

local LOG = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/paper-updates-tools.log"
M.LOG = LOG

function M.probe()
    local args = { "-c", 'for n; do command -v "$n" >/dev/null && echo "$n"; done', "sh" }
    for _, tool in ipairs(M.LIST) do args[#args + 1] = tool.requires end
    local found = {}
    process.run("sh", args, function(line, stream)
        if stream == "stdout" then found[line] = true end
    end, function(code)
        if code ~= nil then M.present:set(found) end
    end)
end

-- Ticked (absent counts as ticked) and on `PATH`.
function M.runnable(flags, present)
    local names = {}
    for _, tool in ipairs(M.LIST) do
        if present[tool.requires] and (flags or {})[tool.name] ~= false then names[#names + 1] = tool.name end
    end
    return names
end

-- The script's last line: a run whose log lacks it is still going, or was killed.
local END = "■ finished"

local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- `▶ name` before each tool, then `[ OK ]` or `[FAIL] <exit code>`; the subshell stops at the first
-- failing command. `$1` is the log path.
local function script(names)
    local lines = { 'exec >"$1" 2>&1' }
    for _, name in ipairs(names) do
        local commands = {}
        for i, argv in ipairs(by_name[name].run) do
            local words = {}
            for j, word in ipairs(argv) do words[j] = quote(word) end
            commands[i] = table.concat(words, " ")
        end
        lines[#lines + 1] = "printf '%s\\n' " .. quote("▶ " .. name)
        lines[#lines + 1] = string.format('if ( %s ); then echo "[ OK ]"; else echo "[FAIL] $?"; fi',
            table.concat(commands, " && "))
    end
    lines[#lines + 1] = "echo " .. quote(END)
    return table.concat(lines, "\n")
end

function M.start(names)
    runner:start("sh", { "-c", script(names), "sh", LOG })
end

-- The log as `{ lines, tool, failures, done }`: `tool` is the index of the last tool begun. The run
-- is done at the script's last line, or when the process is gone without it (`exited`): then a tool
-- begun with no result line was stopped, by a logout or `kill`.
function M.parse(text, plan, exited)
    local lines, failures, own, tool, open, done = {}, {}, {}, 0, false, exited
    for line in (text or ""):gmatch("[^\n]+") do
        if line == END then
            done = true
            break
        end
        lines[#lines + 1] = line
        if line:find("^▶ ") then
            tool, open, own = tool + 1, true, {}
        elseif open and line == "[ OK ]" then
            open = false
        elseif open and line:find("^%[FAIL%] %d+$") then
            local code = tonumber(line:match("%d+"))
            local name = plan[tool] or "?"
            failures[#failures + 1] = {
                name = name,
                reason = model.tool_reason(code, by_name[name] and by_name[name].requires or name, own),
            }
            open = false
        else
            own[#own + 1] = line
        end
    end
    if done and open then
        failures[#failures + 1] = { name = plan[tool] or "?", reason = "Stopped before it finished" }
    end
    return { lines = lines, tool = math.max(tool, 1), failures = failures, done = done }
end

return M
