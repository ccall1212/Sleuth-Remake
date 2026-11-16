# Design decisions: current state

One page, plain language. Updated 2026-11-16 by Claude (first written 2026-10-26). Every row says **who decided**, **when**, and
**what is still open**. Details live in [GAME_DESIGN_BRAINSTORM.md](GAME_DESIGN_BRAINSTORM.md) (the
sections dated 2026-10-25 and 2026-10-26 at the end) and the evidence log in
`Claude observations/ORIGINAL_GAMEPLAY_OBSERVATIONS.md`. "Observed" means seen in the original game;
sample sizes are small (14 games of live play, plus 28 scripted games for the danger clock).

## Decided by the user

| Area | Decision | Date |
| --- | --- | --- |
| Cast | 6-8 suspects (Easy may use 4, Normal 5) from a pool of about 10; the player can name, choose or randomize; exactly one victim per case, in the cast and not a suspect | 10-25 |
| House | Somewhat larger than the old 7-room scope. First real map: **house-02**, the user's own ten-room blockout (nine rooms, one north-south hall, secret passage); blockout first, backgrounds painted after | 10-25, 10-26 |
| Accusation | Original style: no checklist; accusing needs assembling first. **Superseded 11-16:** assembling needs any item in hand (not the magnifying glass); winning needs the true weapon, the right person and the right room | 10-25, 11-16 |
| Wrong accusation | Ends the case and reveals the truth: right person, wrong room = confession plus the true room; wrong person, right room = the real culprit stands up; both wrong = names both | 10-25 (observed in games 2, 10, 14) |
| Wrong weapon | New outcome: right person and room but the wrong item in hand = the culprit corrects the weapon (a new line type). The culprit always corrects the most important thing first: person, then room, then weapon | 11-16 |
| Danger clock | Counted in **walking steps** (measured on the original, 28 games): warning at a seeded step 140-200, stalking 80-115 steps later, about 10% death per room entered while stalking, halls safe. Visible phases: calm, suspicious, stalking, ambush. Originally decided as turn-based; changed to steps after the experiments | 10-25, 10-26 |
| Glass | Random room; never in the secret room on Easy or Medium; may be on Hard | 10-25 |
| Independence | Culprit, murder room, weapon item and glass chosen independently; weapon and murder room may rarely coincide | 10-25 |
| Murder-room clue | Easy/Medium: a lens trace; Hard: original rule (bloodstains only while a guest stands staring at the floor) | 10-25 |
| Guests | Some guests can be found in the secret room, as in the original (seen in games 3 and 14) | 10-26 |
| Personalities | Eight (warm, nervous, proud, guarded, hot-tempered, curious, fragile, calm), random per case with manual override; voice and mood only | 10-25 |
| Murder room | Never the secret room, on any difficulty (glass and weapon may still be there on Hard; guests can stand in it) | 10-26 |
| Hard bias | On Hard, relocating guests head for the murder room 30% of the time and always stare there | 10-26 |
| Carrying | The player holds **one item at a time, and the magnifying glass is an item**. Any item can be picked up (not only the murder weapon). An item can be **dropped anywhere** and stays where it was dropped (so items can be gathered in a hall); the player does not have to remember a home room. The notebook should list last known item locations. To carry the weapon the player must first drop the glass, so the lens work (floor trace, weapon check) comes first and cannot be repeated while carrying the weapon | 11-16 |
| Murderer grab | The ambush "grab" scene applies to whatever item is in hand | 11-16 |
| Weapon pickup speeds the stalker | Picking up the **true murder weapon** makes the murderer stalk faster (a new rule: in 4 measured games of the original, carrying the weapon changed nothing). Numbers and whether the player is told are open (see below) | 11-16 |
| Phase label | The "calm / suspicious / stalking" indicator must carry a label ("Murderer: ...") and use the yellow and orange text colours | 11-16 |
| Lens | The lens shows "a stain" on the weapon and on two decoy items (Normal, Hard); the wound kind (blunt, sharp, heavy), revealed with the murder room, says which stained item is the weapon. Easy keeps the lens naming the weapon. Decoys never share the weapon's kind | 11-16 |
| Layout and danger | Long hallways; about 10% death chance per room entered once stalking starts; halls are safe but spend clock | 10-26 |
| Guest spots | Each spot carries a kind and a facing (one side, several, or any). This is separate from personalities; personalities later use the allowed directions when choosing a stance | 10-26 |
| Poses | A new resigned shrug for reveals; rest and sleep poses; two body-language templates (women follow Char; men follow a male template made with Chris first); neutral male standing is hands in pockets; no hat-removal gesture | 10-25, 10-26 |
| Chris | His appearance is approved (larger-eyed anime v2); Chris is the example pose set for men, Char for women; both keep the same folder layout and the five murderer reveal poses live in `exports/murderer-reveal` | 10-26 |
| Front Entry | The two side blocks are pillars or statues, not staircases; no windows across its top | 10-26 |

