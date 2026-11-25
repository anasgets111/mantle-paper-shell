-- Lock screen, polkit dialog and idle. Returns { surfaces }.
--
-- `mantle toggle lock.preview` shows the lock cover in an overlay without locking (its password
-- line is a picture, not a secure field); `mantle set lock.preview_state '{...}'` feeds it a fake
-- `mantle.lock` payload to see errors and messages.
local util = require("lib.util")
local cover = require("modules.lock.cover")
local polkit = require("modules.lock.polkit")
local dim_panel = require("modules.lock.idle_run")
local idle_page = require("modules.lock.idle_page")

-- Keep the lock up while the cover fades out after a correct password.
mantle.lock:set_unlock_animation(260)

-- Declared, not open: nothing maps until `mantle.lock:lock()`, then one surface per output.
local lock_screen = lock {
    id = "paper-lock",
    child = function(output) return cover(output) end,
}

local preview = state("lock.preview", false)
local preview_state = state("lock.preview_state", {
    active = true, authenticating = false, unlocking = false, attempts = 0, error = "", messages = {},
})

-- `mantle set lock.preview_player '{...}'` shows a fake `PlayerState` on the preview; `{}` shows the real one.
local preview_player = state("lock.preview_player", {})
local media = require("modules.lock.media")
local shown_player = computed({ preview_player, media.player }, function(fake, real)
    return fake.id and fake or real
end)

local preview_panel = panel {
    id = "paper-lock-preview",
    namespace = "paper-lock-preview",
    output = "active",
    layer = "overlay",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive_zone = "ignore",
    width = "fill",
    height = "fill",
    visible = preview,
    on_escape = function() preview:set(false) end,
    -- `on_escape` needs the keyboard; the preview takes it while shown.
    keyboard_interactivity = util.choose(preview, "exclusive", "none"),
    child = util.lift(preview, function(on)
        return on and cover("preview", { preview = true, source = preview_state, player = shown_player }) or rect {}
    end),
}

return { surfaces = { lock_screen, polkit, preview_panel, dim_panel, idle_page.surface } }
