# Mansion Mystery

**Version 0.1.3 · Early playable prototype**

A pixel-art murder mystery set inside a secluded mansion. The doors are locked,
the guests have conflicting stories, and someone in the house is hiding the truth.
Explore the rooms, examine suspicious objects, question the household and piece
together what happened before presenting your accusation.

Inspired by the classic DOS game *Sleuth*, Mansion Mystery brings that style of
deduction into an atmospheric mansion with expressive characters and illustrated
Victorian interiors.

## Current local playtest

**Godot F5 now starts the current painted mystery.** Its main entry scene is
`src/mystery/painted_mystery.tscn`, with painted rooms and a randomized case.

The working checkout now has a full seeded investigation through eleven painted
rooms, with six suspects, personality dialogue, stable repeat accounts, clues,
danger and accusation endings. Char and Chris use directional poses; the remaining
cast uses temporary standing artwork. The investigator, object sprites, inspection
closeups and house map are available. Item floor positions are still provisional.

Launch the current painted mystery from PowerShell:

```powershell
.\tools\run_house_blockout.ps1 -Painted -Investigate
```

Use WASD/arrows to walk, E for nearby interactions and N for learned evidence.
Q drops the held item. The magnifying glass is a permanent tool that never
occupies the carrying slot. On Normal/Hard compare stained-item kinds with
the wound clue before choosing what to present. Nearby stacked items have a chooser.
Find the magnifying glass, compare accounts and inspect the house. Carry the
identified weapon before assembling an accusation. The seed and difficulty
menu starts a fresh randomized case. Turn off Random mystery to replay a case
number; the launcher also accepts `-CaseSeed <number>`. An ambush requires being
alone with the killer; other guests prevent an attack. The older authored mansion
remains available as its own scene, separate from the previously released version below.

## Controls and screens

The room fills the window. A translucent HUD shows the room name top-left, the
murderer's phase (Calm, Suspicious or Stalking) top-right in yellow and orange
phase colours, and a context action bar along the bottom.

- E interacts, speaks, examines or takes; Q drops the carried item.
- F examines the floor and needs the magnifying glass; N opens the journal.
- Tab shows the house map, Esc opens the menu and F11 toggles fullscreen.
- You carry one evidence item at a time. No evidence item can ever be in the Front Entry.
- The accusation screen shows six character cards and uses the room where everyone was gathered.
- The journal is player-controlled, with checkboxes and notes. Easy adds an automatic
  Facts tab only. Notes reset each case and never change the mystery.
- During an ambush the murderer's portrait zooms in dramatically.
- Char and Chris kneel to study the floor.

## In the current version

- One playable case: **The Silent Library**.
- Three suspects with accounts to compare.
- Evidence to examine, collect and inspect with a magnifying glass.
- A clue book that records discoveries and witness statements.
- Seven main rooms across three floors with revised interiors, connected by a stair hall and landing.
- Automatic doorway travel, named destinations and clear upstairs/downstairs routes.
- A current-floor connection map that highlights your room.
- Enlarged character portraits during conversations, plus saving and loading.

This is an early prototype. Room artwork, character presentation and the
investigation are still being refined. There is no packaged game download yet.

## Where the game is heading

An experimental **placeholder case lab** now tests generated mysteries separately
from the mansion: four suspects, four rooms, evidence, a notebook and replayable
seeds. See the [case-lab launch instructions](docs/development/README.md#placeholder-mystery-case-lab).
It offers an introductory witness conflict and a standard time-and-access case,
with Assisted, Standard or Classic notebook settings. Its fun and replayability
need playtesting.

Future plans include replayable randomized cases, characters with changing
personalities and activities, richer evidence, a difficulty-based
time limit and multiple endings. These features are planned for later versions.

## More information

- [How to play the current case](docs/FIRST_PLAYABLE_CASE.md)
- [Game ideas and future features](docs/GAME_DESIGN_BRAINSTORM.md)
- [Development setup and technical documentation](docs/development/README.md)
