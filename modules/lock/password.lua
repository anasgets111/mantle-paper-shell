-- A password written on a ruled line, for the lock cover and the polkit note. Ported from
-- ~/.config/mantle/components/password_prompt.lua: the keys go to `secure_submit` and never reach
-- Lua; a failure shakes the line like a pencil scribble and writes the error in red marker.
--
-- opts = { id, capability = "lock"|"polkit", source? (signal, default mantle[capability]),
--          preview? (no secure field: a picture of one), width?, idle?, status? fn(state) -> text?,
--          on_cancel?, submit_disc? (false: the caller has its own labelled submit) }
local k = require("lib.paper")
local icons = require("components.icons")
local util = require("lib.util")
local controls = require("components.controls")
local G = require("modules.lock.glyphs")

-- Damped left-right wobble, one keyframe per 60 ms.
local SHAKE = {
    duration = 60,
    easing = "in_out_quad",
    keyframes = { { x = 0 }, { x = -12 }, { x = 11 }, { x = -7 }, { x = 6 }, { x = -2 }, { x = 0 } },
}
local ERROR_TEXT = {
    ["authentication failed"] = "Wrong password, try again",
    ["too many attempts"] = "Too many tries, wait a little",
}

-- Failures per source, counted where an attempt ends with an error. The count is the shake's
-- `run`: a new value replays the keyframes. It drops to 0 when the prompt closes, so a field built
-- for the next lock or polkit prompt does not shake on arrival. (A `pulse` built inside the
-- preview's `util.lift` callback was seen not to fire, so the edge is caught with `on_change`.)
local failures = {}
local function failure_count(source, key)
    if failures[key] == nil then
        local count = state("lock.failures." .. key, 0)
        source:on_change(function(now, before)
            if not now.active then
                count:set(0)
            elseif before and before.authenticating and not now.authenticating and (now.error or "") ~= "" then
                count:set(count:get() + 1)
            end
        end)
        failures[key] = count
    end
    return failures[key]
end

return function(opts)
    local source = opts.source or mantle[opts.capability]
    local W = opts.width or 360
    local busy = source:map(function(s) return s ~= nil and (s.authenticating or s.unlocking == true) end, false)
    local failed = source:map(function(s)
        return s ~= nil and s.active and not s.authenticating and not s.unlocking and (s.error or "") ~= ""
    end, false)
    local fails = failure_count(source, opts.preview and "preview" or opts.capability)

    -- PAM's own question when it is not the usual "Password:", e.g. a verification code.
    local placeholder = source:map(function(s)
        local asked = s and s.prompt and util.trim(s.prompt.text):gsub(":$", "") or ""
        return (asked == "" or asked:lower() == "password") and "password" or asked:lower()
    end, "password")

    local feedback = source:map(function(s)
        local status = opts.status and opts.status(s)
        if status then return status end
        if s and s.authenticating then return "checking\u{2026}" end
        local err = s and s.error or ""
        if err ~= "" then return ERROR_TEXT[err] or err end
        local notes = s and s.messages or {}
        if #notes > 0 then return notes[#notes].text end
        return opts.idle or ""
    end, opts.idle or "")

    local field = controls.field {
        id = opts.id,
        width = W - 52,
        size = 32,
        placeholder = placeholder,
        accessible_name = "Password",
        placeholder_color = k.INK_SOFT,
        mask_character = "\u{2022}",
        on_cancel = opts.on_cancel,
        secure_submit = not opts.preview and { capability = opts.capability, action = "authenticate" } or nil,
        masked = source:map(function(s) return not (s and s.prompt and s.prompt.echo) end, true),
    }

    local submit = controls.disc_button {
        id = opts.id .. ".go",
        icon = G.submit,
        size = 40,
        seed = 77,
        tooltip = "Unlock",
    }
    submit.submits_secure = busy:map(function(b) return not b and not opts.preview end, not opts.preview)
    submit.opacity = util.choose(busy, 0.5, 1)
    submit.align_v = "center"
    -- A chevron's weight sits left of its box; nudge it to the disc's optical centre.
    submit.children[2].translate = { x = 1.5 }

    local caps = rect {
        visible = mantle.keyboard:map(function(kb) return kb.caps_lock end, false),
        align_v = "center",
        children = { controls.chip("Caps lock", "#F2CFC8", 2) },
    }

    local lines = {
        row {
            width = W,
            spacing = 12,
            translate = { x = 0, y = 0 },
            animate = fails:map(function(n)
                return n > 0 and { translate = util.with(SHAKE, "run", n) } or {}
            end),
            children = opts.submit_disc == false and { field } or { field, submit },
        },
        row {
            width = W,
            spacing = 10,
            children = {
                -- Deep red: bright red is kept for marks, not words.
                k.hand(feedback, 26, {
                    font_weight = 700,
                    width = "fill",
                    wrap = "word",
                    max_lines = 2,
                    foreground = util.choose(failed, k.DEEP_RED, k.INK_SOFT),
                }),
                caps,
            },
        },
    }

    if opts.capability == "lock" then
        -- pam_fprintd's lines ("Place your finger", "Failed to match") while its conversation runs.
        lines[#lines + 1] = row {
            spacing = 8,
            visible = source:map(function(s) return s.fingerprint ~= nil end, false),
            children = {
                icons.doodle(G.fingerprint, 20, k.INK_SOFT),
                k.body(source:map(function(s)
                    local notes = s.fingerprint and s.fingerprint.messages or {}
                    return #notes > 0 and notes[#notes].text or "Or touch the fingerprint reader"
                end, ""), 19, { foreground = k.INK_SOFT, align_v = "center", width = W - 28, elide = "end" }),
            },
        }
    end

    return column { spacing = 6, children = lines }
end
