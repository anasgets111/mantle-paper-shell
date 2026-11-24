-- Pressed feedback: the control under a held left button shrinks a little. One name at a time.
local M = {}

local pressed = state("taskbar.pressed", "")
local release

-- `on_drag` for a slot. A node rebuilt mid-press (a click that focuses a window rebuilds its task
-- icon) never gets its "end", so a press also lets go by itself after 600 ms.
function M.track(slot)
    return function(_, _, phase)
        if phase == "move" then return end
        if release then release:cancel() end
        release = nil
        if phase == "start" then
            pressed:set(slot)
            release = timer(600, function()
                release = nil
                pressed:set("")
            end)
        else
            pressed:set("")
        end
    end
end

function M.scale(slot)
    return pressed:map(function(p) return p == slot and 0.93 or 1 end)
end

return M
