# Layout editor

A browser tool for arranging house layouts: move rooms around a floor plan, rotate them, connect doors and
check the result. Plain HTML and JavaScript, no network, no build step.

## Open it

Double-click `tools/layout_editor/index.html` (works from `file://`). `index.html` loads `core.js` from the
same folder. The page autosaves to the browser's localStorage when that is available.

## Workflow

1. **Open** a layout JSON (for example `assets/maps/house-01.layout.json`) or **Load sample**. Screens
   without a plan position are arranged automatically from the start screen.
2. **Add screens** with Room, Hall (E-W), Hall (N-S) or Secret passage. Rename them, change ids and set the
   start screen in the side panel.
3. **Move** tiles by dragging (20-unit grid, toggle "Snap grid"). Pan by dragging empty space or the middle
   mouse button, zoom with the wheel.
4. **Rotate** the selected tile with `R` (90 clockwise), `Shift+R` (counter-clockwise) or `T` (180).
5. **Doors**: `D` or "Add door", then click a tile edge. Drag a door marker along its wall to move it. Click
   a door, then click a door in another room (or press `L` first) to link them. Unlinked doors are red.
6. **Edit inside** (double-click or `E`): drag and resize walk regions (green) and obstacles (brown), drag the
   item slot, guest spots, spawn and doors. "Preview rotated" shows the baked, read-only result.
7. Watch the **Live checks** panel (problems, step-cost min/median/max, full matrix). Click a problem to
   select the screen it names.
8. **Save** keeps the editable project (with `plan` and `link`). **Export baked** writes the layout the game
   and Python read.

## What rotation does

`plan.rot` (0, 90, 180, 270, clockwise) turns a tile around its centre on the plan. On export, every
screen's geometry is rotated by it: walk regions, obstacles, spawn, item slot, guest spots, door positions,
door `facing` and `side`, and halls swap `orientation` (`ew` and `ns`) for 90 and 270. The 90/270 transform
squeezes the room into the landscape 480x360 frame (x factor 4/3, y factor 3/4), so a rotated room is a
different shape from its source and its art is painted for that orientation afterwards. Arrivals are
recomputed from the partner door (16 px inside it) and clamped onto open floor, and secret panel columns are
recomputed along the rotated wall. With every rotation at 0 the exported geometry equals the input.
`plan.x`, `plan.y` are the top-left of the unrotated 480x360 tile in plan units (1 unit = 1 logical pixel);
the tile turns around the centre of that rectangle. The plan draws tiles at 0.4 scale.

## Kinds (obstacle and guest spot labels)

Each screen can carry two parallel arrays next to the lists they describe:

- `obstacle_kinds`: one string per entry of `obstacles`, same order and length.
- `guest_spot_kinds`: one string per entry of `guest_spots`, same order and length.

Obstacle vocabulary: bookshelf, shelf, table, dining_table, coffee_table, console_table, desk, chair, armchair,
sofa, stool, bench, bed, dresser, wardrobe, window, fireplace, counter, island, pantry, sideboard, plant, pillar,
stairs, crate, rubble, other. Guest spot vocabulary: stand, seat, table, browse, window, fireplace, stairs. Any
other string in a file is kept as written, drawn grey and offered in the dropdowns.

In the inside view obstacles are filled with their kind colour and labelled (the label is hidden when the box is
too small); guest spots are coloured circles, labelled when selected. Select one to change its **Kind** in the
side panel (one undo step); "other..." asks for a custom name (lower-case letters, digits, underscore). The
toolbar's "New obstacle kind" and "New spot kind" pick the kind given to items you add (defaults `other` and
`stand`). The **Kind legend** in the side panel is collapsible. Add, delete, undo, rotation and baking always
keep the arrays in step. On load a missing array is created, a short one is padded with the defaults, and a
too-long one is truncated with a warning in the problems panel. Save and Export baked both write the arrays.

## Guest spot facing

`guest_spot_facing` is a third parallel array, one entry per `guest_spots` entry: how a guest standing there
may face. An entry is a side string (`"north"`, `"east"`, `"south"`, `"west"`), `"any"`, or an array of 2 or 3
distinct sides in the order north, east, south, west (for example `["north","east"]`). Four sides become
`"any"` and a one-side array becomes the plain string. It is kept in step with `guest_spots` by every add,
delete and undo. On load a missing array is padded with `south`, a short one is padded, a too-long one is
truncated, and an invalid entry (unknown string, empty array, duplicates) becomes `south`; truncation and
invalid entries are reported in the problems panel. Baking rotates every side with the room (rotation 90:
north to east to south to west; arrays are re-sorted; `"any"` stays). The inside view draws one arrow per
facing direction (a circle with a cross for `"any"`; the rotated value in "Preview rotated"). With a guest
spot selected, the **Facing** buttons N, E, S, W toggle directions independently and **Any** selects `"any"`
(one undo step each). `Shift`+arrow sets exactly that direction; `Shift`+`Alt`+arrow toggles it in or out of
the set. "New spot facing" in the toolbar uses the same buttons for spots you add. Save and Export baked write
the array.

## Files

- Project file: the normal layout format (see `docs/case-design/HOUSE_LAYOUT_FORMAT.md`) plus
  `screen.plan = {x, y, rot}` and `portal.link = "<partner portal id>"`. Unknown fields are preserved. If
  `link` is missing it is inferred from the partner portal in the target screen.
- Baked file: the same format with rotations applied; `plan` and `link` are kept. Check it with
  `layout.problems(layout.load(path))` in `tools/case_design/layout.py`.
- `core.js` holds the pure functions (`bakeLayout`, `problems`, `stepCosts`, `summary`, edit helpers,
  `autoPlan`) and works with no DOM, so it can also be required from Node.

## Shortcuts

| Key | Action |
| --- | --- |
| `R`, `Shift+R`, `T` | rotate 90 cw, 90 ccw, 180 |
| `D` | add door mode |
| `L` | link mode |
| `E` / double-click | edit inside |
| `Delete` | delete selected door (or shape inside) |
| `Esc` | cancel mode, deselect, back to plan |
| `Ctrl+Z`, `Ctrl+Y` | undo, redo (100 states) |
| `Ctrl+S` | save project JSON |
| `?` | help |
