-- The now-playing card under the calendar: cover pinned with tape, Caveat title, three paper discs.
-- Shown only while an MPRIS player runs; the playing one wins, else the longest-running.
local k = require("lib.paper")
local controls = require("components.controls")
local util = require("lib.util")
local glyphs = require("modules.notifications.glyphs")

local M = {}

local W, H = 328, 124

M.player = mantle.mpris:map(function(mpris)
    return util.find(mpris.players, function(p) return p.play_state == "playing" end) or mpris.players[1]
end, nil)

local function cover(p)
    local art = p.album_art_path ~= "" and image { source = p.album_art_path, fit = "cover", width = 70, height = 70 }
        or rect {
            width = 70, height = 70, background = "#E9DDBB",
            children = { glyphs.glyph(glyphs.music, 30, k.INK_SOFT) },
        }
    return rect {
        rotate = -3,
        align_v = "center",
        children = {
            rect { padding = 4, background = "#FBF8F0", shadows = k.SHADOW.rest, children = { art } },
            k.tape { width = 36, height = 14, translate = { x = 22, y = -6 }, rotate = 8, seed = 4 },
        },
    }
end

local function controls_row(p)
    local function disc(name, icon, cmd, enabled)
        return controls.disc_button {
            id = "notifications.media." .. name,
            icon = icon,
            size = name == "play" and 38 or 32,
            seed = #name + 70,
            tooltip = name,
            ink = enabled and k.INK or "#3A363160",
            on_click = function() if enabled then mantle.mpris:control(p.id, cmd) end end,
        }
    end
    local playing = p.play_state == "playing"
    return row {
        spacing = 10,
        align_v = "center",
        children = {
            disc("previous", glyphs.previous, "previous", p.can_go_previous),
            disc("play", playing and glyphs.pause or glyphs.play,
                "play_pause", playing and p.can_pause or p.can_play),
            disc("next", glyphs.next, "next", p.can_go_next),
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
                spacing = 14,
                padding = { left = 16, right = 14, top = 10, bottom = 10 },
                children = {
                    cover(p),
                    column {
                        width = "fill",
                        spacing = 2,
                        align_v = "center",
                        children = {
                            k.hand(p.title ~= "" and p.title or (p.identity ~= "" and p.identity or "Playing"), 26, {
                                font_weight = 700, width = "fill", elide = "end",
                            }),
                            k.body(p.artist ~= "" and p.artist or p.identity, 17, {
                                foreground = k.INK_SOFT, width = "fill", elide = "end",
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
                color = "#C5D7EE",
                rotate = -0.8,
                child = rect { width = "fill", height = "fill", children = body },
            },
        },
    }
end

return M
