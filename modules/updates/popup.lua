-- The updates popup: a ledger page hung above the taskbar widget. One body per `service.view`:
-- `list` (pending packages grouped by repository, or all caught up), `running` (current package,
-- a pencil progress bar, the log) and `result` (success or failure, restart when one is due).
local k = require("lib.paper")
local c = require("components.controls")
local icons = require("components.icons")
local tooltip = require("components.tooltip")
local util = require("lib.util")
local ui_state = require("lib.ui_state")
local S = require("modules.updates.service")
local model = require("modules.updates.model")
local G = require("modules.updates.glyphs")
local sheet = require("modules.updates.sheet")

local M = {}

-- The surface the widget sits on. ponytail: one static parent, so a widget on a second taskbar
-- output opens the popup on the instance clicked only when the click arms a grab (BUILD.md).
M.PARENT = "paper-taskbar"
M.ID = "paper-updates"

local W = 600
-- Page content width: the sheet less its padding.
local INNER = W - 64
local MS = 160

local INK, INK_SOFT, BLUE = k.INK, k.INK_SOFT, k.BLUE
local hand, body = k.hand, k.body

M.tips = tooltip.new { id = "paper-updates-tip", parent = M.ID, side = "top" }

local anchor = state("updates.anchor", { x = 0, y = 0, width = 1, height = 1 })
-- A click opens it with a grab, so an outside click closes it; `mantle call updates.toggle` has none.
local grab = state("updates.grab", true)
local log_open = state("updates.log_open", false)
local restart_deadline = state("updates.restart_deadline", 0)
local LOG_SCROLL = scroll("updates.log")
local LIST_SCROLL = scroll("updates.list")

-- A click on the widget while open dismisses the grab first; if that same click then reaches
-- `open`, it must close rather than reopen.
local dismissed_at = -1

local function close() S.open:set(false) end

-- A modal opening (start menu, settings) takes the screen.
ui_state.active_modal:on_change(function(kind)
    if kind ~= "" and S.open:get() then close() end
end)

function M.open(r, with_grab)
    if S.open:get() or mantle.clock:now() - dismissed_at < 0.3 then
        close()
        return
    end
    r = r or {}
    -- One surface at a time: a modal left open would sit under the page holding the keyboard.
    ui_state.active_modal:set("")
    anchor:set({ x = r.x or 0, y = r.y or 0, width = math.max(1, r.width or 1), height = math.max(1, r.height or 1) })
    grab:set(with_grab ~= false)
    log_open:set(false)
    restart_deadline:set(0)
    LIST_SCROLL:scroll_to(0)
    S.open:set(true)
end

-- For a keybind: anchors where the widget was last clicked, or the right end of the first output.
action("updates.toggle", function()
    local r = anchor:get()
    if r.x == 0 then
        local screen = mantle.screens:get()[1]
        r = { x = (screen and screen.width or 1920) - 420, y = 12, width = 40, height = 40 }
    end
    M.open(r, false)
end)

-- Pieces ----------------------------------------------------------------------------------------

local function caption(content, props)
    local t = { foreground = INK_SOFT }
    for key, v in pairs(props or {}) do t[key] = v end
    return body(content, 16, t)
end

local function button(id, label, kind, on_click)
    return c.button { id = "updates." .. id, label = label, kind = kind, height = 40, size = 23, on_click = on_click }
end

-- A faint blue ledger rule under a row.
local function rule()
    return rect { width = "fill", height = 1, background = "#7FA3D055" }
end

-- The page's red margin, down the left edge of the content.
local margin = rect {
    width = 1.4, height = "fill", translate = { x = 22 }, background = "#D9534F60",
}

-- A sticky note that fits its text, for warnings and the restart prompt.
local function note(child, seed)
    return rect {
        rotate = -1,
        padding = { top = 8, bottom = 4 },
        children = {
            rect {
                children = {
                    rect {
                        width = "fill",
                        height = "fill",
                        shape = sheet.torn_fit(seed, 1.5),
                        background = k.STICKY,
                        shadows = { { blur = 8, offset = { x = 2, y = 4 }, color = "#00000050" } },
                        effect = k.paper_fx { rim = 0, grain = 0.18 },
                    },
                    rect { padding = { top = 12, left = 16, right = 18, bottom = 12 }, children = { child } },
                },
            },
            k.tape { width = 54, height = 18, translate = { y = -6 }, rotate = 3, seed = seed },
        },
    }
