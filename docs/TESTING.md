# Testing and validation

Guest occupancy (2026-11-16): **31,507** checks pass across180 worst-crowd
starts on both layouts, all three difficulties, false alibi pairs, replay and12
relocation snapshots per case. All tested starts separate claimed partners;
later relocation may reunite them, with a two-guest limit. Gatherings still fit
six. Runtime158, painted guest20,501, danger446 and aggression6,865 pass.
Older danger fixtures now stage at most two guests.

Character pronouns/briefing (2026-11-16): **2,071** focused pronoun checks pass
for all15 characters and independent victim/accused/partner/speaker roles;
**955** dialogue checks pass against432 independently migrated expected strings.
Existing dialogue session1,094, guest presentation406 and personality pose497
checks pass. Opening screen **34 headless and34 native** checks pass, including
paused danger, no solution slots, approved/temporary portraits, reveal/dismissal
and restart. Inspected `test-results/case-opening/game.png` and gendered room
narration captures. Painted walking249 and default entry6 checks pass.

Win sound/random floor placement (2026-11-16): **7** win-audio checks pass,
including exact supplied MP3 hash, single playback, correct-accusation-only trigger
and new-case stop. Clip duration3.024s. Placement checks **26,665** pass across both
layouts and 100 seeds per room: reachable collision-clear points, no door/mask
overlap, seed replay stability, position variety and unchanged authored layout.
Each painted room produces 50–96 distinct sampled positions. Existing full walking
checks pass **218** unpainted / **249** painted, two cases each, using actual item
positions; presentation390, dialogue73 and inventory142 pass. Native F5 entry6
checks pass and its new item location was visually inspected. Earlier audio-active
harness shutdown warnings prompted explicit scene-exit audio cleanup; focused win
and entry checks after cleanup emitted no such warning.

F5/timing correction (2026-11-16): configured-main-entry checks pass **6 headless
and 6 native GPU** assertions without layout flags: painted rooms, active six-guest
case, ten items, random startup, no debug/forced-killer mode. Inspected native
`test-results/main-entry/game.png`. Encounter UI **17** passes, including dialogue
starting at sting onset while the audio remains playing. The old main scene was
`playable_mansion.tscn`; only the main-scene setting changed in project settings.

User-selected MP3s (2026-11-16): audio/typewriter **20** and encounter sequence
**17** checks pass. Both runtime files match supplied SHA-256 hashes, decode and
play once. Door length1.896s, sting8.328s; dialogue waits for sequential playback
instead of the old fixed synthesized-cue duration. Source paths/hashes recorded
in `assets/audio/SOURCES.md`. Native audio probe logs are in
`test-results/selected-audio/`; no original-game audio or image changes.

Independent difficulty attacks (2026-11-16, supersedes forced-cap results below):
**6,865** checks pass across 600 question and 600 entry cases. Exact seeded-RNG
comparison confirms no forced attacks. Entries and ordinary questions use Easy15%,
Normal20%, Hard25%; only true-weapon questioning uses50%. Safety/phase gates remain;
danger447, clock36 and runtime155 regression checks pass.

Louder cue: PCM peak29,883 remains below clipping; player attenuation changed from
-10dB to0dB. Native measured bus peak about-1.4dB, master unmuted. Louder WAV sample
is `test-results/ambush-audio/three-hit-sting-louder.wav`. Audio/typewriter19checks
pass; pause test uses configured timing, preserving Claude's faster text settings.

Aggressive solo encounters (2026-11-16): new **2,322** checks pass across 100 seeds
per held state. Empty/glass/ordinary item: 2.73 eligible questions average, maximum
4; true weapon: 1.78 average, maximum 3. Verified base25%/weapon50%, actual pickup,
combined question/entry miss budget, no reset from object switching or safe exits,
and preserved calm/witness/hall/frozen protections. Same-room waiting/walking still
does not roll. Existing danger **447**, weighted clock **36**, runtime **155** pass.
These are controlled eligible-encounter samples, not whole-mystery win-rate results.

Weapon/glass ambush investigation (2026-11-16): **1,203** read-only scratch checks
pass. All **100** identical-phase/solo-room weapon/glass pairs attack on the same
eligible question attempt (mean 9.53, longest 62). Same-room waiting/walking does
not create attack rolls; real room entry and culprit questioning do. No held-item
gate or glass-only unlock reproduced, and probabilities remain unchanged. Evidence:
`test-results/ambush-hold/checks.json`. Native audio probe confirms an unmuted
default output, 1.35s sting, measured bus peak about -14 dB; exported local listening
sample is `test-results/ambush-audio/three-hit-sting.wav`. This verifies signal
playback, not the user's system speaker volume or perceptual sound quality.

Personality presentation (2026-11-16): **418** preview/confession checks, **74**
eight-case UI checks and **497** approved world/portrait pose checks pass. All
eight voices and 48 new confession templates are covered. Existing presentation
checks **406** and authored dialogue **955 / 432 fixture strings** pass. Native
captures `test-results/personality-ui/Char-curious.png` and `Chris-nervous.png`
show matching thinking/fidget portraits and authored voice text. No artwork or
Claude dialogue/source edits were overwritten; phase calm is distinct from personality.

## Encounter, notebook and single-knife corrections — 2026-11-16

Focused checks pass: single-knife catalog **4,657 / 270 cases**; notebook **15**;
typewriter/audio **19**; collision-aware ambush approach **27**; native encounter
UI **17 headless / 17 GPU**. Native captures under `test-results/encounter-ui/`
show the full floor/wound popup, evidence-first Summary, in-room approach and
partially revealed ambush dialogue. Final captures refresh HUD state before
rendering, so case labels correspond to the staged fixture.

Regressions: core case **3,362**, session **1,430**, item art **136**, unpainted
walking **218**, painted walking **249**, play presentation **390**, killer preview
**43**, dialogue UI **73**, inventory UI **143** all pass. Walking checks complete
two cases per layout. Reference generator remains unchanged; actual catalog item
kinds/stains are authoritative for this single-knife playtest.

The wound was previously clipped in a 34px HUD strip; session state already stored
the discovery. No state-loss bug was reproduced. Notebook now exposes blood room
and wound before accounts and always resets to Summary. Encounter checks confirm
approach, sting-before-dialogue timing, gradual reveal and Space-to-finish without
rewriting authored text or case facts. Cue duration is 1.35s, non-clipping PCM;
listening quality and human encounter pacing still need user review. No approved
art or dialogue JSON changed in this correction; Claude owns the pending item text.

