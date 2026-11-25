-- The idle settings page body (timers, profiles, inhibit), shown by the settings builder on its
-- Power page. Call it to build the page's node; `.surface` is its tooltip popup. Ported from
-- ~/.config/mantle/modules/global/idle_settings.lua with paper controls.
local theme = require("theme")
local k = require("lib.paper")
local icons = require("components.icons")
local util = require("lib.util")
local controls = require("components.controls")
local idle = require("modules.lock.idle")
local G = require("modules.lock.glyphs")
local tooltip = require("components.tooltip")
local rows = require("modules.settings.rows")

-- One ruled pitch per stage, so the rules run under the text and all four stages fit the tab.
local ROW_H = rows.PITCH
-- The page body: the notebook's content width less its 12 px right padding.
local BODY_W = rows.WIDTH - theme.spacing.md

-- The page is drawn inside the settings modal, so its notes hang from that surface.
local tips = tooltip.new { id = "paper-idle-tip", parent = "paper-modal-host", side = "top" }
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
        spacing = theme.spacing.xs,
        align_v = "center",
        -- A press here is a click, never the start of a row drag.
        on_drag = function() end,
        on_wheel = function(_, steps) step(steps > 0 and 1 or -1) end,
        children = {
            tips.wrap(controls.disc_button { id = "lock.idle.less." .. stage.key, icon = G.less, size = theme.control.sm, seed = 3,
                tooltip = "Shorter", on_click = function() step(-1) end }, "paper.disc.lock.idle.less." .. stage.key, "Shorter"),
            k.hand(current:map(idle.format), theme.font.heading, {
                font_weight = theme.BOLD, width = theme.lock.duration_w, text_align = "center", align_v = "center",
                foreground = current:map(function(sec) return sec > 0 and theme.DEEP_BLUE or theme.INK_SOFT end),
            }),
            tips.wrap(controls.disc_button { id = "lock.idle.more." .. stage.key, icon = G.more, size = theme.control.sm, seed = 5,
                tooltip = "Longer", on_click = function() step(1) end }, "paper.disc.lock.idle.more." .. stage.key, "Longer"),
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
    local cut = elided("lock.idle.detail." .. item.key)
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
                height = ROW_H - 2,
                align_v = "center",
                shape = k.torn(BODY_W, ROW_H - theme.lock.stage_highlight_inset, 70 + item.index, theme.paper.light_tear),
                background = theme.CARD,
                opacity = util.choose(mine, 1, 0),
                shadows = theme.SHADOW.lift,
            },
            rows.line({
                icons.doodle(G.drag, theme.icon.label, theme.INK_SOFT),
                k.hand(tostring(item.index), theme.font.title, { font_weight = theme.BOLD, foreground = theme.BLUE, width = theme.lock.stage_title_inset }),
                icons.doodle(stage.icon, theme.icon.md, theme.INK),
                k.body(stage.title, theme.font.control, { foreground = util.choose(enabled, theme.INK, theme.INK_SOFT) }),
                tips.wrap(k.body(stage.detail, theme.font.xs, { foreground = theme.INK_SOFT, width = "fill", elide = "end", elided = cut }),
                    "lock.idle.detail." .. item.key, function() return cut:get() and stage.detail or "" end),
            }, { stepper(stage) }),
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

-- A ruled row: the words on the left, the switch at the right edge.
local function switch_row(id, label, value, on_toggle)
    return rows.line({ rows.label(label) }, {
        controls.toggle { id = "lock.idle." .. id, value = value, on_toggle = on_toggle },
    })
end

local function setting_toggle(id, label, field)
    return switch_row(id, label, settings:map(function(s) return s[field] end),
        function(on) idle.write({ [field] = on }) end)
end

local status = computed({ settings, idle.schedule, idle.reasons }, function(s, plan, reasons)
    if #reasons > 0 then return "Held awake by: " .. table.concat(reasons, ", ") end
    if plan.total == 0 then return "No steps on this profile" end
    local first = plan.list[1]
    local line = string.format("%s after %s idle", first.title:lower(), idle.format(first.at))
    return s.enabled and "First: " .. line or "Paused; would " .. line
end)

-- Called like a function by the settings page; `surface` is the tooltip popup for the shell's list.
-- `part` = "idle" or "awake" builds one section, for a page that shows them under separate tabs.
local function build(part)
    local list = {}
    local function add(node) list[#list + 1] = node end
    if part ~= "awake" then
        if not idle.ENABLED then
            -- A sticky note so nobody wonders why the timers do nothing yet. Two pitches tall, and
            -- inset so its tilt clears the card's clip.
            add(rect {
                width = "fill",
                height = rows.PITCH * 2,
                padding = { left = theme.spacing.sm, top = theme.spacing.hairline },
                children = {
                    controls.sticky {
                        width = BODY_W - theme.lock.disabled_note_inset,
                        seed = 13,
                        rotate = -0.6,
                        tape = false,
                        child = row {
                            width = "fill",
                            spacing = theme.spacing.snug,
                            padding = { left = theme.spacing.lg, right = theme.spacing.lg, top = theme.spacing.md, bottom = theme.spacing.md },
                            children = {
                                icons.doodle(G.info, theme.icon.md),
                                k.body("Idle actions are switched off in this build. Timers are saved for later.", theme.font.sm, {
                                    align_v = "center", width = "fill", elide = "end",
                                }),
                            },
                        },
                    },
                },
            })
        end
        add(rows.heading("When idle"))
        add(switch_row("enabled", "Automatic actions", settings:map(function(s) return s.enabled end),
            function(on) idle.write({ enabled = on }) end))
        add(rows.line({ rows.caption(status, { width = "fill", elide = "end" }) }))
        add(rect {
            width = "fill",
            visible = has_battery,
            children = {
                rows.line({
                    controls.radio_group {
                        id = "lock.idle.profile",
                        options = PROFILES,
                        value = shown_profile,
                        on_select = function(p) picked:set(p) end,
                    },
                }),
            },
        })
        add(rows.note("Each step counts from the one before it. Drag a row to change the order."))
        add(stages)
    end
    if part ~= "idle" then
        add(rows.heading("Keep awake"))
        add(switch_row("manual", "Keep awake now", idle.manual, idle.set_manual))
        add(setting_toggle("capture", "While the camera, microphone or screen is being captured", "privacy_auto_inhibit"))
        add(setting_toggle("sleep", "While an app is blocking sleep", "sleep_holds_keep_awake"))
    end
    return column { width = "fill", children = list }
end

return setmetatable({ surface = tips.surface }, { __call = function(_, part) return build(part) end })
