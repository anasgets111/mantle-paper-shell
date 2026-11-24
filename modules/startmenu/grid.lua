-- Where a dragged pinned tile lands: its own cell shifted by the drag, in whole cells, clamped to
-- the grid. Kept apart from the nodes so the arithmetic can be checked without a renderer.
local M = {}

--- @param from integer 1-based index of the dragged tile
--- @param count integer tiles in the grid
--- @return integer to
function M.target(from, dx, dy, count, columns, cell_w, cell_h)
    local col, row = (from - 1) % columns, (from - 1) // columns
    local rows = (count + columns - 1) // columns
    local c = math.max(0, math.min(columns - 1, col + math.floor(dx / cell_w + 0.5)))
    local r = math.max(0, math.min(rows - 1, row + math.floor(dy / cell_h + 0.5)))
    return math.max(1, math.min(count, r * columns + c + 1))
end

return M
