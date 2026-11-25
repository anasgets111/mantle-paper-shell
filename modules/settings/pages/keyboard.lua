-- Keyboard page: the configured layouts, by name, and the lock keys. Names come from
-- `mantle.keyboard`, which names only the active layout, so the taskbar's list fills in as each
-- layout becomes active. Layouts are added in the compositor's input config.
local theme = require("theme")
local k = require("lib.paper")
local c = require("components.controls")
local rows = require("modules.settings.rows")
local layouts = require("lib.layouts")

local kbd = mantle.keyboard

local function layout_rows()
    return column {
        width = "fill",
        children = computed({ kbd, layouts.seen }, function()
            local list = layouts.list()
            if #list == 0 then return { rows.note("No keyboard layouts reported yet.") } end
            local options = {}
            for i, l in ipairs(list) do options[i] = { i - 1, l.name } end
            return {
                rows.list(
                    c.radio_group {
                        id = "settings.keyboard.layout",
                        vertical = true,
                        options = options,
                        value = kbd:map(function(s) return s.active_layout_index end),
                        on_select = function(index) kbd:switch_layout(index) end,
                    }, #options
                ),
            }
        end),
    }
end

-- Read only, so a plain ticked box with no pointer: lock keys change on the keyboard.
local function lock_key(name, field)
    return row {
        spacing = theme.spacing.snug,
        padding = { right = theme.spacing.xxl },
        children = kbd:map(function(s)
            return { k.checkbox(theme.icon.control, s[field] == true), k.body(name, theme.font.control, { align_v = "center" }) }
        end, { k.checkbox(theme.icon.control, false), k.body(name, theme.font.control, { align_v = "center" }) }),
    }
end

local function backlight_rows()
    return column {
        width = "fill",
        visible = kbd:map(function(s) return s.backlight_percent ~= nil end, false),
        children = {
            rows.line({
                rows.label("Backlight", { width = theme.settings.backlight_label_w }),
                c.slider {
                    id = "settings.keyboard.backlight",
                    width = theme.settings.backlight_slider_w,
                    value = kbd:map(function(s) return (s.backlight_percent or 0) / 100 end, 0),
                    on_change = function(v) kbd:set_backlight(v * 100) end,
                    on_wheel = function(_, steps)
                        local now = kbd:get()
                        local pct = now and now.backlight_percent
                        if pct then kbd:set_backlight(math.max(0, math.min(100, pct + steps * 5))) end
                    end,
                },
            }),
        },
    }
end

return {
    key = "keyboard",
    title = "Keyboard",
    build = function()
        return {
            rows.heading("Input sources", {
                rows.caption(kbd:map(function(s) return s.active_layout ~= "" and ("now: " .. s.active_layout) or "" end, "")),
            }),
            layout_rows(),
            rows.note("Add or reorder layouts in your compositor's input config.", 1),
            rows.heading("Lock keys"),
            rows.line({ lock_key("Caps Lock", "caps_lock"), lock_key("Num Lock", "num_lock"), lock_key("Scroll Lock", "scroll_lock") }),
            backlight_rows(),
        }
    end,
}
