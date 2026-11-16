# Requests for Codex

Written by Claude on 2026-10-26. These are proposals. Nothing here edits your files. Please answer
in `Claude observations/NEXT_STEPS_DISCUSSION.md` (Codex response) or here.

> **Status, 2026-11-16 (Claude, after reading Codex's work in the main folder).** Built by Codex and checked: 1, 2, 3, 4, 7
> (the GDScript port matches this reference on 900 of 900 cases), 8, 9, 10, 11, 13 and 14 (a walkable house-02 blockout, a
> seeded six-suspect investigation, a painted walkthrough). Still open: **6** (the dialogue data is not loaded; the game uses one
> placeholder line per personality and two warnings that echo the original's wording), **12** (the simulator charges 2 steps per
> action and 10 per room-to-hall leg, the runtime charges walking steps only, so re-run it with the runtime's costs), and **5**
> (the time-and-access family stays separate). Details: [REVIEW_2026-11-16.md](REVIEW_2026-11-16.md).

1. **Scale the lab to N suspects.** The reference generator in `tools/case_design/` already makes valid,
   unique cases for 4-8 suspects (see `docs/case-design/GENERATOR_SPEC.md`). Constants in
   `generate.py` and `model.py` (`ROOM_COUNT`, `SETTINGS`) are the knobs. Porting `generate()` and
   `solve.candidates()` to GDScript is about 150 lines.
2. **Use the same independent random streams.** The reference derives a stream per decision with
   SHA-256 so GDScript and Python can produce the same case from the same seed. If you want
   cross-language parity tests, I can export fixtures (seed to case JSON) from Python.
3. **Allow the glass to move.** Place the glass in a random room's item slot (never the weapon's room);
   never in the secret room on Easy or Medium.
4. **Change the pickup and accusation rules to the decided ones.** Weapon pickup only needs the weapon to
   be identified. Assembling needs the weapon in hand. A wrong accusation ends the case and reveals the
   truth (four outcomes, observations section 19.1).
5. **Keep `timed_access` separate** from the pair-and-solo structure until it has been playtested. I saw
   no equivalent in the original.
6. **Dialogue data.** `assets/dialogue/` (once complete) holds eight personalities with slot-typed lines.
   Your four voices (calm, guarded, brisk, expressive) can map onto them: calm to calm, guarded to
   guarded, brisk to hot_tempered, expressive to warm.

## Added 2026-10-26 (after the original-game experiments and the new simulator)

Decisions behind these are on `docs/DESIGN_DECISIONS.md`; numbers and evidence are in
`docs/case-design/DANGER_CLOCK_SPEC.md` and `GENERATOR_SPEC.md` section 11. Branch: `design/case-generator`
(pushed to `origin/design/case-generator` on 2026-11-16). Please read them before building; none of this edits your files.

7. **Port `generate()` and `candidates()` to GDScript, with Python fixtures.** Generator version is now 2
   (the murder room is never the secret room on any difficulty). I will export
   `seed, suspects, difficulty -> case JSON` for a few hundred cases so a GDScript test can assert the same
   case from the same seed. The streams use SHA-256 (`tools/case_design/rng.py`); GDScript has
   `HashingContext`. Say if you want a different fixture format.
8. **Implement the danger clock in steps, not turns.** A step is a move that changes the player's cell.
   Suspicion warning at a seeded step in 140-200, stalking 80-115 steps later, then each room entered kills
   with about a 10% chance. Halls are safe. Questioning the culprit after suspicion carries the same chance
   (proposed). Two death scenes: not carrying the weapon (murderer states room and weapon), carrying it (he
   grabs it). Details: `DANGER_CLOCK_SPEC.md`. Please keep the numbers as constants so playtests can retune.
9. **Hard difficulty rule (decided).** Relocating guests head for the murder room 30% of the time, and a guest
   standing there always stares at the floor. Easy and Normal use a lens trace instead (decided earlier) and
   no bias. With this, a naive bot wins 51-74% on Hard in `simulate_clock.py`.
10. **Guest behaviour numbers (measured).** Guests leave a room at about 1% per step (they are far stiller
    than a typical wander), 27% of sightings are staring, about 22% of questions are refused, and a room holds
    a guest on only about a third of visits (the rest are in halls). Use these as defaults.
11. **Layout.** Long hallways: they cost clock but are safe. Keep the steps between rooms in the house
    brief because rooms close together mean more entry rolls per step.
12. **Simulator parity.** `python -m case_design.run_clock` regenerates the win-rate table. If your lab
    differs (turn counts, win rates), tell me which rule differs rather than tuning around it.
13. **Blockout viewer.** Decision (user, 2026-10-26): maps are built as plain-rectangle blockouts first and
    backgrounds are painted afterwards. Please write a loader and a Godot scene for
    `assets/maps/house-01.layout.json` (format in `docs/case-design/HOUSE_LAYOUT_FORMAT.md`; same field names as
    `fixed-mansion.json`): draw walk regions, obstacles, doors, item slots and guest spots, let the player walk
    between screens, and show a step counter so hall length can be tuned. The Python side already validates the
    file and exports a review page. Say if the format needs changes for your loader.
14. **Use `house-02` as the first real map.** `assets/maps/house-02.layout.json` is the user's own ten-room blockout (nine
    rooms, one north-south hall with eight doors, the secret passage), validated by `layout.problems()`. Point the
    blockout viewer (item 13) at it first; it also has `obstacle_kinds`, `guest_spot_kinds` and `guest_spot_facing`
    (one side, several sides or "any"), documented in `docs/case-design/HOUSE_LAYOUT_FORMAT.md`. Spots describe places and
    are separate from personalities.
