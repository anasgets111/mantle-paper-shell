# Paper shell: shared brief for every builder

You are one of five builders working **at the same time** on one Mantle shell config in
`~/mantle-paper-shell`. The shell is running live on the user's Hyprland desktop (monitor DP-1,
3440x1440, scale 1) and reloads on every save. The user is using the desktop while you work.

## Read first

- `~/mantle-paper-shell/plan.html`: the plan (open it as text). Your feature's row is the spec.
- `~/mantle-paper-shell/DESIGN.md`: the paper design rules (materials, ink, type, motion). Follow them.
- `lib/paper.lua` (the kit: `sheet`, `card`, `torn`, `torn_top`, `torn_circle`, `tape`,
  `paper_fx`, `hand` (Caveat), `body` (Patrick Hand), `glyph`, `checkbox`, `squiggle`, `star`...),
  `components/controls.lua` (button, link, disc_button, toggle, radio_group, checkbox_row, slider,
  field, tabs, chip, sticky, pencil_loop, ruled, divider), `components/menu.lua` (sticky-note
  context menu on a popup, with submenus), `components/modal.lua` + `modules/modal_host.lua`,
  `lib/ui_state.lua` (`active_modal`, `toggle_modal`, `close_modal`, `on_modal_close`),
  `lib/apps.lua` (pins, launch, entry lookup), `lib/store.lua`, `lib/util.lua`,
  `lib/identity.lua` (user full name/host), `lib/compositor.lua` (logout/dpms on Hyprland).
- Mantle API: the stubs in `/mnt/Work/0Coding/1Rust/mantle/lua-meta/*.lua` are the exact truth
  for every node property, signal and capability. Docs: `/mnt/Work/0Coding/1Rust/mantle/docs/`
  (`guide/agents.md`, `guide/input.md`, `nodes/*.md`, `surfaces/*.md`, `capabilities/*.md`,
  `cookbook/*.md`). Never guess a property name; grep the stubs.
- The user's own shell, for LOGIC to reuse (not its look): `~/.config/mantle` (see the
  "Logic to reuse" column in the plan). Copy and adapt logic into this config; never edit
  `~/.config/mantle`.

## Rules

1. **Own your files.** Write only inside your module directory (named in your task). Shared files
   (`lib/*`, `components/*`, `shell.lua`, `modules/modal_host.lua`, `modules/desktop.lua`) may get
   a small additive change only with the Edit tool (never Write/rewrite them), and only when your
   module truly cannot work otherwise; say so in your report. A new shared helper you need goes in
   your own module first.
2. **Persistence:** keep your own `persistent_table` at `mantle.config_dir .. "/state-<module>.json"`
   rather than editing `lib/store.lua` (pins and app usage stay in `lib/store.lua` via `lib/apps.lua`).
3. **Names are global.** Prefix every `state`, `hover`, `focused`, `geometry`, `scroll`, `action`
   name and every surface/popup `id` with your module name (e.g. `taskbar.`, `paper-taskbar-...`).
4. **`require` inside a table constructor keeps two values.** Bind every `require` to a local first.
5. **Validate before you consider a change done:** `cd ~/mantle-paper-shell && ./run.sh check`
   (must say ok; fix shadow-cut warnings for your surfaces too), then save and watch
   `mantle log 2>&1 | tail -30` for errors from the live reload. A failed reload keeps the old
   scene, so an error you cause also blocks the other builders' changes: fix it at once.
   Another builder's error may show up there too; ignore errors in files you don't own.
6. **Look at it.** Take screenshots: `grim -o DP-1 /tmp/<module>-N.png`, then crop the region you
   care about with `magick in.png -crop WxH+X+Y +repage out.png` and view it with the Read tool.
   The bottom layer (desktop cards) is hidden behind the user's windows; top/overlay layers (taskbar,
   modals, notifications, OSD) draw above them, so they show. Iterate until it looks polished and
   consistent with the desk: torn paper, card stock, pencil, marker, highlighter, washi tape,
   sticky notes. No flat UI rectangles, no rounded material cards.
7. **Drive it without the user's mouse:** `mantle set <state> <json>`, `mantle toggle <state>`,
   `mantle call <action>`, `mantle input <surface-id> click X Y | move X Y | wheel X Y DY | key COMBO | type TEXT`.
   `mantle set` / `mantle toggle` with no args list the states. The modal host is
   `mantle set modal '"startmenu"'` / `'"settings"'` / `'""'`.
8. **Don't steal the user's desktop.** Close anything you opened (modals take the keyboard
   exclusively) right after each screenshot: `mantle set modal '""'`. Never lock the screen, log
   out, suspend, reboot or power off. Never launch apps except to test one launch, then close it.
   Never send real notifications in a loop (one or two `notify-send` tests are fine).
9. **Never stop or restart the running shell**, never run `mantle stop`, never edit Hyprland config.
10. Code style: Lua, 4-space indent, 120 columns, comments only for non-obvious decisions. Small
    files per concern inside your module directory. No dead code.
11. Report at the end: what you built (files), what works (verified by screenshot/log), what doesn't,
    engine gaps you hit (with stub/doc evidence), and any shared-file edits. Keep screenshots you
    want the coordinator to see under `~/mantle-paper-shell/shots/<module>-*.png`.

## Verified engine facts (from a source review)

- Mouse wheel: `on_wheel = function(rect, steps, modifiers)`.
- `capture { window = id, live = 4 }` needs an explicit `width`/`height`; Hyprland only; give a
  title/icon fallback.
- Popups: `parent` is the surface id; on a per-output panel a click opens it on the clicked
  instance. For a hover popup (no click), use `parent = "paper-taskbar@DP-1"` and `grab = false`.
- Tray: call `mantle.tray:menu_will_show(...)` before showing a dbusmenu, children can be lazy.
- Logout: `lib/compositor.lua` (`hyprctl dispatch 'hl.dsp.exit()'`). Reboot/poweroff/suspend:
  `process.detach("systemctl", {...})`. Hibernate is unavailable here (`CanHibernate=na`): hide it.
- Minimize does nothing on Hyprland; Mantle reports no minimized state.
- `WindowEntry` has no geometry; `fullscreen` is reported on Hyprland.
- `applications.entries` have no categories or desktop actions.
- No recent-files feed: parse `~/.local/share/recently-used.xbel` with `file.read` on open.
- Light/dark for apps: `gsettings set org.gnome.desktop.interface color-scheme prefer-dark|prefer-light`.
- Keyboard layout names: `hyprctl -j devices`. Display changes: write a Hyprland monitor fragment
  (settings builder only proposes this; never edit Hyprland config).
