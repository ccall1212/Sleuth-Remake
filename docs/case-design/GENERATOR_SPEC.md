# Case generator and solver: rules and simulated difficulty

Reference implementation: `tools/case_design/` (Python 3, no Godot). Written 2026-10-26.
Labels used throughout: **observed** (seen in the original), **decided** (the user chose it, see
`docs/GAME_DESIGN_BRAINSTORM.md`), **inferred** (my reading) and **assumed** (a simulation setting
I made up). Test command: `python -m pytest tests/case_design`.

## 1. What a case is

One victim, 4-8 suspects and a house of 7-12 rooms. The last room is a secret room. Each room holds one
carryable item. The case fixes: the culprit, the murder room, the weapon (an item in some room), the
room whose item slot holds the magnifying glass, and each suspect's statement. All of it comes from a
seed.

- **Suspects and rooms** (decided: 6-8 suspects, with 4 and 5 allowed for Easy and Normal):
  4 suspects = 7 rooms, 5 = 8, 6 = 10, 7 = 11, 8 = 12 (counting the secret room).
- **Cast:** names come from a pool, the last chosen name is the victim, who is never a suspect (decided).
- **Personalities:** one of eight per suspect, at most two of the same (decided). Voice only.

## 2. The four independent choices (decided)

Culprit, murder room, weapon room and glass room each use their **own** random stream, derived from
`SHA-256(version, seed, name)`. No stream reads another's state, so changing the cast, the voices, the
guests' starting rooms or the room names never changes the mystery (tested).

Rules that only constrain the *values*, never the streams:
- The glass and weapon never share an item slot. The weapon may share a room with the murder room by
  chance (about 1 in 9 at six suspects; tested at 7-14%).
- The murder room is **never** in the secret room on any difficulty (user, 2026-10-26; generator version 2).
- Easy and Normal never place the glass or weapon in the secret room. Hard may.
- Statements never place anyone in the secret room.

## 3. Alibis (observed in the original, observations sections 12, 17.6 and 18.3)

For N suspects there are N-1 innocents:
- They form **mutual pairs** (each names the other and the same room) plus **0 to 2 solos** ("alone").
  The solo count has the parity needed, and at least one pair always exists.
  Typical shapes: 4 suspects = one pair and one solo; 5 = two pairs; 6 = two pairs and one solo; 7 =
  three pairs; 8 = three pairs and one solo.
