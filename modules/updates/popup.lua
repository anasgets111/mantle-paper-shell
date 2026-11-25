-- The updates popup: a ledger page hung above the taskbar widget. One body per `S.view`:
-- `list` (pending packages grouped by repository, or all caught up), `running` (current package,
-- a pencil progress bar, the log) and `result` (success or failure, restart when one is due).
local theme = require("theme")
local k = require("lib.paper")
local c = require("components.controls")
local icons = require("components.icons")
local tooltip = require("components.tooltip")
local util = require("lib.util")
local rows = require("modules.settings.rows")
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

local W = theme.updates.width
-- Page content width: the sheet less its padding.
local INNER = W - theme.updates.sheet_inset
local MS = 160

local INK, INK_SOFT, BLUE = theme.INK, theme.INK_SOFT, theme.BLUE
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
        r = { x = (screen and screen.width or 1920) - theme.updates.anchor_inset, y = theme.spacing.md, width = theme.updates.anchor_w, height = theme.control.md }
    end
    M.open(r, false)
end)

-- Pieces ----------------------------------------------------------------------------------------

local function caption(content, props)
    local t = { foreground = INK_SOFT }
    for key, v in pairs(props or {}) do t[key] = v end
    return body(content, theme.font.xs, t)
end

local function button(id, label, kind, on_click)
    return c.button { id = "updates." .. id, label = label, kind = kind, height = theme.control.md, size = theme.font.compact_hand, on_click = on_click }
end

-- A faint blue ledger rule under a row.
local function rule()
    return rect { width = "fill", height = 1, background = theme.UPDATE_RULE }
end

-- The page's red margin, down the left edge of the content.
local margin = rect {
    width = 1.4, height = "fill", translate = { x = theme.spacing.wide }, background = theme.RULE_RED,
}

-- Text inside the page's red margin, as the package rows are.
local INDENT = theme.updates.indent
-- A sticky note's text width: the page's content less its margin and the note's own padding.
local NOTE_W = INNER - INDENT - theme.updates.note_inset

-- Warnings and prompts on a sticky note (dog-eared, taped), stuck inside the margin.
local function note(child, seed)
    return rect { padding = { left = INDENT - theme.spacing.xxs }, children = { rows.sticky(child, seed) } }
end

local function warning_note()
    local text = S.look:map(function(l) return l.warning end)
    return rect {
        width = "fill",
        visible = text:map(function(t) return t ~= "" end),
        children = {
            note(row {
                spacing = theme.spacing.snug,
                width = NOTE_W,
                children = {
                    G.exclamation(theme.icon.md),
                    body(text, theme.font.caption, { width = "fill", wrap = "word", align_v = "center" }),
                },
            }, 71),
        },
    }
end

-- The header: the state's glyph, the title in Caveat, the detail in pencil.
local function face(look)
    if look.glyph == "failed" then return G.exclamation(theme.icon.task) end
    if look.glyph == "done" then return icons.doodle("check", theme.icon.task, BLUE) end
    if look.glyph == "restart" then return icons.doodle("restart", theme.icon.task, theme.RED) end
    if look.glyph == "warning" then return G.exclamation(theme.icon.task) end
    return G.package(theme.icon.xl)
end

