# For Codex: start here (written by Claude, 2026-10-26)

The user asked me to point you at a request list. It is proposals, not orders; answer or push back in
`Claude observations/NEXT_STEPS_DISCUSSION.md` ("Codex response") or in a reply file next to this one.

## Where my work is

A separate git worktree inside this folder: `.claude/worktrees/case-design`, branch `design/case-generator`
(**pushed to `origin/design/case-generator` on 2026-11-16; please do not merge it or push to it**, ask Claude). Read these there, in this order:

1. `docs/case-design/REQUESTS_FOR_CODEX.md`: 14 numbered requests (items 7-14 are new today).
2. `docs/DESIGN_DECISIONS.md`: every decision the user made, with dates, plus what is still open.
3. `docs/case-design/GENERATOR_SPEC.md` (section 11: simulation), `DANGER_CLOCK_SPEC.md`, `HOUSE_LAYOUT_FORMAT.md`.
4. `Claude observations/CLOCK_EXPERIMENTS_2026-10-26.md` (this folder): what I measured on the original game.

## The short version of what I am asking

- **First map:** `assets/maps/house-02.layout.json` is the user's own ten-room blockout (plain rectangles, no art). Build the
  Godot loader and viewer (request 13/14): draw the screens, let the player walk between rooms, show a step counter. Same
  field names as `assets/mansion/fixed-mansion.json`. Backgrounds are painted afterwards to match, so doors never have to
  be moved to fit art.
- **Generator port:** port `generate()` and `candidates()` to GDScript with Python fixtures for parity tests (request 7). Generator
  version 2: the murder is never in the secret room.
- **Danger clock, in steps (request 8-10):** warning at a seeded step in 140-200, stalking 80-115 steps later, about 10% death
  per room entered while stalking, halls safe. Hard: guests head for the murder room 30% of the time and always stare there.
- **Your lab:** tell me which rule differs from `simulate_clock.py` rather than tuning around it (request 12).

## Things I changed in files you own (please check them)

- `assets/characters/poses/tools/pose_runner.py`: new drafts now go to `drafts/runner-01/` (not the old flat
  `north/east/south/west/` folders), and the approved idle is read from `exports/south/`. The review page uses `approved_export`.
- Chris's pose library now mirrors Char's (exports by direction, `masters/`, `metadata/`, `drafts/`), and both characters' five
  murderer reveal poses moved to `exports/murderer-reveal/`. Your commit `6e315e3` already includes this. I updated paths in
  `assets/characters/pose-catalog.json` (`source_char_asset` for the Char reveals), both `directional-index.json` files,
  manifests, metadata and the Godot `.import` files that moved with the images. Hashes are unchanged; every approval record
  passes `tools/check_image_approval.py`.
- Stale paths I left alone: `char/prompts/rest-sleep-01.md` still names `exports/south/char_standing_shrug_south_resigned.png`
  (a retained prompt), and Char's index lists a few superseded `revision-02/03` exports that no longer exist.

## Open questions for you (from NEXT_STEPS_DISCUSSION.md)

The `lying` group in the pose index, the stale pose validator, duplicate batch records for the east-west lying pair, the
`.import` policy, and a push protocol. Several Chris approvals rest on soft user quotes ("Everything looks fine to me, but do
what you need to do and continue", "Looks great! Are we almost finished with Chris' poses?"); the user decides whether they
stand.

## Update 2026-11-16: dialogue is the next data-only task

Read `docs/case-design/DIALOGUE_WIRING_SPEC.md` (request 15) on the same branch. Your generator port already matches my Python reference on 900 of 900
cases (I checked it with a Godot headless dump); the dialogue data is written but not loaded by the game, and two runtime warnings echo the original's
wording. `docs/case-design/dialogue_fixtures.json` has 216 expected answers so you can test parity without me.

## Where to read it (updated 2026-11-16)

The branch worktree is git-ignored, so a plain copy of everything you need is in `Claude observations/for-codex/` (see its `MANIFEST.md`: source paths,
hashes, and the commit it was copied from). Read-only; changes go through Claude. Start with `docs__case-design__DIALOGUE_WIRING_SPEC.md`. The branch itself
(`design/case-generator`) is now pushed: `git fetch origin` then `git show origin/design/case-generator:<path>` or `git worktree add` to read it.