end

local function warning_note()
    local text = S.look:map(function(l) return l.warning end)
    return rect {
        width = "fill",
        visible = text:map(function(t) return t ~= "" end),
        children = {
            note(row {
                spacing = 10,
                width = INNER - 40,
                children = {
                    G.exclamation(20),
                    body(text, 17, { width = "fill", wrap = "word", align_v = "center" }),
                },
            }, 71),
        },
    }
end

-- The header: the state's glyph, the title in Caveat, the detail in pencil.
local function face(look)
    if look.glyph == "failed" then return G.exclamation(30) end
    if look.glyph == "done" then return icons.doodle("check", 30, BLUE) end
    if look.glyph == "restart" then return icons.doodle("restart", 30, k.RED) end
    if look.glyph == "warning" then return G.exclamation(30) end
    return G.package(32)
end

local header = row {
    width = "fill",
    spacing = 14,
    children = {
        rect {
            width = 36, height = 40,
            children = S.look:map(function(l) return { util.with(face(l), "align_h", "center") } end),
        },
        column {
            width = "fill",
            align_v = "center",
            children = {
                hand(S.look:map(function(l) return l.title end), 34, {
                    font_weight = 700, elide = "end", width = "fill",
                }),
                caption(S.look:map(function(l) return l.detail end), {
                    visible = S.look:map(function(l) return l.detail ~= "" end), elide = "end", width = "fill",
                }),
            },
        },
    },
}

-- The list -------------------------------------------------------------------------------------

local function package_row(p)
    local reboot = model.needs_reboot(p.name or "")
    local size = p.download_size or 0
    local slot = "updates.name." .. (p.repository or "") .. "/" .. (p.name or "?")
    local cut = elided(slot)
    local cells = {
        M.tips.wrap(body(p.name or "?", 18, { width = "fill", elide = "end", elided = cut, align_v = "center" }), slot,
            function() return cut:get() and p.name or "" end),
        body(p.old_version or "", 15, {
            foreground = INK_SOFT, max_width = 150, elide = "middle", align_v = "center",
        }),
        rect { align_v = "center", children = { G.arrow() } },
        body(p.new_version or "", 15, { max_width = 150, elide = "middle", align_v = "center" }),
        caption(size > 0 and util.bytes(size) or "cached", { min_width = 64, text_align = "end", align_v = "center" }),
    }
    -- Its new version only runs after a restart.
    if reboot then table.insert(cells, 2, icons.doodle("restart", 15, k.RED)) end
    return column {
        width = "fill",
        children = {
            row {
                width = "fill",
                height = 30,
                spacing = 8,
                padding = { left = 34, right = 4 },
                children = cells,
            },
            rule(),
        },
    }
end

local function group_head(g)
    return row {
        width = "fill",
        height = 40,
        spacing = 12,
        padding = { left = 34, top = 6 },
        children = {
            hand(g.repo, 26, { font_weight = 700, foreground = BLUE, align_v = "end" }),
            caption(model.plural(#g.packages, "package") .. (g.size > 0 and (" · " .. util.bytes(g.size)) or ""), {
                align_v = "end", padding = { bottom = 5 },
            }),
        },
    }
end

