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

- Measure the real staring and refusal rates in the original (Task 3 experiments) to replace the
  assumed settings.
- Port `generate()` and `candidates()` to GDScript, with Python-exported fixtures for parity tests.
- Specify the danger clock and re-run the simulator with the player under pressure.
