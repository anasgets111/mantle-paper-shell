-- Polkit's authorization prompt as a sticky note in the middle of the screen. Reading
-- `mantle.polkit` registers this shell as the session's polkit agent; the note maps only while
-- polkitd waits for a password. Ported from ~/.config/mantle/modules/global/polkit.lua.
local k = require("lib.paper")
local util = require("lib.util")
local controls = require("components.controls")
local password = require("modules.lock.password")

local W, H = 560, 420
local MS = 180

local active = mantle.polkit:map(function(p) return p.active end, false)
local shown = util.linger(active, MS)

local function cancel() mantle.polkit:cancel() end

local function label(fn) return mantle.polkit:map(fn, "") end

-- Several accounts can answer (wheel members); the session user is preselected by the engine.
local who = column {
    spacing = 6,
    children = mantle.polkit:map(function(p)
        local ids = p.identities or {}
        if #ids <= 1 then
            local name = ids[1] and ids[1].name ~= "" and ids[1].name or os.getenv("USER") or ""
            return { k.body("as " .. name, 19, { foreground = k.INK_SOFT }) }
        end
        local options = {}
        for i, id in ipairs(ids) do options[i] = { id.uid, id.name ~= "" and id.name or ("uid " .. id.uid) } end
        return {
            controls.radio_group {
                id = "lock.polkit.who",
                options = options,
                value = p.identity,
                on_select = function(uid) mantle.polkit:select_identity(uid) end,
            },
        }
    end, {}),
}

local ok = controls.button { id = "lock.polkit.ok", label = "Allow", kind = "primary", width = 120 }
ok.submits_secure = true

local note = controls.sticky {
    width = W,
    height = H,
    seed = 61,
    rotate = -1,
    child = column {
        width = "fill",
        height = "fill",
        spacing = 10,
        padding = { left = 30, right = 28, top = 26, bottom = 22 },
        children = {
            row {
                spacing = 12,
                children = {
                    icon {
                        name = label(function(p) return p.icon_name ~= "" and p.icon_name or "dialog-password-symbolic" end),
                        size = 30, foreground = k.INK, align_v = "center",
                    },
                    k.hand("Password needed", 38, { font_weight = 700, align_v = "center" }),
                },
            },
            k.body(label(function(p) return p.message end), 20, { width = "fill", wrap = "word", max_lines = 3 }),
            -- What is being granted, so a vague message can still be judged.
            k.body(label(function(p) return p.action_id end), 16, { foreground = k.INK_SOFT, width = "fill", elide = "end" }),
            who,
            password { id = "lock.polkit.password", capability = "polkit", width = W - 70, on_cancel = cancel },
            rect { height = "fill" },
            row {
                align_h = "end",
                spacing = 18,
                children = {
                    controls.button { id = "lock.polkit.cancel", label = "Cancel", width = 120, on_click = cancel },
                    ok,
                },
            },
        },
    },
}

return panel {
    id = "paper-polkit",
    output = "active",
    namespace = "mantle-paper-polkit",
    layer = "overlay",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive_zone = false,
    width = "fill",
    height = "fill",
    visible = shown,
    on_escape = cancel,
    -- Exclusive while open: the one secure field arms on keyboard focus with no click.
    keyboard_interactivity = util.choose(shown, "exclusive", "none"),
    child = rect {
        width = "fill",
        height = "fill",
        background = "#2A201540",
        children = {
            rect {
                align_h = "center",
                align_v = "center",
                opacity = util.choose(active, 1, 0),
                translate = active:map(function(on) return { y = on and 0 or 12 } end),
                animate = { opacity = { duration = MS, easing = "out_cubic", from = 0 },
                    translate = { duration = MS, easing = "out_cubic", from = { y = 12 } } },
                children = { note },
            },
        },
    },
}
