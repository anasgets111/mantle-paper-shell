-- Recent files from ~/.local/share/recently-used.xbel, read again each time the menu opens: the
-- engine has no recent-files feed (gap 13). Parsed with string patterns; the file is GTK's own
-- flat XBEL, one `<bookmark>` per file.
local M = {}

local LIMIT = 12
local PATH = "~/.local/share/recently-used.xbel"

local ENTITIES = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'" }

local function unescape(text)
    return (text:gsub("&(%a+);", function(name) return ENTITIES[name] end))
end

local function percent_decode(text)
    return (text:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

-- The icon role (modules/startmenu/icons.lua) for a mime type; anything else is a document.
local function icon_for(mime)
    local major = mime:match("^(%w+)/") or ""
    if mime == "inode/directory" then return "folder" end
    if major == "image" or major == "audio" or major == "video" or major == "text" then return major end
    if mime:find("zip") or mime:find("tar") or mime:find("compressed") then return "archive" end
    return "document"
end

--- The newest `LIMIT` bookmarks, newest first.
--- @return { uri: string, name: string, icon: string, at: string }[]
function M.parse(xml)
    local files = {}
    for attrs, inner in (xml or ""):gmatch("<bookmark%s([^>]*)>(.-)</bookmark>") do
        local href = attrs:match('href="([^"]*)"')
        if href then
            local uri = unescape(href)
            -- Percent-decoded for the label only: xdg-open takes the URI as written.
            local name = percent_decode(uri:gsub("/+$", ""):match("([^/]+)$") or uri)
            files[#files + 1] = {
                uri = uri,
                name = name,
                icon = icon_for(inner:match('mime%-type type="([^"]*)"') or ""),
                -- ISO 8601 in UTC sorts as text.
                at = attrs:match('modified="([^"]*)"') or attrs:match('added="([^"]*)"') or "",
            }
        end
    end
    table.sort(files, function(a, b) return a.at > b.at end)
    return { table.unpack(files, 1, math.min(#files, LIMIT)) }
end

M.files = state("startmenu.recent", {})

function M.refresh()
    file.read(PATH, function(text)
        M.files:set(M.parse(text))
    end)
end

-- "2026-11-10T06:14:41Z" as "Nov 10", or the time when it is today.
function M.when(at, now)
    local y, mo, d, h, mi = at:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
    if not y then return "" end
    local stamp = os.time {
        year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi),
    }
    -- `os.time` read the fields as local time; shift by the UTC offset to get the real instant.
    local offset = os.time(os.date("*t", now)) - os.time(os.date("!*t", now))
    stamp = stamp + offset
    if os.date("%Y%j", stamp) == os.date("%Y%j", now) then return os.date("%H:%M", stamp) end
    return os.date("%b %d", stamp)
end

return M
