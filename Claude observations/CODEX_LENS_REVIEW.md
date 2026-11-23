# Lens review and port plan — Codex, 2026-11-16

**900/900 existing-field cases match; 11,700 field comparisons, zero differences. 900/900 have one culprit solution. 432/432 first/repeat dialogue strings match. No game implementation, commits, merges or pushes.**

Read `for-codex/MANIFEST.md` first, then the requested documents, Python files and fixtures in order. All **22** snapshot files match the manifest's byte counts/hash prefixes. Reference: snapshot `c4dbf35`, not a merged branch. Evidence: `../test-results/lens-review/parity.json` and `snapshot-check.json` (local, ignored).

## 1. Findings and disagreements

1. **Generator design looks reproducible.** Keep `items` and `stains` separate from all existing streams. Draw kinds for **every room**, including glass and secret slots. With `stains`, shuffle ascending ordinary-room indices excluding weapon/glass, take 0/2, **sort**, then repair matching kinds in that sorted order. Repair choices retain `blunt, sharp, heavy` order minus the wound kind. Even Easy executes the shuffle before taking zero. Different draw/sort order breaks parity. Do not add name draws to either stream.
2. **Generated fixtures are sound; validation is incomplete.** All 900 satisfy the lens contract and snapshot model/solver invariants. Malformed-case probes show `problems()` accepts Normal with zero decoys, Normal with `weapon_certain=True` and no decoys, and Easy with `weapon_certain=False`. An out-of-range decoy raises `IndexError`. Add difficulty/count/certainty, index-range and sorted-decoy validation before relying on it for loaded cases. These are validator gaps, not observed generator failures.
3. **Names/art cannot remain a unique shuffled catalog.** Six-suspect fixtures can require **8 sharp non-glass items**; the current art catalog has only **1 sharp candidate**. The suggested legacy list has only 2. Randomly labelling a knife “heavy” is unacceptable. Preserve repaired reference kinds, then choose compatible catalog entries with `item_art`, allowing repeated types with distinct instance IDs, or deliberately revise the reference/fixtures. More approved art is another option; none is authorized here.
4. **The clock simulation is not the full inventory prototype.** `_take_weapon()` toggles two booleans; it does not track arbitrary held items, drop locations, stacked objects or recovering the glass. `_win_sequence()` travels to the murder room, unlike our current-room gathering. `won` checks the culprit only; it does not exercise five accusation outcomes.
5. **Its danger rates are not runtime calibration.** Entry death ignores killer presence/witnesses; culprit-question death lacks hall/alone safeguards. It also charges actions and relocates guests during ticks. Preserve the user's newer solo-killer restriction, hall safety, walking-only costs and room-entry snapshots. Do not port those simulator differences or quote its win rates as predictions for this build.
6. **Version 2 now has two shapes.** Old-case defaults intentionally mean legacy certain-weapon behavior. Distinguish absent lens fields from newly generated Normal/Hard fields; do not silently regenerate old cases. Add an inventory/save-schema revision independently of generator version.

## 2. What was actually compared

Ran the **unchanged** `src/mystery/generated_case.gd` against the supplied `case_fixtures.json`: seeds 0–59 × 5 suspect counts × 3 difficulties. All **13 currently returned fields** match, including claims, cast, personalities, staging and crime/glass/weapon rooms. `item_kinds`, `decoy_rooms`, `weapon_certain` are absent in all 900 GDScript results: **this is not full new-model parity**. Separately checked all three new fixture fields' contract. Snapshot model/solver execution used memory-only loading; no source edits to make checks pass.

Dialogue parity covers successful first/repeat accounts, **not the missing new lens/drop/correction lines or all endings**.

## 3. Port order, size and risks

Estimates are touched/new production lines, excluding tests and authored dialogue; notebook work is included in the session estimate.

| Order / files | Change | Rough size / principal risk |
|---|---|---|
| 1. `src/mystery/generated_case.gd`, parity harness | Three fields; exact `items`/`stains` sequence; compare all fields on all 900 cases. | 35–60; ordering and legacy defaults. |
| 2. `assets/mystery/house_item_catalog.json`, `src/mystery/house_item_art.gd` | Stable catalog IDs and kinds; kind-compatible names/art from `item_art` after generation. | 20–50; repeated types versus current unique-name shuffle. |
| 3. `src/mystery/house_case_session.gd` | Instance registry, one held ID, any-item pickup/drop, learned stain/kind/wound facts, new assembly/accusation gates, held-item ambush slot, notebook. | 210–340; eliminate room-index-as-current-location assumptions. |
| 4. `src/mystery/house_runtime.gd`, `assets/mystery/house_runtime_rules.json` | Separate physical steps from accumulated danger; configurable proposed `weapon_clock_multiplier: 2.0`. | 25–50; pickup/drop timing and fractional accumulation. |
| 5. `src/blockout/house_investigation.gd` | Select/examine/take nearby instances, Drop control, inventory, multiple depth-sorted items at actual positions, five endings, labelled phase. | 100–180; overlapping drops, halls and stale single-slot controls. |
| 6. `src/blockout/house_blockout.gd` | Optional dynamic item markers for investigation diagnostics; retain authored slots as initial spawn markers. | 10–25; keep standalone geometry preview independent. |
| 7. Dialogue JSON/schema checks, targeted integration tests | Supply pending authored text, test movement/drop/lens/clock/outcome combinations, then painted playtest. | Data-dependent; no invented text. |

