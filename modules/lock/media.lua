-- Now playing, on the lock cover: a scrap of card stock under the name label with the cover art
-- taped on, the title and artist, and previous / play-pause / next discs. Hidden with no player.
-- The discs are pointer-only: a press focuses any named control (docs/guide/input.md, keyboard
-- controls), which would stop typing reaching the password field and turn Enter into play/pause.
-- An empty `accessible_name` keeps them out of focus, at the cost of screen-reader access.
-- No tooltips: a lock surface cannot parent a popup.
local theme = require("theme")
local k = require("lib.paper")
local icons = require("components.icons")
local controls = require("components.controls")
local util = require("lib.util")
local G = require("modules.lock.glyphs")

local W, H, ART = theme.lock.media_w, theme.lock.media_h, theme.lock.media_art

local M = {}

--- The player to show: the playing one, else the longest-running; nil with none.
M.player = mantle.mpris:map(function(mpris)
    for _, p in ipairs(mpris.players) do
        if p.play_state == "playing" then return p end
    end
    return mpris.players[1]
end, nil)

local function art(p)
    -- Only a local file: an `https` art URL would need fetching, and the lock should not reach out.
    local path = p.album_art_path ~= "" and p.album_art_path
    local picture = path and image { source = path, fit = "cover", width = ART, height = ART, async = true }
        or rect {
            width = ART, height = ART, background = theme.CARD,
            children = { util.with(icons.doodle(G.music, theme.icon.task, theme.INK_SOFT), "align_h", "center") },
        }
    return rect {
        rotate = -3,
        align_v = "center",
        children = {
            rect { padding = theme.spacing.xxs, background = theme.CARD_LIGHT, shadows = theme.SHADOW.rest, children = { picture } },
            k.tape { width = theme.lock.media_tape_w, height = theme.lock.media_tape_h, translate = { x = theme.spacing.wide, y = -theme.spacing.xs }, rotate = 8, seed = 6 },
        },
    }
end

local function disc(p, name, icon, cmd, enabled, size)
    return util.with(controls.disc_button {
        id = "lock.media." .. name,
        icon = icon,
        size = size,
        seed = #name + 80,
        tooltip = name,
        ink = enabled and theme.INK or theme.INK_SOFT,
        on_click = function() if enabled then mantle.mpris:control(p.id, cmd) end end,
    }, "accessible_name", "")
end

local function scrap(p)
    local playing = p.play_state == "playing"
    local title = p.title ~= "" and p.title or (p.identity ~= "" and p.identity or "Playing")
    -- The artist, else the player's name, unless the title already is that name.
    local byline = p.artist ~= "" and p.artist or (p.title ~= "" and p.identity or "")
    return k.sheet {
        width = W,
        height = H,
        seed = 961,
        depth = theme.paper.light_tear,
        color = theme.CARD,
        shadows = theme.SHADOW.rest,
        fx = { rim = 1.2 },
        child = row {
            width = "fill",
            height = "fill",
            spacing = theme.spacing.lg,
            padding = { left = theme.spacing.wide, right = theme.spacing.roomy },
            children = {
                art(p),
                column {
                    width = "fill",
                    align_v = "center",
                    spacing = -theme.spacing.hairline,
                    children = {
                        k.hand(title, theme.font.title, { font_weight = theme.BOLD, elide = "end", width = "fill" }),
                        k.body(byline, theme.font.caption, {
                            foreground = theme.INK_SOFT, elide = "end", width = "fill", visible = byline ~= "",
                        }),
                    },
                },
                row {
                    spacing = theme.spacing.sm,
                    align_v = "center",
                    children = {
                        disc(p, "Previous track", G.previous, "previous", p.can_go_previous, theme.lock.media_skip_disc),
                        disc(p, playing and "Pause" or "Play", playing and G.pause or G.play, "play_pause",
                            playing and p.can_pause or p.can_play, theme.lock.media_play_disc),
                        disc(p, "Next track", G.next, "next", p.can_go_next, theme.lock.media_skip_disc),
                    },
                },
            },
        },
    }
end

--- The scrap for `player` (a signal of a `PlayerState` or nil; default `M.player`).
function M.card(player)
    return rect {
        width = "fill",
        children = (player or M.player):map(function(p)
            -- k.sheet has no `rotate`: the tilt goes on this wrapper.
            return p and { rect { align_h = "center", rotate = 0.8, children = { scrap(p) } } } or {}
        end, {}),
    }
end

return M
