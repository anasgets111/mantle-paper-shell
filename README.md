# Paper shell

A hand-drawn paper desktop shell for [Mantle](https://github.com/anasgets111/mantle) on Hyprland:
card stock, tape, torn edges, Caveat lettering and pencil doodles, laid out like GNOME with Dash to
Panel and ArcMenu. No blur and no translucency.

It covers a taskbar (pinned and running apps with previews, tray, workspaces, keyboard layout,
privacy and keep-awake stickers, updates), a start menu, quick settings, notifications with a
calendar, on-screen displays, a lock screen, a polkit prompt, a settings notebook, screen recording,
night light and a wallpaper picker.

## Run

Needs Mantle built from `main`: the shell draws with path features (`taper_start`, `stroke_dash`,
`fit = "tile"`, shape holes) newer than v0.15.0. It runs on Hyprland and niri; night light and the
Displays page's config lines are Hyprland-only and hide elsewhere.

    ./run.sh check                    # mantle check with the bundled fonts
    ./run.sh                          # start detached on every output
    PAPER_OUTPUT=DP-1 ./run.sh        # one output only
    mantle stop --pid <pid>

`run.sh` points fontconfig at `fonts.conf`, which adds the bundled fonts. Start the shell from your
login session (Hyprland `exec-once`), so `$XDG_SESSION_ID` is set and the polkit agent can register.

## Optional tools

| Feature | Needs |
| --- | --- |
| Night light | `hyprsunset` (Hyprland only) |
| Screen recording | `gpu-screen-recorder`, `slurp` for a region |
| Default terminal | `xdg-terminal-exec` |
| App icons | Papirus icon theme |
| Updates | `pacman`, optionally `yay` for the AUR |

The wallpaper picker lists `~/Pictures/Wallpapers`, or the folder `$PAPER_WALLPAPERS` names.

## Files

`shell.lua` wires the modules under `modules/`; shared drawing lives in `lib/paper.lua` and
`components/`. Design rules: `DESIGN.md` and `AGENTS.md`. `python3 -I tools/make_assets.py`
regenerates `img/`. The shell keeps its state in `~/.local/state/paper-shell/` (`$XDG_STATE_HOME`).

## License

MIT, see `LICENSE`. Fonts: Caveat and Patrick Hand, SIL Open Font License (licences in `fonts/`).