local header = row {
    width = "fill",
    spacing = theme.spacing.inset,
    padding = { left = INDENT },
    children = {
        rect {
            width = theme.updates.header_icon_w, height = theme.control.md,
            children = S.look:map(function(l) return { util.with(face(l), "align_h", "center") } end),
        },
        column {
            width = "fill",
            align_v = "center",
            children = {
                hand(S.look:map(function(l) return l.title end), theme.font.display, {
                    font_weight = theme.BOLD, elide = "end", width = "fill",
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
        M.tips.wrap(body(p.name or "?", theme.font.sm, { width = "fill", elide = "end", elided = cut, align_v = "center" }), slot,
            function() return cut:get() and p.name or "" end),
        body(p.old_version or "", theme.font.version, {
            foreground = INK_SOFT, max_width = theme.updates.version_w, elide = "middle", align_v = "center",
        }),
        rect { align_v = "center", children = { G.arrow() } },
        body(p.new_version or "", theme.font.version, { max_width = theme.updates.version_w, elide = "middle", align_v = "center" }),
        caption(size > 0 and util.bytes(size) or "cached", { min_width = theme.updates.size_w, text_align = "end", align_v = "center" }),
    }
    -- Its new version only runs after a restart.
    if reboot then table.insert(cells, 2, icons.doodle("restart", theme.icon.inline_marker, theme.RED)) end
    return column {
        width = "fill",
        children = {
            row {
                width = "fill",
                height = theme.control.chip,
                spacing = theme.spacing.sm,
                padding = { left = INDENT, right = theme.spacing.xxs },
                children = cells,
            },
            rule(),
        },
    }
end

local function group_head(g)
    return row {
        width = "fill",
        height = theme.control.md,
        spacing = theme.spacing.md,
        padding = { left = INDENT, top = theme.spacing.xs },
        children = {
            hand(g.repo, theme.font.heading, { font_weight = theme.BOLD, foreground = BLUE, align_v = "end" }),
            caption(model.plural(#g.packages, "package") .. (g.size > 0 and (" · " .. util.bytes(g.size)) or ""), {
                align_v = "end", padding = { bottom = theme.spacing.compact },
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

-- Row heights as built below: a group head 40, a package row 30 plus its 1 px rule.
local HEAD_H, ROW_H, LIST_MAX, FADE = theme.updates.head_h, theme.updates.row_h, theme.updates.list_max, theme.updates.fade
local OPAQUE = { gradient = "linear", stops = { { 0, "#000000FF" }, { 1, "#000000FF" } } }

-- Rows cut by the viewport fade out, on an edge only while more of the list lies past it.
local list_fade = computed({ items, LIST_SCROLL }, function(list, offset)
    local content = 0
    for _, item in ipairs(list) do content = content + (item.head and HEAD_H or ROW_H) end
    local view = math.min(LIST_MAX, content)
    offset = offset or 0
    -- ponytail: the engine exposes no content height, so `content` is summed from the row heights and
    -- ran 2.4 px over the real one at 150 rows; half a row of slack holds to ~900 rows. Upgrade: read
    -- the viewport's extent once the engine reports it.
    local top, bottom = offset > 0.5, offset < content - view - ROW_H / 2
    if view <= 0 or not (top or bottom) then return OPAQUE end
    local f = FADE / view
    return { gradient = "linear", stops = {
        { 0, top and "#00000000" or "#000000FF" }, { f, "#000000FF" },
        { 1 - f, "#000000FF" }, { 1, bottom and "#00000000" or "#000000FF" },
    } }
end, OPAQUE)

local package_list = list {
    width = "fill",
    max_height = LIST_MAX,
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
    spacing = theme.spacing.xs,
    padding = { top = theme.spacing.snug, bottom = theme.spacing.snug },
    visible = has_packages:map(function(on) return not on end),
    children = {
        hand(S.checking:map(function(on) return on and "Looking for updates…" or "All caught up" end), theme.font.xxl, {
            align_h = "center", foreground = INK_SOFT,
        }),
        rect { align_h = "center", children = { k.squiggle(theme.updates.empty_rule_w, BLUE) } },
    },
}

local list_view = column {
    width = "fill",
    spacing = theme.spacing.inset,
    children = {
        warning_note(),
        caught_up,
        rect { width = "fill", visible = has_packages, mask = list_fade, children = { package_list } },
        caption(tools_line, {
            width = "fill", wrap = "word", padding = { left = INDENT },
            visible = tools_line:map(function(t) return t ~= "" end),
        }),
        row {
            width = "fill",
            spacing = theme.spacing.md,
            children = {
                caption(checked_line, {
                    width = "fill", wrap = "word", align_v = "center", padding = { left = INDENT },
                }),
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
local BAR_H = theme.updates.progress_h
local function progress_bar()
    local w = INNER - INDENT
    local line = {
        { op = "M", points = { theme.updates.progress_inset, BAR_H / 2 } },
        { op = "Q", points = { w / 2, BAR_H / 2 - 1.5, w - theme.updates.progress_inset, BAR_H / 2 + 1 } },
    }
    local indeterminate = S.progress:map(function(p) return p.count == "" end)
    return rect {
        width = w,
        height = BAR_H,
        clip = "box",
        children = {
            k.wobble_box(w, BAR_H, 19, theme.PROGRESS_INK),
            path {
                width = w,
                height = BAR_H,
                stroke = theme.PROGRESS_RED,
                stroke_width = theme.updates.progress_ink_w,
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
    if lowered:find("error", 1, true) or lowered:find("fail", 1, true) then return theme.DEEP_RED end
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
    padding = { left = INDENT },
    children = {
        rect {
            width = "fill",
            background = theme.LOG_PAPER,
            shadows = theme.SHADOW.log_inset,
            padding = { top = theme.spacing.xs, bottom = theme.spacing.xs, left = theme.spacing.snug, right = theme.spacing.snug },
            effect = k.paper_fx { rim = 0, grain = 0.1 },
            children = {
                list {
                    width = "fill",
                    height = theme.updates.log_h,
                    scroll = LOG_SCROLL,
                    items = S.log_lines,
                    each = function(line)
                        return column {
                            width = "fill",
                            children = {
                                text {
                                    content = line ~= "" and line or " ",
                                    font = theme.MONO,
                                    font_size = theme.font.mono_small,
                                    line_height = 18 / 13,
                                    foreground = log_colour(line),
                                    width = "fill",
                                    wrap = "word",
                                    max_lines = 3,
                                },
                                rect { width = "fill", height = 1, background = theme.RULE_BLUE },
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
        padding = { left = INDENT },
        children = log_open:map(function(open)
            return { c.link {
                id = "updates.log", label = open and "hide the log" or "show the log", size = theme.font.xl,
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
    spacing = theme.spacing.lg,
    children = {
        rect { padding = { left = INDENT }, children = { progress_bar() } },
        row {
            width = "fill",
            padding = { left = INDENT },
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
            spacing = theme.spacing.sm,
            width = NOTE_W,
            children = {
                row {
                    width = "fill",
                    spacing = theme.spacing.inset,
                    children = {
                        icons.doodle("restart", theme.icon.badge, theme.RED),
                        column {
                            width = "fill",
                            children = {
                                hand("Restart to finish updating", theme.font.heading, { font_weight = theme.BOLD }),
                                body(left:map(function(n)
                                    return n > 0 and string.format("Click again within %d s to restart now.", n)
                                        or "The new kernel or system libraries load on the next boot."
                                end), theme.font.xs, {
                                    foreground = left:map(function(n) return n > 0 and theme.DEEP_RED or INK_SOFT end),
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
            spacing = theme.spacing.snug,
            width = NOTE_W,
            children = {
                G.exclamation(theme.icon.md),
                column {
                    width = "fill",
                    spacing = theme.spacing.xxs,
                    children = {
                        body("The package manager said:", theme.font.xs, { foreground = INK_SOFT }),
                        text {
                            content = error_lines:map(function(l) return table.concat(l, "\n") end),
                            font = theme.MONO, font_size = theme.font.mono, foreground = theme.DEEP_RED,
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
    spacing = theme.spacing.inset,
    children = {
        failure_note,
        column {
            width = "fill",
            padding = { left = INDENT },
            visible = failures:map(function(f) return #f > 0 end),
            children = failures:map(function(list)
                local rows = {}
                for i, f in ipairs(list) do
                    rows[i] = column {
                        width = "fill",
                        children = {
                            row {
                                width = "fill",
                                spacing = theme.spacing.snug,
                                padding = { top = theme.spacing.xxs, bottom = theme.spacing.xxs },
                                children = {
                                    G.exclamation(theme.icon.sm),
                                    body(f.name, theme.font.sm),
                                    caption(f.reason, { width = "fill", wrap = "word", padding = { top = theme.spacing.hairline } }),
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
            spacing = theme.spacing.md,
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
    -- 34 on top clears the tape across the sheet's edge.
    padding = { top = theme.spacing.binding, left = theme.spacing.page, right = theme.spacing.binding, bottom = theme.spacing.tab },
    child = rect {
        width = "fill",
        children = {
            margin,
            column {
                width = "fill",
                spacing = theme.spacing.lg,
                children = {
                    header,
                    rect { padding = { left = INDENT }, children = { c.divider(INNER - INDENT, false, 11) } },
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
    offset = { y = theme.spacing.snug },
    constraint_adjustment = { "slide_x", "flip_y" },
    grab = grab,
    on_escape = close,
    on_dismiss = function()
        dismissed_at = mantle.clock:now()
        close()
    end,
    child = rect {
        padding = { top = theme.spacing.roomy, left = theme.spacing.roomy, right = theme.spacing.tab, bottom = theme.spacing.panel },
        opacity = util.choose(S.open, 1, 0),
        translate = S.open:map(function(o) return { y = o and 0 or theme.spacing.snug } end),
        animate = {
            opacity = { duration = MS, easing = "out_cubic", from = 0 },
            translate = { duration = MS, easing = "out_cubic", from = { y = theme.spacing.snug } },
        },
        children = {
            page,
            k.tape { width = theme.updates.tape_w, height = theme.control.knob, translate = { y = 2 }, rotate = -2.5, seed = 41, color = theme.UPDATE_TAPE },
        },
    },
}

return M