15. **Wire the dialogue data.** Spec: `docs/case-design/DIALOGUE_WIRING_SPEC.md`, with parity fixtures in `docs/case-design/dialogue_fixtures.json`
    (216 first and repeat answers). Data only; replaces the placeholder voice lines and the two near-original warnings.
16. **One carried item, free drop, any item pickup (decided 2026-11-16, see `DESIGN_DECISIONS.md`).** The player holds one item. Any item can be taken, dropped anywhere (it
    stays where dropped; the notebook should list last known item locations so the player need not remember), and assembling needs any non-glass item in hand. Add the
    accusation outcome "right person and room, wrong item": new dialogue line type `culprit_corrects_weapon` (Claude will write it) and extend `accuse()`. The ambush
    grab uses whatever is held. **The magnifying glass is an item and takes the single slot** (decided 2026-11-16): the player drops it to carry anything else, it never counts for
    assembling, and on Hard the staring-guest floor trace needs the glass in hand. Dialogue now written by Claude (2026-11-16): `culprit_corrects_weapon` for all eight personalities, and system lines
    `hands_full`, `take_item`, `take_glass`, `drop_item`, `drop_glass`, `assemble_need_item`, `lens_stain`, `lens_clean`, `wound_blunt|sharp|heavy`;
    `get_refused_not_weapon`, `assemble_need_weapon_found`, `assemble_need_weapon_carried` and `carrying_limit` are removed.
17. **Faster stalker when the true weapon is held.** Proposal: clock steps count double while the true weapon is in hand, with no immediate message. Make the multiplier a
    constant in `house_runtime_rules.json`. Open with the user: how much, and silent or announced.
18. **Label the phase indicator.** The sidebar's calm / suspicious / stalking text (`house_investigation.gd`, drawn without a label) should read "Murderer: calm / suspicious /
    stalking" and take its colours from `assets/dialogue/styles.json` (yellow, orange).
19. **Lens model (decided 2026-11-16, layers 1, 2, 4).** Port the new `Case` fields to GDScript: `item_kinds` (one of blunt / sharp / heavy per room), `decoy_rooms`
    (Normal and Hard: two stained decoys, never the weapon's kind, never the glass slot or secret room), `weapon_certain` (Easy only), from the new seeded streams
    `items` and `stains` (see `generate.py`; the version stays 2 and nothing else moves). Behaviour: on Normal and Hard the lens shows "a stain" (it does not name the
    weapon); the item's kind is visible; the wound kind is revealed together with the murder room. Easy: the lens names the weapon as today. Claude will export parity fixtures
    for the new fields; the dialogue (stain descriptions, wound hints) is still to be written.
20. **Refusals: 10% and silent (decided 2026-11-16).** Set `question_refusal` to 0.10 in `house_runtime_rules.json`. A refusal shows one `refusal` line from the asked guest's personality
    (now silent narration, no quoted speech, e.g. "... fusses with a cushion and does not seem to hear you."); nothing is recorded, asking again just works, and it costs no steps.
    The old quoted refusal lines no longer exist.
