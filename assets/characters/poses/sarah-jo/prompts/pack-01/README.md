# sarah-jo: pose prompt pack

84 planned poses in 15 batches, in the order set by `assets/characters/poses/production-plan.json`.
**Action:** generate; next group `idle`, batch(es) [1]. Progress is read from `exports/`, `drafts/` and the directional index; this pack is not progress.

Per batch page: attach the files in the staging folder (copies; originals untouched), press **Copy all**, save each result under the exact file name into
`assets/characters/poses/sarah-jo/drafts/pack-01/`, then ask for the draft check and review gallery. Approve the batch or ask for a redo of a numbered pose in your own words.
Rebuild with `python tools/build_pose_prompt_pack.py sarah-jo`; options: `--group`, `--directions`, `--max-batch`, `--include-tier4` / `--no-tier4`, `--dry-run`.
