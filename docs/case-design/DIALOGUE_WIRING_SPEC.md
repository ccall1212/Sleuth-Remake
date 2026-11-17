# Dialogue wiring spec (for Codex)

Written 2026-11-16 by Claude. This is a proposal for a **data-only** integration: the game's text comes from JSON written and
validated on the design branch; code only loads it, picks variants from a seeded stream and fills slots. Nothing here changes a case
(who did it, where, with what), only the words, and nothing here touches guest spots (spots and personalities stay separate).

## 0. Why

`REVIEW_2026-11-16.md` section 3: the game has one fixed opening per personality, a flat "I was in the X", and two warnings that echo the
original game's wording. The design branch has 864 personality lines, 20 system keys and 5 rank titles that pass an original-wording check.

## 1. What to take

From branch `design/case-generator` (pushed to `origin/design/case-generator` on 2026-11-16; also the local worktree `.claude/worktrees/case-design`): copy, byte for byte,

- `assets/dialogue/personalities.json` and `assets/dialogue/system.json` (data; the only files the game needs);
- `docs/case-design/dialogue_fixtures.json` and `docs/case-design/DIALOGUE_SCHEMA.md` (for tests and the contract);
- optionally `tools/case_design/dialogue.py` and `validate_dialogue.py` as the reference implementation and validator.

Do not edit the JSON in the game repo; changes go through the validator on the design branch (`python tools/case_design/validate_dialogue.py`,
exit 0) so the no-original-wording and no-pronoun rules keep holding.

## 2. Loading and slots

