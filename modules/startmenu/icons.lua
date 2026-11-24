-- Every icon the start menu draws, by role: pencil doodles for glyphs and die-cut stickers for apps,
-- both from components/icons.lua. `name` keeps theme names for components/menu.lua, which draws its own.
local k = require("lib.paper")
local paper_icons = require("components.icons")

local M = {}

-- Role → doodle name; a role without one draws its theme icon through `doodle_for`.
local DOODLES = {
    search = "search",
    lock = "lock",
    logout = "logout",
    suspend = "suspend",
    reboot = "restart",
    poweroff = "power",
    home = "home",
    documents = "file",
    downloads = "download",
    pictures = "image",
    music = "music",
    videos = "video",
    settings = "settings",
    terminal = "terminal",
    -- Recent files, by mime family.
    folder = "folder",
    image = "image",
    audio = "music",
    video = "video",
    text = "file",
    archive = "folder",
    document = "file",
}

local THEME = {
    calc = "accessories-calculator-symbolic",
    open = "media-playback-start-symbolic",
    pin = "view-pin-symbolic",
    menu_pin = "non-starred-symbolic",
    menu_unpin = "starred-symbolic",
}

-- The theme name for a role, for components that take a name (the context menu).
function M.name(role)
    return THEME[role]
end

-- A pencil glyph in ink, centred in its slot.
function M.glyph(role, size, color)
    local doodle = DOODLES[role]
    local node = doodle and paper_icons.doodle(doodle, size, color or k.INK)
        or paper_icons.doodle_for(THEME[role], size, color or k.INK)
    return rect { align_h = "center", align_v = "center", children = { node } }
end

-- An app's own icon as a die-cut sticker. Its box is `size` plus the cut margin on each side.
function M.app(app, size)
    return paper_icons.sticker(app.icon or "application-x-executable", size)
end

return M