## Single-slot inventory/lens port — 2026-11-16

Final focused runs: full-field generator parity **10,503 checks / 900 cases**;
inventory/lens session **1,430 / 36 cases / all five outcomes**; weighted clock
**36**; dialogue **957** including **432 exact first/repeat strings**; silent
refusals **690** over **48 authored lines**. All passed.

Migrated rule regressions pass: core case **3,362**, danger **447**, assembly
**2,951**, dialogue/session **1,094**, original walking integration **216** and
painted walking integration **247**, each with two complete cases. The walking
routes identify the weapon from observed stains/kinds/wound rather than truth.
Guest runtime **21,027**, play presentation **390**, dialogue UI **73**, art
mapping/hash checks **416**, killer preview **43** also pass. Existing PNGs remain
unchanged; 38 named variants use existing type artwork.

`tools/lens_ui_checks.gd` passes **142 headless and 142 native GPU** assertions:
real item selection/take/drop callbacks, portable glass and stains, arbitrary hall
drops, stacked-item chooser and exact recovery, hands-full controls, notebook
without automatic weapon answer, same-room gathering with a decoy, post-gather
drop/recovery, final empty-hand block and visible wrong-weapon correction. Inspected
native captures under `test-results/lens-ui/`: stain, notebook, stack, wrong-weapon.
Visible action bounds fit the viewport. Commands use the painted investigation
layout and optional `--capture-ui`; no index was created/changed.

Remaining: human held-key/control feel, clue clarity and clock/difficulty tuning;
variant-specific art; explicitly marked missing dialogue; packaged export and save
migration are not established by these checks. The current painted playtest has
no inventory save/load feature. Updated local game opened for user review.

Confession role wording (2026-11-16): **957** dialogue checks and **861** session
checks pass. Three regressions render Char/John with distinct killer/victim roles;
all 432 first/repeat fixture strings remain exact. Updated reviewed personality
hash accounts for only the three corrected confession/correction templates.

North-facing conversation portrait correction (2026-11-16): **406** presentation
checks and **70** native GPU dialogue UI checks pass. Portraits expose the face
while north-facing seated/world poses remain unchanged; downcast mood is preserved.
Inspected `test-results/dialogue-ui/north-face-portrait.png` above the text box.

Guest portrait restoration (2026-11-16): **68** focused dialogue UI checks pass,
including all 15 speaker identities, approved/current seated pose, refusals,
above-dialog bounds and cleanup on close/item/system text. Native conversation
capture `test-results/dialogue-ui/warm-first.png` inspected: enlarged guest above
text, no text occlusion. Killer playtest checks: **112** seed-selection assertions
and **43** scene assertions pass for six alternating Char/Chris cases, unchanged
generated facts, actual ambush/accusation art and fixed replay after expiry.

Current-room gathering correction (2026-11-16): **2,949 headless / 2,950 GPU**
assembly checks pass. All ten ordinary painted spaces fit six guests; the narrow
secret passage rejects without moving anyone. Kitchen remains Kitchen, including
after cached plans for other rooms. An artificially blocked room leaves progress
and guests unchanged. Native `test-results/house-investigation/assembly-kitchen-preview.png`
shows all six guests and investigator, with no overlap or mask hiding. Full walked
mystery checks pass **215** painted / **164** unpainted. No alternate-room fallback.

## Painted doors and final gathering — 2026-11-16

Focused Godot checks passed: painted door approaches **581** (72 crossings:
center and ±15px offsets for all 24 directed doors); painted end-to-end **217**
(two complete walked mysteries, separate gathering/accusation, locked exits and
free movement); unpainted investigation **164**; assembly **2,924** headless and
**2,925** GPU across 20 seeds on both layouts; refusal wording **402**; dialogue
session **861**; dialogue UI **36**; play presentation **390**; solo-killer danger
regression **422**. No failures in final runs.

Inspected native `test-results/house-investigation/assembly-preview.png`: all six
living guests and investigator visible, no furniture-mask occlusion or overlap,
accusation menu withheld until requested. Corrected a phantom item interaction
after pickup. Broader trigger lanes required the test route planner to avoid
outward edges through unintended doors; the revised routes pass. Human held-key
door feel remains a manual playtest. Updated painted game opened for that review.

## Placeholder case lab — 2026-10-25

Second iteration after human feedback that the first seeds were similar and easy:
**30 targeted pytest tests passed; 3,714 native checks across 200 cases** (100 seeds
per family). The new timed-access family is deterministic, uniquely solvable from
obtained evidence and independent of hidden-answer fields. Removing time or access
leaves two possible suspects; testimony alone leaves more alternatives. Both attack
windows are exercised. Gameplay and JSON saves cover both families and all three
notebook modes; Classic stores no automatic notes. Bound UI checks cover the opening
setup, independent settings, raw Standard observations and Assisted comparisons.

The owned preview opened on seed 4, showing the new-game settings. Native screenshot
`test-results/screenshots/case-lab-start-cc6a7d273d.png` was visually inspected; labels,
descriptions and start/load controls fit. It remains open for human testing. The
new settings currently apply to the lab, not the mansion scene. Existing v1 lab saves
are preserved; the new generator uses a separate v2 slot. No new art or HTML index.
Human feedback on the second structure, notebook usability and difficulty is pending.
This remains a constrained two-pattern lab without danger or NPC schedules.

First iteration evidence (before the second family and notebook settings):

`pytest tests/test_case_lab.py tests/test_server.py tests/test_original_navigation.py -q`:
**30 passed**. The native Godot lab harness passes **2,508 checks across 100 seeds**,
with 97 distinct claim/room/weapon bindings, all four culprit roles, all four crime
rooms, both false-claim variants and weapon/crime-room co-location represented.
These are bindings within one case family, not 97 structurally different mysteries.

The validator receives only observed testimony/physical propositions. Tests change
the hidden culprit and voice bindings without changing its inferred candidates,
reject a hidden answer inconsistent with clues, retain alternatives when evidence
is absent, and reject contradictory physical observations. Gameplay checks exercise
connected room travel, glass collection, testimony and stable recaps, object/floor
inspection, delayed weapon collection, wrong triples, a clue-derived correct ending,
JSON save/restore and rejection of altered saved testimony. UI checks instantiate
the real scene and activate connected glass, room and question buttons, verify the
notebook updates, and reset to another seed. A JSON number-type restore bug was
found and fixed during those checks.

