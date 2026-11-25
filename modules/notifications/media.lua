-- The now-playing card under the calendar: cover pinned with tape, Caveat title, three paper discs.
-- Shown only while an MPRIS player runs; the playing one wins, else the longest-running.
local theme = require("theme")
local k = require("lib.paper")
local util = require("lib.util")
local glyphs = require("modules.notifications.glyphs")
local tips = require("modules.notifications.tips").menu

local M = {}

local W, H = theme.notifications.media_w, theme.notifications.media_h

M.player = mantle.mpris:map(function(mpris)
    return util.find(mpris.players, function(p) return p.play_state == "playing" end) or mpris.players[1]
end, nil)

local function cover(p)
    local art = p.album_art_path ~= "" and image { source = p.album_art_path, fit = "cover", width = theme.notifications.media_art, height = theme.notifications.media_art }
        or rect {
            width = theme.notifications.media_art, height = theme.notifications.media_art, background = theme.TAB_CREAM,
            children = { glyphs.doodle(glyphs.music, theme.icon.task, theme.INK_SOFT) },
        }
    return rect {
        rotate = -3,
        align_v = "center",
        children = {
            rect { padding = theme.spacing.xxs, background = theme.CARD_LIGHT, shadows = theme.SHADOW.rest, children = { art } },
            k.tape { width = theme.notifications.media_tape_w, height = theme.notifications.media_tape_h, translate = { x = theme.spacing.wide, y = -theme.spacing.xs }, rotate = 8, seed = 4 },
        },
    }
end

local function controls_row(p)
    local function disc(name, label, icon, cmd, enabled)
        return tips.wrap(glyphs.disc {
            id = "notifications.media." .. name,
            icon = icon,
            size = name == "play" and theme.icon.large or theme.icon.xl,
            seed = #name + 70,
            tooltip = label,
            ink = enabled and theme.INK or theme.INK_FADED,
            on_click = function() if enabled then mantle.mpris:control(p.id, cmd) end end,
        }, "paper.disc.notifications.media." .. name, label)
    end
    local playing = p.play_state == "playing"
    return row {
        spacing = theme.spacing.snug,
        align_v = "center",
        children = {
            disc("previous", "Previous track", glyphs.previous, "previous", p.can_go_previous),
            disc("play", playing and "Pause" or "Play", playing and glyphs.pause or glyphs.play,
                "play_pause", playing and p.can_pause or p.can_play),
            disc("next", "Next track", glyphs.next, "next", p.can_go_next),
        },
    }
end

function M.card()
    local body = M.player:map(function(p)
        if p == nil then return {} end
        return {
            row {
                width = "fill",
                height = "fill",
                spacing = theme.spacing.inset,
                padding = { left = theme.spacing.lg, right = theme.spacing.inset, top = theme.spacing.snug, bottom = theme.spacing.snug },
                children = {
                    cover(p),
                    column {
                        width = "fill",
                        spacing = theme.spacing.hairline,
                        align_v = "center",
                        children = {
                            k.hand(p.title ~= "" and p.title or (p.identity ~= "" and p.identity or "Playing"), theme.font.heading, {
                                font_weight = theme.BOLD, width = "fill", elide = "end",
                            }),
                            k.body(p.artist ~= "" and p.artist or p.identity, theme.font.caption, {
                                foreground = theme.INK_SOFT, width = "fill", elide = "end",
                            }),
                            controls_row(p),
                        },
                    },
                },
            },
        }
    end)
    return rect {
        visible = M.player:map(function(p) return p ~= nil end),
        children = {
            k.card {
                width = W,
                height = H,
                seed = 91,
                color = theme.STOCK.primary[1],
                rotate = -0.8,
                child = rect { width = "fill", height = "fill", children = body },
            },
        },
    }
end

return M
