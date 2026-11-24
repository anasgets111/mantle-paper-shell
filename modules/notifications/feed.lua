-- Notification helpers with no nodes or signals: body runs, identity, history records, grouping and
-- sections. Adapted from ~/.config/mantle/lib/notifications.lua.
local apps = require("lib.apps")

local M = {}

-- Bare web and file addresses in unlinked text become links; `<a href>` targets are kept. Trailing
-- sentence punctuation is stripped.
local URL_PATTERNS = { "%f[%S]https?://[^%s<>'\"]+", "%f[%S]file://[^%s<>'\"]+" }

-- Text runs and inline picture paths, in one pass.
function M.body(spans, link_color)
    local runs, images = {}, {}
    local function append(span, text, href)
        local is_link = href ~= nil and href ~= ""
        if text and text ~= "" then
            runs[#runs + 1] = {
                text = text,
                bold = span.bold or false,
                italic = span.italic or false,
                underline = span.underline or is_link,
                color = is_link and link_color or nil,
                href = is_link and href or nil,
            }
        end
    end
    for _, span in ipairs(spans or {}) do
        local text = span.kind == "text" and (span.href == nil or span.href == "") and span.text or nil
        if not text then
            if span.kind == "text" then
                append(span, span.text, span.href)
            elseif span.kind == "image" and span.image_path then
                images[#images + 1] = span.image_path
            end
        else
            local at = 1
            while at <= #text do
                local first, last
                for _, pattern in ipairs(URL_PATTERNS) do
                    local from, to = text:find(pattern, at)
                    if from and (not first or from < first) then first, last = from, to end
                end
                if not first then break end
                local href = text:sub(first, last):gsub("[.,;:!?]+$", "")
                last = first + #href - 1
                if first > at then append(span, text:sub(at, first - 1), span.href) end
                append(span, href, href)
                at = last + 1
            end
            append(span, text:sub(at), span.href)
        end
    end
    return runs, images
end

-- Content identity. Include `timestamp`, not only id: `replaces_id` reuses an id for new content, and
-- server ids restart from 1 with the shell, so a stored id alone can name someone else's notification.
function M.key(notification)
    return string.format("%d:%d", notification.id or 0, notification.timestamp or 0)
end

-- `transient` asks to be popup-only, and low urgency is chatter nobody returns to.
function M.kept_in_history(notification)
    return not notification.transient and notification.urgency ~= "low"
end

-- Critical stays until acted on, the rest for a day.
local HISTORY_SECONDS = 86400
function M.stale(record, now)
    return record.urgency ~= "critical" and (record.timestamp or 0) < now - HISTORY_SECONDS
end

-- "now", then minutes, hours or days.
function M.age(now, timestamp)
    local seconds = now - (timestamp or now)
    if seconds < 60 then return "now" end
    if seconds < 3600 then return string.format("%d min", seconds // 60) end
    if seconds < 86400 then return string.format("%d h", seconds // 3600) end
    return string.format("%d d", seconds // 86400)
end

-- The app a notification belongs to: `desktop_entry` when sent (stable, finds the installed name and
-- icon), else `app_name`. Folded, since desktop ids vary in case.
function M.group_key(notification)
    local entry = notification.desktop_entry
    return entry and string.lower(entry) or (notification.app_name or "?")
end

-- The key `unread_by_app` uses: the desktop id as sent, else the app name.
function M.app_key(notification)
    return notification.desktop_entry or notification.app_name or "?"
end

-- What history keeps across restarts: display fields only. Actions and reply belong to the live
-- sender, which a restart has disconnected.
function M.record(notification)
    local plain = {}
    for _, span in ipairs(notification.body or {}) do
        if span.kind == "text" and span.text then plain[#plain + 1] = span.text end
    end
    return {
        key = M.key(notification),
        id = notification.id,
        timestamp = notification.timestamp,
        app_name = notification.app_name,
        desktop_entry = notification.desktop_entry,
        app_icon = notification.app_icon,
        summary = notification.summary,
        body = table.concat(plain),
        image_path = notification.image_path,
        urgency = notification.urgency or "normal",
    }
end

-- One group per app. Critical first, then newest; the key breaks equal-second ties.
function M.groups(records, applications)
    local groups, by_key = {}, {}
    for _, record in ipairs(records or {}) do
        local key = M.group_key(record)
        local group = by_key[key]
        if group == nil then
            local entry = apps.entry(applications, record.desktop_entry)
            group = {
                key = key,
                app_name = (entry and entry.name) or record.app_name or "?",
                app_icon = (entry and entry.icon) or record.app_icon,
                urgency = "normal",
                latest = 0,
                items = {},
            }
            by_key[key] = group
            groups[#groups + 1] = group
        end
        if record.urgency == "critical" then group.urgency = "critical" end
        group.latest = math.max(group.latest, record.timestamp or 0)
        group.items[#group.items + 1] = record
    end
    for _, group in ipairs(groups) do
        table.sort(group.items, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    end
    table.sort(groups, function(left, right)
        local lc, rc = left.urgency == "critical", right.urgency == "critical"
        if lc ~= rc then return lc end
        if left.latest ~= right.latest then return left.latest > right.latest end
        return left.key < right.key
    end)
    return groups
end

-- Groups bucketed into urgent / today / earlier, flattened with `kind = "header"` rows for a `list`.
-- Colon keys cannot collide with desktop ids.
function M.sections(groups, now)
    local today = os.date("*t", now)
    local today_start = os.time({ year = today.year, month = today.month, day = today.day, hour = 0 })
    local buckets = {
        { label = "urgent", items = {} },
        { label = "today", items = {} },
        { label = "earlier", items = {} },
    }
    for _, group in ipairs(groups or {}) do
        local index = group.urgency == "critical" and 1 or group.latest >= today_start and 2 or 3
        table.insert(buckets[index].items, group)
    end
    local rows = {}
    for _, bucket in ipairs(buckets) do
        if #bucket.items > 0 then
            rows[#rows + 1] = { kind = "header", key = "header:" .. bucket.label, label = bucket.label }
            for _, group in ipairs(bucket.items) do rows[#rows + 1] = group end
        end
    end
    return rows
end

return M
