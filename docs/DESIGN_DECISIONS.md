# Design decisions: current state

One page, plain language. Updated 2026-10-26 by Claude. Every row says **who decided**, **when**, and
**what is still open**. Details live in [GAME_DESIGN_BRAINSTORM.md](GAME_DESIGN_BRAINSTORM.md) (the
sections dated 2026-10-25 and 2026-10-26 at the end) and the evidence log in
`Claude observations/ORIGINAL_GAMEPLAY_OBSERVATIONS.md`. "Observed" means seen in the original game;
sample sizes are small (14 games).

## Decided by the user

| Area | Decision | Date |
| --- | --- | --- |
| Cast | 6-8 suspects (Easy may use 4, Normal 5) from a pool of about 10; the player can name, choose or randomize; exactly one victim per case, in the cast and not a suspect | 10-25 |
| House | Somewhat larger than the current 7-room scope; first slice stays small | 10-25 |
| Accusation | Original style: no checklist; **assembling requires carrying the true weapon**; accusing needs assembling first | 10-25 |
| Wrong accusation | Ends the case and reveals the truth: right person, wrong room = confession plus the true room; wrong person, right room = the real culprit stands up; both wrong = names both | 10-25 (observed in games 2, 10, 14) |
| Danger clock | Turn-based (room change or action) with visible phases: calm, "grown suspicious", stalking, ambush | 10-25 |
| Glass | Random room; never in the secret room on Easy or Medium; may be on Hard | 10-25 |
| Independence | Culprit, murder room, weapon item and glass chosen independently; weapon and murder room may rarely coincide | 10-25 |
| Murder room | Easy/Medium: a lens trace; Hard: original rule (bloodstains only while a guest stares) | 10-25 |
| Guests | Some guests can be found in the secret room, as in the original (seen in games 3 and 14) | 10-26 |
| Personalities | Eight (warm, nervous, proud, guarded, hot-tempered, curious, fragile, calm), random per case with manual override; voice and mood only | 10-25 |
| Murder room | Never the secret room, on any difficulty (glass and weapon may still be there on Hard; guests can stand in it) | 10-26 |
| Hard bias | On Hard, relocating guests head for the murder room 30% of the time and always stare there | 10-26 |
| Layout and danger | Long hallways; about 10% death chance per room entered once stalking starts; halls are safe but spend clock | 10-26 |
| Poses | A new resigned shrug for reveals; rest and sleep poses; two body-language templates (women follow Char; men follow a male template made with Chris first); neutral male standing is hands in pockets | 10-25, 10-26 |

## Observed in the original (use as evidence, not as rules)

- Innocents form mutual pairs plus a solo; the culprit names someone who does not return the claim
  (games 2-9). Two people naming the same partner in different rooms occurred in games 6 and 7.
- Bloodstains in the murder room appeared only while a guest stared at the floor there (9 of 9
  positive findings had a staring guest); staring guests also appeared in innocent rooms (about 47% of
  sightings were in the murder room).
- Assembling needs the weapon in hand; the weapon and murder room differed in all of my games.
- The murderer's ambush has two scenes (confession, or grabbing the weapon you carry).
- The secret passage entrance is a random column; the glass can be inside it.

## Built so far (branch `design/case-generator`, uncommitted)

- `tools/case_design/`: a case generator (4-8 suspects), an independent solver that proves each case
  has exactly one answer, and a simulator. 57 tests pass. See
  [case-design/GENERATOR_SPEC.md](case-design/GENERATOR_SPEC.md).
- `assets/dialogue/`: 864 original lines for the eight personalities plus narrator text, with a
  validator that blocks wording from the original. See
  [case-design/DIALOGUE_SCHEMA.md](case-design/DIALOGUE_SCHEMA.md).
- Comparison with Codex's case lab and requests for Codex:
  [case-design/PARITY_WITH_CODEX_LAB.md](case-design/PARITY_WITH_CODEX_LAB.md),
  [case-design/REQUESTS_FOR_CODEX.md](case-design/REQUESTS_FOR_CODEX.md).

## Still open

| Question | Where it matters |
| --- | --- |
| How to tame Hard: in the simulation a bot spends 210-300 turns after the weapon is found waiting for a staring guest | Danger clock and Hard difficulty (generator spec, section 9) |
| Danger clock: measured (moves-based, 28 games); still open: what sets the 136-198 onset and the command cost | [case-design/DANGER_CLOCK_SPEC.md](case-design/DANGER_CLOCK_SPEC.md) |
| How the original counts "moves", and its rank thresholds | Scoring |
| Hard difficulty: with the decided bias, naive-bot win rate is 51-74%; whether that is the right difficulty needs playtests | [GENERATOR_SPEC.md](case-design/GENERATOR_SPEC.md) section 11 |
| Whether Codex's "time and access" case family belongs in the long-term design | Lab scope |
| Whether to add a `lying` group to the pose index, and who fixes the stale pose validator | Pose pipeline |
| Chris's full appearance approval (his poses are disposable drafts until then) | Male template |
