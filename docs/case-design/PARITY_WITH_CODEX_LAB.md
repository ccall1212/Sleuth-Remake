# Parity: Python reference generator vs Codex's case lab

Compared on 2026-10-26 by reading `src/mystery/lab_case.gd` (version 2, uncommitted on Codex's branch).
I did **not** run the lab. This note lists where the two agree, where they differ, and what each
difference would mean. Proposed changes for Codex are in [REQUESTS_FOR_CODEX.md](REQUESTS_FOR_CODEX.md).

## Where they agree

| Rule | Lab (`conflicting_witness`) | Reference generator |
| --- | --- | --- |
| Innocents form mutual pairs plus solos | One pair and one solo among 3 innocents | Pairs plus 0-2 solos for 4-8 suspects |
| The culprit names a partner who does not return the claim | Yes | Yes (always a partner, never "alone") |
| Innocents' claimed rooms differ from the murder room | Yes (`rooms[0]` is the crime, pair and solo use `rooms[1]`, `rooms[2]`) | Yes |
| Solver uses only discoverable facts and must find exactly one answer | `candidates()` and `validate()` | `solve.candidates()` and `problems()` |
| Weapon item and cast/voices use independent random streams | `rng`, `staging_rng`, `voice_rng` | Seven named SHA-256 streams |
| Claims repeat unchanged when asked again | Yes (`question()` keeps the same claim) | Same rule; refusals add retries only |

## Where they differ

| Topic | Lab | Reference | Why it matters |
| --- | --- | --- | --- |
| Suspects and rooms | 4 suspects, 4 rooms | 4-8 suspects, 7-12 rooms | The user decided on 6-8 suspects and a larger house |
| Culprit's claimed room | Always a room another group occupies (the pair's room or the solo's room) | Any claimable room except the murder room; a decoy uses a different room from the target's | The reference reproduces what I saw in the original (games 6 and 7: the culprit and the pair-mate named the same person in different rooms) |
| Decoy (two people name one partner) | Variant 1 only by accident (solo room, pair member) | Explicit difficulty setting (0, 0.5, 1.0) | Needed for Hard |
| Solver logic | Enumerates room x weapon x culprit and checks "placed" locations | Enumerates culprits only; room and weapon are single discovered facts | The reference treats the lens trace and the weapon mark as direct clues, which matches the original |
| Honest statement may name the culprit if the room equals the crime room | Allowed (`placed[culprit] != room` check) | Never allowed | Simpler for the player; fine to merge on the stricter rule |
| Glass | Fixed in the foyer | Random room; never in the secret room on Easy/Medium; may be in it on Hard | Decided 2026-10-25 |
| Secret room | None | Hidden room as the last room; weapon, glass or murder room may be there only on Hard | Decided 2026-10-25 |
| Murder-room discovery | Always a lens trace in the room | Easy/Medium: lens trace. Hard: only while a guest is staring at that floor | Decided 2026-10-25 |
| Weapon pickup | Blocked until the crime room is known and all four accounts are heard | Allowed once identified | The original and the decision are "assembling needs the weapon in hand"; picking it up earlier is fine, and it starts the danger phase |
| Accusation gate | Blocks accusing until glass, accounts, room and weapon are done; wrong accusation permits a retry | Assemble needs the weapon; accusing needs assembly; a wrong accusation ends the case and reveals the truth | The user decided to remove the checklist and use original-style consequences |
| Danger clock | None | Not in the generator; the simulator reports "turns after the weapon is found" as exposure | A turn-based clock is decided but not yet specified |
| Family 2 (`timed_access`) | Two five-minute windows plus restricted weapon access | None | I saw nothing like it in the original. It looks like a new design; test it separately from the pair-and-solo structure |

## Notes

- The lab's `LINKS` graph (four rooms in a ring) and its four voices are fine for the lab. The
  reference simulator uses a hub-and-spoke house, and its guest movement is deliberately simple.
- The reference has no `timed_access` equivalent on purpose. If Codex wants one, the solver contract
  should stay the same: it may use only discoverable facts and must return exactly one culprit.
