# Paper shell (throwaway Mantle study)

    ./run.sh check                    # mantle check with the bundled fonts
    ./run.sh                          # start detached on every output
    PAPER_OUTPUT=DP-1 ./run.sh        # one output only
    PAPER_SHOT=1 ./run.sh             # bar on the overlay layer, over another shell's bar
    mantle toggle paper.controls --pid <pid>   # show or hide the control sheet
    mantle stop --pid <pid>

Running beside another Mantle shell works; both draw a wallpaper and a bar, so stop yours or use
a spare output for a clean look. `python3 -I tools/make_assets.py` regenerates `img/`.
Fonts: Caveat and Patrick Hand, SIL OFL (licences in `fonts/`). Guidelines: `DESIGN.md`.
