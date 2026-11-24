# Paper shell: design guidelines

A desktop laid out like a desk: torn paper, pencil, marker, highlighter, washi tape and sticky
notes. `shell.lua` draws the bar, cards and dock; `controls.lua` draws the control sheet
(`mantle toggle paper.controls`). Screenshots: `screenshot.png`, `controls.png`. Rules marked
*spec* are not built yet.

## 1. Materials

Every surface is one of these. Do not invent another.

| Material | Use | Build |
| :--- | :--- | :--- |
| Notebook paper `#EEE3CB` | Bar, cards, dock, pages | `sheet{}`: torn `shape`, paper finish, drop shadow |
| Card stock: blue `#C5D7EE`, cream `#F4ECDA`, pink `#F2CFC8`; tab tints `#E9DDBB` `#C9D8EA` `#EBCBC5` | Buttons, tabs, the active workspace | `sheet{}` with `color` |
| Paper disc `#F4ECDA` | Icon buttons, toggle knobs | `sheet{}` with `torn_circle` |
| Sticky note `#F3E3A0` | Tooltips, notifications | Folded corner (`#DCC67A`), torn top, tape on top |
| Washi tape, 70 to 80% alpha | Holding cards down, chips | `tape_shape` (zigzag torn ends), grainy |
| Groove | Toggle track, pressed into the page | Capsule `shape`, inset shadow |

The **paper finish** is one shader, `shaders/paper.frag`, run as `effect.shader` on every material.
It samples `img/grain.png` tiled at 1:1 (R fine tooth, G mottle, B fibres), adds a pale fibre rim
inside a torn edge with `mantle_sdf`, and can shade the shape with pencil hatching. Grain never
scales with the box. The finish runs on a backing layer under the content, so ink stays clean. The
fibre rim is for large sheets only (bar, cards, dock, pages); small controls keep a clean cut.

Paper has no straight edge except where it meets the screen edge. Tear depth: 5 px for the bar and
pages, 4 px for cards, 2 to 3 px for buttons, photos and stickers. About 8% of edge points bite deep
(70 to 100% of depth).

## 2. Ink

| Token | Hex | On paper | Use |
| :--- | :--- | :--- | :--- |
| `INK` | `#3A3631` | 9.4:1 | Body text, icons, pencil outlines |
| `INK_SOFT` | `#6B6258` | 4.7:1 | Secondary text, done items, quotes |
| `BLUE` | `#3F74C7` | 3.6:1 | Section headings at 24 px or more, ticks, focus loop, marker underline |
| Deep blue | `#24477F` | 7.2:1 (6.3:1 on blue stock) | Text on blue stock, links, the active workspace numeral |
| `RED` | `#D9534F` | 3.1:1 | Marker: progress, favourite, push-pin, doodles. Never text under 24 px |
| Deep red | `#8E2B25` | 5.8:1 on pink stock | Text on pink stock |
| Highlighter | `#9EC0EC99` (multiply), `#F2C94C80` (multiply) | n/a | Slider value, link hover, text selection |
| Pencil hatching | `rgba(0.2, 0.38, 0.7, 0.75)`, 3.2 to 4 px pitch, 45° | n/a | "On" and "selected" fills |

Strokes: pencil 1.3 to 1.6 px, marker 2.2 to 3 px, focus loop 1.8 px, drawn twice with 1 to 2 px
drift. Caps and joins are round.

State never rests on colour alone. A toggle that is on is hatched and its disc rolls across. A
checked box gets a tick, a chosen radio gets a scribble, and the selected tab stands taller.

## 3. Type

| Role | Face | Size |
| :--- | :--- | :--- |
| Display (clock) | Caveat 400 | 96 to 110 |
| Headings, card titles, button labels | Caveat 700 | 24 to 52 |
| Body, list items, status bar | Patrick Hand | 18 to 25 |
| Captions | Patrick Hand, `INK_SOFT` | 16 |

Use Caveat only at 24 px or more, and never for body text. Caveat text takes right padding of 15%
of its size (section 7). Both fonts are OFL, bundled in `fonts/` and loaded through `fonts.conf`.

## 4. Placement, light and motion

- Cards turn between -1.2 and +1.2 degrees, alternating. Buttons rest at -0.6, 0 or +0.6 degrees.
  Photos and stickers may turn up to 6 degrees. A card holding a text field or more than five rows
  turns at most 1 degree.
- Tape crosses an edge, half on and half off, turned 1.5 to 4 degrees against what it holds.
- Light comes from the top left. Shadows: card `blur 14, (2, 5), #00000070`; resting control
  `blur 5, (1, 2)`; lifted control `blur 16, (3, 9)`; tape `blur 3, (0, 1)`. A groove takes an
  inset shadow `blur 5, (0, 2)`.
