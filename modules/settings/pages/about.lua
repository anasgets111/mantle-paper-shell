-- About page: the machine on an index card. Files are read and tools run each time the notebook
-- opens; disks come from `mantle.sysinfo`.
local k = require("lib.paper")
local util = require("lib.util")
local identity = require("lib.identity")
local rows = require("modules.settings.rows")

local facts = state("settings.about", { os = "", kernel = "", cpu = "", memory = "" })

local function remember(key, value)
    facts:set(util.with(facts:get(), key, value))
end

local function load()
    file.read("/etc/os-release", function(text)
        local name = text and (text:match('PRETTY_NAME="([^"\n]*)"') or text:match("PRETTY_NAME=([^\n]*)"))
        remember("os", name or "Linux")
    end)
    file.read("/proc/cpuinfo", function(text)
        if not text then return end
        local model = text:match("model name%s*:%s*([^\n]+)") or "Unknown CPU"
        local _, threads = text:gsub("\nprocessor%s*:", "")
        remember("cpu", string.format("%s × %d", util.trim(model), threads + 1))
    end)
    file.read("/proc/meminfo", function(text)
        local total = text and tonumber(text:match("MemTotal:%s*(%d+)"))
        local free = text and tonumber(text:match("MemAvailable:%s*(%d+)"))
        if total and free then
            remember("memory", string.format("%s  ·  %d%% in use", util.bytes(total * 1024), (total - free) * 100 // total))
        end
    end)
    process.capture("uname", { "-r" }, function(out) remember("kernel", util.trim(out)) end)
    -- Disks are read only while the notebook is open. ponytail: nothing else here polls sysinfo; a
    -- module that does needs a shared owner of the intervals, or this close would stop its disks.
    mantle.sysinfo:configure { disk_interval = 30 }
end

local function fact(label, value)
    return rows.line({
        rows.label(label, { width = 150, foreground = k.INK_SOFT }),
        rows.label(value, { tip = "about." .. label }),
    })
end

local function version()
    local v = mantle.version
    return string.format("%d.%d.%d", v.major, v.minor, v.patch)
end

local function disk_rows()
    local sysinfo = mantle.sysinfo
    local shape = sysinfo:map(function(s) return rows.key(s.disks, { "name" }) end, "")
    return column {
        width = "fill",
        children = shape:map(function()
            local list = {}
            for _, d in ipairs(sysinfo:get() and sysinfo:get().disks or {}) do
                list[#list + 1] = fact("Disk " .. d.name, sysinfo:map(function(s)
                    local now = util.find(s.disks, function(x) return x.name == d.name end) or d
                    return string.format("%s of %s used (%d%%)", util.bytes(now.used_bytes), util.bytes(now.total_bytes), now.percent)
                end, ""))
            end
            return list
        end),
    }
end

return {
    key = "about",
    title = "About",
    on_open = load,
    on_close = function() mantle.sysinfo:configure { disk_interval = 0 } end,
    build = function()
        return {
            rows.line({
                k.hand(identity.account:map(function(a) return a:match("@(.*)$") or a end), 52, { font_weight = 700 }),
            }, {
                k.hand("Mantle " .. version(), 28, { foreground = k.BLUE }),
            }, 2),
            rows.heading("This machine"),
            fact("System", facts:map(function(f) return f.os end)),
            fact("Kernel", facts:map(function(f) return f.kernel end)),
            fact("Processor", facts:map(function(f) return f.cpu end)),
            fact("Memory", facts:map(function(f) return f.memory end)),
            disk_rows(),
            rows.heading("Session"),
            fact("User", identity.full_name),
            fact("Compositor", mantle.workspaces:map(function(w)
                return (w.compositor:gsub("^%l", string.upper))
            end, "")),
            fact("Shell", "Mantle " .. version() .. ", paper desk"),
        }
    end,
}
