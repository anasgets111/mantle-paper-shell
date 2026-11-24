-- System tray: one small ink icon per item, passive ones hidden. Left click activates (or opens the
-- menu when the item is only a menu), right click opens its DBusMenu on a sticky note.
local k = require("lib.paper")
local menus = require("modules.taskbar.menus")
local icons = require("modules.taskbar.icons")

local M = {}

local SIZE = 22

local items = mantle.tray:map(function(tray)
    local out = {}
    for _, item in ipairs(tray and tray.items or {}) do
        if item.status ~= "passive" then out[#out + 1] = item end
    end
    return out
end, {})

-- `needs_attention` uses the attention artwork when sent, else the base pair.
local function artwork(item)
    if item.status == "needs_attention" and (item.attention_icon_name or item.attention_icon_path) then
        return item.attention_icon_name, item.attention_icon_path
    end
    return item.icon_name, item.icon_path
end

local function face(item)
    local name, file = artwork(item)
    if name and name ~= "" then
        return icons.app(name, SIZE, { foreground = k.INK })
    end
    if file and file ~= "" then
        return icons.pixmap(file, SIZE)
    end
    return k.hand(string.upper((menus.tray_label(item)):sub(1, 1)), 24, { align_h = "center", align_v = "center" })
end

local function tray_item(output, item)
    local hovered = hover("taskbar.tray." .. output .. "." .. item.id)
    return rect {
        width = SIZE + 12,
        height = "fill",
        hover = hovered,
        accessible_name = menus.tray_label(item),
        cursor = "pointer",
        on_click = function(r, button)
            local cx, cy = math.floor(r.x + r.width / 2), math.floor(r.y)
            if item.menu and (button == "right" or item.item_is_menu) then
                menus.open_tray(item, r)
            elseif button == "right" then
                mantle.tray:context_menu(item.id, cx, cy)
            elseif button == "middle" then
                mantle.tray:secondary_activate(item.id, cx, cy)
            elseif button == "left" then
                mantle.tray:activate(item.id, cx, cy)
            end
        end,
        on_wheel = function(_, steps) mantle.tray:scroll(item.id, math.floor(steps + 0.5), "vertical") end,
        children = {
            rect {
                align_h = "center",
                align_v = "center",
                translate = hovered:map(function(v) return { y = v and -2 or 0 } end),
                rotate = hovered:map(function(v) return v and -4 or 0 end),
                animate = {
                    translate = { duration = 140, easing = "out_cubic" },
                    rotate = { spring = { stiffness = 300, damping = 16 } },
                },
                children = { face(item) },
            },
        },
    }
end

function M.new(output)
    return list {
        direction = "horizontal",
        height = "fill",
        align_v = "center",
        items = items,
        key = function(item) return item.id end,
        each = function(item) return tray_item(output, item) end,
    }
end

return M
