---
name: asset-production
description: Produce game art (character poses and pose sets, expressions, sprites, backgrounds, furniture, evidence, objects) in resumable, numbered review batches, from request through record reconciliation, user approval and promotion. Use whenever the user asks to make, redo, import, approve or organise artwork, a pose set, an image batch or a review gallery. Not for code or level logic.
---

# asset-production

Procedure for getting AI-generated art from a request to approved, verified files. It adds discipline; it does not replace the project's own rules.

## Step 0: read the project first (always)
1. Find the project config: `ASSET_PRODUCTION.md` in the repo root or docs folder (template: `project-config-template.md`). If missing, ask the user for the six facts in the template before doing anything.
2. Read the project's own image rules (AGENTS.md or equivalent) and its manifests/queues. **Project rules override this skill.**
3. Run `git status` and list existing batches/queues for this asset. Resume instead of restarting.
4. **Reconcile the production records before choosing work** (see "Reconcile records" below). Records can disagree (a queue, a manifest, an index, the files on disk). Work from files and hashes; report conflicts; correct nothing until the user agrees.

## Hard rules (never break)
- Generation permission is not approval. A technically valid image is not approved. Silence is not approval. Only the user's own words approve, and only what they name.
- Never overwrite, rename, recompress, crop, recolour or mirror an approved file. New revisions get new names.
- Never start the next batch before the user has reviewed the current one, unless the project config grants a standing draft allowance (and then respect its caps).
- Never invent an approval, a hash or a result. If you cannot generate images, say so, and prepare prompts and the exact attachments instead.
- Drafts, candidates, approved and integrated are four different states. Never imply a later state than the one reached.
- Folder presence is not approval; resolve assets through the manifest.

## Workflow
**A. Plan** (stop and confirm if anything is ambiguous)
1. Restate the request: asset type, how it is used, how many, which character/room.
2. Identify references: the approved master for identity and an approved same-kind asset for composition (see `references/batch-generation.md`).
3. Decide filenames and folders from the project's convention. Check nothing already exists.
4. Show the plan and counts to the user when the batch is more than a few images.

