# Independent workflow audit (Claude), 2026-11-20

Read-only. Nothing in the repository was changed; this file and `skill-drafts/` are untracked notes. "Verified" means I checked it in the repo or on GitHub
today. Everything under "Recommendation" is my opinion.

## 1. Verified facts

**Where the project actually is**
- GitHub `main` = merge commit of 17 Nov. 45 commits, 4 tags (v0.1.1 to v0.1.4), 3 merged pull requests (25 and 26 Oct), 0 open. The repo is **public**.
- Branches on GitHub: `main`, `game/house-runtime` (same commit as `main`), `design/case-generator`, `art/pose-production`, two release checkpoints, one docs branch.
- **`feature/ux-overhaul` exists only on this computer**: 17 commits ahead of `main` (HUD overlay, F floor key, glass as a permanent tool, Front Entry rule,
  accusation cards, journal, murderer zoom, kneeling poses, title screen, stalker movement, prompt packs, Sarah Jo master). Anyone reading GitHub, including ChatGPT, cannot see it.
- Until 17 Nov the playable game was **not in git at all** (about 490 untracked files, found and backed up on 17 Nov).
- Current game: painted house mystery, six suspects, seeded generator with a Python reference and GDScript port, eight personalities, Char and Chris with 81 approved poses each.
  Kwinn and Sarah Jo have approved base models only; prompt packs exist; no poses generated.
- Tooling: 64 headless check scripts (`tools/*_checks.gd`), 49 Python tools, 28 Python test files, a project MCP server (`tools/dos-game-mcp`) for the original DOS game, a
  pose runner (`assets/characters/poses/tools/pose_runner.py`, Chris-specific), an image-approval preflight (`tools/check_image_approval.py`).
- No skills exist yet (no `.agents` folder; `.claude` holds only worktrees, `.codex` only a local config).

**The docs, as a cost to an AI agent**
- `docs/` has 64 markdown files, 9,695 lines. 47 of them were last committed between 24 and 26 Oct; only 17 are newer than 1 Nov.
- `AGENTS.md` tells every agent to read README, ORIGINAL_GAME_ANALYSIS, GAME_DESIGN, DEVELOPMENT_PLAN and TESTING first. That is about **34,000 tokens** before any work, and
  `TESTING.md` alone is 45% of it (it is a dated test log, not instructions).
- Stale statements (checked against code): five docs still say the magnifying glass takes the single carry slot (code: permanent tool); `HOUSE_RUNTIME.md` and others say 22% refusals,
  10% ambush and 50% isolation (code: 10% refusals, 15/20/25% ambush by difficulty, 75% isolation); `HOUSE_INVESTIGATION.md` says the accusation asks for a person and a room and that taking the weapon needs identification (code: portrait cards, room = gathering room, no gate);
  `FIRST_PLAYABLE_CASE.md` and part of `README.md` still describe the three-suspect "Silent Library" foyer case; `GAME_DESIGN.md` is dated 24 Oct.
- Rules repeated in several places: never overwrite approved art (8 places, wording agrees), never mirror a direction (13 places, **not in AGENTS.md**, wording differs), approval needs explicit words
  (agrees), backlog caps (**60 vs 48 total, disagree**), export naming (agrees, but AGENTS.md omits `exports/lying` and `exports/murderer-reveal`).
- Duplicate copies of docs: `Claude observations/for-codex/` and `.claude/worktrees/case-design/` (about 2.5 MB). They already differ from the originals.

## 2. Assessment

**Working well (keep)**
1. **The approval discipline.** Exact quote, date, scope, file hash, `check_image_approval.py`, drafts separate from exports. This is the most valuable thing in the project, and it caught real problems:
   the Sarah Jo files arrived first with a black background, then with a baked-in checkerboard.
2. **Tests as the authority.** 64 headless checks print one JSON line each; the Python reference and GDScript port are compared on fixtures. Changes could be made fast and verified.
3. **AI roles split by file ownership.** Codex on integration and art, Claude on design and dialogue, the user as approver. Few conflicts.
4. **Preflight and recovery habits** (backup untracked work, exclude personal reference photos, local commits per phase).

**Unnecessarily complicated**
- Three layers of pose-production instructions (`CHARACTER_POSE_PRODUCTION_WORKFLOW` 421 lines, `..._PROMPT`, `DIRECTIONAL_POSE_BATCH_PROMPT`), plus the runner prompt, plus the per-character queue. The queue and manifests are the real state; the prose is history.
- Handoff files for AIs (`SESSION_HANDOFF`, `CLAUDE_NEXT_SESSION_PROMPT`, `pose-production/HANDOFF`) that go stale the day after they are written. One of them labels itself obsolete.

**Where an AI can be misled** (concrete): the glass-as-item statements, the old percentages, the foyer case, `README.md` contradicting itself (eleven rooms vs seven), version drift (`README` 0.1.3, `project.godot` 0.1.1, tag v0.1.4).

