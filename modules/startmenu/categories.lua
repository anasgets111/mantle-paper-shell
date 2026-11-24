-- A desktop entry's menu category, guessed from its id, name, generic name and keywords: the
-- engine reports no `Categories=` (gap 11). ponytail: a hand-made word list misfiles apps it has
-- never seen into "Other"; upgrade when `AppSummary` carries `categories`.
local M = {}

M.NAMES = { "Internet", "Development", "Graphics", "Media", "Office", "System", "Utilities", "Other" }

-- First match wins, so the order settles overlaps: "Document Scanner" is Graphics before it is
-- Office, an IDE called a text editor is Development before Utilities.
local RULES = {
    { "Development", { "zed", "nvim", "neovim", "vim", "vscode", "code-oss", "developer", "programming",
        "yaak", "t3code", "t3 code", "git", "debugger", "api client", "jetbrains" } },
    { "Internet", { "browser", "web", "mail", "thunderbird", "chat", "messag", "telegram", "discord",
        "vesktop", "torrent", "rustdesk", "remote desktop", "kdeconnect", "kde connect", "network" } },
    { "Graphics", { "photo", "image", "draw", "paint", "gimp", "inkscape", "krita", "scan", "graphics",
        "vector", "raster" } },
    { "Media", { "video", "music", "audio", "player", "mpv", "vlc", "v4l2", "camera", "spotify",
        "sound", "media" } },
    { "Office", { "office", "document", "wordcraft", "word processor", "writer", "spreadsheet",
        "presentation", "pdf", "ebook" } },
    { "System", { "terminal", "kitty", "alacritty", "wezterm", "console", "btop", "htop", "nvtop",
        "monitor", "missioncenter", "firmware", "nvidia", "lshw", "lstopo", "hardware", "kvantum",
        "qt6ct", "system" } },
    { "Utilities", { "calculator", "files", "file manager", "nautilus", "text editor", "archive",
        "utility", "accessibility", "showmethekey", "hex", "solaar", "openrgb", "uuctl", "disk", "clipboard",
        "screenshot" } },
}

-- `word` at a word start only: "git" must not hit "logitech". Plain finds; a `%f` pattern per word
-- and app overran the frame budget on reload.
local function starts_word(hay, word)
    local at = hay:find(word, 1, true)
    while at do
        if at == 1 or not hay:sub(at - 1, at - 1):match("%w") then return true end
        at = hay:find(word, at + 1, true)
    end
    return false
end

local function match(hay)
    for _, rule in ipairs(RULES) do
        for _, word in ipairs(rule[2]) do
            if starts_word(hay, word) then return rule[1] end
        end
    end
end

-- Id and names before keywords: keywords are loose ("network" on a system monitor).
--- @param app AppSummary
--- @return string
function M.of(app)
    local names = table.concat({ app.id or "", app.name or "", app.generic_name or "" }, " "):lower()
    return match(names) or match(table.concat(app.keywords or {}, " "):lower()) or "Other"
end

return M