local items = S.groups:map(function(groups)
    local out = {}
    for _, g in ipairs(groups) do
        out[#out + 1] = { key = "repo:" .. g.repo, head = g }
        for _, p in ipairs(g.packages) do out[#out + 1] = { key = g.repo .. "/" .. (p.name or "?"), package = p } end
    end
    return out
end)

local has_packages = S.count:map(function(n) return n > 0 end)

local tools_line = computed({ S.tools_runnable, has_packages }, function(names, pending)
    if #names == 0 then return "" end
    return (pending and "Then " or "Update tools runs ") .. model.plural(#names, "developer tool") .. ": "
        .. table.concat(names, ", ") .. "."
end, "")

local package_list = list {
    width = "fill",
    max_height = 430,
    scroll = LIST_SCROLL,
    items = items,
    key = function(item) return item.key end,
    each = function(item)
        if item.head then return group_head(item.head) end
        return package_row(item.package)
    end,
}

-- The header already says when an empty list was checked.
local checked_line = computed({ S.updates, S.minute }, function(u, minute)
    local parts = {}
    if u and u.last_successful_check and #u.packages > 0 then
        parts[#parts + 1] = "checked " .. model.ago(u.last_successful_check, minute * 60)
    end
    if u and u.aur_helper and S.saved.aur:get() then parts[#parts + 1] = "AUR through " .. u.aur_helper end
    return table.concat(parts, " · ")
end, "")

local caught_up = column {
    width = "fill",
    spacing = 6,
    padding = { top = 10, bottom = 10 },
    visible = has_packages:map(function(on) return not on end),
    children = {
        hand(S.checking:map(function(on) return on and "Looking for updates…" or "All caught up" end), 30, {
            align_h = "center", foreground = INK_SOFT,
        }),
        rect { align_h = "center", children = { k.squiggle(120, BLUE) } },
    },
}

local list_view = column {
    width = "fill",
    spacing = 14,
    children = {
        warning_note(),
        caught_up,
        rect { width = "fill", visible = has_packages, children = { package_list } },
        caption(tools_line, {
            width = "fill", wrap = "word", padding = { left = 34 },
            visible = tools_line:map(function(t) return t ~= "" end),
        }),
        row {
            width = "fill",
            spacing = 12,
            children = {
                caption(checked_line, { width = "fill", wrap = "word", align_v = "center" }),
                rect {
                    children = S.checking:map(function(on)
                        return { button("check", on and "Checking…" or "Check now", "plain", S.check) }
                    end),
                },
                rect {
                    visible = computed({ has_packages, S.tools_runnable }, function(p, t) return p or #t > 0 end),
                    children = has_packages:map(function(p)
                        if p then return { button("install", "Update all", "primary", S.install) } end
                        return { button("tools", "Update tools", "primary", S.update_tools) }
                    end),
                },
            },
        },
    },
}

-- Running ---------------------------------------------------------------------------------------

-- A pencil-drawn bar with a red marker stroke over the finished share; a sliding stroke while
-- pacman has reported no steps.
local BAR_H = 22
local function progress_bar()
    local w = INNER - 34
    local line = {
        { op = "M", points = { 6, BAR_H / 2 } },
        { op = "Q", points = { w / 2, BAR_H / 2 - 1.5, w - 6, BAR_H / 2 + 1 } },
    }
    local indeterminate = S.progress:map(function(p) return p.count == "" end)
    return rect {
        width = w,
        height = BAR_H,
        clip = "box",
        children = {
            k.wobble_box(w, BAR_H, 19, "#3A3631A0"),
            path {
                width = w,
                height = BAR_H,
                stroke = "#D9534FCC",
                stroke_width = 9,
                stroke_cap = "round",
                blend = "multiply",
                commands = line,
                trim_end = computed({ S.progress, indeterminate }, function(p, on)
                    if on then return 0.22 end
                    return p.total > 0 and math.max(0.02, p.done / p.total) or 0.02
                end, 0),
                translate = { x = 0 },
                animate = indeterminate:map(function(on)
                    if not on then return { trim_end = { duration = 400, easing = "out_cubic" } } end
                    return { translate = {
                        duration = 1600, easing = "linear", loops = "infinite",
                        keyframes = { { x = -0.25 * w }, { x = w } },
                    } }
                end),
            },
        },
    }
end

-- Failures and warnings stand out in two hundred lines of pacman output.
local function log_colour(line)
    local lowered = line:lower()
    if lowered:find("error", 1, true) or lowered:find("fail", 1, true) then return k.DEEP_RED end
    if line:find("^▶") or line:find("^::") or line:find("^%[ OK %]") then return INK end
    return INK_SOFT
end

-- ponytail: the log follows its newest line even after a scroll back; the user's shell hit the same
-- limit (no "wheel moved this viewport" signal).
S.log_lines:on_change(function(lines)
    if #lines > 0 and log_open:get() then LOG_SCROLL:reveal(#lines) end
end)

-- Typewriter lines on ruled paper; each line carries its own rule, so the rules scroll with it.
local log_card = rect {
    width = "fill",
    visible = log_open,
    padding = { left = 30 },
    children = {
        rect {
            width = "fill",
            background = "#F8F2E4",
            shadows = { { inset = true, blur = 4, offset = { y = 1 }, color = "#00000030" } },
            padding = { top = 6, bottom = 6, left = 10, right = 10 },
            effect = k.paper_fx { rim = 0, grain = 0.1 },
            children = {
                list {
                    width = "fill",
                    height = 220,
                    scroll = LOG_SCROLL,
                    items = S.log_lines,
                    each = function(line)
                        return column {
                            width = "fill",
                            children = {
                                text {
                                    content = line ~= "" and line or " ",
                                    font = "Nimbus Mono PS",
                                    font_size = 13,
                                    line_height = 18 / 13,
                                    foreground = log_colour(line),
                                    width = "fill",
                                    wrap = "word",
                                    max_lines = 3,
                                },
                                rect { width = "fill", height = 1, background = "#7FA3D040" },
                            },
                        }
                    end,
                },
                caption("No output yet", {
                    align_h = "center", align_v = "center",
                    visible = S.log_lines:map(function(l) return #l == 0 end),
                }),
            },
        },
    },
}

local function log_toggle()
    return rect {
        padding = { left = 30 },
        children = log_open:map(function(open)
            return { c.link {
                id = "updates.log", label = open and "hide the log" or "show the log", size = 24,
                on_click = function()
                    log_open:set(not log_open:get())
                    local n = #S.log_lines:get()
                    if not open and n > 0 then timer(50, function() LOG_SCROLL:reveal(n) end) end
                end,
            } }
        end),
    }
end

local running_view = column {
    width = "fill",
    spacing = 16,
    children = {
        rect { padding = { left = 34 }, children = { progress_bar() } },
        row {
            width = "fill",
            padding = { left = 34 },
            children = {
                caption(S.progress:map(function(p)
                    if p.count == "" or p.total == 0 then return "preparing…" end
                    return string.format("%d%% done", math.floor(100 * p.done / p.total + 0.5))
                end), { width = "fill" }),
                caption(computed({ S.run, mantle.clock }, function(r)
                    return r.started_at and ("running for " .. model.duration(os.time() - r.started_at)) or ""
                end, "")),
            },
        },
        log_toggle(),
        log_card,
    },
}

-- Result ----------------------------------------------------------------------------------------

local outcome = S.run:map(model.outcome)

-- Restart asks twice: the first click arms a 10 s countdown in red marker, the second restarts.
local COUNTDOWN = 10
local left = computed({ mantle.clock, restart_deadline }, function(_, at)
    return math.max(0, math.ceil(at - mantle.clock:now()))
end, 0)

local function restart_button(n)
    return button("restart", n > 0 and ("Yes, restart · " .. n) or "Restart now", "danger", function()
        if left:get() > 0 then
            restart_deadline:set(0)
            S.restart()
        else
            restart_deadline:set(mantle.clock:now() + COUNTDOWN)
        end
    end)
end

-- The button sits under the text, so its armed label can grow without crowding the title.
local restart_note = rect {
    width = "fill",
    visible = S.reboot,
    children = {
        note(column {
            spacing = 8,
            width = INNER - 40,
            children = {
                row {
                    width = "fill",
                    spacing = 14,
                    children = {
                        icons.doodle("restart", 26, k.RED),
                        column {
                            width = "fill",
                            children = {
                                hand("Restart to finish updating", 26, { font_weight = 700 }),
                                body(left:map(function(n)
                                    return n > 0 and string.format("Click again within %d s to restart now.", n)
                                        or "The new kernel or system libraries load on the next boot."
                                end), 16, {
                                    foreground = left:map(function(n) return n > 0 and k.DEEP_RED or INK_SOFT end),
                                    width = "fill", wrap = "word",
                                }),
                            },
                        },
                    },
                },
                rect { align_h = "end", children = left:map(function(n) return { restart_button(n) } end) },
            },
        }, 93),
    },
}

local failures = S.run:map(function(r) return r.failures or {} end)

-- The header gives the reason in plain words; the note quotes the package manager's own errors.
local error_lines = computed({ S.updates, outcome }, function(u, name)
    local found = {}
    if name ~= "failed" then return found end
    for _, line in ipairs(u and u.install_log or {}) do
        line = model.strip_ansi(line)
        if line:find("^error:") and #found < 4 then found[#found + 1] = line end
    end
    return found
end, {})

local failure_note = rect {
    width = "fill",
    visible = error_lines:map(function(l) return #l > 0 end),
    children = {
        note(row {
            spacing = 10,
            width = INNER - 40,
            children = {
                G.exclamation(20),
                column {
                    width = "fill",
                    spacing = 4,
                    children = {
                        body("The package manager said:", 16, { foreground = INK_SOFT }),
                        text {
                            content = error_lines:map(function(l) return table.concat(l, "\n") end),
                            font = "Nimbus Mono PS", font_size = 14, foreground = k.DEEP_RED,
                            width = "fill", wrap = "word",
                        },
                    },
                },
            },
        }, 57),
    },
}

local result_view = column {
    width = "fill",
    spacing = 14,
    children = {
        failure_note,
        column {
            width = "fill",
            padding = { left = 34 },
            visible = failures:map(function(f) return #f > 0 end),
            children = failures:map(function(list)
                local rows = {}
                for i, f in ipairs(list) do
                    rows[i] = column {
                        width = "fill",
                        children = {
                            row {
                                width = "fill",
                                spacing = 10,
                                padding = { top = 4, bottom = 4 },
                                children = {
                                    G.exclamation(16),
                                    body(f.name, 18),
                                    caption(f.reason, { width = "fill", wrap = "word", padding = { top = 2 } }),
                                },
                            },
                            rule(),
                        },
                    }
                end
                return rows
            end),
        },
        restart_note,
        log_toggle(),
        log_card,
        row {
            width = "fill",
            spacing = 12,
            children = {
                rect { width = "fill" },
                rect {
                    children = outcome:map(function(name)
                        if name == "failed" then
                            return { button("retry", "Try again", "primary", S.install) }
                        elseif name == "issues" then
                            return { button("retry-tools", "Retry failed tools", "primary", S.retry_tools) }
                        end
                        return {}
                    end),
                },
                button("dismiss", "Done", "plain", function()
                    S.dismiss()
                    close()
                end),
            },
        },
    },
}
local VIEWS = { list = list_view, running = running_view, result = result_view }

local page = sheet.sheet {
    width = W,
    seed = 517,
    padding = { top = 26, left = 30, right = 34, bottom = 26 },
    child = rect {
        width = "fill",
        children = {
            margin,
            column {
                width = "fill",
                spacing = 16,
                children = {
                    header,
                    rect { padding = { left = 34 }, children = { c.divider(INNER - 34, false, 11) } },
                    rect { width = "fill", children = S.view:map(function(v) return { VIEWS[v] } end) },
                },
            },
        },
    },
}

M.surface = popup {
    id = M.ID,
    parent = M.PARENT,
    visible = S.open,
    anchor_rect = anchor,
    anchor = "top",
    gravity = "top",
    offset = { y = 10 },
    constraint_adjustment = { "slide_x", "flip_y" },
    grab = grab,
    on_escape = close,
    on_dismiss = function()
        dismissed_at = mantle.clock:now()
        close()
    end,
    child = rect {
        padding = { top = 18, left = 18, right = 26, bottom = 28 },
        opacity = util.choose(S.open, 1, 0),
        translate = S.open:map(function(o) return { y = o and 0 or 10 } end),
        animate = {
            opacity = { duration = MS, easing = "out_cubic", from = 0 },
            translate = { duration = MS, easing = "out_cubic", from = { y = 10 } },
        },
        children = {
            page,
            k.tape { width = 110, height = 26, translate = { y = 4 }, rotate = -2.5, seed = 41, color = "#B4CBE6C0" },
        },
    },
}

return M
