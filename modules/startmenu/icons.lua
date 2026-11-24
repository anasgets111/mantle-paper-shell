-- Every icon the start menu draws, by role, so another icon set (stickers, doodles) swaps in here.
local k = require("lib.paper")

local M = {}

local NAMES = {
    search = "system-search-symbolic",
    calc = "accessories-calculator-symbolic",
    open = "media-playback-start-symbolic",
    pin = "view-pin-symbolic",
    menu_pin = "non-starred-symbolic",
    menu_unpin = "starred-symbolic",
    lock = "system-lock-screen-symbolic",
    logout = "application-exit-symbolic",
    suspend = "weather-clear-night-symbolic",
    reboot = "system-reboot-symbolic",
    poweroff = "system-shutdown-symbolic",
    home = "user-home-symbolic",
    documents = "folder-documents-symbolic",
    downloads = "folder-download-symbolic",
    pictures = "folder-pictures-symbolic",
    music = "folder-music-symbolic",
    videos = "folder-videos-symbolic",
    settings = "emblem-system-symbolic",
    terminal = "utilities-terminal-symbolic",
    -- Recent files, by mime family.
    folder = "folder-symbolic",
    image = "image-x-generic-symbolic",
    audio = "audio-x-generic-symbolic",
    video = "video-x-generic-symbolic",
    text = "text-x-generic-symbolic",
    archive = "package-x-generic-symbolic",
    document = "x-office-document-symbolic",
}

-- The theme name for a role, for components that take a name (the context menu).
function M.name(role)
    return NAMES[role]
end

-- A symbolic glyph in ink. `props` adds node properties (alignment, padding).
function M.glyph(role, size, color, props)
    local t = { name = NAMES[role], size = size, foreground = color or k.INK, align_v = "center" }
    for key, v in pairs(props or {}) do t[key] = v end
    return icon(t)
end

-- An app's own full-colour icon.
function M.app(app, size, props)
    local t = { name = app.icon or "application-x-executable", size = size, align_v = "center" }
    for key, v in pairs(props or {}) do t[key] = v end
    return icon(t)
end

return M
