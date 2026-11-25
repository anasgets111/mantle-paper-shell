-- Now playing, on the lock cover: a scrap of card stock under the name label with the cover art
-- taped on, the title and artist, and previous / play-pause / next discs. Hidden with no player.
-- The discs are pointer-only: a press focuses any named control (docs/guide/input.md, keyboard
-- controls), which would stop typing reaching the password field and turn Enter into play/pause.
-- An empty `accessible_name` keeps them out of focus, at the cost of screen-reader access.
-- No tooltips: a lock surface cannot parent a popup.
local k = require("lib.paper")
local icons = require("components.icons")
local controls = require("components.controls")
local util = require("lib.util")
local G = require("modules.lock.glyphs")

local W, H, ART = 460, 104, 66

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
    local path = p.album_art_path ~= "" and p.album_art_path or p.art_url:match("^file://(.+)")
    local picture = path and image { source = path, fit = "cover", width = ART, height = ART, async = true }
        or rect {
            width = ART, height = ART, background = k.CARD,
            children = { icons.doodle(G.music, 30, k.INK_SOFT) },
        }
    return rect {
        rotate = -3,
        align_v = "center",
        children = {
            rect { padding = 4, background = k.CARD_LIGHT, shadows = k.SHADOW.rest, children = { picture } },
            k.tape { width = 34, height = 13, translate = { x = 22, y = -6 }, rotate = 8, seed = 6 },
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
        ink = enabled and k.INK or k.INK_SOFT,
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
        depth = 2,
        rotate = 0.8,
        color = k.CARD,
        shadows = k.SHADOW.rest,
        fx = { rim = 1.2 },
        child = row {
            width = "fill",
            height = "fill",
            spacing = 16,
            padding = { left = 22, right = 18 },
            children = {
                art(p),
                column {
                    width = "fill",
                    align_v = "center",
                    spacing = -2,
                    children = {
                        k.hand(title, 28, { font_weight = 700, elide = "end", width = "fill" }),
                        k.body(byline, 17, {
                            foreground = k.INK_SOFT, elide = "end", width = "fill", visible = byline ~= "",
                        }),
                    },
                },
                row {
                    spacing = 8,
                    align_v = "center",
                    children = {
                        disc(p, "Previous track", G.previous, "previous", p.can_go_previous, 32),
                        disc(p, playing and "Pause" or "Play", playing and G.pause or G.play, "play_pause",
                            playing and p.can_pause or p.can_play, 40),
                        disc(p, "Next track", G.next, "next", p.can_go_next, 32),
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
            return p and { rect { align_h = "center", children = { scrap(p) } } } or {}
        end, {}),
    }
end

return M
