# Seeded investigation in House 02

Initial objects now use deterministic per-case floor positions within their
assigned rooms, rather than a fixed item slot. Positions avoid furniture masks,
door trigger areas and (where space permits) guest interaction zones. Picking up
and dropping still retains the player's chosen drop position. A correct accusation
plays the user-selected win MP3 while the conclusion text appears; failures do not.

Personality presentation update (2026-11-16): questioning uses approved nervous
fidget, proud hands-on-hips, guarded/hot-tempered crossed arms, curious thinking,
fragile withdrawn and warm/calm talking poses. Both world and enlarged portraits
vary; seated and floor-focused guests keep their established posture. The latest
authored `confession` stories are connected by Claude; reveals now use suitable
approved personality poses instead of always shrugging (Chris's crying is crouched).
The next eight opt-in Char/Chris preview cases cover every killer personality once
via natural seed selection, without changing generated case facts. Ordinary fixed
replay and random generation retain their existing personality distribution.

## Presentation corrections — 2026-11-16

Ambushes now briefly stage the killer approaching the inspector within the room,
play an original synthesized three-hit sting, then open normal portrait dialogue.
The large grey pose viewer is retained only as a developer art tool. Accusation
conclusions also use the normal dialogue layout. Text reveals gradually with
punctuation pauses; Space/Enter/E or clicking the text reveals the remainder.
This approach is an explicit cinematic exception to stationary guest snapshots;
it never changes case facts, player position, room or danger clocks.

Floor discoveries open a full dialogue popup with an explicit wound-kind title,
so the wound paragraph is not clipped by the short HUD strip. The notebook has
Summary, Accounts, Items and Searches tabs; blood room/wound appear first and
opening it resets to Summary. Previously recorded clues were buried rather than
proven lost; no automatic weapon deduction is added.

The active item catalog is back to ten distinct types, with at most one Kitchen
knife per case and no knife variants. Actual inventory kinds determine wounds
and stain matching. A catalog deal without replacement and compatible-decoy
selection replace the previous many-variant runtime presentation; raw reference
generator output remains unchanged for parity. Runtime item records, not raw
reference item-kind/decoy arrays, are authoritative for playable lens evidence.
The first two pending-dialogue examples are being handled by Claude separately.

## Single-slot inventory and lens playtest — 2026-11-16

The glass now occupies the one carrying slot. Any object can be taken without
identification. **Q / Drop held item** leaves it at the player's current floor
position, including halls and the secret passage; it stays there until picked up.
Overlapping objects have a nearby-item chooser. With empty hands E takes the
selected item; while carrying, E examines it. The separate item buttons remain.

On Normal/Hard the held glass reveals stains on the weapon and two decoys; kind
is visible without the glass. The murder-room trace reveals wound kind. Hard
still needs a genuinely staring guest plus the held glass. Easy directly names
the weapon. The notebook records observed items, stains, kinds, wound and last
known locations; Normal/Hard never automatically name the matching weapon.

Holding the true weapon silently doubles the danger clock. Dropping restores
ordinary future speed, without removing elapsed danger. Physical walking counts,
guest entry snapshots, hall safety and solo-killer ambush protection are preserved.
The phase heading is labelled Murderer and uses authored yellow/orange styles.

Gathering accepts any non-glass held item, stays in the current room, and permits
dropping/swapping afterward. Final accusation checks what is actually held: correct
person and room with the wrong item produces `wrong_weapon`; the other four
outcomes remain. Empty hands/glass block the final accusation. An ambush grabs
whatever is held, including glass, while the truth summary names the actual weapon.

Latest Claude dialogue supplies orange stains, red wounds, drop text, wrong-weapon
corrections and silent refusals (10% chance). Missing text is explicitly marked
`[PENDING_DIALOGUE:...]` in dialogue JSON. Existing confession corrections remain.
There are 38 distinct named catalog variants; some share existing approved type
artwork temporarily. No source PNGs were changed or new artwork generated.

Confession wording correction (2026-11-16): three personality templates now
explicitly say "I killed {victim}" rather than following the victim's name with
"me". This intentionally updates the imported personality snapshot; case-role
bindings and the 432 successful account/repeat fixture strings remain unchanged.

Guest conversations again show an enlarged version of the speaker above the
dialogue box. The portrait reuses the current approved pose (or temporary cast
sprite), preserving seating/facing and leaving the world guest unchanged. It
hides when dialogue closes and does not carry into item inspection.
When the room pose faces north, the enlarged conversation uses face-visible
south artwork instead. North-facing chairs keep their room orientation; downcast
inspection keeps its mood in the close view. No guest placement or saved facing changes.

For the requested six-case killer-art playtest, launch with
`tools/run_house_blockout.ps1 -Painted -Investigate -KillerPreviewCount 6`.
Random cases alternate Char/Chris as culprit by finding a matching generated seed;
clues and alibis are not patched. The filter expires after six cases in that
running session. Fixed-seed replay bypasses it. Existing ambush threat and accused
resigned-shrug artwork are shown; this does not yet vary reveal poses by personality.

## Door approaches, gathering and refusals — 2026-11-16

Painted doors use broad floor thresholds, separate from the unchanged user marker
coordinates on the door artwork. Arrivals use the paired floor threshold. The
dining table collider starts below the open walking band behind it.

After collecting the identified weapon, **Gather everyone** brings all six living
suspects into the player's current room, with no automatic room relocation.
Temporary collision-clear standing contacts support
the current cast artwork without changing saved guest placements. Doors and secret
exits lock; relocation and danger stop. Walking, looking, questioning and the
notebook remain available. A second, explicit **Make an accusation** action opens
the suspect/room choices. Starting another mystery releases the locks.
If no safe six-guest arrangement is available, gathering reports that constraint
and leaves the player, guests and unlocked investigation unchanged in that room.

Occasional refusals remain at their existing probability. A scoped
`assets/dialogue/refusal-playtest.json` override supplies three brief lines per
personality (24 total), rotating on actual refusals without changing case facts or
gameplay RNG. Successful first/repeat accounts and Claude's source JSONs are intact.

## Play presentation and encounter correction — 2026-11-16

The painted mystery now displays the original investigator and four-direction
walking presentation, actual existing object artwork and matching inspection
closeups. Player, guests, objects and furniture masks share depth ordering.
The default interface hides coordinate/step/door/secret debug markings, provides
nearby interaction controls, a compact case file, themed dialogs, a pause/new-case
menu and a read-only house map. Tab opens the map; F11 toggles fullscreen; F3
exposes optional developer overlays/tools. Seated and floor-focused rules remain.

New mysteries randomize by default. Uncheck Random mystery in the new-case menu
to replay a case number, or use `-CaseSeed <number>` with the launcher. Object
identities are independently shuffled per case from ten existing, matching art
entries in `assets/mystery/house_item_catalog.json`; the magnifying glass keeps
its separate generated location. This does not reroll culprit/room/testimony or
advance their RNG streams. Item floor positions remain provisional, but visible
gold cubes are replaced by object sprites. No new artwork was generated.

Ambushes now require being alone with the actual killer. Stalking has a 50%
room-entry bias toward relocating bystanders elsewhere when capacity permits;
it never removes a witness midway through a visit. See [danger rules](HOUSE_RUNTIME.md).

Native checks cover 422 danger assertions, 41 investigator presentation checks,
136 item-art checks and 71 house-map checks. The two painted end-to-end case
routes still pass. This is the first playable UI pass for user review, not final
menu design or final character/item/furniture art.

`tools/play_presentation_checks.gd` additionally passes 390 headless assertions
and 394 assertions with GPU captures, covering random/fixed case callbacks,
24 distinct item permutations over 24 seeds, actual item art and pickup, menu
bounds, read-only map state, and paused physics. Its injected-key attempt is not
reported by Godot's physical-key polling; a real held OS key remains a manual
input check. Four inspected captures are under `test-results/play-ui/`.

## Authored dialogue — 2026-11-16

The painted mystery now reads Claude's eight-personality dialogue and narrator
text from `assets/dialogue/`. The three JSON files (personalities, system, styles)
were copied byte-for-byte from the design branch; their hashes are recorded by
`tools/case_dialogue_checks.gd`. No original-game text was copied. The authored
data passes the design validator, including its available local reference check.

The GDScript loader matches all 216 first/repeat pairs (432 strings) in
`tests/fixtures/dialogue_v2.json`. Dialogue uses independent text-only seed streams:
asking questions cannot reroll a case, guest spot, personality or danger threshold.
The first successful account gets a full answer; subsequent answered questions
get a stable recap. Refusals reveal no account and do not consume the first-answer
state. Actual painted room names replace the generator's reference labels.

Refusals, clues, negative searches, preparation hints, four accusation outcomes
and both ambush types use the authored data while preserving their existing gates.
Hard searches without a real staring guest remain explicitly inconclusive. Weapon
innocence is never asserted before identification; a floor is not described as
unwatched while another guest is present. The notebook stores learned claims and
discoveries, not commentary or wording.

Question popups have selectable, scrollable plain text and retain the room view.
For seated or floor-focused guests, the spoken portion of an authored answer is
prefaced by the actual pose's narration, so prose such as standing up or looking
up cannot contradict the sprite. Refusals do not receive an "answering" preface.
Warning colours, red discoveries and red ambush messages come from styles.json;
warning/feedback text wraps instead of cutting off long lines.

No guest pose or historical case fact changed. Current resigned reveal artwork
uses resigned confession text in the appropriate voice. Unconfirmed rank titles,
rank thresholds and personality-to-confession-tone mappings are not enabled.
Outdoor-stoop, carrying-limit/drop and physical assembly/door-lock prose remain
unused where the current mechanics do not implement those actions.

Validation includes 954 loader assertions, 861 session-dialogue assertions, the
432 exact fixture strings, existing case/runtime/posture regressions, and two
walked painted investigations (201 scene assertions, controlled relocation/risk
for repeatability). Native dialogue captures were visually checked. Default-risk
pacing, puzzle satisfaction and final artwork still require human playtesting.

A further 36 native UI assertions check scrollable full answers, refusal and
recap presentation, preserved seated posture, red discovery/ambush text and
yellow/orange warnings. GPU captures are in `test-results/dialogue-ui/`.

## Painted investigation — current integration, 2026-11-16

Run `tools/run_house_blockout.ps1 -Painted -Investigate` for the mystery on the
eleven approved room backgrounds and user-positioned doors. The old unpainted
investigation remains available without `-Painted`; F5's older mansion entry is
unchanged. The painted walkthrough without `-Investigate` remains a fit editor.

`tools/build_house_investigation.py` combines the approved painted geometry and
validated guest export into `assets/maps/house-02.investigation.layout.json`.
It preserves all 55 guest anchors, 19 masks and 24 directed doors, adds reachable
interaction approaches beside furniture, and places ten provisional gold item
markers on connected floor. Those item markers are playable clue positions,
not final object-art/furniture attachments. Rebuild after importing a later guest
download; the browser itself does not edit the running case.

Only the six seeded suspects occupy compatible free authored slots. Char and Chris
can sit; the other thirteen cast members use their existing, hash-checked standing
test cutouts until their directional/seated pose libraries exist. Those temporary
sprites are not mirrored or promoted to final art. Room-entry snapshots select
spots and activities; guests remain stationary while the room is visible. Slot
capacity and nearby-occupant clearance prevent stacking on scarce hall/secret spots.

Activities are selected from compatible idle, reading, upward/downward inspection
or seated rest poses. A saved upward-looking preview does not force that activity
forever. Posture and calibrated chair facing are preserved. Conversation turns a
standing Char/Chris toward the player; a floor-focused guest can keep inspecting
with matching narration. Seated guests answer/wake while seated and never flip
north to south or reverse their chair. Available seated sprites retain their
calibrated view; independent head-turn artwork is not available. Other test
cutouts retain their existing orientation. Conversation presentation does not
change historical testimony, settled position, activity RNG or difficulty clues.

Guest rendering and original-background foreground masks share painter order,
using standing feet or seated contact depth. Question popups sit below the room's
main guest area so the posture remains visible. Standing near a guest's reachable
approach enables the actual question callback even when their seat is inside
blocked furniture. Notebook, glass/weapon inspection, collection, assembly, danger
and accusation all use the same case state as the existing investigation.

Validation: 26 Python import/layout tests; 382 conversation-presentation checks;
21,027 painted guest-runtime assertions across 75 cases; and 201 native scene
checks completing two walked investigations from collected evidence through
accusation. The two end-to-end routes freeze relocation/refusal/death for stable
interaction regression; they are not default-risk win-rate or fun measurements.
Existing 155 runtime, 161 blockout and 162 unpainted scene checks also pass.
GPU captures of actual painted cast placement and seated questioning were
visually inspected under `test-results/house-investigation/painted-*.png`.

The older sections below describe the original unpainted investigation and its
initial integration history where superseded by this section.

Run `tools/run_house_blockout.ps1 -Investigate`, or open
`src/blockout/house_investigation.tscn` in Godot and press F6. The original blockout,
existing mansion launch and earlier four-suspect lab remain separate.

The default is six suspects, Normal, seed 2. This seed includes both Char and Chris.
Changing the seed produces a repeatable case with a different cast, culprit,
alibis, clue locations, guest starting rooms and personalities. Easy, Normal and
Hard are playable. The generator supports 4–8 suspects, but this ten-room layout
hosts six. Hard needs a live staring guest to expose the murder-room floor trace.

## Playing

Walk with WASD/arrows. Cyan marks room doors; gold marks an item; purple marks
guests who do not yet have artwork. Char and Chris use their approved art. Walk
close to a guest or item, then use the sidebar buttons or E. Inspect floors from
within a room. E also uses the exposed Library secret panel and passage exit.

Find and take the magnifying glass first. It lets you identify the marked weapon
and crime traces. Question guests and compare their accounts in the notebook (N).
Answered questions repeat the same facts; some guests refuse, allowing another
attempt. Personality changes their introductory wording.
The notebook contains only observations you obtained, without a suspect shortlist
or automatic solution. The existing notebook-assistance options are not yet ported.

Taking the weapon requires identifying it. Carrying it is enough to assemble the
guests; there is no all-accounts or known-room checklist. Choose a person and room
in the accusation dialog. A correct accusation wins. Wrong person, wrong room,
or both wrong ends the case and reveals the full truth. Restart/replay or choose
another seed to begin again. Opening dialogs pauses walking.

Guests remain stationary throughout each room visit. Entering another room resolves
a chance that they had relocated; there is no NPC walking. Walking separately advances the clock.
Persistent suspicion and stalking warnings precede room-entry danger. Halls are
safe. Inspecting, reading and standing still add no steps. There are no saves yet.
The map's secret panel is exposed for review; concealment remains future work.
See [guest and danger rules](HOUSE_RUNTIME.md) for exact settings and simulator differences.

## Approved art in Godot

Char and Chris have directional sprites, remaining stationary at authored spots and switching to
talking, downward-looking, reading or upward-looking poses as appropriate.
Settled facing comes from the map's guest spot. Other guests keep temporary markers.
The `Char / Chris pose viewer`
button lets you preview all 81 indexed poses for each character, including reveals,
seated, kneeling and lying art. Previewing a pose does not change case facts.
When Char or Chris is revealed as the murderer, their approved resigned shrug
accompanies an accusation ending; their threat pose accompanies an ambush.

Original PNGs are unchanged. The loader verifies each selected export's indexed
SHA-256. Room sprites use the existing shared character renderer's opacity bounds,
torso/feet pivot and adult-height setting, with one south-idle standing reference
per character. Textures are loaded lazily with an eight-entry cache. This is initial
standing presentation; seated/lying furniture contacts, masks and general activity
selection remain uncalibrated. The pose viewer displays those assets separately.

## Generator parity and validation

`src/mystery/seed_stream.gd` reproduces the Python version-2 SHA-256 streams using
unsigned byte-wise modular arithmetic. `generated_case.gd` ports the generator and
independent solver. Generator room labels remain identical to the reference for
parity; the playable session binds their indices to the actual nine authored room
names, with the secret passage last. Room IDs such as `kitchen` (the Study) are
never substituted for display names.

The runtime needs no Python or design worktree. Reproduce checked-in fixtures with:

```powershell
.venv/Scripts/python.exe tools/export_case_fixtures.py --reference .claude/worktrees/case-design/tools
```

The exporter reads Claude's authored Python reference without modifying or merging
that local branch. Source hashes are stored in `tests/fixtures/case_design_v2.json`.
It includes 795 cases covering 4–8 suspects, all three difficulties, 53 seeds
(including negative/large values), plus 44 RNG sequences and partial-evidence solver
expectations.

Run the configured Godot executable headless with each `--script`:

- `res://tools/generated_case_checks.gd`: 15,374 checks, exact Python generation,
  RNG, partial and full solver parity, uniqueness and cosmetic independence.
- `res://tools/house_case_checks.gd`: 2,562 checks over 80 base cases, inspection,
  collection, repeated accounts, learned-only solution and all accusation outcomes.
- `res://tools/house_investigation_checks.gd`: 162 checks; two controlled cases walked
  through real geometry using the actual interaction callbacks, secret route,
  nearby selection, assembly UI, art loading, spot facing and pose-viewer availability.
  The old route regression freezes wandering/refusals/risk explicitly; live-runtime
  checks cover Hard selection, warning/stalking HUD and guest location synchronization.
- `res://tools/house_runtime_checks.gd`: 155 focused checks for stationary room-entry snapshots,
  reproducibility, phase thresholds, safe halls, ambushes, refusals and Hard clues.
- `res://tools/house_blockout_checks.gd`: 161 existing geometry/transition checks.

The investigation harness can run graphically with `-- --capture-ui`; local
screenshots of dialogue, accusation and the Chris pose viewer are in ignored
`test-results/house-investigation/`. Screenshots were visually inspected; human
playtesting is still needed for clarity and fun. The solver is used by tests, not
as an automatic-win feature in the playable UI.

Next: human pacing/playability feedback, then fuller personality dialogue. Current
clock choices and reconciliation are documented in [House runtime](HOUSE_RUNTIME.md).
