-- Press feedback: a control sinks a little while the left button is held on it. `on_drag` brackets
-- the press: "start" on press, "end" on release or when the pointer leaves, always before the click.
local M = {}

local pressed = state("taskbar.pressed", "")

-- The on_drag handler that marks `slot` held.
function M.track(slot)
    return function(_, _, phase)
        pressed:set(phase == "end" and "" or slot)
    end
end

-- Scale for the node that sinks: 0.93 while `slot` is held.
function M.scale(slot)
    return pressed:map(function(p) return p == slot and 0.93 or 1 end)
end

return M
