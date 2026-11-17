# House 02 walkable blockout

First implementation step approved October 26, 2026. This standalone Godot scene
uses the user's plain-rectangle house before any room art is painted. The mansion
and the existing mystery lab remain separate.

Run `tools/run_house_blockout.ps1` from PowerShell. It uses the Godot GUI binary
already configured in ignored `tools/dos-game-mcp/local.json`, verifying its hash.
Alternatively, open `src/blockout/house_blockout.tscn` in Godot and run this scene
with F6. F5 still launches the existing mansion.

- WASD/arrows: walk; move outward through cyan doorways to change screens.
- E: open the exposed purple Library panel, or leave the secret passage at its exit.
- R: restart in Front Entry and reset measurements.
- Screen picker: inspect any room; this resets counters so jumps are not mistaken
  for measured routes. Labels can be hidden.

The layout contains nine ordinary rooms, one secret passage and one hall screen.
Names are authoritative: the Study's legacy ID is `kitchen`. Furniture footprints
block movement; purple markers show guest-spot kinds and allowed facings; gold
squares are potential item positions. These markers are not instantiated guests
or case evidence.

One walking step is 24 logical pixels of actual travel, accumulated across frames
and screens. Standing still, pushing into a wall and teleporting to a portal's
arrival do not add distance. Diagonal movement is normalized. Non-hall arrivals
are counted separately. This is instrumentation, not a danger-clock decision;
action costs, portal costs and clock reconciliation are intentionally deferred.

The map is a byte-identical snapshot of Claude's local design worktree's
`assets/maps/house-02.layout.json`. The local design branch has not been merged
or pushed. The viewer exposes the first reachable north-wall secret panel for
testing and derives an exit marker from passage geometry; seeded concealment and
authored secret-portal locations belong to the later case integration.

Validation: run the configured Godot executable with `--headless --path . --script
res://tools/house_blockout_checks.gd`. The native harness exercises all 24 directed
doors by walking routes around furniture, validates arrivals, thin-obstacle
collision, blocked-movement counting, stationary counting, teleport-distance
exclusion, inspection reset and both secret transitions. Screenshots are local in
ignored `test-results/house-blockout/`.

Next: human walking/layout review, then generator/solver parity fixtures and the
GDScript port. Danger, guest simulation, dialogue and final art remain later steps.

Room-art clarification from the user, 2026-10-26: the Front Entry's north/top
connection leads into the rest of the house (Hall 2). Its two side obstacle areas
are intended for pillars, statues or similar decoration, not staircases; the
automatically assigned `stairs` labels are not an approved furnishing choice.
Do not put windows across the top of this entry. Side windows and other suitable
decoration are allowed. Tables may have appropriate chairs or stools, with door
access and walking routes preserved. Review the whole house layout and its room
connections before generating more artwork. The first staircase foyer candidate
was rejected and must not be integrated. No replacement art has been approved.

Furnishing review, 2026-10-29: the user authorized tidying obstacles room by room,
including repositioning awkward chairs/stools, with guest placement afterward.
The proposed layout and full room-art review are in
`assets/rooms/house-02/furnishing-review/index.html`. Ten newly generated room
candidates accompany the revised foyer; the study's unintended south opening was
corrected in v2. `batch.json` records exact candidate hashes and pending review.
The original playable layout is unchanged. All eleven proposed screens preserve
the original portals and walk regions, and a 4-pixel-grid check with 7-pixel
clearance connects all door/secret approaches. This checks proposed geometry only:
painted footprints differ, so art approval, collider tracing, doorway alignment
and guest/item placement remain separate steps before gameplay integration.

The user subsequently rejected the Living-Room and Hall 2 doorway architecture:
use ordinary doors set into continuous side walls, not stacked-looking arches or
individual pillar portals. Redraw those two candidates. Across the entire house,
the old marker coordinates are provisional; after the artwork is settled the
user will choose door-marker positions on the images. Preserve room connectivity,
then calibrate transitions, arrivals and collision to those chosen positions.
Do not force finished artwork or final transition triggers to the old coordinates.

The review now includes a user-operated door/panel placement editor (27 markers
across 11 spaces). Choose a destination, then click or drag on its image. Positions
save in browser storage keyed by room and artwork SHA-256; download
`house-02-door-positions.json` to hand them back for integration. The export keeps
stable portal IDs, targets, original side labels and explicit placed/unplaced
flags in 480x360 coordinates. It does not modify runtime geometry. Hall v9 alone
has recorded visual approval from “Looks good for now. Continue”; other rooms
remain pending. Rebuild the gallery with `tools/build_house_room_review.py`.
The local HTTP review binds to loopback and serves only `assets/rooms/house-02`.
UI checks verified placement, persistence after reload, selected-marker reset
and JSON download; exported data includes 11 rooms and 27 unique valid markers.

## Painted walkthrough — 2026-10-29

All eleven current images now have explicit approval (“Approve all current room
images”). The user's newer export is retained at
`assets/maps/house-02.door-positions.json`; the basement's unchanged marker was
explicitly accepted. `tools/build_painted_house.py` verifies approval/image hashes
and builds `assets/maps/house-02.painted.layout.json`, preserving all 27 positions.
It pairs arrivals with the reverse door, adds initial painted floor polygons,
door approach cutouts and furniture masks, and places the two passage panels.
The original map and investigation remain independently runnable.

Run `tools/run_house_blockout.ps1 -Painted` for the eleven-room artwork walkthrough.
WASD/arrows move the white foot marker; walk into cyan doors; E uses secret panels;
R restarts. The room picker can jump for inspection. Labels and collision overlays
can be toggled. Guest/clue placements are deliberately absent from this preview,
pending their own calibration. `-Painted -Investigate` is rejected explicitly
rather than placing guests at invalid old positions.

