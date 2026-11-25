-- Displays page, read only: Mantle can't write output settings (gap 18). Screens are drawn as paper
-- rectangles arranged by position; each row offers the Hyprland `hl.monitor` line that would set it.
local k = require("lib.paper")
local rows = require("modules.settings.rows")
local nightlight_page = require("modules.nightlight.page")

local MAP_W, MAP_H = rows.WIDTH - 20, rows.PITCH * 6 - 16

local function mode_of(s)
    local scale = s.fractional_scale or s.scale or 1
    return string.format("%dx%d", math.floor(s.width * scale + 0.5), math.floor(s.height * scale + 0.5))
end

local function hz(s)
    return s.refresh > 0 and string.format("%.0f", s.refresh) or nil
end

-- Field names checked against Hyprland's own `HL.MonitorSpec` stub (/usr/share/hypr/stubs).
local function monitor_line(s)
    return string.format('hl.monitor { output = "%s", mode = "%s%s", position = "%dx%d", scale = %s }',
        s.name, mode_of(s), hz(s) and ("@" .. hz(s)) or "", s.x, s.y, string.format("%g", s.fractional_scale or s.scale))
end

-- Every screen scaled into one box; a screen is a sheet of card stock with its name pencilled on.
local function arrangement(screens)
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, s in ipairs(screens) do
        x0, y0 = math.min(x0, s.x), math.min(y0, s.y)
        x1, y1 = math.max(x1, s.x + s.width), math.max(y1, s.y + s.height)
    end
    local f = math.min((MAP_W - 40) / (x1 - x0), (MAP_H - 30) / (y1 - y0))
    local ox = (MAP_W - (x1 - x0) * f) / 2
    local oy = (MAP_H - (y1 - y0) * f) / 2
    local sheets = {}
    for i, s in ipairs(screens) do
        local w, h = math.floor(s.width * f), math.floor(s.height * f)
        sheets[i] = rect {
            padding = { left = math.floor(ox + (s.x - x0) * f), top = math.floor(oy + (s.y - y0) * f) },
            children = {
                rect {
                    rotate = (i % 2 == 0) and 0.8 or -0.6,
                    children = {
                        k.sheet {
                            width = w,
                            height = h,
                            seed = 300 + i,
                            depth = 3,
                            color = i % 2 == 1 and "#C5D7EE" or k.CARD,
                            shadows = k.SHADOW.rest,
                            child = column {
                                align_h = "center",
                                align_v = "center",
                                spacing = 0,
                                children = {
                                    k.hand(s.name, 34, { font_weight = 700, foreground = k.DEEP_BLUE, align_h = "center" }),
                                    k.body(s.width .. " × " .. s.height, 18, { foreground = k.INK, align_h = "center" }),
                                },
                            },
                        },
                        k.tape { width = 74, height = 22, rotate = i % 2 == 0 and -3 or 2.5, seed = 40 + i },
                    },
                },
            },
        }
    end
    return rect { width = MAP_W, height = MAP_H, padding = { top = 8 }, children = sheets }
end

local function details(s)
    local scale = s.fractional_scale or s.scale
    local parts = { s.width .. " × " .. s.height }
    if hz(s) then parts[#parts + 1] = hz(s) .. " Hz" end
    parts[#parts + 1] = "scale " .. string.format("%g", scale)
    parts[#parts + 1] = "at " .. s.x .. ", " .. s.y
    if s.orientation ~= "normal" then parts[#parts + 1] = "turned " .. s.orientation end
    return table.concat(parts, "  ·  ")
end

return {
    key = "displays",
    title = "Displays",
    build = function()
        return {
            rows.heading("Arrangement"),
            rect {
                width = "fill",
                height = MAP_H + 16,
                children = mantle.screens:map(function(screens)
                    if #screens == 0 then return { rows.note("No screens reported yet.") } end
                    return { arrangement(screens) }
                end),
            },
            column {
                width = "fill",
                children = mantle.screens:map(function(screens)
                    local list = {}
                    for _, s in ipairs(screens) do
                        list[#list + 1] = rows.heading(s.name, {
                            rows.caption(s.model ~= "" and s.model or (s.description or "")),
                        })
                        list[#list + 1] = rows.line({ rows.label(details(s)) })
                        list[#list + 1] = rect {
                            width = "fill",
                            height = rows.PITCH * 2,
                            children = {
                                k.body(monitor_line(s), 16, {
                                    font = "monospace", foreground = k.DEEP_BLUE, width = "fill", wrap = "word",
                                    line_height = rows.PITCH / 16, padding = { top = 2 },
                                }),
                            },
                        }
                    end
                    return list
                end),
            },
            rows.note("Mantle can only read display settings. To change one, put its hl.monitor line "
                .. "in Hyprland's config and reload Hyprland.", 2),
            nightlight_page(),
        }
    end,
}