The actual lab window was launched with the official MCP client, reached its own
ready state and produced a viewport capture. The refreshed comparison-notebook UI
was visually inspected at 960x720 logical / 1280x960 window size. Current capture:
`test-results/screenshots/case-lab-start-4f6a94f670.png`. The preview session stays
owned while the user plays and stops when its window closes. The existing mansion
save and default scene are separate. No new image assets or review index were made.

Human feedback subsequently confirmed that these cases felt similar and easy,
prompting the second iteration above. Automated consistency does not establish fun, pacing or a
10–15-minute duration. This version has no danger timer or autonomous NPC schedule.

## Focused behavioral study — 2026-10-25

Research-only update; no runtime/adapter implementation changed. A bounded official
MCP session finished in 53.82 seconds and confirmed the glass pickup before its
study. Screenshots at baseline, four/eight seconds of passive waiting and after
questions/search show unchanged marker positions. Re-entry shows the same piano
anchor/activity with a different named occupant; both entry captures were inspected.
Six short questions produced five consistent alibis and one transient refusal;
the next question after that refusal succeeded. One guest search found nothing.
No weapon pickup, gathering or accusation occurred; the owned process was stopped.

Local record: test-results/original-research/behavior-2ee94a3d/case-5.json. Comparison
of the four previous survey transcripts is recorded locally in dialogue-comparison.json:
67 parsed alibi replies, nine manually checked refusals, and one consistent claim
per observed speaker/case combination (15 combinations). Including the focused
study yields 72 answered claims and ten refusals across 82 asks / 16 combinations.
These are sample descriptions, not fitted probabilities or proof of an RNG rule.
The private study driver is an observation aid; the complete playthrough/ending
was intentionally not attempted. Documentation was checked with `git diff --check`;
no gameplay tests were rerun for this research/prose-only change.

## Original navigation and investigation survey — 2026-10-25

`python tools/dos-game-mcp/research_original.py --cases 3` completed all three
planned surveys through the official MCP client: wide/split/wide layouts,
75.14/67.21/81.26 seconds, 532 movement keys, 15 guest encounters and 60 captured
question/alibi responses. All three introduction/roster fingerprints differed.
The split-floor stair transfer and sampled dialogue were checked against captures.
These are navigation and dialogue samples, not wins or complete suspect coverage.

After the user's workflow clarification, one additional live survey first confirmed
the glass pickup, then completed inspection/interview routes in 136.48 seconds:
328 movement keys, 16 responses, 12 object/floor examinations. The displayed text
identified both a weapon and murder-room bloodstains. Only `get magnifying glass`
was sent; no weapon pickup, assembly or accusation occurred. The new policy fails
closed if no glass is found on the visible route. The test used full examination
commands; the later shortening to `q` / `ex` and head-noun keywords is unit checked
and uses command aliases established by the user and earlier observations.

`pytest tests/test_server.py tests/test_original_navigation.py -q`: **28 passed**.
Coverage includes movement verification and wall stops, map doorways/intermediate
columns, odd/even guest-column approach, both-layout connectivity, malformed-map
rejection, glass-first gating, pickup confirmation and weapon-pickup rejection.
All owned processes were stopped. Local evidence: original-research/cb946831c391
and original-research/f10633b3fd19 under ignored test-results. No original assets
or dialogue transcripts were added to tracked files.

## DOS text adapter — 2026-10-25

