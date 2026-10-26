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