## Observed in the original (use as evidence, not as rules)

- Innocents form mutual pairs plus a solo; the culprit names someone who does not return the claim
  (games 2-9). Two people naming the same partner in different rooms occurred in games 6 and 7.
- Bloodstains in the murder room appeared only while a guest stared at the floor there (9 of 9
  positive findings had a staring guest); staring guests also appeared in innocent rooms (about 47% of
  sightings were in the murder room).
- Assembling needs the weapon in hand; the weapon and murder room differed in all of my games.
- The murderer's ambush has two scenes (confession, or grabbing the weapon you carry).
- The secret passage entrance is a random column; the glass can be inside it.

## Built so far

On `design/case-generator` (Claude; pushed to `origin/design/case-generator` on 2026-11-16; 147 tests pass):

- `tools/case_design/`: case generator (4-8 suspects, version 2), independent solver that proves each case has one answer,
  turn simulator and step-clock simulator, layout loader/validator, `auto_label.py`, and the dialogue validator. See
  [case-design/GENERATOR_SPEC.md](case-design/GENERATOR_SPEC.md) and
  [case-design/DANGER_CLOCK_SPEC.md](case-design/DANGER_CLOCK_SPEC.md).
- `assets/dialogue/`: 864 original lines for the eight personalities plus 20 system keys and five rank titles, with a
  validator that blocks wording from the original. See [case-design/DIALOGUE_SCHEMA.md](case-design/DIALOGUE_SCHEMA.md).
- `assets/maps/house-01` and `house-02` layouts, `tools/layout_editor/` (browser editor: move, link and rotate rooms, furniture
  kinds, guest spots with kind and facing), and [case-design/HOUSE_LAYOUT_FORMAT.md](case-design/HOUSE_LAYOUT_FORMAT.md).
- [case-design/REVIEW_2026-11-16.md](case-design/REVIEW_2026-11-16.md): review of Codex's work (generator parity, runtime vs
  decisions, dialogue gap, stale docs).

By Codex on `art/pose-production` and in the main folder (mostly **uncommitted** as of 2026-11-16):

- A GDScript port of the generator (900 of 900 cases identical to mine), a playable six-suspect investigation on house-02
  (blockout viewer, danger clock, stationary guests, Char and Chris in approved art), a painted walkthrough with eleven
  approved room images and user-placed door markers, and a guest and mask placement tool. See `docs/HOUSE_BLOCKOUT.md`,
  `docs/HOUSE_INVESTIGATION.md` and `docs/HOUSE_RUNTIME.md` in the main folder.
- Chris's pose library (80 approved, 19 queued) in Char's folder layout, tagged `v0.1.4` on `origin/main`.

## Still open

| Question | Where it matters |
| --- | --- |
| My dialogue (864 lines, system keys, rank titles) is not wired into the game; two runtime warnings are near-original wording | [case-design/REVIEW_2026-11-16.md](case-design/REVIEW_2026-11-16.md) section 3 |
| Simulator win rates assume 2 steps per action and 10 per room-to-hall leg; the runtime charges walking steps only | Re-run `simulate_clock.py` with the runtime's costs |
| Painted rooms have no guest spots yet; should they use my kinds and facings or the user's own placements? | House-02 art integration |
| Hard at 51-74% for a naive bot: right difficulty? | Needs playtests |
| What sets the 136-198 onset of the original's warning, and how it counts "moves" and ranks | Scoring and clock details |
| Whether Codex's "time and access" case family belongs in the long-term design | Lab scope |
| Lying group in the pose index, the stale pose validator, `.import` policy, push protocol | Pose pipeline |
| Several Chris approvals rest on soft quotes ("Everything looks fine ... continue", a question counted as approval) | The user decides whether they stand |
| `design/case-generator` is pushed but not merged into `main`; the game does not use the dialogue, editor or docs yet | Release plan |
| How much faster does the stalker get when the true weapon is held, and is it announced? Recommended: the clock runs at 2x while it is in hand, with no immediate message (an immediate warning would tell the player the item is the weapon) | Danger clock |
| Lens redesign (layers 1, 2, 4 decided 2026-11-16; prototyped in Python, not in the game): same-kind decoys and a trace trait on the weapon (layer 3) are deferred; see GENERATOR_SPEC section 12 | Lens design |
