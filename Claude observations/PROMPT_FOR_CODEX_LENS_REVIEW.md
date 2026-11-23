# Prompt to paste into Codex: review Claude's lens and item model

Paste everything between the two `=====` lines.

=====

Claude has redesigned how the magnifying glass, items and the murder weapon work, prototyped it in a Python reference, and written down new decisions from the user.
I want your review and a port plan **before anything is implemented**. Do not change game files, commit or push; write your answer to
`Claude observations/CODEX_LENS_REVIEW.md` and tell me when it is there.

**Where to read (read-only copies in this folder, do not edit them):** `Claude observations/for-codex/`. Open `MANIFEST.md` first; it lists every file, its source path on the branch
`design/case-generator` and the commit it was copied from. The branch itself is not to be merged or pushed by you.

**Read in this order**
1. `docs__case-design__GENERATOR_SPEC.md`, section 12 (the lens model, the numbers, and the limits of what was measured).
2. `docs__DESIGN_DECISIONS.md`: the rows dated 11-16 (Carrying, Murderer grab, Weapon pickup speeds the stalker, Phase label, Lens, Wrong weapon, Accusation) and the "Still open" table.
3. `docs__case-design__REQUESTS_FOR_CODEX.md`: items 15-19 (15 dialogue wiring; 16 one item / free drop / glass is the item; 17 faster stalker; 18 label the phase indicator; 19 lens model).
4. The Python reference: `tools__case_design__model.py`, `generate.py`, `solve.py`, `simulate_clock.py`.
5. Parity data: `docs__case-design__case_fixtures.json` (900 cases, every field of `Case.to_dict()` including the new `item_kinds`, `decoy_rooms`, `weapon_certain`) and `dialogue_fixtures.json`.

**What the new rules are, in one paragraph.** The player holds one item at a time and the magnifying glass is an item, so the glass must be dropped to carry anything else. Any item can be
taken and dropped anywhere (it stays where dropped; the notebook should list last known item locations). Assembling needs any non-glass item in hand; winning needs the true weapon, the right person
and the right room; right person and room with the wrong item is a new outcome (the culprit corrects the weapon). The ambush "grab" takes whatever is held. Picking up the true weapon makes the
danger clock run faster (proposal: 2x, silent). On Normal and Hard the lens shows "a stain" on the weapon and two decoy items, each item has a kind (blunt / sharp / heavy), and the wound kind
is revealed with the murder room and singles out the weapon; on Easy the lens still names the weapon. The phase indicator needs a label ("Murderer: calm / suspicious / stalking") in the yellow and orange from `assets/dialogue/styles.json`.

**What I want from you**
1. **Review the Python reference** for logic errors, anything ambiguous, and anything that will be hard to reproduce in GDScript (seeded stream names `items` and `stains`, draw order, the decoy-kind repair, `sorted` decoys). Say if a rule should change before it is ported.
2. **Check parity of what you already have.** Run your `generated_case.gd` against `case_fixtures.json` for the existing fields (culprit, murder_room, weapon_room, glass_room, claims, rooms, cast, personalities, guest_start, trace_mode). Report the result; do not edit anything to make it pass.
3. **Port plan, file by file,** for requests 16-19 in the runtime (`house_case_session.gd`, `house_runtime.gd`, `house_investigation.gd`, the blockout viewer and any notebook code): what changes, rough size, risks, and the order you would do it. Specifically answer:
   - How items are modelled today (room-bound, names from `ITEMS`) and how to add per-item kinds. I suggest mapping kind to item names, for example sharp: letter opener, kitchen knife; heavy: heavy book, marble ornament; blunt: candlestick, decanter, poker, hammer, wrench, cane. Do you agree, and who draws the name from which stream?
   - Dropping an item anywhere (halls and rooms): where it is drawn and picked up, collisions, how it interacts with the guest and item markers, and what the notebook should show.
   - The danger clock with a carry multiplier: how steps and the clock differ in `house_runtime.gd`, and how `house_runtime_rules.json` should carry the multiplier.
   - The accusation dialog and result with a weapon (five outcomes, listed in the decisions page).
   - The phase label and colours.
   - Anything in the current runtime that contradicts these rules (for example the guest snapshot model, the Hard staring trace needing the glass in hand, or "take weapon requires identification").
4. **Questions for the user** and **disagreements with Claude**, kept short and specific.

**Constraints**
- Dialogue text comes only from `assets/dialogue/*.json`. The lens, wound-hint, take/drop, assemble and weapon-correction lines are now written (see `assets__dialogue__system.json`, `personalities.json` and `styles.json`, and the key mapping in `docs__case-design__DIALOGUE_WIRING_SPEC.md` section 5). Use only those; never invent wording or reuse wording from the original game.
- Preserve approved art, the original archive and the Do-not rules in `AGENTS.md`. No commits, pushes or publishing without the user's authorization.
- Keep the answer short and numbers-first: counts, file paths and sizes, not adjectives. Say what you did not verify.

=====
