-- Where the shell saves its state: $XDG_STATE_HOME/paper-shell, so the config folder stays clean.
local base = os.getenv("XDG_STATE_HOME")
if not base or base == "" then base = (os.getenv("HOME") or "") .. "/.local/state" end
local DIR = base .. "/paper-shell"

return {
    state = function(name) return DIR .. "/" .. name end,
}
