-- App ranking for the search line, the "Frequent" tab and a calculator answer. Ranking is adapted
-- from ~/.config/mantle/modules/global/launcher/apps.lua: field by field, so a query never borrows
-- letters from a long keyword list, with usage breaking ties.
local categories = require("modules.startmenu.categories")

local M = {}

local function field_score(text, needle, weight)
    if text == "" then return -1 end
    if text == needle then return 5000 + weight end
    if text:sub(1, #needle) == needle then return 4000 + weight - math.min(99, #text - #needle) end
    local start = text:find(needle, 1, true)
    if start then
        if text:sub(start - 1, start - 1):match("[%s%-%_%.%/]") then return 3000 + weight end
        return 2000 + weight - math.min(99, start - 1)
    end
    return fuzzy(text, needle) and 1000 + weight - math.min(99, #text - #needle) or -1
end

-- Launch count on a log scale plus a stepped recency bonus, so last hour's app is not buried.
function M.usage_of(usage, now, id)
    local entry = usage[id]
    if not entry then return 0 end
    local age = now - (entry.last or 0)
    local recency = age < 3600 and 8 or age < 86400 and 6 or age < 604800 and 4 or age < 2592000 and 2 or 0
    return math.log(entry.count + 1, 2) + recency
end

-- Shown entries with lowercased fields and a category, once per change of the desktop entries.
function M.index(applications)
    local index = {}
    for _, app in ipairs(applications and applications.entries or {}) do
        if not app.no_display then
            index[#index + 1] = {
                app = app,
                category = categories.of(app),
                name = (app.name or ""):lower(),
                generic_name = (app.generic_name or ""):lower(),
                keywords = table.concat(app.keywords or {}, " "):lower(),
            }
        end
    end
    return index
end

-- Every match for `text`, best first, at most `limit`.
function M.rank(index, text, usage, limit)
    local needle = text:lower()
    local now = os.time()
    local scored = {}
    for _, entry in ipairs(index) do
        local value = math.max(
            field_score(entry.name, needle, 80),
            field_score(entry.generic_name, needle, 60),
            field_score(entry.keywords, needle, 40)
        )
        if value >= 0 then
            scored[#scored + 1] = { app = entry.app, score = value, usage = M.usage_of(usage, now, entry.app.id) }
        end
    end
    table.sort(scored, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.usage ~= b.usage then return a.usage > b.usage end
        return a.app.name < b.app.name
    end)
    local apps = {}
    for i = 1, math.min(#scored, limit) do apps[i] = scored[i].app end
    return apps
end

-- Launched apps by usage, most used first, at most `limit`.
function M.frequent(index, usage, limit)
    local now = os.time()
    local used = {}
    for _, entry in ipairs(index) do
        local u = M.usage_of(usage, now, entry.app.id)
        if u > 0 then used[#used + 1] = { app = entry.app, usage = u } end
    end
    table.sort(used, function(a, b)
        if a.usage ~= b.usage then return a.usage > b.usage end
        return a.app.name < b.app.name
    end)
    local apps = {}
    for i = 1, math.min(#used, limit) do apps[i] = used[i].app end
    return apps
end

-- The index grouped by category in `categories.NAMES` order, apps by name within each.
function M.by_category(index)
    local groups = {}
    for _, entry in ipairs(index) do
        groups[entry.category] = groups[entry.category] or {}
        table.insert(groups[entry.category], entry.app)
    end
    local out = {}
    for _, name in ipairs(categories.NAMES) do
        local list = groups[name]
        if list then
            -- Entries arrive in byte order, which puts "qBittorrent" after "Zen".
            table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
            out[#out + 1] = { name = name, apps = list }
        end
    end
    return out
end

-- An arithmetic query's answer as text, else nil. Adapted from the user's launcher calculator:
-- the allowlist admits no identifier and `load` gets an empty `_ENV`, so nothing but arithmetic
-- runs. `--` and `//` pass the allowlist but are a comment and floor division, so they are refused.
local ALLOWED = "^[%d%s%+%-%*/%(%)%.,%%%^]+$"

function M.calc(input)
    if not input:match(ALLOWED) or not input:match("%d") or not input:match("[%+%-%*/%^%%]") then return nil end
    if input:find("--", 1, true) or input:find("//", 1, true) then return nil end
    local expression = input
        :gsub(",", "")
        :gsub("%*%*", "^")
        :gsub("^%s*%+", "")
        :gsub("(%d+%.?%d*)%%", "(%1/100)")
        -- Floats: Lua integers wrap.
        :gsub("%d+%.?%d*", function(n) return n:find(".", 1, true) and n or (n .. ".0") end)
    local chunk = load("return " .. expression, "=calc", "t", {})
    if not chunk then return nil end
    local ok, value = pcall(chunk)
    if not ok or type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return nil end
    if value == math.floor(value) and math.abs(value) < 1e15 then return string.format("%.0f", value) end
    return string.format("%.12g", value)
end

return M
