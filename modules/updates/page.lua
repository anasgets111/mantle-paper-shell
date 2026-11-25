-- The settings notebook's "Updates" page body: rows on the notebook's 34 px rules, built with
-- `modules/settings/rows.lua`. Every row is bound to a signal, so the page stays live while open.
local c = require("components.controls")
local util = require("lib.util")
local rows = require("modules.settings.rows")
local S = require("modules.updates.service")
local model = require("modules.updates.model")
local tools = require("modules.updates.tools")

local saved = S.saved

local ago = computed({ S.updates, mantle.clock }, function(u)
    local at = u and u.last_successful_check
    return at and model.ago(at, os.time()) or "never"
end, "never")

local status = computed({ S.look, S.count }, function(look, count)
    if count > 0 then return look.title .. " · " .. look.detail end
    return look.title
end, "")

local function aur_caption(u)
    if u == nil then return "" end
    if u.aur_error and saved.aur:get() then return "not checked: " .. model.plain(u.aur_error) end
    return u.aur_helper and ("through " .. u.aur_helper) or "no AUR helper found"
end

local function last_install(last)
    if not last or not last.at then return "No update has run from this shell yet." end
    return string.format("%s · %s", last.text or (last.ok and "Updated" or "Failed"), util.stamp(last.at, os.time()))
end

local function tool_rows()
    return column {
        width = "fill",
        children = tools.present:map(function(p)
            local list = {}
            for _, tool in ipairs(tools.LIST) do
                if p[tool.requires] then
                    list[#list + 1] = rows.line({ rows.label(tool.name) }, {
                        rows.caption(table.concat(tool.run[1], " "), { elide = "end", max_width = 300 }),
                        c.checkbox_row {
                            id = "updates.tool." .. tool.name,
                            label = "include",
                            value = saved.dev_tools:map(function(flags) return flags[tool.name] ~= false end),
                            on_toggle = function(on) S.set_tool(tool.name, on) end,
                        },
                    })
                end
            end
            if #list == 0 then list[1] = rows.note("None of the supported tools is installed.") end
            return list
        end),
    }
end

return function()
    local strip, tab = rows.tabs("updates", { "Checking", "Developer tools" }, 190)
    return { strip, rows.pane(tab, 1, {
        rows.heading("Checking", {
            rows.button("updates.check", "Check now", "plain", S.check),
        }),
        rows.line({ rows.label(status) }, { rows.caption(ago:map(function(a) return "checked " .. a end)) }),
        rows.line({ rows.label("Check") }, {
            rows.dropdown {
                id = "updates.interval",
                label = "Check for updates",
                width = 180,
                options = S.INTERVALS,
                value = saved.interval,
                on_select = S.set_interval,
            },
        }),
        rows.line({ rows.label("Include AUR packages") }, {
            rows.caption(S.updates:map(aur_caption, "")),
            c.toggle { id = "updates.aur", value = saved.aur, on_toggle = S.set_aur },
        }),
        rows.line({ rows.label("Notify when updates arrive") }, {
            rows.caption("once per new package"),
            c.toggle { id = "updates.notify", value = saved.notify, on_toggle = S.set_notify },
        }),
        rows.heading("Last update"),
        rows.note(saved.last_install:map(last_install)),
    }), rows.pane(tab, 2, {
        rows.heading("Developer tools"),
        rows.note("Updated after the packages, as you, in the order below."),
        tool_rows(),
    }) }
end