- Hover peels a control off the page: it rises 3 px, tilts to -2 degrees on a spring, and its
  shadow grows over 160 ms. Springs move what a hand would move (disc, tilt). Lifts and fades
  take 120 to 160 ms `out_cubic`.

## 5. Controls

| Control | Rest | Hover | On or selected |
| :--- | :--- | :--- | :--- |
| Primary button | Blue card-stock scrap, deep-blue Caveat 700 label | Peels up | n/a |
| Secondary button | Cream scrap, ink label | Peels up | n/a |
| Destructive button | Pink scrap, deep-red label | Peels up | n/a |
| Link | Deep-blue Caveat, blue marker squiggle under it | Yellow highlighter swipe | n/a |
| Icon button | Paper disc, ink icon | Peels up | n/a |
| Toggle | Groove pressed into the page, paper disc at the left | n/a | Groove hatched blue, the disc rolls right and turns 160°, its pencil dot goes blue |
| Checkbox | Wobbly pencil square | n/a | Blue marker tick that overshoots the box |
| Radio | Pencil circle that overlaps its start | n/a | Blue marker scribble |
| Slider | Pencil line, slight curve | n/a | Blue highlighter over the value (multiply), red push-pin thumb |
| Text field | Writing on a ruled line, Caveat placeholder at 45% ink | n/a | Focus inks the line blue and 2 px; yellow highlighter selection |
| Tabs | Card-stock index tabs, 36 px | n/a | 44 px, Caveat 700, joined to a card of the same stock |
| Chip | Washi tape, tinted, ±2 degrees | n/a | n/a |
| Tooltip | Small sticky note, taped, turned 2 degrees | n/a | n/a |
| Notification | Sticky note with a folded corner, icon, Caveat title, link actions | n/a | n/a |
| Focus | A blue pencil loop round the control in place of a solid ring | | |

*Spec:* the focus loop is drawn as a static sample. Wiring it to `focus_visible` with
`focus_ring = false` is not built. Disabled controls: the stock fades to 50% and the label to
`INK_SOFT`; a toggle's groove would be dashed, which needs an engine change (section 7).

## 6. Shell parts

- **Bar:** full width, 46 px, straight top, torn bottom. Caveat workspace numerals; the active one
  sits on a hatched blue sticker. The focused app's name, then status icons, date and time in
  Patrick Hand.
- **Cards:** 370 px wide, stacked on the right 4 px apart: clock, quote, todo, music, photo.
- **Dock:** an 820 x 86 px scrap at the bottom centre. Symbolic icons in `INK`, at most two in
  colour, a pencil divider before the trash. Icons grow 12% on hover.

## 7. Engine gaps

Checked against the repo's docs and the installed `mantle` binary.

**Not in the engine:**

| Gap | Effect here | Workaround | Change that would close it |
| :--- | :--- | :--- | :--- |
| Text is scissored to its border box (`renderer/src/layout/paint/build.rs:332`) | Caveat's last `d` or `l` loses its stem | Right padding of 15% of size on Caveat text | Clip text at its ink bounds |
| No dashed strokes | A dashed groove has to be built from separate `M`/`L` and arc subpaths in Lua | Not built | `stroke_dash = { on, off }` on `path` and borders |
| Constant stroke width | Pencil and marker lines have no pressure taper | Two passes with drift | A width that varies along the path, e.g. `stroke_width_end` |
| No strike-through on text runs | Done todo items | A 1.6 px rect over the text | `strikethrough = true` beside `underline` |
| Fonts load only by family name through fontconfig | Shipping a font needs a `fonts.conf` and `FONTCONFIG_FILE` set outside Lua | `run.sh` sets it | Font files in `fonts {}`, relative to `mantle.config_dir` |
| `image` has no tile or nine-slice fit, and `background` takes no image | Tiling needs a shader | `paper.frag` tiles with `fract()` | `fit = "tile"`, an image background layer |

**Limits with an in-engine route:**

| Limit | Effect here | Route |
| :--- | :--- | :--- |
| A `shape` takes 256 commands | The bar's torn edge steps every 16 px and is laid out to 3840 px | Place points with `"NN%"` and `{ from = ..., px = ... }` so the edge follows the box; erode fine fibres in `paper.frag` from `mantle_sdf` and noise. Not tried. A `mask` is no substitute: it leaves `mantle_sdf`, the box shadow and hit testing rectangular |
| `effect.shader` costs two offscreen passes (subtree, then shader) when its layer changes; unchanged layers and parent transforms reuse the cache | Every sheet, chip and tab runs one | Fine for a static shell; animate sparingly |

Everything else used here is in the engine: rotation, torn outlines, tape, shadows on any shape
(inset too), masks, blend modes, gradients, springs, hover and drag input, shaders with `mantle_sdf`.
