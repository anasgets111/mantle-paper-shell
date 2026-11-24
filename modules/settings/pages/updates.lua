-- Updates page: the updates module draws its own rows (`modules/updates/page.lua`). A missing or
-- broken module leaves a note instead of taking the notebook down.
local rows = require("modules.settings.rows")

return {
    key = "updates",
    title = "Updates",
    build = function()
        local ok, updates = pcall(require, "modules.updates")
        if ok and type(updates) == "table" and updates.page then
            local built, list = pcall(updates.page)
            if built then return list end
        end
        return { rows.note("The updates module isn't available.") }
    end,
}
