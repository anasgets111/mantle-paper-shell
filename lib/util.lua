-- Shared helpers without UI nodes. Trimmed from ~/.config/mantle/lib/util.lua.
local util = {}

--- `fn` mapped over a signal, or applied once to a plain value.
function util.lift(value, fn)
    if type(value) == "userdata" then
        return value:map(fn)
    end
    return fn(value)
end

-- `yes` must be truthy, matching Lua's `on and yes or no` idiom.
function util.choose(value, yes, no)
    return util.lift(value, function(on) return on and yes or no end)
end

-- The current value of a signal or plain value.
function util.get(value)
    if type(value) == "userdata" then return value:get() end
    return value
end

function util.find(items, predicate)
    for _, item in ipairs(items or {}) do
        if predicate(item) then
            return item
        end
    end
end

function util.filter(items, predicate)
    local kept = {}
    for _, item in ipairs(items or {}) do
        if predicate(item) then
            kept[#kept + 1] = item
        end
    end
    return kept
end

function util.map(items, fn)
    local out = {}
    for i, item in ipairs(items or {}) do out[i] = fn(item, i) end
    return out
end

function util.index_of(items, value)
    for i, item in ipairs(items or {}) do
        if item == value then return i end
    end
end

function util.chunk(items, size)
    local rows = {}
    for at = 1, #items, size do
        rows[#rows + 1] = { table.unpack(items, at, math.min(at + size - 1, #items)) }
    end
    return rows
end

--- Copy both lists without the stack limit of `table.unpack`.
function util.concat(first, second)
    first, second = first or {}, second or {}
    return table.move(second, 1, #second, #first + 1, table.move(first, 1, #first, 1, {}))
end

--- Copy-on-write triggers a push without mutating a value under an unfinished resolve.
function util.with(source, key, value)
    local copy = {}
    for name, held in pairs(type(source) == "table" and source or {}) do
        copy[name] = held
    end
    copy[key] = value
    return copy
end

-- Move `list[from]` to index `to`, returning a new list.
function util.move(list, from, to)
    local copy = table.move(list, 1, #list, 1, {})
    local item = table.remove(copy, from)
    table.insert(copy, math.max(1, math.min(to, #copy + 1)), item)
    return copy
end

-- Keep the surface mapped through its exit tween.
function util.linger(signal, ms)
    return computed({ signal, delay(signal, ms) }, function(now, was)
        -- Before its first change, delay can hold 0. Lua treats 0 as truthy, so compare with true.
        return now == true or was == true
    end)
end

-- Whitespace off both ends. Parenthesised: `gsub` also returns its count.
function util.trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- 1024-based units.
local BYTE_UNITS = { "B", "KiB", "MiB", "GiB", "TiB" }
function util.bytes(count)
    local size, unit = count, 1
    while size >= 1024 and unit < #BYTE_UNITS do
        size, unit = size / 1024, unit + 1
    end
    return string.format(unit == 1 and "%d %s" or "%.1f %s", size, BYTE_UNITS[unit])
end

-- The time when `at` is on `now`'s day, otherwise the date and time.
function util.stamp(at, now)
    local same_day = os.date("%Y%j", at) == os.date("%Y%j", now)
    return os.date(same_day and "%I:%M %p" or "%b %d, %I:%M %p", at)
end

-- Shared tooltip ownership: leaving one button must not clear another button's hover.
function util.track_hover(key, name)
    return function(is_hovered)
        if is_hovered then
            key:set(name)
        elseif key:get() == name then
            key:set("")
        end
    end
end

return util
