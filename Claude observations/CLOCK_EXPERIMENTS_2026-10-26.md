# Danger clock and guest-rate experiments on the original (Task 3)

Run 2026-10-26 by Claude. Second house layout only (Shore/Seton/Winston/Donleavy estates), 28 logged games (23 reached the stalking phase), every
step logged by script. Counts only; wording paraphrased. "Move" = a key press that changed the player's cell
(my count, not the game's own, which I could not read). Raw logs are local, not in the repo.
Sample sizes are small; treat ranges as ranges.

## 1. The danger clock is counted in moves

| Behaviour (no weapon unless noted) | Games | "Grown suspicious" at move | "Stalking" at move | Room entries by then |
| --- | ---: | --- | --- | --- |
| Tour all rooms | 6 | 152-181 | 248-280 | 32-59 |
| Cross one doorway back and forth | 3 | 157-182 | 253-278 | 138-163 |
| Walk only in the main hall | 3 | 151-191 | 251-271 | 16-20 |
| Stand in one room (door every 100 moves) | 3 | at or before 239* | at or before 353* | 9 |
| Investigate (glass plus examine everything) | 4 | 152-181 | 257-270 | 32-39 |
| Carry the true weapon | 4 | 181-198 | 280-295 | 38-39 |
| Question every guest met | 2 | 132-136 | 217 | n/a |

*Message only shows when the screen redraws, so these are upper bounds.

- **All 20 clean measurements:** suspicion at 136-198 moves (mean 169; 23 stalking onsets, gaps 80-114). Stalking follows **80-114 moves
  later (mean 98)**.
- Behaviour did **not** change the onset, even with 4 to 40 times more room entries per move. So the clock
  counts moves, and moves taken standing in a room count too.
- **Weapon multiplier: not supported for the warnings.** Carrying the weapon from move 131 or 218 gave
  warnings at 181/280 and 191/290, inside the normal range, with the same 99-move gap.
- **Questioning may speed it up (weak).** Both questioning games got suspicion at 132-136, about 35 moves
  early. Two games is not enough to be sure.
- Repeated values (167 four times, 181 three times) suggest the onset is not a smooth random draw, but
  I could not find what sets it.

## 2. Death happens only when you enter a room

- Deaths: 23 games reached stalking; 16 ended in a death scene, **all on entering a room** ("locks the door
  behind you as you enter").
- **Hall only: 3 games, 600 moves each after stalking, no deaths.** Walking inside one room: no deaths either.
- Per room entry after stalking, touring varied rooms: **about 1 death in 10 entries**
  (9 deaths, 92 entries). Delay from stalking to death ranged from 1 to 763 moves.
- Crossing into one room 350 times gave 2 deaths (0.6 per 100). The murderer is not homing on the room
  you keep entering; he looks closer to random.
- **Carrying the weapon:** 3 deaths in 39 entries (7.7 per 100), not different from 9.8 per 100. The
  weapon death scene is the one where the murderer grabs it.
- **Questioning can be the trigger.** In one game I questioned the murderer after the first warning and
  the death scene began right there (move 147), before the stalking message. So asking the murderer is
  dangerous once suspicion is up.
- For the remake: long hallways are **not dangerous** in the original. They cost clock (moves) but never
  a death. Danger comes from the room you step into.

## 3. Guests (126 sightings, 19 touring games)

- **Staring at the floor: 34 of 126 sightings = 27%** (earlier 14 of 36 = 39%). The simulator assumed
  12% per turn. The other activities: searching 14, lying 11, fixing a snack 8, a few others, plus
  activities I did not categorize (54).
- **Guests stay put.** A guest seen in a room was still in that same room at my next visit
  (median 170 moves later) in **14 of 75 cases (19%)**, which is about 1% leaving per move. The simulator
  assumed 35% per turn. Standing still in a room, a guest never moved in 300 moves.
- Guests are in a room on only 37% of room visits (0.37 per visit with 6 guests).
- A guest keeps the same activity only about half the time (7 of 14) while staying.

## 4. Refusals

23 questions answered or ignored in 2 games: **5 refusals (22%)**: "ignores you", "does not respond",
"says nothing". Close to the simulator's 25%. A repeat question gets the same claim restated.

## 5. What this changes

- **Danger clock for the remake:** warning at about 170 moves, stalking about 100 moves after, then a
  per-room-entry risk of about 10%. Use moves as the unit; halls are safe.
- **Hard difficulty:** guests move about 35 times slower than the simulator assumed, and 27% of
  sightings are staring. That makes a staring guest in the murder room easier to catch than I feared,
  but also easier to wait out. Re-run the simulator with the real rates before deciding.
- **Level layout:** if rooms are close together, a player enters more rooms per move, so more death rolls
  per move. Longer halls reduce rolls per move but spend the clock. This is a tuning knob, not a bug.

## 6. Limits

- One house layout; case variety only through the cast and room contents.
- The game's own move count was unreadable, so thresholds are in my count.
- Weapon games: 4 (one survived 324 moves after stalking); questioning games: 2.
- Where my script could not find the glass (about one game in three) I discarded the run.
- Experiments stopped on the user's request.
