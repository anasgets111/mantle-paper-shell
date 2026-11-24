-- A context menu as a taped sticky note on an xdg_popup, with one level of submenus. Used by the
-- taskbar, the tray and the start menu, so every right-click on the desk looks the same.
--
--   local menu = require("components.menu").new { id = "taskbar-menu", parent = "paper-taskbar" }
--   surfaces: menu.surfaces (add both to the shell's list)
--   open:     menu.open(rect, items, { anchor = "top", gravity = "top" })
--   items:    { label, icon?, on_click?, checked? (true/false/nil), disabled?, separator?, children? }
--
-- An item's on_click runs and the menu closes; an item with `children` opens the submenu instead.
local k = require("lib.paper")
local controls = require("components.controls")

local M = {}

local ROW_H, WIDTH = 34, 250
-- Room for the sticky note's shadow (blur 10, offset y 6) inside the popup.
local PAD = { top = 14, left = 14, right = 14, bottom = 22 }

local function item_row(id, i, item, on_pick)
    if item.separator then
        return rect { height = 10, width = "fill", padding = { left = 14, right = 14 }, children = { controls.divider(WIDTH - 28) } }
    end
    local hovered = hover(id .. ".row." .. i)
    local ink = item.disabled and k.INK_SOFT or k.INK
    local lead
    if item.checked ~= nil then
        lead = k.checkbox(18, item.checked)
    elseif item.icon then
        lead = k.glyph(item.icon, 18, ink)
    else
        lead = rect { width = 18, height = 18 }
    end
    local children = {
        lead,
        k.body(item.label, 19, { foreground = ink, align_v = "center", elide = "end", width = "fill" }),
    }
    if item.children then children[#children + 1] = k.glyph("go-next-symbolic", 14, k.INK_SOFT) end
    return rect {
        width = "fill",
        height = ROW_H,
        hover = hovered,
        accessible_name = item.label,
        cursor = item.disabled and "default" or "pointer",
        on_click = function(r)
            if not item.disabled then on_pick(item, r) end
        end,
        children = {
            -- A highlighter swipe under the hovered row.
            rect {
                width = "fill",
                height = ROW_H - 8,
                align_v = "center",
                background = k.HIGHLIGHT,
                blend = "multiply",
                shape = k.tape_shape(WIDTH - 16, ROW_H - 8, i + 3),
                opacity = hovered:map(function(v) return (v and not item.disabled) and 1 or 0 end),
                animate = { opacity = { duration = 100 } },
            },
            row { width = "fill", height = "fill", spacing = 10, padding = { left = 14, right = 14 }, children = children },
        },
    }
end

local function note(id, items, on_pick, title)
    local rows = {}
    if title then
        rows[1] = k.hand(title, 24, { font_weight = 700, padding = { left = 14, bottom = 2, right = 4 }, elide = "end", max_width = WIDTH - 20 })
    end
    for i, item in ipairs(items or {}) do rows[#rows + 1] = item_row(id, i, item, on_pick) end
    local h = 0
    for _, item in ipairs(items or {}) do h = h + (item.separator and 10 or ROW_H) end
    h = h + 26 + (title and 34 or 0)
    return controls.sticky {
        width = WIDTH,
        height = h,
        seed = #id + #(items or {}),
        rotate = -0.8,
        child = column { width = "fill", padding = { top = 14, bottom = 10 }, children = rows },
    }
end

-- o = { id, parent }
function M.new(o)
    local open = state(o.id .. ".open", false)
    local anchor = state(o.id .. ".anchor", { x = 0, y = 0, width = 1, height = 1 })
    local placement = state(o.id .. ".placement", { anchor = "top", gravity = "top" })
    local items = state(o.id .. ".items", {})
    local title = state(o.id .. ".title", false)
    local sub_open = state(o.id .. ".sub.open", false)
    local sub_anchor = state(o.id .. ".sub.anchor", { x = 0, y = 0, width = 1, height = 1 })
    local sub_items = state(o.id .. ".sub.items", {})

    -- Callbacks don't survive a state round trip as data, so the live item tables are kept here.
    local live, live_sub = {}, {}

    local menu = {}

    function menu.close()
        sub_open:set(false)
        open:set(false)
    end

    local function pick(item, r)
        if item.children then
            live_sub = item.children
            sub_items:set(#live_sub)
            sub_anchor:set({ x = r.x, y = r.y, width = r.width, height = r.height })
            sub_open:set(true)
            return
        end
        menu.close()
        if item.on_click then item.on_click() end
    end

    -- rect: the clicked node's rect in the parent surface; opts = { anchor, gravity, title }
    function menu.open(rect_, list, opts)
        opts = opts or {}
        live = list
        sub_open:set(false)
        anchor:set({ x = rect_.x or 0, y = rect_.y or 0, width = math.max(1, rect_.width or 1), height = math.max(1, rect_.height or 1) })
        placement:set({ anchor = opts.anchor or "top", gravity = opts.gravity or "top" })
        title:set(opts.title or false)
        items:set(#list + math.random()) -- a fresh value so the note rebuilds for every open
        open:set(true)
    end

    menu.is_open = open

    menu.surfaces = {
        popup {
            id = o.id,
            parent = o.parent,
            visible = open,
            anchor_rect = anchor,
            anchor = placement:map(function(p) return p.anchor end),
            gravity = placement:map(function(p) return p.gravity end),
            constraint_adjustment = { "flip_y", "flip_x", "slide_x", "slide_y" },
            on_escape = menu.close,
            on_dismiss = menu.close,
            child = computed({ items, title }, function(_, t)
                return rect { padding = PAD, children = { note(o.id, live, pick, t or nil) } }
            end),
        },
        popup {
            id = o.id .. "-sub",
            parent = o.id,
            visible = sub_open,
            anchor_rect = sub_anchor,
            anchor = "right",
            gravity = "bottom_right",
            constraint_adjustment = { "flip_x", "slide_y" },
            on_dismiss = function() sub_open:set(false) end,
            child = sub_items:map(function()
                return rect { padding = PAD, children = { note(o.id .. "-sub", live_sub, pick) } }
            end),
        },
    }

    return menu
end

return M
