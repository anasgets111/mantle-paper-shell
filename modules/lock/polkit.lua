-- Polkit's authorization prompt as a sticky note in the middle of the screen. Reading
-- `mantle.polkit` registers this shell as the session's polkit agent; the note maps only while
-- polkitd waits for a password. Ported from ~/.config/mantle/modules/global/polkit.lua.
--
-- `mantle toggle lock.polkit_preview` shows the note without pkexec (its password line is a
-- picture); `mantle set lock.polkit_preview_state '{...}'` feeds it a fake `mantle.polkit` payload.
local k = require("lib.paper")
local util = require("lib.util")
local controls = require("components.controls")
local password = require("modules.lock.password")
local G = require("modules.lock.glyphs")
local icons = require("components.icons")

local W, PAD_L, PAD_R = 560, 30, 28
local INNER = W - PAD_L - PAD_R
local MS = 180

local preview = state("lock.polkit_preview", false)
local preview_state = state("lock.polkit_preview_state", {
    active = true, authenticating = false, error = "", messages = {},
    message = "Authentication is required to restart the bluetooth.service unit.",
    action_id = "org.freedesktop.systemd1.manage-units", icon_name = "",
    identities = { { uid = 1000, name = os.getenv("USER") or "" } }, identity = 1000,
})

local real = mantle.polkit:map(function(p) return p.active end, false)
local active = computed({ real, preview }, function(r, p) return r or p end)
local shown = util.linger(active, MS)

local function cancel()
    if preview:get() then return preview:set(false) end
    mantle.polkit:cancel()
end

-- Several accounts can answer (wheel members); the session user is preselected by the engine.
local function who(source)
    return column {
        spacing = 6,
        children = source:map(function(p)
            local ids = p.identities or {}
            if #ids <= 1 then
                local name = ids[1] and ids[1].name ~= "" and ids[1].name or os.getenv("USER") or ""
                return { row { spacing = 6, children = {
                    icons.doodle(G.user, 18, k.INK_SOFT), k.body("as " .. name, 19, { foreground = k.INK_SOFT }),
                } } }
            end
            local options = {}
            for i, id in ipairs(ids) do options[i] = { id.uid, id.name ~= "" and id.name or ("uid " .. id.uid) } end
            return {
                controls.radio_group {
                    id = "lock.polkit.who",
                    options = options,
                    value = p.identity,
                    on_select = function(uid) if source == mantle.polkit then mantle.polkit:select_identity(uid) end end,
                },
            }
        end, {}),
    }
end

-- The note for `source` (`mantle.polkit`, or the preview's fake payload with `is_preview`).
local function note(source, is_preview)
    local function label(fn) return source:map(fn, "") end
    local busy = source:map(function(p) return p.authenticating == true end, false)
    local ok = controls.button { id = "lock.polkit.ok", label = "Allow", kind = "primary", width = 120 }
    -- While PAM checks, Allow dims and stops sending, as the lock's submit disc does.
    ok.submits_secure = busy:map(function(b) return not b and not is_preview end, not is_preview)
    ok.opacity = util.choose(busy, 0.5, 1)
    ok.animate = { opacity = { duration = 120 } }
    return controls.sticky {
        width = W,
        seed = 61,
        rotate = -1,
        child = column {
            width = "fill",
            spacing = 10,
            padding = { left = PAD_L, right = PAD_R, top = 26, bottom = 26 },
            children = {
                row {
                    spacing = 12,
                    children = {
                        icons.doodle_for(label(function(p) return p.icon_name ~= "" and p.icon_name or G.lock end), 30),
                        k.hand("Password needed", 38, { font_weight = 700, align_v = "center" }),
                    },
                },
                k.body(label(function(p) return p.message end), 20, { width = "fill", wrap = "word", max_lines = 3 }),
                -- What is being granted, so a vague message can still be judged.
                k.body(label(function(p) return p.action_id end), 16, { foreground = k.INK_SOFT, width = "fill", elide = "end" }),
                who(source),
                password {
                    id = "lock.polkit.password", capability = "polkit", source = source, preview = is_preview,
                    width = INNER, submit_disc = false, on_cancel = cancel,
                },
                row {
                    align_h = "end",
                    spacing = 18,
                    padding = { top = 8 },
                    children = {
                        controls.button { id = "lock.polkit.cancel", label = "Cancel", width = 120, on_click = cancel },
                        ok,
                    },
                },
            },
        },
    }
end

return panel {
    id = "paper-polkit",
    output = "active",
    namespace = "paper-polkit",
    layer = "overlay",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive_zone = false,
    width = "fill",
    height = "fill",
    visible = shown,
    on_escape = cancel,
    -- Exclusive for a real prompt: the one secure field arms on keyboard focus with no click. The
    -- preview has no secure field and takes the keys only when clicked, for Escape.
    keyboard_interactivity = computed({ real, preview }, function(r, p)
        return r and "exclusive" or p and "on_demand" or "none"
    end),
    child = rect {
        width = "fill",
        height = "fill",
        children = {
            rect {
                align_h = "center",
                align_v = "center",
                opacity = util.choose(active, 1, 0),
                translate = active:map(function(on) return { y = on and 0 or 12 } end),
                animate = { opacity = { duration = MS, easing = "out_cubic", from = 0 },
                    translate = { duration = MS, easing = "out_cubic", from = { y = 12 } } },
                children = util.lift(preview, function(on)
                    return { on and note(preview_state, true) or note(mantle.polkit, false) }
                end),
            },
        },
    },
}
