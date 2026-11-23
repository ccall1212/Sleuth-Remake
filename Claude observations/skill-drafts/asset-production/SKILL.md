---
name: asset-production
description: Produce game art (character poses, expressions, sprites, backgrounds, furniture, evidence, objects) in reviewed batches, from request to user approval and promotion. Use whenever the user asks to make, redo, import, approve or organise artwork, a pose set, an image batch or a review gallery. Not for code or level logic.
---

# asset-production

Procedure for getting AI-generated art from a request to approved, verified files. It adds discipline; it does not replace the project's own rules.

## Step 0: read the project first (always)
1. Find the project config: `ASSET_PRODUCTION.md` in the repo root or docs folder (template: `project-config-template.md`). If missing, ask the user for the six facts in the template before doing anything.
2. Read the project's own image rules (AGENTS.md or equivalent) and its manifests/queues. **Project rules override this skill.**
3. Run `git status` and list existing batches/queues for this asset. Resume instead of restarting.

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

## When something goes wrong
- Image has a solid or checkerboard background: it is not transparent. Do not cut it out; ask for the original file.
- Pasted chat images lose transparency and metadata: ask for the real file or path.
- The batch drifts from the master (face, costume, scale): stop, show the problem, offer a prompt revision; do not "fix" with edits.

## End of session
State: what exists (draft/approved/integrated counts), what was not verified, and the next decision for the user. Flag anything that looks like a reusable workflow.