**Process risks I observed this session (not just docs)**
- Work lived outside git for three weeks and on a local-only branch now; a disk problem would lose it.
- Waiting loops that read a log can return early on a stale "DONE" line (cost me several re-checks).
- A test that errors prints no JSON and exits 0, so a naive runner reports "no result" instead of "failed".
- Pasting art as a chat image loses transparency (RGB with black or checkerboard). A real file is needed.

## 3. Recommendations

**Docs (small, high value)**
1. Replace "read these five docs first" in `AGENTS.md` with a **short current-state file** (about 1 page: what exists, which branch, how to run tests, where truth lives) and make the rest "read when relevant".
2. Move `TESTING.md` history to `docs/history/`; keep a 20-line "how to run checks" file.
3. Put the pose-production rules in **one** living file; mark the others "history". Add "never mirror a direction" to `AGENTS.md`; settle the cap (24 per character, 48 total is what the newest prompt says).
4. Fix the five glass-as-item docs and the percentage table, or add a banner "superseded by AGENTS.md" to them.
5. One handoff convention: a dated `HANDOFF.md` that the next session overwrites, never a new file per session.

**Skills, in priority order** (by value and by how much already exists)
1. `art-approval-intake`: record approval, verify transparency and hash, keep original bytes, update the catalog. Smallest, used every time.
2. `asset-production` (design below): generation batches through approval and promotion. Biggest payoff for future games.
3. `godot-headless-checks`: write and run JSON-line check scripts, with the traps listed above.
4. `reference-port-parity`: Python reference + engine port + fixtures.
5. `subagent-component-brief`: the brief template that made the delegations this session work.
6. Later, only when needed: `project-handoff`, `release-management`.
Do **not** build `gameplay-testing` or `technical-documentation` yet: there is little existing infrastructure for them, and a skill without a real process behind it is just a long prompt.

**MCP**
- Keep `tools/dos-game-mcp` as is; it controls an external program, which is exactly what MCP is good for.
- GitHub MCP/connector is worth it for the one thing that hurt: seeing PRs and branches without a local `gh`. Everything else (checks, pack builders, draft checker) should stay a plain local script: simpler, testable, no extra surface.
- An OpenAI image API runner would be a script, not an MCP server.

**Subagents**
- Researcher (read-only, returns a short report), Implementer (new files only, fixed API, own checks), Reviewer (fresh context, reads the diff and runs checks). The rule that prevented conflicts this session:
  **one writer per file**; implementers create new files, the lead does the wiring. Reviewers never edit.

**Challenges to ChatGPT's proposed `asset-production` structure**
- `templates/batch-record.json` would duplicate the per-character `queue.json` and `production-manifest.json` that already exist. Reuse them; the skill should describe them, not replace them.
- Four reference files is more than needed. Two are enough (`batch-generation.md`, `approval-and-validation.md`); `asset-retention.md` is half a page and belongs in the validation file.
- "Generate the requested assets" must not be a step the skill assumes it can do. In this project the generation tool varies (Codex built-in generator, ChatGPT, an API). The skill must say what to do when the agent **cannot** generate images: prepare prompts and the exact attachments, never pretend.
- A universal skill should hold the *procedure*; the engine, naming, sizes and approval rules belong in a **project config file** the skill reads first (see draft). Otherwise the skill rots the moment a second game differs.

## 4. Portability (Claude Code and Codex)
My understanding, not verified against current Codex documentation: both use a folder with `SKILL.md` (frontmatter `name` and `description`) plus optional files and scripts, so one source can serve both
if it avoids tool-specific commands. Keep skills in one git repo (`personal-ai-toolkit/skills/<name>/`) and link or copy into `~/.claude/skills` and the Codex skills folder. Test in both.

## 5. Testing plan for the skill (fresh conversation)
1. Give the skill to a new session in a *different* small project with only a config file; ask for "three poses of character X". Pass if it reads the config, finds no existing batch, writes a batch record, prepares prompts and **stops**.
2. Say "generate" in an environment without an image tool. Pass if it prepares prompts and attachments and says it generated nothing.
3. Hand it a black-background or checkerboard PNG as the "approved" master. Pass if it rejects it as not transparent.
4. Ask it to "approve and import" without an approval quote. Pass if it refuses.
5. Give it a draft whose filename already exists in exports. Pass if it refuses to overwrite.
6. In Sleuth: ask it to resume Kwinn batch 1 after a partial run. Pass if it skips existing files and uses the existing prompt pack.

## 6. Long-term workflow
Project truth in git (one current-state file, specs, manifests, tests) → each session starts by reading that file and `git status` → work happens on a branch with local commits per phase and a
push when the user says so → delegated pieces use the brief template and are verified by the lead → art goes through the approval skill → every session ends by updating the current-state file and
flagging skill candidates.

## 7. Open questions for you
- Do you want me to fix the stale docs now (list in section 1)? It would change tracked files, so I have not.
- Should `feature/ux-overhaul` be pushed? The repo is public: it would publish the new game code and the Kwinn and Sarah Jo prompt packs (no personal reference photos are tracked).
- Which skill first? I would start with `art-approval-intake` because it is small and testable, then `asset-production`.

Drafts: `Claude observations/skill-drafts/asset-production/` (SKILL.md, two reference files, a config template).
