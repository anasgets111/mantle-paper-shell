-- The popup stack: up to four sticky notes at the bottom-right, above the taskbar, newest at the
-- bottom where the eye already is. One surface for the stack, sized to the screen's height so a new
-- note never resizes the buffer; its empty part takes no input.
local util = require("lib.util")
local feed = require("modules.notifications.feed")
local st = require("modules.notifications.state")
local card = require("modules.notifications.card")
local tips = require("modules.notifications.tips")
local quick = require("modules.quick")

local MAX_NOTES = 4
-- The engine never expires a critical note. After this long it retires to the date menu's urgent
-- section instead of holding the corner.
local CRITICAL_POPUP_SECONDS = 60
local EXIT_MS = 260

local HOVER = hover("notifications.stack")

-- The quick-settings sheet opens in this corner; the stack steps aside and waits while it is up.
local quick_open = quick.is_open or false

-- Expiry waits while the stack is read or hidden behind quick settings.
computed({ HOVER, quick_open }, function(hovered, covered) return hovered or covered end)
    :on_change(function(hold) mantle.notifications:hold_expiry(hold and 300 or 0) end)

-- The newest unseen notes, oldest first so the newest lands at the bottom.
local notes = computed({ mantle.notifications, st.seen, st.center_open, st.locked, st.sharing, quick_open, st.muted },
    function(inbox, seen, center_open, locked, sharing, covered, muted)
        -- The date menu shows them all; over the lock screen they would be readable without a password.
        if center_open or locked or covered then return {} end
        local dnd = inbox.dnd or sharing
        local silenced = {}
        for _, app in ipairs(muted or {}) do silenced[app] = true end
        local shown = {}
        for _, n in ipairs(inbox.feed) do
            local quiet = dnd and n.urgency ~= "critical" or silenced[feed.app_key(n)]
            if not n.expired and not quiet and not seen[feed.key(n)] then
                shown[#shown + 1] = n
                if #shown == MAX_NOTES then break end
            end
        end
        local out = {}
        for i = #shown, 1, -1 do out[#out + 1] = { n = shown[i], slot = i } end
        return out
    end, {})

-- Once a second. A hovered stack is being read, so it waits as the expiry hold does.
mantle.clock:on_change(function(clock)
    if HOVER:get() then return end
    local seen = st.seen:get()
    for _, n in ipairs((mantle.notifications:get() or {}).feed or {}) do
        if n.urgency == "critical" and not seen[feed.key(n)]
            and clock.time - n.timestamp >= CRITICAL_POPUP_SECONDS then
            st.hide(n)
        end
    end
end)

return panel {
    id = tips.POPUPS_ID,
    -- Not `mantle-*`: Hyprland frosts that namespace's popups, and paper is opaque.
    namespace = "paper-notifications",
    output = "active",
    layer = "overlay",
    anchor = { top = true, bottom = true, right = true },
    -- No right margin: a note swiped right slides off the screen edge, not into a cut 10 px short of it.
    margin = { top = 12, bottom = 6 },
    width = card.WIDTH + 80,
    height = "fill",
    visible = util.linger(notes:map(function(shown) return #shown > 0 end), EXIT_MS),
    -- Bound, not constant: an `on_demand` surface can take the keyboard at map, which would steal it
    -- on every notification. Hover arms it for the reply field; a typed draft holds it after.
    keyboard_interactivity = computed({ HOVER, st.reply_pending }, function(hovered, pending)
        return (hovered or pending) and "on_demand" or "none"
    end),
    child = column {
        width = "fill",
        height = "fill",
        children = {
            rect { height = "fill" },
            column {
                width = "fill",
                padding = { left = 30, right = 40, top = 24, bottom = 40 },
                hover = HOVER,
                children = {
                    list {
                        width = "fill",
                        spacing = 14,
                        items = notes,
                        limit = MAX_NOTES,
                        key = function(item) return feed.key(item.n) end,
                        each = function(item) return card.build(item.n, item.slot) end,
                    },
                },
            },
        },
    },
}
