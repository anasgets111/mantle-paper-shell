# Paper shell: notes for agents

A hand-drawn notebook desktop shell for [Mantle](https://github.com/anasgets111/mantle). It runs
live on the user's desktop (niri or Hyprland) and reloads on every save, while they use it.

## Read first

- `DESIGN.md`: the paper design rules (materials, ink, type, motion). Follow them.
- `theme.lua`: every colour, font and size. Screens under 1000 px tall scale sizes by 0.8. Add a
  size here and read it from the module rather than writing a bare pixel number.
- `lib/paper.lua` (the kit: `sheet`, `card`, `torn`, `torn_top`, `torn_circle`, `tape`,
  `paper_fx`, `hand`, `body`, `glyph`, `checkbox`, `squiggle`, `star`...),
  `components/controls.lua` (button, link, disc_button, toggle, radio_group, checkbox_row, slider,
  field, tabs, chip, sticky, pencil_loop, ruled, divider), `components/menu.lua` (sticky-note
  context menu on a popup, with submenus), `components/modal.lua` + `modules/modal_host.lua`,
  `lib/ui_state.lua` (`active_modal`, `toggle_modal`, `close_modal`, `on_modal_close`),
  `lib/apps.lua` (pins, launch, entry lookup), `lib/store.lua`, `lib/util.lua`,
  `lib/identity.lua` (user full name/host), `lib/compositor.lua` (logout and DPMS per compositor).
- Mantle API: the engine's `lua-meta/*.lua` stubs are the exact truth for every node property,
  signal and capability; its `docs/` explain them. Never guess a property name; grep the stubs.

## Rules

1. **Persistence:** a module that saves state keeps its own `persistent_table` at
   `require("lib.paths").state("state-<module>.json")`, under `$XDG_STATE_HOME/paper-shell`.
   Pins and app usage stay in `lib/store.lua` via `lib/apps.lua`.
2. **Names are global.** Prefix every `state`, `hover`, `focused`, `geometry`, `scroll`, `action`
   name and every surface/popup `id` with the module name (e.g. `taskbar.`, `paper-taskbar-...`).
3. **`require` inside a table constructor keeps two values.** Bind every `require` to a local first.
4. **Validate before a change is done:** `./run.sh check` must say ok (fix shadow-cut warnings
   too), then save and watch `mantle log 2>&1 | tail -30` for errors from the live reload. A failed
   reload keeps the old scene, so fix an error at once.
5. **Look at it.** Screenshot with `grim -o <output> /tmp/shot.png`, crop with
   `magick in.png -crop WxH+X+Y +repage out.png`, and view the crop. The bottom layer (desk cards)
   hides behind windows; top and overlay layers show. Keep it consistent with the desk: torn paper,
   card stock, pencil, marker, highlighter, washi tape, sticky notes. No flat UI rectangles, no
   rounded material cards. For layout at other screen sizes, run a copy in a nested compositor.
6. **Drive it without the user's mouse:** `mantle set <state> <json>`, `mantle toggle <state>`,
   `mantle call <action>`, `mantle input <surface-id> click X Y | move X Y | wheel X Y DY | key COMBO | type TEXT`.
   `mantle set` / `mantle toggle` with no args list the states. The modal host is
   `mantle set modal '"startmenu"'` / `'"settings"'` / `'""'`. Popups with `grab = true` don't
   open from synthetic input; ask the user to test those by hand.
7. **Don't steal the user's desktop.** Close anything you opened right after each screenshot
   (`mantle set modal '""'`): modals take the keyboard. Never lock the screen, log out, suspend,
   reboot or power off. Launch apps only to test one launch, then close it. One or two
   `notify-send` tests are fine; never a loop.
8. **Never stop or restart the running shell** and never edit the compositor config.
9. **Code style:** Lua, 4-space indent, 120 columns, comments only for non-obvious decisions. One
   concern per file inside the module directory. No dead code.

## Engine facts

- Mouse wheel: `on_wheel = function(rect, steps, modifiers)`.
- `capture { window = id, live = 4 }` needs an explicit `width`/`height`; give a title/icon fallback.
- Popups: `parent` is the surface id; on a per-output panel a click opens it on the clicked
  instance. A hover popup (no click) uses `parent = "paper-taskbar@<output>"` and `grab = false`.
- Tray: call `mantle.tray:menu_will_show(...)` before showing a dbusmenu; children can be lazy.
- Reboot, poweroff, suspend: `process.detach("systemctl", {...})`. Hide hibernate when logind
  reports `CanHibernate=na`.
- `WindowEntry` has no geometry. `applications.entries` have no categories or desktop actions.
- No recent-files feed: parse `~/.local/share/recently-used.xbel` with `file.read` on open.
- Light/dark for apps: `gsettings set org.gnome.desktop.interface color-scheme prefer-dark|prefer-light`.
- A surface takes pointer input only where it has content or a handler; elsewhere clicks, hover and
  focus-follows-mouse pass through to the window below.

## Interaction checklist (every surface, every iteration)

The user judges polish by behaviour as much as looks. Walk this list with `mantle input` for
everything you change, and fix what fails:

- **Dismiss:** every popup, menu and modal closes on an outside click (popups opened by a click use
  `grab = true` + `on_dismiss`), on Escape (`on_escape`), and when its opener is clicked again
  (toggle, no reopen flicker). Opening one closes any other open one. `grab = false` only on hover
  popups (tooltips, previews).
- **Wheel:** wheel over a value changes it: the volume icon (default sink ±5 %, `set_volume`),
  brightness, every slider, the mic icon. Wheel over the taskbar task icons cycles that app's windows;
  over the desk chips it steps through the desks that hold windows. Lists scroll.
- **Middle / right click:** middle click on the volume icon toggles mute; on a task opens a new
  window. Right click opens a context menu wherever one makes sense (tasks, start-menu apps, tray,
  status icons → the matching settings page).
- **Keyboard:** modals and the start menu work by keyboard alone: typing goes to search, arrows move,
  Enter activates, Tab cycles, Escape closes. The focused control shows `pencil_loop`.
- **Feedback:** every clickable shows `cursor = "pointer"` and a hover change; a press shows a
  pressed state; toggles and sliders follow changes made elsewhere (`pactl`, `nmcli`, keyboard keys).
- **Edges:** empty states (no notifications, no Wi-Fi, no battery, no tray items, no results),
  long text (elide plus a tooltip with the full text), many items (scroll, never overflow the screen).
