# House 02: stationary guests and danger clock

Aggression tuning (2026-11-16, superseding the short-lived forced-attack caps):
eligible entry/question chances are Easy 15%, Normal 20%, Hard 25%. Holding the
true weapon raises **questioning only** to 50%; entry keeps the difficulty rate.
Each roll is independent, with no miss counter, escalation or guaranteed attempt.
All checks still require the existing danger phase, actual killer presence, no
witnesses and a non-hall room. The existing silent 2x weapon danger clock remains.
Waiting/walking within the same room does not create new attack attempts. Explicit
0/1 test overrides remain disabled/guaranteed respectively.

Inventory update, 2026-11-16: `steps` remains physical walking distance; a separate
floating `danger_clock` drives phases. While the true weapon is held, each future
physical step adds `weapon_clock_multiplier` (2.0 by default) danger units; other
held items, glass and empty hands add 1.0. Pickup/drop flush prior walking before
changing the held flag. No immediate weapon-specific warning is displayed.
Dropping does not reverse danger. Guest snapshot intervals still use physical
steps. All existing solo-killer, witness, hall-safety and gathering-freeze rules
remain. Claude's updated silent-refusal banks use a 0.10 chance.

Guest presentation corrected October 26, 2026 following the user’s clarification.
Launch `tools/run_house_blockout.ps1 -Investigate` or run
`src/blockout/house_investigation.tscn` with F6.

## Room-entry snapshots

Guests stand at fixed spots for the whole visit. Walking inside the room, waiting,
examining, questioning and reading do not move them or refresh their idle activity.
There is no NPC walking, pathfinding, doorway travel or on-screen relocation.

When the player enters a non-hall room, resolve whether guests **had moved** while
the player was away, then place them directly at valid guest spots before displaying
the new room. Hall entry alone does not resample guests. Repeated per-frame or
inspection synchronization while staying in the same screen never rerolls them.

For now, the existing calibration is preserved: the relocation chance at entry is
`1 - (1 - guest_leave)^elapsed_steps`, with `guest_leave = 0.01` and elapsed walking
steps since the previous room-entry snapshot. Activity refresh uses the same
elapsed-time conversion from its existing 0.004 rate. These rolls are applied only
on entry, not continuously. The percentage remains a tuning choice.

Hard’s 30% direct pull toward the murder room remains checked before hall selection.
Guests already placed in that room always stare; staring can occur elsewhere too.
The glass plus a real stationary staring guest is required for Hard’s floor trace.
Char/Chris use approved static idle, talking, downward-looking, reading or
upward-looking poses. The shared art, scale and allowed spot facings are preserved.
Alibi statements never change with current whereabouts.

## Separate danger clock

Walking still advances the danger clock independently of these guest snapshots:

| Rule | Prototype setting |
| --- | --- |
| Suspicion warning | Seeded step 140–200 |
| Stalking | Warning plus 80–115 steps |
| Stalking room-entry ambush | 10% only when alone with the present killer |
| Culprit questioning after suspicion | 10% only when alone with the present killer |
| Stalking isolation bias | 50% on eligible room-entry snapshots |
| Halls | Safe from entry and question ambushes |
| Question refusals | 22%; unanswered accounts are not recorded |

Reading, standing still, blocked movement, actions and arrival teleports add no
walking steps. Carrying the weapon changes the death narrative, not warning timing.
Warnings persist in the HUD. Both death scenes reveal the solution and end the case.
Both entry and question ambushes require the culprit to be physically present in
the player's non-hall room with no other living guest there. An absent killer or
any bystander prevents the roll. During stalking, a separate seeded 50% isolation
roll can relocate bystanders out of the killer's room when compatible free spots
exist. This occurs only during room-entry snapshots after walking, never while a
visit or conversation is in progress. If relocation has no valid destination,
the bystander stays and continues to prevent an ambush. This is a 50% isolation
chance, not a 50% death chance; warning thresholds and the 10% attack rolls remain.

User correction, 2026-11-16: this supersedes earlier flat-entry death notes in
historical documents. `tools/house_danger_checks.gd` passes 422 assertions covering
absent/crowded/solo encounters, hall safety, both attack triggers, 0/1 isolation
controls, capacity constraints, immutable visible visits and seeded replay.

Settings are in `assets/mystery/house_runtime_rules.json`. They are prototype
choices informed by observations, not recovered DOS implementation details. The
reference simulator’s two-step actions and abstract ten-step hall legs do not apply
to this scene. Its published win rates do not describe this map. Claude’s design
worktree remains unmodified and unmerged.

## Validation

Focused native checks verify that even forced relocation/activity probabilities
cannot change guests while walking in the current room; room entry alone resolves
a completed relocation; snapshots replay deterministically; guest positions stay on
open floor; and alibis remain immutable. Existing clock, safe-hall, ambush, refusal
and live Hard-clue checks remain covered. The obsolete spatial walking tests and
unused NPC pathfinder were removed.

The playable UI regression also checks that in-room physics never moves guests or
resamples their snapshot. Human playtesting is still needed for the entry percentage
and pacing.