### Items, names and locations

Today `progress.glass` is permanent ownership, `progress.carried` is a weapon's original room index, and names are a full catalog shuffle from **`item_art`**. `ITEMS` is only a fallback: letter opener/kitchen knife are not the current ten visual names. Pickup rejects other items; no drop registry exists; halls have `progress.room=-1`; drawing assumes one `screen.item_slot`.

Use immutable IDs (e.g. initial-slot ID plus a separate glass ID), origin index, kind/stain truth, and mutable `screen_id/position` or held location. `weapon_room` remains legacy origin identity, never the weapon's current location. Glass replaces its original slot's ordinary item. Held glass alone enables lens work, including Hard's staring trace. Any non-glass held item enables gathering, without an identification checklist.

Normal/Hard inspection reveals a stain on exactly three items, not weapon identity; the murder-room discovery supplies the wound kind. Easy still names the weapon. An item's kind/stain travels with it; moving it never changes the historical murder room. Kind remains visible without revealing stain truth.

Suggested legacy kinds are sensible: sharp = letter opener/knife; heavy = book/marble ornament; blunt = rest. For **current approved art**, propose knife = sharp, ledger/bust = heavy, remaining seven = blunt. Confirm that mapping; choose kind first, then compatible art/name. Preserve PNGs and metadata approvals.

Drop at the player's reachable floor position in **any screen**, including halls/secret passage; never return it to its origin. Allow multiple dropped items, with a nearby-item chooser for overlap. Items should not create new doorway-blocking colliders. Notebook records only encountered items, learned kinds/stains/wound and last-known locations, updating on take/drop; never list unseen truth locations or automatically label the correct weapon without a separately approved assistance rule.

### Clock, outcomes and text

Accumulate `danger_clock += physical_delta * multiplier` only while the **true weapon** is held. Keep physical walking steps for guest snapshots and stats. Flush pending movement before changing held ID; otherwise frame batching can accelerate earlier walking retroactively. Dropping stops future acceleration, never reverses it. Keep current gathering freeze and witness protection. **2× and silent remain proposals awaiting confirmation.**

| Person / room / held item | Outcome |
|---|---|
| Wrong / wrong / any non-glass | `both_wrong` |
| Wrong / right / any non-glass | `wrong_person` |
| Right / wrong / any non-glass | `wrong_room` |
| Right / right / wrong item | `wrong_weapon` |
| Right / right / true weapon | `solved` |

Empty hands/glass block gathering; final accusation must recheck the held item. Ambush grab applies to **anything held, including glass**: pass `{held_item}` separately; `{weapon}` and the truth summary must still name the true weapon.

Phase colours already work: suspicious **#FFD84A**, stalking **#FF9F40**, from `assets/dialogue/styles.json`. Add the requested **“Murderer: calm/suspicious/stalking”** label and check header fit. No need to replace the current warning text.

All affected player-facing wording must come from `assets/dialogue/*.json`. Until Claude supplies it, plan only marked placeholders: `[PENDING_DIALOGUE:stain_found]`, `[PENDING_DIALOGUE:wound_hint]`, `[PENDING_DIALOGUE:hands_full]`, `[PENDING_DIALOGUE:drop_item]`, `[PENDING_DIALOGUE:drop_glass]`, `[PENDING_DIALOGUE:assemble_need_item]`, and eight-personality `[PENDING_DIALOGUE:culprit_corrects_weapon]`; also review held-item ambush templates. Do not invent replacement prose or copy original-game wording.

## 4. Questions before implementation

1. Confirm **2× only while held, silently**, rather than a permanent pickup trigger?
2. Allow repeated item types/art with distinct instances to preserve reference parity?
3. After gathering, may the player drop/swap items before accusing? Recommend checking the item actually held at final confirmation; glass/empty hands block it.
4. Should the notebook merely record evidence, or explicitly identify a stain/wound match? Recommend recording evidence first.

The snapshot's “dialogue unwired” and “no painted guest spots” notes are stale: dialogue is connected, with **55 spots / 19 masks**. Preserve current portraits, same-room gathering, refusal improvements and three corrected confession templates; do not overwrite them with older copied JSON.

**Not verified:** full Python generator/simulator rerun, reported 1,000-seed win-rate tables, human difficulty/fun, free-drop UX, new clock pacing, save migration or packaged export. The snapshot omits `rng.py` and inherited `simulate.py`; they were not borrowed from or merged out of Claude's worktree. This review changes no game files and authorizes no port implementation.
