# Review report, 2026-11-23

Nothing here is committed or pushed. No images were generated, no approval or approved file changed, no tests run.

## 2. Production counts (image existence, approval and planner status are separate)

| Character | Planned | Image exists | Approval of the existing images | Technically checked | Planner status |
|---|---:|---:|---|---|---|
| chris | 84 | 80 | {"approved": 80} | {"pass": 74, "fail": 5} | {"complete": 80, "missing": 3, "substitute_retained": 1} |
| char | 84 | 81 | {"approved": 32, "user_supplied": 46, "reference_only": 3} | {"measured": 74} | {"complete": 78, "missing": 3, "reference_example": 3} |
| kwinn | 84 | 1 | {"approved": 1} | {"measured": 1} | {"complete": 1, "missing": 83} |
| sarah-jo | 84 | 1 | {"approved": 1} | {"measured": 1} | {"complete": 1, "missing": 83} |

Notes: Chris's 81st image is the approved crouching cry, which is outside the catalog (it satisfies the male crying slot); his 80 catalog images plus the crouch are the 81 exports. Char's 46 'user_supplied' and 3 'reference_only' are index labels, not missing images. Integration into the game is reported by `reconcile` and is separate from all of the above.

## 3. Exact planner behaviour

- **A draft awaiting review:** action = `review_or_recover_first`; next group = None; the planner lists it first (a draft or unrecorded export is waiting for review). No later group is started, no new prompt is prepared.
- **A job marked needs_help:** action = `review_or_recover_first`; next group = None; the planner lists it first (marked needs_help: recover or redo it). No later group is started, no new prompt is prepared.
- **A job marked generating:** action = `review_or_recover_first`; next group = None; the planner lists it first (marked generating: confirm or recover it). No later group is started, no new prompt is prepared.
- **Backlog cap:** unreviewed drafts, `needs_help` and `generating` jobs all count: 24 per character, 48 in total. When a new batch would exceed either cap the action is `paused_backlog_cap`, the batch pages are built with a PAUSED banner and no attachments or combined prompt are staged.
- **Reference-only art** (for example Char's clasp hands before the decision): status `reference_only`; it is NOT counted complete and is listed under decisions for you; it is never used as an approval. With the recorded decision it becomes `reference_example` (accounted for, not an approval, index unchanged).
- **Exported file the index does not mention:** status `review` (approval 'unrecorded'), listed first as review work.
- **User-supplied art** (index label `user_supplied_added_to_project`): counted as existing and complete, labelled `user_supplied` separately from `approved`.
- **Missing approved reference:** the planner looks for an approved same-pose image of the example character (Char for Chris and Sarah Jo, Chris for Kwinn). If there is none: `blocked_on_example` when the example character has the same job still unfinished (Chris waits for Char), otherwise `needs_decision` (proposed nearest poses shown, none used until you confirm). Such a job gets NO prompt. If every unfinished job in the next group is blocked, the action is `needs_reference_decision` and the planner does not skip ahead to a later group on its own; if only some are blocked the rest proceed.
- **Nearest-pose references** are used only when `confirmed: true` in production-plan.json and are described to the image tool as a NEAREST related pose, never as the same pose.
- **Numbering** is computed from the whole plan for the chosen options, so job and batch numbers do not change as work completes. Filtered pack pages link only to pages that exist.
- **File safety:** names are validated; output goes only to `<character>/prompts/<pack>/` and `test-results/pose-batches/<character>/`; a rebuild deletes only its own `batch-NN.html`, and replaces only its own `NN_base-model.*` and `NN_composition_*.png` files.

## 4. Catalog changes

Kneeling inspect (all tier 4): kneeling_inspect_east (planned), kneeling_inspect_south (planned), kneeling_inspect_west (planned), kneeling_inspect_north (EXCLUDED)

Excluded entries (18), kept in the catalog and left out of every plan: kneeling_inspect_north, seated_talk_east, seated_talk_south, seated_talk_west, seated_write_south, seated_write_west, standing_drink_north, standing_inspect_east, standing_inspect_north, standing_inspect_south, standing_inspect_west, standing_look_out_north, standing_peek_east, standing_peek_north, standing_peek_south, standing_peek_west, standing_warm_hands_east, standing_warm_hands_north

Added entries: `kneeling_inspect_south` and `kneeling_inspect_west` (copied from `kneeling_inspect_east`, with an `added` note). New `selection` block records your words. Original summary fields (counts_by_tier 100) still describe the original catalog; the planner counts entries without `excluded: true`: 84 per character.

Recorded mappings: `production-plan.json` `body_template_choices` (male crying slot = crouching_cry_south, female = standing_cry_south); `chris/decisions.json` (confirmed 2026-11-23); `char/decisions.json` (clasp hands remain composition references, not approvals).

## 5. manifest-sync

- **chris, report-only run now (idempotent check):** `{"mode": "append_to_approved_assets", "before": 81, "appended": [], "after": 81, "skipped_hash_mismatch_or_missing": [], "written": false, "character": "chris"}`
- **char, report-only run now (idempotent check):** `{"mode": "write_export_inventory", "entries": 81, "by_label": {"approved": 32, "user_supplied_added_to_project": 46, "reference_only": 3}, "skipped_hash_mismatch_or_missing": [], "written": false, "character": "char"}`
- **Chris, what the earlier `--write` did:** approved_assets 59 to 81; appended 22: kneeling_reach_east|neutral, kneeling_reach_south|neutral, kneeling_reach_west|neutral, lying_idle_north_south_head_north|awake, lying_lounge_north_south_head_north|napping, lying_sleep_east_west_head_east|peaceful, lying_sleep_east_west_head_west|peaceful, lying_sleep_north_south_head_north|peaceful, seated_idle_north|neutral, seated_idle_south|neutral, seated_read_south|neutral, standing_hands_hips_east|confident, standing_hands_hips_north|confident, standing_hands_hips_south|confident, standing_hands_hips_west|confident, standing_think_east|curious, standing_think_north|curious, standing_think_south|curious, standing_think_west|curious, standing_withdraw_east|sad, standing_withdraw_south|sad, standing_withdraw_west|sad
- **Hash mismatches or conflicts:** none. Every appended Chris file and every Char inventory file matched its recorded hash before writing (the command refuses to write otherwise). `reconcile` reports 0 conflicts for both.
- **Char:** `export_inventory` written with 81 entries, labels {"approved": 32, "user_supplied_added_to_project": 46, "reference_only": 3}. Existing manifest keys unchanged.

## 6. Remaining decisions for you

1. **Kneeling inspect reference:** may kneeling reach (east, south, west, already approved) be the nearest-pose reference for kneeling inspect? It is not confirmed (`confirmed: false` in production-plan.json), so those three jobs currently say 'needs a reference decision'. Chris's three then wait for Char's approved ones.
2. **Authorization to commit and push** after your review. Suggested split: (a) planner and data (production-plan, profiles, decisions, pose_planning, pose_runner, build_pose_prompt_pack); (b) catalog and manifest record changes; (c) Kwinn and Sarah Jo idle imports and the deleted packs; (d) the notes folder.
3. **Draft checker:** `tools/check_pose_drafts.py` still reads the old `prompts.json` layout; it needs a small update once packs are regenerated (no decision needed, just a go-ahead).