Native `tools/painted_house_checks.gd`: 169 passed, including real walking through
all 24 directed door links, paired open-floor arrivals, exact user coordinates,
all three secret-panel actions and all eleven image hashes/decodes. Original
blockout checks: 161 passed; room-entry/danger runtime checks: 155 passed. A native
GPU Hall 2 capture was inspected at `test-results/painted-house/hall.png`; room
collision is initial calibration and still needs the user's walking review.

Door-approach correction: removed the obsolete living-room console collider (the
revised artwork removed that furniture) and extended the hall/living-room side
door approaches down onto the painted floor/carpet. User markers are unchanged;
the hall consoles remain solid. Native painted checks now pass 187 assertions,
including straight carpet approaches followed by movement toward each side door,
as well as all original 24 directed links and secret-panel routes.

## Guest placement and foreground preview

The same review page now offers generic guest slots previewed with Char or Chris,
four facings and existing standing/seated activities. It measures 52 unchanged
export PNGs through `tools/house_guest_previews.py`, preserving source proportions
and using the shared 80-unit standing scale. Standing slots anchor at the feet;
seated slots use existing provisional seat landmarks where available, otherwise
an explicitly estimated seat contact. Exact seating/occlusion fit needs review.
Preview identity is cosmetic and does not lock a generated case's cast.

Draw foreground-mask polygons around chair/table front parts and choose the
furniture front floor depth (by clicking the image or entering y). The browser
depth-sorts guest contacts and clipped copies of the original backdrop: guests behind
the front edge are covered, guests in front remain visible. No PNG is edited.
Masks can be selected, removed and have their front depth adjusted. View scene
hides editing outlines. Guest placement and door editing are mutually exclusive.

Slots and masks save per room/artwork hash in browser storage; download
`house-02-guest-positions.json` to request native integration. The current Godot
walking preview still has no guest slots until that user-authored export arrives.
Restart the loopback review with `python tools/serve_house_review.py --port 8796`;
it exposes the room review and only the 52 hash-verified character preview PNGs,
without copying images or serving the rest of the checkout.

UI checks covered Chris seated/read/east, Char standing/read/north, reload
persistence, polygon creation, front-depth ordering, removal and guest/mask JSON
download. The export includes 11 rooms, stable slot IDs, image hashes, contact
and floor points and polygons. All 52 HTTP-served PNG hashes matched their
approved exports, and a path traversal request returned 404. Temporary test
placements were removed without changing the user's door coordinates.

Mask-depth correction: starting a new polygon clears the previous custom depth,
so Finish mask defaults to that polygon's bottom edge. Use mask bottom edge
repairs an existing mask without changing its shape. Seated guests sort by the
seat anchor, standing guests by the feet anchor; exports include explicit depth_y
alongside floor_at. Browser verification preserved the user's eight library
slots and three masks, repaired their stale depths, confirmed both north-facing
seated guests precede the chair mask, and visually checked the chair/foreground
occlusion. JavaScript syntax check passed.

## Native guest fit preview — 2026-11-16

The user's downloaded placement work is now imported for native review at
`assets/maps/house-02.guest-positions.json`: 19 generic slots and eight masks in
the Library, Study and Master Bedroom. The remaining rooms stay empty. These
are fit previews, not case casting or final furniture-fit approval; original
PNG files and browser placements are unchanged.

Run `tools/run_house_blockout.ps1 -Painted -Screen library`. The room picker
visits all eleven painted spaces. Toggle guest previews, furniture masks and
anchors; choose Saved characters or Char/Chris, then try activities. A pose that
does not support the slot's posture/facing falls back to that slot's saved
activity. Preview controls do not rewrite placement data. Guests do not walk.

Reimport a later editor download with:

```powershell
.venv/Scripts/python.exe tools/import_house_guests.py "<download.json>"
```

The importer checks room/image/pose hashes, measured contacts, IDs and coordinates
before atomic replacement. Explicit owning approval records are preflighted where
available; legacy approval labels are retained as validation notes rather than
inventing new approval evidence. User-authored crossing mask edges are preserved;
native SVG rasterization follows the browser's fill rather than triangulating
the polygon. Masks keep the original background resolution and sort by standing
feet/seated contacts. No artwork is regenerated or finalized.

Verification: 19 importer tests, 353 native guest-preview assertions, 26 approved
room-texture checks, 187 painted walking assertions and 162 investigation
regressions passed. Native GPU captures of all three placed rooms were inspected
at `test-results/guest-native/`. The new imported-texture loader eliminates the
local foyer warning; an actual packaged build remains untested. The seeded mystery
still uses its separate blockout until guest/clue placement integration is ready.

The mask editor also now displays the selected mask's saved depth reliably.
Pick furniture front edge, click its floor depth, then draw or continue the polygon;
existing corners are retained. Starting a fresh polygon uses its own bottom edge.

Completed placement import, 2026-11-16: the user's latest download replaces the
partial preview with 55 slots and 19 masks across all eleven rooms. All exact
image/pose/contact checks pass; authored polygon shapes remain unchanged. Native
guest-preview checks now cover all 55 slots and 19 masks (1,000 assertions), and
new GPU captures of Living-Room, Dining Room and Basement were visually inspected.
These are available guest positions, not 55 simultaneous case occupants. Mystery
casting, proximity interactions and clue/item locations still need integration.

The subsequent painted investigation integration is now available with
`tools/run_house_blockout.ps1 -Painted -Investigate`. It uses these same authored
spots and masks with the actual seeded cast, reachable questioning and provisional
clue markers. See [current investigation](HOUSE_INVESTIGATION.md) for conversation
posture rules, temporary cast-art limits and verified end-to-end results.
