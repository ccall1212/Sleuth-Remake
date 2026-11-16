# Danger clock spec (draft)

Written 2026-10-26 by Claude. Evidence: `Claude observations/CLOCK_EXPERIMENTS_2026-10-26.md` (28 logged
games of the original, second house only; small samples). Labels: **observed** (measured in the original),
**decided** (user), **proposed** (my design for the remake, still open to change).

## 1. Unit of time: the move

- **Observed:** the original's clock counts moves (a step that changes the player's cell). Room entries do
  not matter: games with 4 to 40 times more room entries per move got the same warning times.
- **Proposed:** the remake counts **steps** the same way. Steps inside a room count. Talking and
  examining do not advance the clock by themselves (the original's cost for commands is unknown).

## 2. Phases (observed values in brackets)

| Phase | Starts | Player sees |
| --- | --- | --- |
| Calm | game start | nothing |
| Suspicious | about step 170 [136-198, mean 169] | one-time warning, kept on screen |
| Stalking | about 100 steps later [80-114, mean 98] | warning kept on screen |
| Ambush | any room entry while stalking | death scene |

- **Proposed:** onset drawn per case from 140-200 steps (seeded, so a case is reproducible); stalking at
  onset + 80 to 115. Easy may shift the numbers later; do not change the 100-step gap, it is the most stable
  thing I measured.
- **Observed, weak:** asking questions may bring suspicion forward by about 35 steps (2 games). Not adopted.
- **Observed, not supported:** carrying the weapon does not speed up the warnings.

## 3. Ambush rules

- **Observed:** deaths happen **only on entering a room**, never in a hall (0 deaths in 1,800 hall steps
  after stalking) and never while standing in a room.
- **Observed:** about 1 death per 10 room entries after stalking when touring varied rooms (9 deaths in 92
  entries). It does not home in on the room you keep re-entering (2 deaths in 350 entries of one room).
- **Decided (2026-10-26):** long hallways, about **10% per room entered** after stalking.
- **Proposed model:** the murderer occupies one room at a time, hops to a random other room every few
  steps, and kills when you enter his room. That gives about 1 in (rooms) per entry, near the observed 10%
  for a ten-room house, and means a bigger house lowers the per-entry risk automatically. Alternative:
  a flat 10% roll per entry. Pick one when the lab is built; do not mix.
- **Death scene A** (not carrying the weapon): door locks, the murderer states room and weapon, then the
  game offers restart. **Scene B** (carrying it): he grabs the weapon from your hands and strikes you.
  Both reveal the full solution on a loss (observed).
- **Observed:** questioning the murderer after the first warning can start the death scene on the spot.
  **Proposed:** after the suspicious phase, questioning the culprit has the same death chance as entering his
  room.

## 3b. Halls

- Halls are safe but spend clock. The decision to keep long halls (user, 2026-10-26) is a difficulty knob:
  more hall steps means less time left for the investigation, with no extra death rolls.
- Rooms close together raise rolls per step; keep room entry cost (steps between rooms) in the layout
  brief so the level designer sees it.

## 4. Guest and clue rates to use in the simulator (replacing the assumed numbers)

| Setting | Assumed before | Measured |
| --- | --- | --- |
| Guest leaves a room | 35% per turn | about 1% per step (19% still in the same room 170 steps later, 14 of 75) |
| Guest staring at the floor | 12% per turn | 27% of sightings (34 of 126) |
| Question refused | 25% | about 22% (5 of 23) |
| Guest present in a room on entry | not set | 37% of visits (0.37 guests per visit, six guests) |

## 5. Decided with this spec

- The murder room is **never the secret room** on any difficulty (generator version 2). The glass or weapon
  may still be there on Hard, and guests can stand in it.
- **Hard bias (decided 2026-10-26):** guests head for the murder room 30% of the time and always stare there.
  With it a naive bot wins 51-74% on Hard (GENERATOR_SPEC section 11).
- That removes the 700-turn secret-room case from Hard; Hard's remaining question is how long the staring-guest
  wait is with the measured rates (to re-simulate).

## 6. Open

- What sets the 136-198 range; the game's own move count was unreadable.
- Cost of commands in the clock.
- Whether the first house layout behaves the same (only the second house was tested).

## 7. Adopted by the game (2026-11-16)

Codex's runtime uses these numbers unchanged (`assets/mystery/house_runtime_rules.json`): warning 140-200, stalking gap 80-115,
10% entry death, 10% culprit-question death after suspicion, halls safe, refusals 22%. It differs in two ways: actions and doors
cost no steps, and guests relocate only when the player enters a room. Details in `REVIEW_2026-11-16.md`.
