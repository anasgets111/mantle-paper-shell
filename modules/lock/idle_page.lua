-- The idle settings page body (timers, profiles, inhibit), shown by the settings builder on its
-- Power page. Returns a function building the page's node. Ported from
-- ~/.config/mantle/modules/global/idle_settings.lua with paper controls.
local k = require("lib.paper")
local util = require("lib.util")
local controls = require("components.controls")
local idle = require("modules.lock.idle")

local ROW_H = 72
local PROFILES = { { "ac", "Plugged in" }, { "battery", "On battery" } }

local settings = idle.settings

local has_battery = mantle.battery:map(function(b) return b.present end, false)
-- The profile being edited: the live one until someone picks the other.
local picked = state("lock.idle.picked", "")
local shown_profile = computed({ picked, idle.active_profile, has_battery }, function(chosen, active, battery)
    if not battery then return "ac" end
    return chosen ~= "" and chosen or active
end)

local dragging = state("lock.idle.drag", {})
local stage_bounds = geometry("lock.idle.stages")

-- A timeout picker: paper discs step through the stage's options, Off first.
local function stepper(stage)
    local on_key, sec_key = stage.key .. "_on", stage.key .. "_sec"
    local current = computed({ settings, shown_profile }, function(s, profile)
        local held = s[profile]
        return held[on_key] and held[sec_key] or 0
    end)
    local function step(dir)
        -- The stage's options plus whatever either profile stores, so a hand-set value is a stop too.
        local resolved = idle.settings:get()
        local seen, options = {}, {}
        for _, sec in ipairs({ 0, resolved.ac[sec_key], resolved.battery[sec_key], table.unpack(stage.options) }) do
            if not seen[sec] then
                seen[sec] = true
                options[#options + 1] = sec
            end
        end
        table.sort(options)
        local at = util.index_of(options, current:get()) or 1
        local sec = options[math.max(1, math.min(#options, at + dir))]
        local profile = shown_profile:get()
        local held = idle.read(idle.settings:get())[profile]
        -- Off keeps the stored seconds, so switching back on restores them.
        held[on_key] = sec > 0
        if sec > 0 then held[sec_key] = sec end
        idle.write({ [profile] = held })
    end
    return row {
        spacing = 6,
        align_v = "center",
        -- A press here is a click, never the start of a row drag.
        on_drag = function() end,
        children = {
            controls.disc_button { id = "lock.idle.less." .. stage.key, icon = "go-previous-symbolic", size = 34, seed = 3,
                tooltip = "Shorter", on_click = function() step(-1) end },
            k.hand(current:map(idle.format), 28, {
                font_weight = 700, width = 78, text_align = "center", align_v = "center",
                foreground = current:map(function(sec) return sec > 0 and k.DEEP_BLUE or k.INK_SOFT end),
            }),
            controls.disc_button { id = "lock.idle.more." .. stage.key, icon = "go-next-symbolic", size = 34, seed = 5,
                tooltip = "Longer", on_click = function() step(1) end },
        },
    }
end

local function stage_row(item)
    local stage = assert(idle.stage(item.key))
    local enabled = computed({ settings, shown_profile }, function(s, profile)
        local held = s[profile]
        return held[item.key .. "_on"] and held[item.key .. "_sec"] > 0
    end)
    local mine = dragging:map(function(drag) return drag.key == item.key end)
    return rect {
        width = "fill",
        height = ROW_H,
        cursor = util.choose(mine, "grabbing", "grab"),
        z = util.choose(mine, 1, 0),
        rotate = mine:map(function(v) return v and -0.8 or 0 end),
        animate = { rotate = { spring = { stiffness = 300, damping = 18 } } },
        translate = dragging:map(function(drag)
            if not drag.key then return { y = 0 } end
            if drag.key == item.key then return { y = drag.offset } end
            if item.index > drag.index and item.index <= drag.target then return { y = -ROW_H } end
            if item.index < drag.index and item.index >= drag.target then return { y = ROW_H } end
            return { y = 0 }
        end),
        on_drag = function(r, pointer, phase)
            if phase == "start" then
                dragging:set({ key = item.key, index = item.index, target = item.index, offset = 0, grab_y = pointer.y })
                return
            end
            local drag = dragging:get()
            if drag.key ~= item.key then return end
            local bounds = stage_bounds:get()
            local count = #settings:get().order
            local offset = r.y + pointer.y - drag.grab_y - bounds.y - (drag.index - 1) * ROW_H
            offset = math.max((1 - drag.index) * ROW_H, math.min((count - drag.index) * ROW_H, offset))
            local target = drag.index + math.floor(offset / ROW_H + 0.5)
            if phase == "end" then
                dragging:set({})
                idle.move(item.key, target)
            else
                dragging:set({ key = drag.key, index = drag.index, target = target, offset = offset, grab_y = drag.grab_y })
            end
        end,
        children = {
            -- Lifted while dragged: the row becomes a scrap of card stock held above the page.
            rect {
                width = "fill",
                height = ROW_H - 8,
                align_v = "center",
                shape = k.torn(720, ROW_H - 8, 70 + item.index, 2),
                background = "#F4ECDA",
                opacity = util.choose(mine, 1, 0),
                shadows = k.SHADOW.lift,
            },
            row {
                width = "fill",
                height = "fill",
                spacing = 14,
                padding = { left = 6, right = 8 },
                children = {
                    k.glyph("list-drag-handle-symbolic", 18, k.INK_SOFT),
                    k.hand(tostring(item.index), 30, { font_weight = 700, foreground = k.BLUE, width = 24, align_v = "center" }),
                    k.glyph(stage.icon, 22, k.INK),
                    column {
                        width = "fill",
                        align_v = "center",
                        children = {
                            k.body(stage.title, 22, { foreground = util.choose(enabled, k.INK, k.INK_SOFT) }),
                            k.body(stage.detail, 16, { foreground = k.INK_SOFT }),
                        },
                    },
                    stepper(stage),
                },
            },
        },
    }
end

-- Stored order, as a `list`: declared children cannot be reordered.
local stages = list {
    width = "fill",
    geometry = stage_bounds,
    items = settings:map(function(s)
        local items = {}
        for index, key in ipairs(s.order) do items[index] = { key = key, index = index } end
        return items
    end),
    key = function(item) return item.key end,
    each = stage_row,
}

local function setting_toggle(id, label, field)
    return controls.toggle {
        id = "lock.idle." .. id,
        label = label,
        value = settings:map(function(s) return s[field] end),
        on_toggle = function(on) idle.write({ [field] = on }) end,
    }
end

local status = computed({ settings, idle.schedule, idle.reasons }, function(s, plan, reasons)
    if #reasons > 0 then return "Held awake by: " .. table.concat(reasons, ", ") end
    if plan.total == 0 then return "No steps on this profile" end
    local first = plan.list[1]
    local line = string.format("%s after %s idle", first.title:lower(), idle.format(first.at))
    return s.enabled and "First: " .. line or "Paused; would " .. line
end)

return function()
    local children = {
        controls.section("When idle", {
            row {
                width = "fill",
                spacing = 20,
                children = {
                    controls.toggle {
                        id = "lock.idle.enabled",
                        label = "Automatic actions",
                        value = settings:map(function(s) return s.enabled end),
                        on_toggle = function(on) idle.write({ enabled = on }) end,
                    },
                    k.body(status, 19, { foreground = k.INK_SOFT, align_v = "center", width = "fill", elide = "end" }),
                },
            },
            rect {
                visible = has_battery,
                children = {
                    controls.radio_group {
                        id = "lock.idle.profile",
                        options = PROFILES,
                        value = shown_profile,
                        on_select = function(p) picked:set(p) end,
                    },
                },
            },
            k.body("Each step counts from the one before it. Drag a row to change the order.", 17, {
                foreground = k.INK_SOFT,
            }),
            stages,
        }),
        controls.section("Keep awake", {
            controls.toggle {
                id = "lock.idle.manual",
                label = "Keep awake now",
                value = idle.manual,
                on_toggle = idle.set_manual,
            },
            setting_toggle("capture", "While the camera, microphone or screen is being captured", "privacy_auto_inhibit"),
            setting_toggle("sleep", "While an app is blocking sleep", "sleep_holds_keep_awake"),
        }),
    }
    if not idle.ENABLED then
        -- A sticky note so nobody wonders why the timers do nothing yet.
        table.insert(children, 1, controls.sticky {
            width = 520,
            height = 64,
            seed = 13,
            rotate = -1,
            tape = false,
            child = row {
                spacing = 10,
                padding = { left = 16, top = 10 },
                children = {
                    k.glyph("dialog-information-symbolic", 20),
                    k.body("Idle actions are switched off in this build. Timers are saved for later.", 18, {
                        align_v = "center", width = 470, wrap = "word",
                    }),
                },
            },
        })
    end
    return column { width = "fill", spacing = 26, children = children }
end
