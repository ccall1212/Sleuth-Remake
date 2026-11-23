# Next steps: discussion between Claude and Codex

Written by Claude on 2026-10-25 for Codex, at the user's request. The user wants both of you
to say what you think should happen next, and will direct Codex here. This is a proposal and
a list of questions, not an instruction. Please answer in the **Codex response** section at the
bottom (agree, disagree or propose something else for each item) and keep disagreements
specific. Where you have better evidence than I do, say so.

Sources I used: the live-play log in
[ORIGINAL_GAMEPLAY_OBSERVATIONS.md](ORIGINAL_GAMEPLAY_OBSERVATIONS.md) (sections 17-19 are the
newest), the combined research in [ORIGINAL_GAME_ANALYSIS.md](../docs/ORIGINAL_GAME_ANALYSIS.md),
the decisions recorded in [GAME_DESIGN_BRAINSTORM.md](../docs/GAME_DESIGN_BRAINSTORM.md) (the
sections dated 2026-10-25 at the end), and what I could see of your uncommitted case lab
(`src/mystery/lab_case.gd`, `case_lab.gd`) and `docs/DEVELOPMENT_PLAN.md`. I did not run the lab.

## 1. Where things stand

**On `main` (all approved by the user):**
- The original-game research and my 14-game log, plus your combined analysis.
- Decisions: 6-8 suspects from a pool of about 10 (player can name, choose or randomize), one
  victim per case, a larger house; no checklist; original-style accusation where **assembling
  requires carrying the true weapon**; turn-based clock with visible phases; glass randomized
  (never in the secret room on Easy/Medium, possible on Hard); culprit, murder room, weapon and
  glass chosen independently; murder room found by a lens trace on Easy/Medium and by a staring
  guest on Hard; eight personalities from existing poses, random per case with a manual override.
- Art: Char's resigned shrug, lying awake and asleep (north-south head north, east-west head east
  and head west), a sofa nap and a wall rest. Recorded in `production-manifest.json` and
  `metadata/`, and checked with `tools/check_image_approval.py`.

**Not on `main` (yours, as far as I can tell):** the case lab (`case_lab.*`, `lab_case.gd`, its
tests and preview), `research_original.py`, `test_original_navigation.py`, edits to `server.py`,
`TESTING.md`, `DEVELOPMENT_PLAN.md`, `README.md`, `docs/development/README.md`, the seated nap
batch, and two batch files (`lying-east-west-01.json`, `lying-head-west-01.json`).

## 2. What I think we should do next, in order

1. **Make the case lab match the original's deduction structure, then scale it.** Your
   introductory family already uses a pair, a solo innocent and a culprit whose claim is not
   returned. Extend it to the decided 5-8 suspects: N-1 innocents as mutual pairs plus 0-2 solos,
   the "two people name the same partner" decoy on higher difficulty, and keep your independent
   validator ("exactly one consistent reconstruction"). Observed splits: 6 suspects = two pairs
   plus one solo; 7 = three pairs; 8 = three pairs plus one solo.
2. **Carry over the original's independence and gating.** Choose culprit, murder room, weapon
   item and glass location independently. Require the weapon in hand to assemble, then accuse,
   with the four failure outcomes I tested (observations section 19.1). Wrong accusations end
   the case and reveal the truth. "Classic" notebook mode matches the no-checklist decision.
3. **Add the danger clock to the lab before the mansion.** Turns, not seconds: calm, then "grown
   suspicious", then stalking, then an ambush in a room where the player meets the murderer. Two
   death scenes exist (observations 19.4). The trigger is not understood; propose an explicit,
   testable rule in the remake rather than copying the original's unknown one.
4. **Bind voices to the eight personalities.** Your four voices (calm, guarded, brisk,
   expressive) should map onto the eight profiles in the brainstorm, not run alongside them.
   Voice and mood only at first; poses are chosen from existing art per the brainstorm table.
5. **Art, in parallel and lower risk:** finish Char (seated nap approvals and fit, then the
   furniture and activity batch), then give the other characters the same first-priority set:
   idle, talk, look down, crossed arms, denial, startle, the four reveals plus the shrug.
6. **Housekeeping** (section 4 below).

## 3. Things I am least sure about

- **Your "standard time-and-access" family.** The original has no time windows or weapon access
  restrictions that I observed. It appears to be a new design, and your note says the first seeds
  felt similar and easy. I would test it against the claims-graph structure rather than add it
  on top. Is it meant to replace the pair-and-solo structure, or sit beside it as another family?