- Different groups claim different rooms, and **no innocent claims the murder room**.
- The **culprit always names a partner** who does not return the claim, and is never "alone" (an alone
  culprit would hide among the solos).
  - *Plain:* a solo target in the solo's own room, or a pair member in the pair's room.
  - *Decoy (harder):* a pair member in a **different** room, so two people name the same partner.
    This is what I saw in games 6 and 7.
  - Decoy chance: Easy 0, Normal 0.5, Hard 1.0 (assumed; the original's rate is unknown).

## 4. The solver (`solve.py`)

It sees only what a player can discover: statements heard so far and, once found, the murder room. It
never reads the culprit, the weapon or the glass. A suspect **c** is a possible liar when, ignoring
c's own statement, every other statement is believable:

1. it is not in the murder room;
2. it does not name c as a partner (c was at the crime, so honest company would also have been there);
3. if it names a partner whose statement has been heard, that partner names it back in the same room.

Statements not yet heard impose no constraint. A case is **valid** when, with everything known, exactly
one possible liar remains and it is the true culprit. `problems(case)` runs that check plus the house
rules above and returns a list of faults (empty means fair).

Properties tested over thousands of seeds: every generated case is valid and unique for every suspect
count and difficulty; hearing only some statements never rules out the real culprit; hearing everyone is
always enough; handmade bad cases are rejected.

## 5. Difficulty

| Setting | Easy | Normal | Hard |
| --- | --- | --- | --- |
| Decoy chance | 0 | 0.5 | 1.0 |
| Murder room confirmed by | lens trace (always) | lens trace (always) | a guest staring at the floor (original rule) |
| Glass and weapon may be in the secret room (murder room never) | no | no | yes |

All other numbers (movement, refusals, staring) are simulation assumptions.

## 6. Simulated play (`simulate.py`, `run_sim.py`)

A bot plays 1,000 seeds per cell, using only discoverable information and calling `candidates()` to
decide whom to accuse. It tours rooms, takes the glass, questions guests, examines items and floors, takes
the weapon, goes to the murder room, assembles and accuses. A turn is a room change or an action; moving
between rooms costs 2 (via the hall).

**Assumed settings (not measured):** each guest jumps to a random room with probability 0.35 per turn;
a question is refused with probability 0.25 (retried up to 3 times per visit); a guest stares at the
floor with probability 0.12 per turn.

| Suspects | Difficulty | Win | Mean turns | Median | p90 | Max | Questions | Refusals | Turns after weapon found | Culprit known before all questioned |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | easy | 100% | 40.1 | 38 | 54 | 133 | 4.5 | 1.1 | 17.7 | 75.0% |
| 4 | normal | 100% | 42.2 | 39 | 62 | 133 | 4.6 | 1.2 | 19.7 | 61.4% |
| 4 | hard | 100% | 234.1 | 170 | 530 | 1473 | 5.2 | 1.3 | 210.6 | 48.3% |
| 5 | easy | 100% | 47.8 | 46 | 64 | 133 | 5.7 | 1.5 | 20.8 | 72.0% |
| 5 | normal | 100% | 48.1 | 46 | 68 | 148 | 5.8 | 1.5 | 21.1 | 71.3% |
| 5 | hard | 100% | 246.4 | 174 | 550 | 1631 | 6.5 | 1.6 | 219.0 | 72.2% |
| 6 | easy | 100% | 58.0 | 56 | 79 | 158 | 6.7 | 1.7 | 25.4 | 83.0% |
| 6 | normal | 100% | 59.9 | 57 | 86 | 165 | 6.7 | 1.7 | 27.3 | 74.6% |
| 6 | hard | 100% | 318.1 | 234 | 696 | 1934 | 7.8 | 2.0 | 284.5 | 67.4% |
| 7 | easy | 100% | 65.7 | 63 | 91 | 226 | 7.8 | 1.9 | 29.2 | 80.2% |
| 7 | normal | 100% | 65.8 | 63 | 93 | 198 | 7.8 | 1.9 | 29.2 | 78.3% |
| 7 | hard | 100% | 333.8 | 230 | 739 | 1967 | 9.0 | 2.2 | 297.5 | 81.1% |
| 8 | easy | 100% | 70.5 | 69 | 96 | 224 | 8.8 | 2.2 | 30.4 | 86.7% |
| 8 | normal | 100% | 70.7 | 68 | 97 | 224 | 8.7 | 2.2 | 30.7 | 82.0% |
| 8 | hard | 100% | 339.4 | 233 | 756 | 1729 | 10.4 | 2.6 | 299.6 | 75.1% |

Full numbers: `simulation_results.json` (regenerated 2026-10-26 after guests were allowed in the secret room).

## 7. What the numbers say

- **Easy and Normal are almost the same.** About 40-71 turns for a perfect bot, with a long
  tail only in unlucky guest movement. The decoy changes how *clear* the clue is more than how long
  the case takes.
- **Hard is 5-6 times longer, and nearly all the extra time comes after the weapon is found** (211-300
  turns versus 18-31). That is the bot waiting for a guest to stare at the murder room's floor. The tail
  is long (p90 up to 756 turns, max 1,967).
  - Under the decided turn-based danger clock, that wait is also **time spent while the murderer is
    stalking**, so Hard as specified would be close to unwinnable for a careful player. Either tune
    the staring (below) or shorten the danger clock on Hard.
- **The culprit is often known before everyone is questioned** (50-88% of games). Large casts have
  redundant information: the pair-and-solo structure eliminates people quickly. Decide whether that is
  the right feel or whether more suspects should mean more questions.
- **Counting questions:** a bot needs about one question per suspect plus ~25% refusals, regardless of
  difficulty.

## 8. Limits and surprises

- The bot is efficient and ignores danger, so human turn counts will be higher. The settings in
  section 6 are **assumed**, not measured.
- **Hidden murder room (superseded 2026-10-26).** The user ruled out secret-room murders, so the 690-720-turn
  cases no longer occur. The figures in section 6 were produced before that change and with assumed guest rates;
  re-run with the measured rates (`DANGER_CLOCK_SPEC.md`, section 4).
- **Blind floor checks are useless in staring mode:** a player can see who is staring before acting, so
  examining a floor "just in case" never succeeds. Players will learn to watch for staring guests.
- **Move cost between rooms (2 turns via the hall) is a modeling shortcut,** not the original's grid.

## 9. Tuning options for Hard (for the user to choose)

1. Raise the chance that a guest standing in the **murder room** stares (a bias, not a guarantee).
   My live sample was 9 hits in 19 sightings, about 47%, which suggests the original may bias staring
   toward the murder room, but that is a small sample.
2. Guarantee a staring guest in the murder room at least once every N turns.
3. Keep Hard's staring-only rule but give it a longer danger clock.
4. Add a second cue (for example a faint trace visible only to a staring guest's gaze).
5. For secret-room murders on Hard: raise the chance that a guest stands and stares in the secret
   room, or limit secret-room murders to a smaller share of Hard cases.

## 10. Next steps

- ~~Measure the real staring and refusal rates in the original~~ Done 2026-10-26 (28 games): see
  `Claude observations/CLOCK_EXPERIMENTS_2026-10-26.md` and section 11.
- ~~Port `generate()` and `candidates()` to GDScript~~ Done by Codex (`src/mystery/generated_case.gd`); 900 of 900 cases
  identical to this reference. Turn it into a fixture test.
- ~~Specify the danger clock~~ Done (`DANGER_CLOCK_SPEC.md`), adopted by the game's runtime.


## 11. Step-clock simulation (new game's time model, 2026-10-26)

`tools/case_design/simulate_clock.py`, run with `python -m case_design.run_clock`. This replaces the turn
simulator for design decisions; section 6 above used guesses that the original-game experiments disproved.
Inputs are **measured** (see `DANGER_CLOCK_SPEC.md`): guests leave a room at 1% per step, 27% of guest
sightings are staring, 22% of questions are refused, warning at step 140-200, stalking 80-115 steps later,
10% death per room entered while stalking, halls safe. House-model costs are my assumptions: 10 steps per
room-to-hall leg, 2 per action. The bot is naive about danger (keeps its normal search), so win rates are
a **floor** for a player who rushes once warned. 1,000 seeds per cell, results in
`simulation_clock_results.json`. **Re-run 2026-11-16 with 10% silent refusals** (decided; the original measured about 22%). **Hard includes the murder-room bias decided 2026-10-26** (below); the
unbiased Hard numbers are in the tuning table.

| suspects | difficulty | win | died | timed out | reached stalking | median steps (won) | p90 steps (won) | questions | rooms entered |
|---|---|---|---|---|---|---|---|---|---|
| 4 | easy | 94.7% | 5.3% | 0.0% | 21.8% | 204 | 284 | 4.2 | 9.5 |
| 4 | normal | 94.5% | 5.5% | 0.0% | 22.8% | 206 | 286 | 4.2 | 9.7 |
| 4 | hard | 72.6% | 27.4% | 0.0% | 55.8% | 251 | 376 | 4.3 | 13.9 |
| 5 | easy | 89.4% | 10.6% | 0.0% | 40.0% | 228 | 328 | 5.2 | 10.7 |
| 5 | normal | 89.6% | 10.4% | 0.0% | 40.5% | 231 | 330 | 5.2 | 10.8 |
| 5 | hard | 68.7% | 31.3% | 0.0% | 65.3% | 278 | 380 | 5.3 | 14.2 |
| 6 | easy | 78.1% | 21.9% | 0.0% | 60.1% | 264 | 400 | 6.3 | 12.9 |
| 6 | normal | 77.7% | 22.3% | 0.0% | 61.1% | 266 | 402 | 6.3 | 13.0 |
| 6 | hard | 57.4% | 42.6% | 0.0% | 77.6% | 316 | 430 | 6.5 | 15.8 |
| 7 | easy | 67.0% | 33.0% | 0.0% | 70.8% | 286 | 440 | 7.3 | 13.8 |
| 7 | normal | 67.7% | 32.3% | 0.0% | 70.7% | 286 | 442 | 7.3 | 13.8 |
| 7 | hard | 56.3% | 43.7% | 0.0% | 78.2% | 310 | 454 | 7.5 | 15.7 |
| 8 | easy | 61.8% | 38.2% | 0.0% | 77.0% | 307 | 472 | 8.4 | 14.6 |
| 8 | normal | 61.6% | 38.4% | 0.0% | 76.9% | 309 | 474 | 8.4 | 14.7 |
| 8 | hard | 50.6% | 49.4% | 0.0% | 83.6% | 336 | 496 | 8.5 | 16.3 |

Reading it:
- **Easy and Normal** win 95% (4 suspects) down to 63% (8 suspects) for the naive bot. Median winning
  game is 206-312 steps, in line with the original's 233-549 moves. The decoy changes nothing measurable.
- **Hard, unbiased, is nearly unwinnable:** 10-17% win, 85-90% die (tuning table). The bot needs a staring guest
  in the murder room, and that takes longer than the clock allows; with danger off the same cases need a median
  of **1,347 steps**. With the decided bias Hard wins **51-74%** (74% at 4 suspects, 56% at 6, 51% at 8), median
  winning game 255-334 steps. It stays the hardest setting but is winnable.
- Bigger casts are harder because of more questions and more room entries before the stalking phase ends.

Hard tuning options tested (6 suspects, same bot):

| Change on Hard | Win | Died |
| --- | ---: | ---: |
| As specified | 11.5% | 88.5% |
| Guests in the murder room always stare | 32.4% | 67.6% |
| Relocating guests head to the murder room 15% of the time | 19.8% | 80.2% |
| Both of those | 49.0% | 51.0% |
| Pull 30% plus always staring | 56.5% | 43.5% |
| Pull 30%, always staring, death 5% per entry | 71.2% | 28.8% |
| Death 5% per entry only | 17.5% | 82.5% |

**Decided (user, 2026-10-26):** on Hard, a relocating guest heads for the murder room 30% of the time and a
guest standing there always stares (`HARD_BIAS`, `params_for('hard')`). The original's live sample (9 of 19
staring sightings in the murder room) already suggests staring is concentrated there. Lowering the death
chance alone does not fix Hard; the staring wait was the bottleneck. The generator itself is unchanged: the
bias is a runtime rule the game must implement for Hard.

**Caveat, 2026-11-16.** The game's runtime (`assets/mystery/house_runtime_rules.json` in the main folder) charges walking steps
only (`action_steps` 0, `portal_steps` 0) and rolls guest relocation once per room entry. The simulator above charges 2 steps per
action and 10 per room-to-hall leg and moves guests every tick, so its win rates are a model of an earlier design, not of the
shipped rules. Re-run `python -m case_design.run_clock` with `ClockParams(action_steps=0, ...)` before using it to tune.

## 12. The lens model: stains, wound kinds and the glass slot (2026-11-16)

Decided by the user: **layers 1, 2 and 4** of the inspecting ideas. Layer 3 (decoys of the *same* kind, and a trace trait on the weapon matched to suspects) is
deferred.

- **Layer 1: the lens shows "a stain", not "the weapon".** On Normal and Hard it shows a stain on the weapon and on **two decoy items**; the player sees each item's
  kind. (Decoys are part of layer 1: without other stained items a stain would still name the weapon.)
- **Layer 2: the wound kind.** Every item has a kind (`blunt`, `sharp`, `heavy`, in `model.ITEM_KINDS`). The wound is the weapon's kind and is revealed **with the
  murder room** (the floor trace on Easy and Normal, the staring-guest trace on Hard). Decoys are always of another kind, so exactly one stained item matches.
  Checked by `solve.weapon_candidates` and `problems()` on every case.
- **Layer 4: Easy stays easy.** On Easy the lens names the weapon outright (no decoys), as before; the wound is still the same kind.
- **Streams:** two new seeded streams, `items` and `stains`; none of the four independent choices, the alibis or the cast move. `Case` gains `item_kinds`, `decoy_rooms`,
  `weapon_certain` (older cases load with defaults). The version number stays 2.
- **One item at a time, the glass is the item, free drop (decided).** Modelled in `simulate_clock.py`: the bot drops the glass to take the weapon, cannot use the lens
  while carrying it, and the danger clock runs `weapon_clock_multiplier` (2.0) times faster while the **true** weapon is in hand.

Measured, 6 suspects, 1,000 seeds per cell, naive bot (it still needs the murder room before it can accuse, so the wound is free for it):

| | Win, old lens | Win, new lens, x1 | Win, new lens, x2 |
| --- | ---: | ---: | ---: |
| Easy | 78.5% | 78.5% | 78.1% |
| Normal | 78.2% | 78.2% | 77.7% |
| Hard | 57.6% | 57.6% | 57.4% |

(The table above was re-measured at 10% refusals; the notes below were first measured at 22% and change by about a point.)

What the numbers say:

- **The new lens barely moves a methodical bot's win rate**, because deducing the weapon costs it nothing extra: the murder-room trace it needs anyway reveals
  the wound. The change is about **how a player decides**, not how long the bot takes.
- **A sloppy player is punished.** The first stained item the lens shows is the weapon in only **35% of Normal cases and 33% of Hard cases**, so carrying it and
  accusing without using the wound clue gives the new wrong-weapon outcome about two times in three.
- **Between first stain and wound known** a bot spends about 78 steps (Normal) and 115 steps (Hard): the window in which a gambler can only guess.
- **The weapon multiplier is weak as a deterrent for this bot.** A bot that takes the weapon as soon as it knows it and keeps questioning loses about 2 points of win
  rate at x2 and 3.6 at x3 on Normal (76.7 to 74.7 and 73.1). It matters more for a human who carries early; tune it by playtest. A bigger multiplier, or a higher
  ambush chance while carrying, are the levers.