Both files are UTF-8 JSON. A slot is `{name}` written exactly; `render()` replaces each with the slot value, errors on a missing slot or a
stray brace, and ignores unused slots. Slot names: `speaker, room, partner, victim, other, weapon, chosen_room, culprit, true_room, moves, rank`
(each line type's required slots are in `DIALOGUE_SCHEMA.md`). The game adds the quotation marks around `claim_*`, `commentary_*` and
`repeat_*` lines; `refusal`, confession, ambush and `culprit_corrects_*` lines are complete blocks and quote their own speech.

## 3. Questioning (the part that must match exactly)

Algorithm, identical to `dialogue.compose_reply`:

1. `claim_kind` = `"pair"` if the suspect's claim names a partner, else `"solo"`; `lines` = `personalities[personality]`.
2. `pick(n)` = `stream.below(n)` where `stream` = `Rng(case.version, case.seed, "dialogue/<suspect index>/<ask>")`, the same SHA-256 stream
   construction as the case (`seed_stream.gd`). `ask` is 0 for the first question and 1 for every repeat.
3. Pick order is fixed. **First ask:** claim template (`claim_<kind>`), opening, then a commentary type, then the commentary line. The commentary
   types considered are `commentary_victim`, `commentary_suspect`, `commentary_self`, in that order, skipping any whose required slots are
   missing (`commentary_suspect` needs `other`); the type is `kinds[pick(len(kinds))]`, taken before the line pick.
   Result: `<opening> "<claim> <commentary>"`.
4. **Repeat:** claim template, `repeat_lead`, `repeat_close`. Result: `"<lead> <claim lowercased-first-letter> <close>"`. The claim's first letter is
   lowercased unless its template starts with a slot or with the word `I`.
5. Slots: `speaker` = cast[suspect]; `room` = rooms[claim.room]; `partner` = cast[claim.partner] when present; `victim` = cast[-1];
   `other` = cast[(suspect + 1) % suspects].

`docs/case-design/dialogue_fixtures.json` holds the expected first and repeat text for 36 cases (12 seeds x Easy/Normal/Hard, six suspects),
216 suspects in all. A GDScript test should load it, regenerate each case with `generated_case.gd` (already identical to Python), render both texts and
compare strings exactly. If a string differs, the pick order or the lowercase rule is wrong; do not "fix" the data.

## 4. Other player-facing text

Per-personality lines use the stream `dialogue/<suspect>/<kind>/<n>` (kind and n are free, but must be deterministic so a replayed case reads the same).

| Moment | Line type | Notes |
| --- | --- | --- |
| Guest refuses (22%) | `refusal` | No alibi, never recorded; asking again can succeed |
| Culprit ambushes, player not carrying the weapon | `ambush_locked` | slots speaker, victim, room, weapon |
| Culprit ambushes, player carries the weapon | `ambush_grab` | slots speaker, weapon |
| Accusation: right person and room | `confession_<tone>` | tone below |
| Accusation: right person, wrong room | `culprit_corrects_room` | adds `chosen_room` |
| Accusation: wrong person, right room | `culprit_corrects_person` | the culprit stands up |
| Accusation: right person and room, wrong item in hand | `culprit_corrects_weapon` | slots `weapon` (true) and `chosen_weapon` (carried); new 2026-11-16 |
| Accusation: both wrong | system `accuse_wrong_both` | slots culprit, victim, true_room, chosen_room |

Confession tone by personality, a **proposal for the user to confirm**: warm, fragile, nervous → `remorseful`; proud, curious → `triumphant`;
hot_tempered → `furious`; guarded, calm → `resigned`; `defiant` is available as an alternate for any personality. Keep the tone a pure function of
the personality so it never signals guilt before the accusation.

## 4b. Colours

Apply `assets/dialogue/styles.json` when a line is shown (for example a `[color=#FFD84A]` span in a RichTextLabel): **yellow** for the suspicious warning,
**orange** for the stalking warning, **red** for blood on the floor, blood on the weapon, and the whole ambush death text (the scene line from
`ambush_locked` or `ambush_grab` and the "killed ... Your investigation has ended." line). Colour is applied by line key, never by guessing from the
words. The investigation's current phase colours (`house_investigation.gd`) should read from the same file so the sidebar and the messages agree.

## 5. System text: runtime string to key

| Today (`house_case_session.gd` / `house_runtime.gd`) | Use |
| --- | --- |
| "The murderer has grown suspicious. Be careful who you question." | `warning_suspicious` (drop the original-style wording; keep any UI hint as separate, non-narrative text) |
| "The murderer is stalking you. Entering rooms is dangerous; halls are safe." | `warning_stalking` |
| "Carry the identified weapon and assemble the guests first." | `accuse_need_assembly` (not assembled yet) / `assemble_need_item` (nothing but the glass in hand) |
| assemble succeeds | `assemble_ok` {room} |
| "You find traces of the crime. The murder happened in the X." | `floor_blood` {room} |
| "Nothing conclusive..." with no guest watching / with one | `floor_nothing_unwatched` / `floor_nothing` |
| "The magnifying glass reveals matching traces on the X..." | Easy: `weapon_blood` {weapon}. Normal and Hard: `lens_stain` {item} on the weapon and on decoys alike |
| an item with no stain (Normal, Hard) | `lens_clean` {item} |
| the murder-room trace, on Normal and Hard | `floor_blood` {room} followed by one of `wound_blunt` / `wound_sharp` / `wound_heavy` for the weapon's kind |
| non-weapon item examined | `item_flavor_generic` (12 lines) |
| taking an item or the glass | `take_item` {item} / `take_glass` |
| hands already full | `hands_full` {item} (the item may be the glass) |
| putting something down | `drop_item` {item} / `drop_glass` |
| asking someone too far away | `too_far_to_hear` {speaker} |
| the front door, the secret panel | `front_stoop`, `secret_panel` |
| notebook header for the guest list | `guest_list_header` |
| examining an item without the glass / the glass itself / nothing to examine / a hall floor / floor without glass / Hard floor nobody watches | `item_needs_glass` {item} / `inspect_glass` / `no_item` / `no_floor` / `floor_needs_glass` / `floor_inconclusive` |
| putting down with nothing held / nowhere to put it | `no_held_item` / `drop_blocked` |
| the closing lines of an ambush or an accusation | `investigation_ended`, `case_closed`, `case_ended`, `truth_summary` {culprit} {victim} {weapon} {true_room} |

Pass item names to `{item}`, `{weapon}`, `{chosen_weapon}` and `{held_item}` **lower-case** (`lcfirst`): they sit mid-sentence ("the oak kitchen stool").
| win screen | `win` {culprit} {victim} {moves} {rank} |

`ranks` is exactly five titles, best to worst, invented for this game and **not yet confirmed by the user**. How `moves` maps to a rank is undecided: the
original's thresholds are unknown. Open decision (user): thresholds in walking steps.

## 6. Acceptance checks

1. The fixture test above passes (all 216 first and repeat strings identical).
2. In one case, the same question to two suspects with different personalities reads differently; the same seed replays identically.
3. No runtime string quoted in section 5 remains in `src/` except as a documented UI hint.
4. `validate_dialogue.py` exits 0 on the copied data (run with `SLEUTH_REFERENCE_DIR` set locally to also check against the original's text; never commit that text).
5. Notebook entries still record only facts (room and partner), never the wording.

## 7. Not in scope

Personality-driven stance or pose choices (they will use a guest spot's allowed facings later), a notebook assistant, localisation, and any change to
case generation.