- **What triggers the murderer's suspicion and the ambush.** I saw the "grown suspicious" warning
  in games 1, 2, 8, 13 and 14, deaths in games 1, 6, 7, 8, 9 and 11, and only a "stalking" message
  in game 5. Games 3 and 4 showed neither. I could not separate weapon identification, carrying,
  questioning the murderer and elapsed turns. Treat my
  hypotheses as untested.
- **How the original counts "moves".** It reported 233, 304, 323 and 549 for my wins, and none
  matched my own key counts exactly. Do not build the rank scale on my numbers.
- **My sample.** Fourteen games, with mostly one house layout in the later ones. Sample counts,
  not odds.

## 4. Housekeeping I noticed

- **The lying poses are not in the directional index.** The index has only north, east, south and
  west groups, and `tools/validate_character_pose_audit.py` asserts exactly that. I recorded the
  lying poses (`exports/lying/`) in the manifest and metadata only. Do you want a `lying` group
  added (and the validator updated), or a separate index?
- **That validator already fails before my changes** ("Regenerate stale report:
  `assets/characters/poses/pose-requirements.json`") and expects only seven indexed assets while
  the index now holds about 70. Who owns fixing it?
- **Two records for the east-west lying pair.** Your `batches/lying-east-west-01.json` and my
  `metadata/lying-east-west-01/` plus manifest entries both exist, with different approval quotes
  from the user. Which should be the source of truth? My suggestion: metadata plus manifest hold
  approvals; batch files track jobs.
- **`.import` files.** They are tracked for earlier art but were untracked for newer images, and I
  did not create them. Do you want them committed with each pose?
- **Pushing protocol.** I have been pushing approved docs and art straight to `main` as
  fast-forwards while you have uncommitted work in the same folder. Nothing collided, but I would
  rather agree a rule, for example: Codex works on a feature branch, `main` takes approved docs and
  art only, and each side asks the user before pushing.
- **Line endings.** Git warns that CRLF will become LF on several docs. Is that intended?

## 4b. Tooling

I got much faster after reading the DOS text page directly (your `server.py` text channel) and
adding a breadth-first path planner with a position check after every key. A whole game fit in about
10-15 calls. `original_move` already has the verification loop; a `walk_to(col, row)` tool and a
`question_nearest` tool on the same idea would remove most manual steps. Details are in
observations section 18.7. My helper is a throwaway in a temp folder, not in the repo.

## 5. Questions for Codex

1. Does the standard time-and-access family belong in the long-term design, and why?
2. How hard is it to make the validator take N suspects (4-8) and the decoy double-claim?
3. What would you do first if you could pick only one item from section 2?
4. Which original behaviors in observations section 19 do you want verified again by your own
   runs (for example the staring-guest rule for bloodstains, or the weapon-in-hand requirement
   to assemble)?
5. Do you disagree with any decision listed in section 1 as "approved"? If so, flag it to the
   user, since they made those calls.
6. What is the smallest playtest that would tell us whether the generated cases are fun?

## 6. Proposed division of work (for both of you to adjust)

| Area | Lead | Notes |
| --- | --- | --- |
| Case lab generator, validator, notebook | Codex | Add N suspects, decoy, independence, assemble/accuse rules |
| Original-game verification | Claude | Targeted runs when a rule needs checking |
| Clock, personalities, accusation text | Shared | Design in docs first, then lab |
| Art import, approvals, manifest | Claude | Only after explicit user approval |
| Pose production prompts | Claude drafts, user generates | One image at a time with approval stops |
| Index and validator fixes | Codex | Decide the `lying` question first |

## Status update, 2026-11-16 (Claude)

Codex answered most of this in code rather than in this file: the GDScript generator port exists and matches the Python reference on
900 of 900 cases, house-02 is a walkable blockout with a seeded six-suspect investigation and a painted walkthrough, and Chris's pose
library follows Char's layout (`exports/`, `masters/`, `metadata/`, `drafts/`, plus `exports/murderer-reveal`). Still open from the questions
above: the `lying` group in the pose index, the stale pose validator, `.import` policy and a push protocol. New items are in
`docs/case-design/REVIEW_2026-11-16.md` (dialogue not wired in, simulator costs, painted rooms without guest spots).

## Codex response

*(Codex: please answer here. For each numbered item in section 2 write Agree, Disagree or
Alternative, then a sentence or two of reasoning. Answer the questions in section 5 and anything
in section 4 that needs a decision.)*
