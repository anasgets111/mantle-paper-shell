-- A context menu as a taped sticky note on an xdg_popup, with one level of submenus. Used by the
-- taskbar, the tray and the start menu, so every right-click on the desk looks the same.
--
--   local menu = require("components.menu").new { id = "taskbar-menu", parent = "paper-taskbar" }
--   surfaces: menu.surfaces (add both to the shell's list)
--   open:     menu.open(rect, items, { anchor = "top", gravity = "top" })
--   items:    { label, icon?, on_click?, checked? (true/false/nil), disabled?, separator?, children? }
--   opts.width: the note's width, 250 by default.
--
-- An item's on_click runs and the menu closes; an item with `children` opens the submenu instead.
-- Up and Down move the keyboard between rows; Down with no row focused starts at the ticked one.
local theme = require("theme")
local k = require("lib.paper")
local controls = require("components.controls")

local M = {}

local ROW_H, WIDTH = theme.menu.row_h, theme.menu.width
-- Room for the sticky note's shadow (blur 10, offset y 6) inside the popup.
local PAD = { top = theme.spacing.inset, left = theme.spacing.inset, right = theme.spacing.inset, bottom = theme.spacing.wide }

local function row_target(id, i) return focus_target(id .. ".row." .. i) end

-- The next row from `i` by `by` that takes focus, skipping separators and disabled rows.
local function neighbour(items, i, by)
    local j = i + by
    while items[j] and (items[j].separator or items[j].disabled) do j = j + by end
    return items[j] and j
end

local function item_row(id, i, item, on_pick, width, items)
    if item.separator then
        return rect { height = theme.menu.separator_h, width = "fill", padding = { left = theme.spacing.inset, right = theme.spacing.inset }, children = { controls.divider(width - theme.menu.divider_trim) } }
    end
    local hovered = hover(id .. ".row." .. i)
    local keyed = focus_visible(id .. ".row." .. i)
    local lit = computed({ hovered, keyed }, function(h, f) return h or f end)
    local ink = item.disabled and theme.INK_SOFT or theme.INK
    local lead
    if item.checked ~= nil then
        lead = k.checkbox(theme.icon.label, item.checked)
    elseif item.icon then
        lead = k.glyph(item.icon, theme.icon.label, ink)
    else
        lead = rect { width = theme.menu.lead_size, height = theme.menu.lead_size }
    end
    local children = {
        lead,
        k.body(item.label, theme.font.label, { foreground = ink, align_v = "center", elide = "end", width = "fill" }),
    }
    if item.children then children[#children + 1] = k.glyph("go-next-symbolic", theme.icon.xs, theme.INK_SOFT) end
    return rect {
        width = "fill",
        height = ROW_H,
        hover = hovered,
        focus_target = row_target(id, i),
        focus_visible = keyed,
        focus_ring = false,
        on_key = function(key)
            local by = ({ Up = -1, Down = 1 })[key.name]
            local to = by and neighbour(items, i, by)
            if to then row_target(id, to):request() end
            return by ~= nil
        end,
        accessible_name = item.label,
        cursor = item.disabled and "default" or "pointer",
        on_click = function(r)
            if not item.disabled then on_pick(item, r) end
        end,
        children = {
            -- A highlighter swipe under the hovered or keyboard-focused row.
            rect {
                width = "fill",
                height = ROW_H - theme.menu.highlight_trim_y,
                align_v = "center",
                background = theme.HIGHLIGHT,
                blend = "multiply",
                shape = k.tape_shape(width - theme.menu.highlight_trim_x, ROW_H - theme.menu.highlight_trim_y, i + 3),
                opacity = lit:map(function(v) return (v and not item.disabled) and 1 or 0 end),
                animate = { opacity = { duration = 100 } },
            },
            row { width = "fill", height = "fill", spacing = theme.spacing.snug, padding = { left = theme.spacing.inset, right = theme.spacing.inset }, children = children },
        },
    }
end

local function note(id, items, on_pick, title, width)
    width = width or WIDTH
    local rows = {}
    if title then
        rows[1] = k.hand(title, theme.font.xl, { font_weight = theme.BOLD, padding = { left = theme.spacing.inset, bottom = theme.spacing.hairline, right = theme.spacing.xxs }, elide = "end", max_width = width - theme.menu.title_trim })
    end
    for i, item in ipairs(items or {}) do rows[#rows + 1] = item_row(id, i, item, on_pick, width, items) end
    local h = 0
    for _, item in ipairs(items or {}) do h = h + (item.separator and theme.menu.separator_h or ROW_H) end
    h = h + theme.menu.body_extra + (title and theme.menu.title_h or 0)
    return controls.sticky {
        width = width,
        height = h,
        seed = #id + #(items or {}),
        rotate = -0.8,
        child = column { width = "fill", padding = { top = theme.spacing.inset, bottom = theme.spacing.snug }, children = rows },
    }
end

-- The popup root hears keys no row took: Up or Down before any row has focus starts at the ticked
-- row, else the first.
local function enter(id, items, key)
    if key.name ~= "Down" and key.name ~= "Up" then return false end
    local start
    for i, item in ipairs(items) do
        if item.checked and not start then start = i end
    end
    start = start or neighbour(items, 0, 1)
    if start then row_target(id, start):request() end
    return true
end

-- o = { id, parent }
function M.new(o)
    local open = state(o.id .. ".open", false)
    local anchor = state(o.id .. ".anchor", { x = 0, y = 0, width = 1, height = 1 })
    local placement = state(o.id .. ".placement", { anchor = "top", gravity = "top" })
    local items = state(o.id .. ".items", {})
    local title = state(o.id .. ".title", false)
    local width = state(o.id .. ".width", WIDTH)
    local sub_open = state(o.id .. ".sub.open", false)
    local sub_anchor = state(o.id .. ".sub.anchor", { x = 0, y = 0, width = 1, height = 1 })
    local sub_items = state(o.id .. ".sub.items", {})

    -- Callbacks don't survive a state round trip as data, so the live item tables are kept here.
    local live, live_sub = {}, {}

    local menu = {}

    local dismissed

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
        -- The press on the opener closed this menu before its click arrived: that click toggles it shut.
        if dismissed and dismissed.x == rect_.x and dismissed.y == rect_.y and mantle.clock:now() - dismissed.at < 0.3 then
            return
        end
        opts = opts or {}
        live = list
        sub_open:set(false)
        anchor:set({ x = rect_.x or 0, y = rect_.y or 0, width = math.max(1, rect_.width or 1), height = math.max(1, rect_.height or 1) })
        placement:set({ anchor = opts.anchor or "top", gravity = opts.gravity or "top" })
        title:set(opts.title or false)
        width:set(opts.width or WIDTH)
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
            on_dismiss = function()
                local r = anchor:get()
                dismissed = { at = mantle.clock:now(), x = r.x, y = r.y }
                menu.close()
            end,
            child = computed({ items, title, width }, function(_, t, w)
                return rect {
                    padding = PAD,
                    on_key = function(key) return enter(o.id, live, key) end,
                    children = { note(o.id, live, pick, t or nil, w) },
                }
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
                return rect {
                    padding = PAD,
                    on_key = function(key) return enter(o.id .. "-sub", live_sub, key) end,
                    children = { note(o.id .. "-sub", live_sub, pick) },
                }
            end),
        },
    }

    return menu
end

return M
