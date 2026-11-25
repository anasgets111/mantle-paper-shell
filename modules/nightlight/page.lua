-- The "Night light" section of Settings › Displays: on/off, warmth, and the schedule. Called by the
-- Displays page; returns one column of ruled rows.
local k = require("lib.paper")
local c = require("components.controls")
local icons = require("components.icons")
local rows = require("modules.settings.rows")
local tips = require("modules.settings.tips")
local nightlight = require("modules.nightlight")

local store = nightlight.store
local STEP = 30 -- minutes per click or wheel notch
local installed = nightlight.installed:map(function(v) return v ~= false end, true)
local supported = nightlight.supported

local function nudge_warmth(_, steps)
    nightlight.set_temperature((store.temperature:get() or 4000) - steps * 250)
end

-- A time picker: chevron discs either side of the time, the wheel steps it too.
local function time_picker(key, name)
    local function step(dir)
        store:set(key, ((store[key]:get() or 0) + dir * STEP) % (24 * 60))
    end
    local function disc(dir, icon, tip)
        local id = "settings.nightlight." .. key .. "." .. dir
        return tips.wrap(c.disc_button { id = id, icon = icon, size = 30, seed = dir > 0 and 7 or 5, tooltip = tip,
            on_click = function() step(dir) end }, "paper.disc." .. id, tip)
    end
    return row {
        spacing = 4,
        align_v = "center",
        accessible_name = name,
        on_wheel = function(_, steps) step(steps > 0 and 1 or -1) end,
        children = {
            disc(-1, "chevron-left", "Earlier"),
            k.hand(store[key]:map(nightlight.format_time), 26, {
                font_weight = 700, foreground = k.DEEP_BLUE, width = 70, text_align = "center", align_v = "center",
            }),
            disc(1, "chevron-right", "Later"),
        },
    }
end

return function()
    return column {
        width = "fill",
        children = {
            rows.heading("Night light", { rows.caption(nightlight.status) }),
            rect {
                width = "fill",
                visible = supported:map(function(v) return not v end),
                children = { rows.note("Night light warms the screen with hyprsunset, which works only on Hyprland.", 2) },
            },
            rect {
                width = "fill",
                visible = computed({ supported, installed }, function(s, i) return s and not i end),
                children = {
                    rows.note("Night light needs hyprsunset: sudo pacman -S hyprsunset. The switch shows up here within a minute of installing it.", 2),
                },
            },
            column {
                width = "fill",
                visible = computed({ supported, installed }, function(s, i) return s and i end),
                children = {
                    rows.line({ rows.label("Warm the screen at night") }, {
                        c.toggle {
                            id = "settings.nightlight.enabled",
                            value = store.enabled,
                            on_toggle = nightlight.set_enabled,
                        },
                    }),
                    rows.line({
                        icons.doodle("night", 22),
                        c.slider {
                            id = "settings.nightlight.warmth",
                            accessible_name = "Warmth",
                            show_value = false,
                            width = 420,
                            value = nightlight.warmth,
                            on_change = function(v) nightlight.set_warmth(v) end,
                            on_wheel = nudge_warmth,
                        },
                    }, {
                        rows.caption(store.temperature:map(function(kelvin) return kelvin .. " K" end, "")),
                    }),
                    rows.list(c.radio_group {
                        id = "settings.nightlight.schedule",
                        vertical = true,
                        options = { { "manual", "Whenever it's on" }, { "times", "Sunset to sunrise, at fixed times" } },
                        value = store.schedule,
                        on_select = function(v) store:set("schedule", v) end,
                    }, 2),
                    rect {
                        width = "fill",
                        visible = store.schedule:map(function(s) return s == "times" end, false),
                        children = {
                            rows.line({
                                rows.label("From", { width = 56 }),
                                time_picker("from", "Start time"),
                                rows.label("to", { width = 30 }),
                                time_picker("to", "End time"),
                                rect { width = "fill" },
                            }),
                        },
                    },
                },
            },
        },
    }
end