**B. Prepare**
5. Build the prompts and reference list (reference 1 = identity, reference 2 = composition only). Record them in the batch record (use the project's existing queue/manifest format).
6. Stage attachments in a git-ignored folder as copies; never move originals.

**C. Generate** (only if you have an image tool)
7. One image per job unless the tool proves it can return separate images reliably. Save under the exact filename. Retry failures at most twice, then mark `needs_help`.
8. Update the record after every image so a crash loses nothing.

**D. Validate** (`references/approval-and-validation.md`)
9. Run the technical checks (real transparency, size, margins, height, filename). Record results. Technical pass is not approval.
10. Build the review gallery (index.html, neutral backing, approved reference first, failures and missing items listed) and open it for the user with a clickable link.

**E. Review and approve**
11. Present the actual images. Ask the user to approve, request changes or reject, per file or per batch.
12. Stop. Do nothing further until they answer.
13. Record each approval: exact quote, date, file path, SHA-256, scope ("base model only", "pose, not runtime fit").

**F. Promote and integrate**
14. Only with explicit approval: verify the hash again, copy (do not move) into the approved/export location with the project's naming, update manifests/indexes, run the project's approval preflight.
15. Integration into the game/engine is a separate step with its own checks; never claim it from approval.

**G. Clean up**
16. Remove only files you created that the retention policy classifies as clutter, after checking nothing references them. Keep approved results, masters, metadata and meaningful decisions. When unsure, keep and ask.

## Pose sets (characters, expressions, directions)
Use this for any set of related images (a character's poses, a prop in several angles, a tileset). The project supplies three small data files and a planner; this skill supplies the procedure.

**Inputs (project-owned, no duplication):** a catalog of what exists (ids, directions, variants, priority tiers); a production plan (ordered groups of pose *families*, default and minimum batch size); a character profile (master, canvas, standing height, identity lock, any approved substitutions). In Mansion Mystery: `assets/characters/pose-catalog.json`, `assets/characters/poses/production-plan.json`, `assets/characters/poses/<slug>/profile.json`, planner `assets/characters/poses/tools/pose_planning.py`.

**Automatic sequencing.** Do not ask the user which pose is next. Run the planner (`pose_runner.py --character <slug> next`, or `tools/build_pose_prompt_pack.py <slug> --dry-run`). It answers in this order:
1. **Review or recover first.** Drafts awaiting review, `needs_help` and `generating` jobs come before any new group. The planner never jumps ahead past them.
2. **Backlog cap.** At most 24 unreviewed drafts per character and 48 in total, counting drafts awaiting review. At the cap, stop and say so.
3. **The next incomplete group**, kept intact (idle, then reaching, then kneeling, then the remaining groups in the plan's explicit order). Small groups stay small; large groups split into equal batches; the default maximum is 8 and the user may override group, directions and maximum.
4. **Reference check.** If no approved same-pose reference exists, say "needs a reference decision" and offer the proposed nearest pose or an external image; never invent a reference and never use an unapproved image as one.
- A missing job = no export and no draft. A prompt pack, a queue line or a manifest list is not progress by itself. A short manifest list is a record problem, not missing artwork.
- Report five separate facts for every pose and never merge them: image exists; approval (approved, user-supplied, reference-only, unrecorded); technically checked; integrated into the game; planner status.
- **Catalog growth.** A pose added to the catalog is planned automatically for every eligible character (optional fields: `eligible_characters`, `exclude_characters`, `eligible_body`, `reuse_from`, `excluded`). It creates no approval and does not mean every character must have it. Families no group names land in a last group "catalog-additions".
- **Substitutions** (for example a crouching cry replacing a standing cry) are shown as an explicit decision: retain the substitute or add a distinct pose. Never count one as the other.

**Resumable batches.** Batch numbers and pose numbers come from the full plan, so they do not shift as work completes. On resume, skip jobs that already have a draft or export; a batch page lists every job with its status and only the unfinished ones go into the attachments and the combined prompt. Never regenerate completed work and never overwrite an existing file.

**Each pose is its own image.** Reference 1 = the approved master (identity, costume, scale). Reference 2 = an approved same-pose image of the example character of the same body template (composition only). Put a STOP between jobs in a combined prompt. If the image tool merges jobs or returns them one at a time, report it and let the user choose; do not invent a workaround that edits images.

**Reconcile records (read-only).** `pose_runner.py --character <slug> reconcile` compares catalog, queue, manifest, directional index, exports and hashes, and lists conflicts with evidence. Typical findings: a manifest approved-list that lags the files; a queue slot outside the catalog because of an approved substitution; index entries that are exported but not plainly "approved" (user-supplied, reference-only). Rules: files and hashes outrank prose; never infer an approval; never rewrite history; propose the record fix and wait for the user's go-ahead.

**Numbered review and targeted redo (the workflow proven with Chris).**
1. After a batch is saved, run the technical check and build the review gallery (numbered by job).
2. Present the actual images with their numbers and the checker's pass/warn/fail.
3. The user answers per batch or per number: "approve all", "approve 1-6, redo 7 with ...". Record exact words and scope; approve only what is named.
4. A redo reuses the same job number and filename with a revision suffix (`_r2`) and a prompt that states the change; the original draft is kept until the redo is approved or rejected.
5. Only after approval: promote (copy, never move), update records, run the preflight. Integration is a separate step.

**Stages never merge.** Planning, generation, technical validation, visual approval, promotion and runtime integration/fit are six separate steps. Finishing one never implies the next.

## When something goes wrong
- Image has a solid or checkerboard background: it is not transparent. Do not cut it out; ask for the original file.
- Pasted chat images lose transparency and metadata: ask for the real file or path.
- The batch drifts from the master (face, costume, scale): stop, show the problem, offer a prompt revision; do not "fix" with edits.

## End of session
State: what exists (draft/approved/integrated counts), what was not verified, and the next decision for the user. Flag anything that looks like a reusable workflow.
