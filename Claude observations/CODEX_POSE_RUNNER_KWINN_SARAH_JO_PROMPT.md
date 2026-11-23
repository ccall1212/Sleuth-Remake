# Codex prompt: pose production for Kwinn and Sarah Jo

Replaces `CODEX_POSE_PRODUCTION_RUNNER_PROMPT.md` for the next run. That file is stale: Chris's 80 poses are done and approved, and its
catalog step already exists. This one uses the ready-made prompt packs, so Codex does not rebuild a catalog or ask which character to start.
Paste everything between the `=====` lines into Codex (signed in with the personal ChatGPT account, repo folder open). Claude does not edit these files while it runs.

=====

You are the Pose Production Runner for Mansion Mystery (repo root = your working directory). Generate DRAFT pose images for **Kwinn** and **Sarah Jo**
at the same time, batch by batch, and stop for the user's approval after each batch.

READ FIRST: `AGENTS.md`, `docs/IMAGE_ASSET_WORKFLOW.md`, then `assets/characters/poses/kwinn/prompts/pack-01/README.md` and
`assets/characters/poses/sarah-jo/prompts/pack-01/README.md`. Their base models are already approved by the user (records:
`assets/characters/poses/kwinn/drafts/model-review-02/candidates.json` and `assets/characters/poses/sarah-jo/drafts/model-review-07/candidates.json`).
No pose is approved yet.

THE JOBS: each character has `assets/characters/poses/<slug>/prompts/pack-01/prompts.json` with 80 jobs in order. Each job has `save_as`, an `attach` list of two
reference images (reference 1 = the approved base model, reference 2 = an approved same-pose image used for composition only) and a finished `prompt`.
Do not change the prompts. Eleven batch pages (`batch-NN.html`, 8 jobs each) show the same jobs.

PRODUCTION LOOP (both characters, interleaved: Kwinn batch 1, Sarah Jo batch 1, Kwinn batch 2, and so on):
1. For each job in order, skip it if `assets/characters/poses/<slug>/drafts/pack-01/<save_as>` already exists. Never overwrite a file.
2. Generate one image with the built-in image generator, attaching exactly the two `attach` files and using the job's `prompt` unchanged. Requirements are in the prompt:
   one character, real PNG alpha transparency, no mirroring of another direction.
3. Save the result as `assets/characters/poses/<slug>/drafts/pack-01/<save_as>`. If the tool returns a different format, convert only to PNG without altering pixels.
4. Retry a failed image at most 2 times, then record it in `assets/characters/poses/<slug>/drafts/pack-01/needs_help.txt` and move on.
5. After each finished batch of 8, run `.venv\Scripts\python.exe tools/check_pose_drafts.py <slug> --html` and fix nothing yourself: it only reports.
6. Backlog cap: at most 24 unreviewed drafts per character and 48 in total. When a cap is reached, STOP and tell the user to open
   `assets/characters/poses/<slug>/drafts/pack-01/review/index.html`.

RULES
- Drafts only. Never copy anything into `masters/` or `exports/`, write an approval, edit `pose-catalog.json`, or touch any approved image. Approval needs the user's explicit words.
- Do not mirror, crop, recolor, upscale or edit images. Do not generate poses that are not in `prompts.json` (tier 4 and the standing idle south are intentionally excluded).
- Only create files under `assets/characters/poses/kwinn/drafts/pack-01/` and `assets/characters/poses/sarah-jo/drafts/pack-01/`. Do not edit `src/`, `tools/`, `tests/`, docs, or `Claude observations/`.
  Do not commit or push.
- If a prompt or reference looks wrong, stop and say so instead of improvising.

REPORT after each batch (short): jobs generated, jobs skipped, failures, the checker's pass/warn/fail counts and the gallery path. Say what you did not verify.

=====