Replaced the unstable clipboard experiment with the installed DOSBox-X debugger
control protocol. The private loopback connection exposes only the BIOS display
page offset and its 4,000-byte visible color text page. No original executable is
changed or disassembled; no solution variables, CPU state or arbitrary memory
commands are exposed. Host clipboard access was removed. Supported protocol is
[documented by DOSBox-X](https://github.com/joncampbell123/dosbox-x/blob/b6abbd5/README.debugger).

`read_original_screen` returns the 80x25 text grid. Blank transitional screens
return an explicit retry error. `original_command` checks for an idle gameplay
prompt, sends an allowlisted command to the owned HWND, then waits for a stable
prompt. Menu input uses `send_game_input`; verified walking uses `original_move`. Original
`look` was observed to be rejected by the game; the adapter reports that response
without interpreting it as a successful gameplay action.

Live official-MCP smoke: three independent case starts, different guest rosters,
and nine captured responses (`guest`, `look`, `gather` per case), initially
0.595–0.726 seconds per command. After adding prompt/stability checks, one further
case passed all three commands at 0.843–0.972 seconds each. Title and gameplay
screenshots agree with text captures. This verifies transport and short command
cycles, not solved cases, autonomous navigation or 50 playthroughs. Every owned
process was stopped. Captures, emulator copies and response transcripts remain
ignored under test-results.

`pytest tests/test_server.py -q`: 18 passed, including both MCP discovery modes,
protocol framing/disconnect/error handling, fixed display-page selection,
unsupported memory-command rejection, menu input gating and owned-process limits.

## Original dialogue data audit — 2026-10-25

`python tools/audit_original_dialogue.py` verifies all 33 archive entries against
the preserved inventory and local reference, then checks fixed-width tables:
ALIBI1 36×70, ALIBI2 56×188, ACT.V1/V2 120×55 each, WEAPN.V1/V2 33×220 each,
including delimiters, trailing padding, manually identified confession slots and
empty object slots. Full decoded output is restricted to ignored test-results.
No original executable/script ran or was decompiled; no new runtime observation
or gameplay regression result is claimed. See DIALOGUE_RANDOMIZATION_DESIGN.md.

## Char alignment_01 review assets

Seven separate built-in image-generation jobs produced transparent masters. The native Compatibility review tool completed without Godot errors, verified pixel-preserving blank padding, and captured a comparison, three contexts and a closeup sheet. `python tools/validate_char_alignment.py` passes source/input hashes, seven RGBA assets, padded pixel recovery/margins, contact offsets, common scale, shorter seated extents, exact furniture IDs and five image dimensions. Reports: `test-results/char-alignment-review.log` and `test-results/char-alignment-validation.json`. No runtime code or game integration changed, so the full gameplay suite was not rerun. The user subsequently approved the seven artwork samples. Masks, collision/navigation/occupancy and actual fit remain pending. See [the review](CHAR_ALIGNMENT_01_REVIEW.md).

## Character pose planning audit â€” 2026-10-23

This documentation/metadata task produced no artwork, renderer change or gameplay
implementation. The derived inventory records 45 concrete pose IDs, 34 semantic
families, all 209 room contacts (163 enabled / 46 disabled), and all 84 orientation
IDs (38 currently used). Current native Godot capture evidence agrees with every
enabled contact's pose IDs and local-clearance result: 102 clear / 61 blocked.
Zero contacts are staging-approved. Char's seven proposed alignment jobs have no
executed generation prompts, tool calls, outputs or approvals. Her manifest links
the planning deliverables and preserves the existing identity reference hashes.

Validation commands:

```powershell
python tools/audit_character_poses.py
python tools/audit_character_poses.py --check
python tools/validate_character_pose_audit.py
```

The validator checks native-report parity, complete CSV/JSON correspondence,
source/family/pose references, unique seven-sample batch IDs, locally clear first
seat approaches, artifact/source hashes and documentation links. It does not
validate art, pose fit, path reachability or future event selectors. Results are
in `test-results/character-pose-audit-validation.json`. Existing native capture
evidence was reused because room data and runtime code were unchanged. The full
gameplay regression suite was not rerun for these documentation-only changes;
the previous completed runtime milestone is recorded below.

## Previous room furniture coverage

Latest room furniture coverage: **43 tests pass** in the full suite (59.34 s).
The furniture harness passes **616 engine/editor assertions**, including all 18
rooms, 14 registered backgrounds, unique room-scoped IDs, 84 orientation IDs,
mouse-driven calibration/save/reload and disabled-contact behavior. The official
MCP SDK owned-window smoke passes the expanded eight foyer IDs, F6 toggle,
overlay capture and clean Godot diagnostics; it stops its owned game process.

The native Compatibility renderer captured **18 individual 1440x960 tagged room
screenshots and three 1440x1560 floor sheets** without Godot errors. All three
floor sheets and dense dining/bedroom/storage examples were visually inspected.
Gold bounds and numbered legends identify furniture; orange/cyan marks identify
draft contact/approach points. All 118 unique tags remain unapproved for automatic
staging. There are 149 room-scoped instances; 102 of 163 enabled room contacts have
a clear local approach footprint under current colliders. This is not a pathfinding
or pose-fit approval; remaining contacts need calibration and/or navigation changes.
No NPC placement, collision, room connectivity, character artwork or animation was
changed. Char's 42 planned requirements include seven initial alignment samples;
these are planning records, not newly generated poses.

Reports: `test-results/furniture-tests.json`, `furniture-mcp.json`,
`tagged-room-coverage.json`, `tagged-room-capture.log` and `pytest.xml`.
Review [TAGGED_ROOM_SCREENSHOTS.md](TAGGED_ROOM_SCREENSHOTS.md) and
[CHAR_POSE_PLAN.md](CHAR_POSE_PLAN.md). The tag bootstrap was rerun and added zero
duplicate tags; existing mapper calibrations were preserved, with the locked front
door's exterior contact explicitly disabled.

```powershell
python tools/open_furniture_mapper.py
.venv/Scripts/python.exe -m pytest tests/test_furniture.py -q
.venv/Scripts/python.exe tools/dos-game-mcp/smoke_furniture.py
```

Latest character prototype: **39 tests pass**, including **1,560 character/occupancy
assertions** over 64 NPC seeds. The character harness also passes with the real
Compatibility renderer. Reports: `test-results/character-prototype-tests.json` and
`test-results/character-prototype-gui.log`; screenshots are in
`test-results/character-prototype/`. The owned-window MCP smoke records targeted
keyboard movement, Eleanor questioning, lens/library investigation and reset/cleanup
in `test-results/remake-smoke.json`. See [CHARACTER_RENDERING.md](CHARACTER_RENDERING.md)
for scope and remaining animation/background limitations.

```powershell
.venv/Scripts/python.exe -m pytest -q
# Configured Godot executable, headless or with --capture for native screenshots:
godot --headless --path . --script tools/character_prototype_checks.gd -- --npc-seed=20261023
.venv/Scripts/python.exe tools/dos-game-mcp/smoke_remake.py
```

Previous fixed-house integration: **38 tests pass**, including **222 actual-physics
walking/investigation assertions**. The same checks pass with the Compatibility
renderer, producing native captures of all 18 spaces. Every directed doorway/stair
endpoint (44) is walked, and save/load is checked from another floor. See
[FIXED_MANSION.md](FIXED_MANSION.md) for scope, reproducible commands and art gaps.
The earlier blueprint-only counts below describe historical validation.

Validated on 2026-10-23, America/Denver. Reports and captured reference material are
local and excluded from Git. No game binaries or captures should be published.

Latest blueprint validation: **34 automated tests passed**, exit code 0, including real stdio
discovery in modern and legacy modes. The original-game baseline exercised all 15
tools before the remake existed. The separate remake smoke now validates the real
launch, keyboard movement, inspection, captures, reset and process cleanup. Mouse
support still correctly returns unavailable.
The original title, main menu and Basic Sleuth entrance screen were captured and
visually inspected. The archive SHA-256 still matches the initial reference hash.

## Repeatable commands

Blueprint additions: tests/test_mansion_blueprints.py validates all four physical
door graphs, opposite ports, non-overlapping cells, aligned stair shafts and complete
reachability after removing either shaft. A real Godot run passes 180 compact-layout session checks:
seed reproduction, stable art, stair reversal/floor memory, JSON round trips, room
memory and corrupt-state rejection. Twelve rendered review captures cover all floors.
The checks include actual save-file write/read/replacement, arrival-port ownership
and map browsing without changing the current logical floor. The real-window foyer
smoke passed with startup blueprint metadata and stable selection during movement,
while preserving the clock, Eleanor, reset and owned-process cleanup checks.
These are logical topology/session tests, not physical walking or collision tests
for the unconnected new room paintings. See MANSION_BLUEPRINTS.md for the boundary.

Compact revision: each plan now has four functional rooms and two hallway/stair
spaces per floor. Tests reject the former oversized-plan save schema and verify
that the north front door is locked, has no destination and cannot be traversed.
The foyer's fourteenth engine assertion verifies its locked-front-door response.
test-results/screenshots/foyer-locked-front-door.png was rendered and inspected.
The previous real-window smoke predates the dialogue-only wording change; current
foyer engine checks and the native door capture cover that change.

Environment additions: tests/test_environments.py validates 18 assets and invokes
24 real Godot review checks. All 36 native/2x actor preview captures were rendered
and inspected; assets/rooms/review/asset-checks.json records dimensions, alpha,
unique hashes and paths. ENVIRONMENT_ASSET_QA.md details the visual review and the
remaining gameplay collision/transition boundary.

Run from the project root:

```powershell
.\.venv\Scripts\python.exe -m pytest tests -q --junitxml=test-results/pytest.xml
.\.venv\Scripts\python.exe tools/dos-game-mcp/smoke.py
.\.venv\Scripts\python.exe tools/dos-game-mcp/smoke_remake.py
codex mcp get sleuth_game --json
.\.venv\Scripts\python.exe tools/dos-game-mcp/verify_codex.py
```

Pytest does not launch the original. The explicit smoke client does: it starts the
stdio server, discovers tools, launches an owned DOSBox-X window, waits eight seconds,
captures the title, sends ENTER twice to accommodate title timing, captures the menu,
presses A, captures Basic Sleuth, restarts, captures again and stops the owned process.
It runs the fixed pytest suite through MCP and reads its persisted results. Test
reports: `test-results/smoke.json`, `latest-tests.json`, `pytest.xml` and the
`run-*/emulator.log` files. Every smoke invocation adds a fresh run and unique captures.

## Actual tool coverage

| Tool | Validation performed |
| --- | --- |
| inspect_game_archive | Real 33-file ZIP, expected SHA-256, no execution |
| get_game_environment | Real host/runtime/path/capability report |
| get_project_status | Current tree, tests and playable foyer status |
| launch_original_game | Real DOSBox-X window, title and Basic Sleuth captured and inspected |
| launch_remake | Real Godot foyer, verified owned HWND and readiness state |
| get_game_status | Not launched, live owned HWND/PID and terminated exit status |
| stop_game | Actual emulator terminated and waited; unrelated-process safety test |
| send_game_input | PID-targeted original menu input and remake movement/inspection, verified by live state; unsupported keys and durations rejected |
| send_mouse_input | Explicit unsupported result; no global mouse injection |
| capture_game_screenshot | Original PrintWindow PNGs and Godot viewport PNGs; foyer and clue panel visually inspected; absent game rejected |
| reset_game | Original fresh copy; remake fresh process resets player and clue state |
| read_game_logs | Bounded real emulator/Godot output and its actual path |
| run_project_tests | Real subprocess suite via MCP, exit code, timeout bound and JSON/JUnit evidence |
| get_test_results | Read back matching saved exit code and test summary |
| compare_game_screenshots | Real capture compared with itself, synthetic changed pixels/dimensions, unsafe path rejection |

SDK clients exercised both automatic protocol negotiation and legacy initialization
over real stdio subprocesses. Malformed game enums are rejected by SDK input validation.
Tests cover traversal, drive/absolute names, Windows devices, alternate data streams,
unsafe ZIP names, symlinks, case collisions, overwrite refusal and reference hash.
They also check missing executables, nonzero child exit, command deadline expiry,
emulator startup failure/timeout cleanup and stopping only a tool-owned process.

The first run exposed a ZIP path-normalization test issue and SDK structured-output
annotation issue. Both were corrected; final runs must be read from latest-tests.json,
not the retained initial failure report. No remaining test failures are known.

## Codex integration evidence and final desktop check

`codex mcp get sleuth_game --json` recognizes the project server without changing
global configuration. `verify_codex.py` feeds those returned settings to the installed
Codex app-server and requests `mcpServerStatus/list`; it discovered all **15** tools.
Evidence is `test-results/codex-discovery.json`. No chat or model run was created.
An app-server without a bound chat does not load project context automatically;
the verifier explicitly supplies the loaded server settings as command-line overrides.

This proves Codex runtime compatibility and discovery. It does not prove that the
already-open desktop chat has refreshed its registry. Close and reopen the project
or restart Codex, then check `/mcp`. For a fresh CLI connection, run `codex` from this
project directory and check `/mcp`. Trust the project if the client requests it.
The current conversation cannot hot-add the new tool namespace.

## Limits and troubleshooting

The server runs only stdio, with no listener. Local configuration allowlists the
external archive and emulator; model callers cannot supply alternative executables,
commands or shell text. All caller-supplied image paths stay inside approved project
screenshot directories, including resolved symlink checks. Output filenames are
validated and unique. Raw logs are bounded and are not interpreted as instructions.

Window control requires one visible top-level HWND with the child process's PID.
Key messages go directly to that HWND; they do not use desktop-wide SendInput.
Delivery only confirms that Windows handled the message. Screenshot inspection
confirmed the tested title/menu/A sequence; other keys and full parser behavior
require observation. Software surface rendering was selected so PrintWindow works.
Black/uniform images are rejected, but a screenshot cannot by itself prove semantic
correctness. Captures currently include whatever frame PrintWindow returns.

Games are tracked per server instance. A graceful server shutdown stops owned games;
an abrupt OS kill can leave an orphan which a new instance intentionally will not
adopt or terminate. Stop games before restarting the server. Multiple independent
clients may each have their own emulator, which is safe but potentially confusing.
All waits and subprocess operations have deadlines. Win32 message waits are bounded
per key; key batches are limited to 120. Shutdown uses terminate/kill and waits.

No emulator installation or system-wide automation setup is pending. The existing
interactive desktop was sufficient. Elevated, minimized, locked or remote sessions
may require separate validation. Full sound behavior is untested. Remake launch,
optional remake mouse controls and deterministic mystery scenarios remain pending
for later milestones. Foyer engine checks are now implemented.
Current get_project_status reports the available main scene.

## Playable foyer validation

The pytest suite includes a real headless Godot run of `--foyer-test`. Fourteen assertions
exercise actual CharacterBody2D movement and collision against a wall, the clock and
foreground furniture; opening, closing and repeating the clue interaction; and pausing
movement during dialogue. Five of the assertions cover starting guest questioning,
recording her alibi, returning to the menu, the evidence-dependent clock answer and
releasing the player on exit. Result: `test-results/foyer-engine-tests.json`. Missing
Godot causes a clearly reported skip on machines without the local configuration.

`smoke_remake.py` uses the official MCP client over stdio to launch the configured
Godot GUI binary. On Windows, the console executable is a wrapper which spawns the
GUI as another PID. Using the GUI binary directly is necessary for reliable ownership,
window targeting and shutdown. Both executable hashes are stored by setup_local.py.
An initial wrapper-based launch failed its readiness check; its verified child was
cleaned up. The corrected GUI-based launch and shutdown both passed.

The smoke sends a timed right-arrow hold and checks actual x movement, returns to the
entry, walks left/up to the clock, presses E, verifies clue_found/dialogue_open, saves
the rendered clue panel, presses Escape and confirms it closes. It restarts and checks
the initial position and cleared clue, then stops the exact owned process. Evidence:
`test-results/remake-smoke.json`, per-run state.json/remake.log and unique screenshot
paths inside the report. No global keyboard injection or model-selected commands occur.

The real-window smoke now also walks around the reading stand to Eleanor's window,
opens the question menu through E, asks for her alibi, checks the recorded topic and
actual answer text, returns to the menu and asks about the clock after examining it.
It captures the question menu and alibi, verifies Escape releases the player, and
checks that a restart clears the question history. An initial direct route collided
with the stand; the test route was corrected to walk around it. No collision was
disabled to make the conversation test pass.

A later restart exposed a transient status-snapshot validation failure. The status
reader now revalidates and retries briefly while the snapshot is being replaced,
without relaxing its project-path restriction. A regression test injects a transient
validation failure and verifies the next approved snapshot is returned. The final
26-test suite and real-window conversation/reset smoke both passed.

The camera update adds a default 2x following view and a Z overview toggle. The same
real-window smoke verifies camera_zoom starts at 2, changes to 1 and returns to 2,
then exercises clock inspection with the close view active. Entry, overview and
dialogue screenshots verify the larger investigator and fixed screen-space UI.
The actor's world-space height is 48 logical pixels, independently of the camera.

The remake's development hook is enabled only by the fixed launcher's --dev-session
argument matching `res://test-results/remake-<32 hex digits>`. It writes state and
handles a fixed capture.request filename. It accepts no command code or arbitrary
output paths and opens no network listener. Godot viewport captures avoid graphics
driver limitations of PrintWindow for the OpenGL renderer. Writes use temporary
files and rename when complete. Normal F5 launches do not enable this hook.

The main project uses the Compatibility renderer, nearest texture sampling, a
480 x 360 logical canvas and integer scaling. A separate default-renderer launch
captured `test-results/screenshots/foyer-native.png` at 480 x 360; the real-window
smoke captures at 960 x 720. Both sizes were visually checked. Artwork and generated
prompt provenance are documented in assets/foyer/ASSET_NOTES.md. The reading stand
is placeholder art; baked room lighting and minimal dust are the current atmosphere,
not a dynamic lighting or sound system. Whole-mystery gameplay is not implemented.

## Official API and configuration references consulted

Evidence milestone (2026-10-23): the complete suite passes 36 tests, including 76
headless evidence assertions. A separate actual Compatibility-rendered playtest
passes 39 assertions with Godot keyboard dispatch, collection, tool gating,
innocent controls, notebook, file persistence, invalid-save rejection and all
production variants. Native captures were visually inspected. The existing
real-window MCP smoke passed movement, zoom, clock and Eleanor regression checks.
See EVIDENCE_ASSET_QA.md for exact commands, artifacts and remaining scope.

Character review-v8 verification (2026-10-23): Godot parsed the contact-sheet tool
and rendered both sheets successfully. The gallery validator passed for 17 active
designs, 15 named photo-based identities, 24 views and seven alternate-look cards.
Numbers 16-19 are absent from the active roster; sources remain archived. Art
selections 01-15 match v7, including Sarah Jo's unchanged approved PNG hash recorded
in review-v8/change-checks.json. Jessica and John's cartoon faces and the complete
overview were visually inspected. Runtime assets and gameplay were not changed;
these checks do not establish runtime sprite scale or animation quality.

- [MCP Python SDK](https://py.sdk.modelcontextprotocol.io/) â€” current SDK 2.3.0, MCPServer and stdio transport.
- [SDK testing](https://py.sdk.modelcontextprotocol.io/get-started/testing/) and [client transports](https://py.sdk.modelcontextprotocol.io/client/transports/) â€” supported Client API.
- [Serving legacy clients](https://py.sdk.modelcontextprotocol.io/run/legacy-clients/) â€” compatibility testing.
- [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli) â€” project-scoped stdio configuration and MCP management commands.
- [Codex configuration basics](https://learn.chatgpt.com/docs/config-file/config-basic) â€” trusted project configuration.
- [Godot CharacterBody2D](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html) and [custom 2D drawing](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html) â€” movement, top-down motion mode and drawing APIs.

The installed Codex CLI's generated app-server JSON schemas, held under
`test-results/codex-schema/`, established the exact discovery request fields.

## Directional next-phase planning validation â€” 2026-10-23

No art or runtime implementation was produced. SHA-256 comparison confirms all 112
existing character PNGs are unchanged, including the seven approved masters and
seven padded exports. Directional index validation checks all seven IDs, directions,
scoped approvals, file hashes and exact furniture contact references. The pose audit
check, contact/native-evidence parity validator and Char alignment validator pass.
Reports: `test-results/next-phase-planning-validation.json`,
`test-results/character-pose-audit-validation.json` and
`test-results/char-alignment-validation.json`. Native images/logs are previous review
evidence, not new runtime tests. No new screenshots or full gameplay run were needed
for this documentation/metadata change. Runtime contact calibration remains pending.

## Image approval and cleanup â€” 2026-10-23

Explicit approval preflight passes Char's 14 approved source/export files and the
four finalized detective frames. Negative checks reject missing/pending approval
and a changed approved hash. The Godot alignment exporter exits with code 2 and
IMAGE_APPROVAL_LOCK before any writes when a batch contains approved samples.
No new image generation, resampling or gameplay logic changes occurred.

The focused detective/character/environment/evidence/furniture/fixed-house/blueprint/
foyer suite produced 17 passes and one obsolete assertion requiring a duplicate
original PNG. That assertion now protects the canonical original using its recorded
hash and manifest path; its focused rerun passes (18 relevant tests passed in total).
Approved images and all other retained assets/reference images are byte-identical.
Markdown links and literal runtime asset references resolve; formatted screenshot
output templates are not missing input assets. Pose-audit and alignment validators
are rerun after refreshing retained-artifact fingerprints. Reports are under
`test-results/image-approval-validation.json` and `test-results/asset-cleanup-validation.json`.

## Directional folders and side-contact integration â€” 2026-10-23

Furniture catalog regeneration and native Godot furniture/editor tests pass after
adding side anchors and gaze-target transform/validation checks. Graphical Godot
Compatibility capture refreshed all 18 tagged rooms and three floor sheets without
script errors. The review gallery now includes facing arrows, gaze targets and exact
contact tables. Char's seven exports were moved and consistently renamed; approval
preflight still verifies the same source/export hashes. The full pose/contact audit
is updated to 247 room contacts, 201 enabled, 47 concrete pose IDs. All staging flags
remain false; locally clear endpoints are not pathfinding or sprite-fit approval.
Each relevant index.html is opened and linked for user review under the project-wide
rule. See test-results/directional-assets-side-contacts-validation.json for checks.

## Opt-in Char live placement test â€” 2026-10-23

F7 starts/finds Char, F8 randomizes her room and approved pose, F10 restores normal
mode. One identity-keyed roster replacement removes the old Char assignment; room
loads remove old actor nodes before spawning current occupants. Shared contact
rendering uses common 64/1673 scale and floor feet independently of chair seat.
All seven approved images remain unchanged. Seated masks/clearance/contact fit are
provisional and require visual review; this is not general NPC scheduling/staging.
Native checks cover 126 room visits, 100 rerolls, all seven poses, contact alignment,
save/load protection and roster restoration. The real owned-window smoke also
captured all seven poses and verified unique live assignments. See CHAR_LIVE_TEST.md
and test-results/char-live-test/index.html. No art approval or image hashes changed.

## HD/readability presentation preview â€” 2026-10-23

User reported Char and the overall game were too small. The internal viewport is
now 960Ã—720, with up to a 1280Ã—960 window, monitor-fit sizing and F11 fullscreen.
Shared adult stature is 80 instead of 64; identity ratios/proportions are preserved.
World/physics/furniture coordinates stay 480Ã—360. The presentation adapter scales
camera/HUD/inspection UI into HD; detail zoom is 1.5Ã— and Z provides full overview.
F7/F8 now focus Char in detail mode instead of forcing overview. Her source masters,
exports, approval hashes and original alignment metadata remain unchanged; 64 in
those source-review records is historical. Runtime source scale is 80/1673.

The live owned-window smoke captured all seven poses at 1280Ã—960 and verified both
Z modes, F11 fullscreen on/off, and one Char assignment. Native checks verify HD
HUD/inspection scaling and preserve contact transforms/unique identity across room
visits/rerolls. Character/foyer/evidence, fixed-mansion, furniture and environment
checks pass. [Presentation comparison](../test-results/presentation-review/index.html)
uses two retained previous-runtime captures and current actual captures; source art
is never resampled. Presentation and chair fit still await user visual review.
Current room backgrounds retain their existing authored pixel detail; the change
increases display/readability, not the detail contained in those background files.


## First authored case and chair fit preview â€” 2026-10-23

F4 opens The Silent Library: three suspects, room-owned rug observation, evidence
gates, statements in the notebook, accusation and written ending. Wrong accusations
allow retries in this prototype. Case progress and roster round-trip through the
fixed session snapshot. The focused native integration run passes 31 checks;
actual Compatibility captures are in test-results/first-case/index.html. Three
Char chair offsets/foreground polygons are preview-only and await visual review.
Approved character PNGs are unchanged. See [FIRST_PLAYABLE_CASE.md](FIRST_PLAYABLE_CASE.md)
for controls, reproduction and remaining group/reveal/randomization work.


## Compact mansion scope â€” 2026-10-23

The active graph is nine unique backgrounds: seven main rooms plus two circulation
spaces. Physics traversal checks sixteen directed endpoints. Char room/pose coverage
is now 63 visits; older 18-room/44-endpoint reports above are historical. Native
current-room captures and explicit art gaps are in test-results/compact-mansion/index.html.
The first case retains all ground-floor evidence and suspect locations.

## Evidence detail rendering â€” 2026-10-24
Native preview tools/evidence_detail_preview.gd passes 23 condition variants: source textures retain more detail and bottom anchors match existing sprites. Captured four inspection before/after pairs and a foyer pair in test-results/evidence-detail/index.html. Visual approval pending; gameplay regression was not rerun for this narrow rendering change. Existing PNGs are unchanged. Raw masters currently load from the project filesystem (masters/.gdignore); a packaged export must explicitly include these PNGs before distribution.


## Revised room furniture tags â€” 2026-10-24
Godot native preview validates all nine registered layouts (126 unique per-layout tags), captures nine screenshots and confirms staging flags are false. All nine selected room artwork approval hashes pass the approval checker. Review generator maps 187 exact contacts including disabled ones to Char pose coverage. Draft anchors, clearance, furniture size, occlusion and Char seating are not fit-approved; no runtime room or character artwork changed. Preview: test-results/reworked-furniture/index.html.


Char revised-library fit: native Godot captured four separate contact candidates, each raw/masked, at shared 80/1673 scale. Source export SHA-256 checks passed. Manually inspected all four; corrected the overbroad red-chair mask and added foreground-chair occlusion at the reading table. Contacts and masks remain visual-review candidates, separate from runtime settings; export packaging and navigation are not tested. See test-results/char-library-fit/index.html.


Approved library live fixture: native harness passes 4 seats plus 20 cycles with exactly one Char, save disabled, no door teleports, valid player spawn, and actual player movement stopping at the desk collider. Captured four actual gameplay views. Source sprite warnings concern raw image loading for packaged export; this is a local project review. Normal mansion routes remain unchanged. Review: test-results/char-library-live/index.html.


Room integration: fixed_mansion_checks.gd passes 102 checks, including all 16 directed passages, safe arrivals/facing, cross-room lens/knife flow and save/load. first_case_checks.gd passes 31 checks after relocating the floor clue out of the new furniture. Native captures cover all nine active spaces. One stair-corridor entry initially caught the player at a corner; widened its feet corridor and reran traversal successfully. Existing source art/poses unchanged; packaging and broad automatic furniture staging remain unvalidated.


Destination labels: refreshed all nine native room captures and visually inspected the library's Main Stair Hall and Dining Room labels. Door/stair logic is unchanged by this presentation edit.

Floor-map local preview: native harness verifies current-floor membership, one highlighted room, valid edge indices and 4/2/1 main-room counts, then captures all three floors. Godot compile/preview passes after adding an explicit integer type to the floor-difference calculation. No gameplay logic or layout changes in this HUD addition.


Opposite-door preparation: tools/opposite_door_checks.gd passes 18 reciprocal linked directions and stationary/wrong-direction/cooldown/no-bounce trigger checks. Four generated room drafts and furnished foyer v2 are saved as separate paths; source dimensions verified 1536x1024 and hashes recorded. This is not live traversal verification: artwork approval and coordinate calibration remain pending. Automatic crossing is gated by automatic_doorways; existing compact-2 does not enable it.


## Current update: compact-3 opposite-door integration
User approved the four current room candidates (“Looks good to me”, 2026-10-24). See [OPPOSITE_DOOR_LAYOUT.md](OPPOSITE_DOOR_LAYOUT.md) for the superseding route plan, hashes, provisional furniture status and validation. All 18 directed crossings now use opposite-side arrivals and automatic walking triggers. Fixed mansion checks: 108 passed; first-case checks: 31 passed. Older compact-2 route notes above are historical.


## House-02 blockout — 2026-10-26

Godot 4.7.2 native checks: **161 passed, zero failures** (`tools/house_blockout_checks.gd`). All 24 authored directed doors were traversed with collision-aware walking routes, checking exact arrivals and room-entry counts; both secret transitions were reached through real open-floor routes. Additional checks cover 24px walking steps, thin-obstacle tunnelling, blocked/idle movement, teleport distance exclusion and inspection counter resets. A doorway-plane condition prevents adjacent hall doors from capturing the player prematurely.

The standalone scene starts cleanly headless; GPU renders of Front Entry and Hall 2 were captured and visually inspected. The revised sidebar fits the viewport. Captures are local in ignored `test-results/house-blockout/`. Walking feel and layout suitability still require human playtesting; no generator or danger-clock behaviour is claimed. See [launch and controls](HOUSE_BLOCKOUT.md).


## House-02 investigation — 2026-10-26

Godot-native results: generator parity **15,374 checks** over **795 Python case fixtures** and 44 RNG streams; session rules **2,562 checks** over 80 base cases; playable integration **151 checks**, including two complete cases walked through the authored geometry; blockout regression **161 checks**. All passed. No original-game files or unpublished design branch were merged.

The integration harness uses actual proximity, inspection, question, pickup and accusation callbacks. It checks all 162 pose records are available, directional sprite hash/loading, permitted facing, unblocked guest placement and modal startup. Native GPU captures of Char/Chris room presentation, questioning, accusation and the Chris pose viewer were inspected; dialogs fit and source PNGs were unchanged. Capture files are local under `test-results/house-investigation/`. Human readability, puzzle satisfaction and furniture/activity fit remain unverified. No clock or guest-movement validation is claimed. Launch and fixture reproduction: [House investigation](HOUSE_INVESTIGATION.md).


## House-02 guests and danger clock — 2026-10-26

Native runtime checks: **16,336 passed**, zero failures. Coverage includes exact warning/stalking thresholds, seed/frame-batch invariance, no idle time advancement, unconditional hall safety, question/entry ambushes, weapon-dependent loss narratives, terminal freeze, refusals and immutable answered claims, real Hard staring evidence, all authored door reachability and 159 sampled NPC screen crossings with every sampled position on open floor. Playable scene checks: **160 passed**, including two controlled route regressions with risk/wander/refusal disabled and added live-runtime HUD/Hard/location checks. These are not default-risk win-rate measurements. Core case rules remained at 2,562 passing checks; generator code is unchanged. Native GPU warning and stalking captures were inspected and fit the viewport. See [runtime rules and limitations](HOUSE_RUNTIME.md).


## Correction: room-entry guest snapshots — 2026-10-26

The user explicitly rejected visible NPC walking. Guest pathfinding/travel has been removed. Guests stay at fixed positions and activities throughout a visit; only entering a non-hall room resolves the chance that they had relocated, placing them directly at their new spots. The existing elapsed-step rate is applied at that entry, not continuously. The danger clock remains separate and unchanged. Previous spatial-walking implementation/test descriptions above are superseded. Focused snapshot/clock checks and UI regressions cover the corrected behaviour. See [current rules](HOUSE_RUNTIME.md).

## UX overhaul checks (2026-11-17)

Branch `feature/ux-overhaul` (not yet merged to `main`). Run each headless check
with the Godot 4.7.2 console executable from the project root:

```powershell
<Godot 4.7.2 console executable> --headless --path . --script tools/<name>.gd -- --layout=res://assets/maps/house-02.investigation.layout.json
```

Each check prints one JSON line with `checks` and `failures`.

- `front_entry_checks`: no evidence in the Front Entry, generator parity with Python on 900 cases, drops refused.
- `accusation_room_checks`: all five accusation outcomes; the room is the gathering room.
- `floor_key_checks`: F equals the Floor button and is ignored in modals.
- `game_hud_checks`: room name, murderer phase and action bar in the HUD.
- `accusation_cards_checks`: six character cards on the accusation screen.
- `journal_checks`: journal behaviour, plus the journal assertions in `encounter_ui_checks`.
- `murderer_zoom_checks`: both ambush types, and skip.
- `murderer_zoom_flow_checks`: both ambush types, and skip, through the full flow.
- `kneeling_pose_checks`: Char and Chris kneel to study the floor.

Python tests:

```powershell
.venv\Scripts\python.exe -m pytest tests/case_design tests/test_pose_runtime_status.py
```

Screenshot scripts run WITHOUT `--headless` and write PNGs to
`test-results/screenshots/` (git-ignored): `tools/ux_screens_capture.gd` and
`tools/kneel_capture.gd`.

Known gap: the 13 Python dialogue tests in `tests/case_design/test_dialogue*.py`
fail because the game's dialogue data gained pronoun slots and new keys that the
Python dialogue library does not know yet. This is pre-existing and not caused by
this work.
