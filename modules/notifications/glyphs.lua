-- Every icon this module draws, in one place, so a sticker or doodle icon set can replace them here.
local k = require("lib.paper")

local M = {
    close = "window-close-symbolic",
    send = "mail-send-symbolic",
    prev_month = "go-previous-symbolic",
    next_month = "go-next-symbolic",
    previous = "media-skip-backward-symbolic",
    next = "media-skip-forward-symbolic",
    play = "media-playback-start-symbolic",
    pause = "media-playback-pause-symbolic",
    music = "audio-x-generic-symbolic",
    app_fallback = "dialog-information-symbolic",
}

-- An app's icon: a theme name or an absolute path, coloured icons left as they are.
function M.app(name, size)
    return icon { name = name or M.app_fallback, size = size, foreground = k.INK, align_v = "center" }
end

M.glyph = k.glyph

return M
