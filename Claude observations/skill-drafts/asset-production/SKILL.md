---
name: asset-production
description: Produce game art (character poses and pose sets, expressions, sprites, backgrounds, furniture, evidence, objects) in resumable, numbered review batches, from request through record reconciliation, reference checking, user approval and promotion. Use whenever the user asks to make, plan, redo, check, import, approve or organise artwork, a pose set, an image batch or a review gallery. Not for code or level logic.
---

# asset-production

How to get AI-generated art from a request to approved, verified files without losing track and without ever approving anything for the user. It adds discipline to the project's own rules; it does not replace them.

## Step 0: read the project first (always)
1. Find the project config: `ASSET_PRODUCTION.md` (repo root or `docs/`). It names the facts below and the project's four commands (next, build, check, reconcile). If it is missing, ask the user for those facts before doing anything (template: `project-config-template.md`).
2. Read the project's own image rules (AGENTS.md or equivalent) and the manifests/queues it names. **Project rules override this skill.**
3. Run `git status`, then the project's *next* command. Resume existing work; never restart a batch that exists.
4. Run the project's *reconcile* command before choosing work. Records can disagree (a queue, a manifest, an index, the files on disk). Work from files and hashes, report conflicts with evidence, and correct nothing until the user agrees.

## Hard rules
- Generation permission is not approval. A technically valid image is not approved. Silence is not approval. Only the user's own words approve, and only what they name.
- Never overwrite, rename, recompress, crop, recolour or mirror an approved file. Revisions get new names (`_r2`).
- Never start the next batch before the current one is reviewed, except under a standing draft allowance in the config, and then obey its caps.
- Never invent an approval, a hash, a reference or a result. If you cannot generate images, say so and prepare prompts plus the exact attachments.
- Drafts, candidates, approved and integrated are four different states. Never imply a later one than the one reached. Folder presence is not approval; use the manifest or index.
- **Full paths, always.** Every prompt and handoff names files by their complete location, never "the batch folder" or a path relative to something unstated, because a chat can run out of space and be restarted from nothing. When the assistant that will do the work reads the repository from GitHub, give each file as a full raw GitHub URL on the pushed branch, and say the files must be committed and pushed first (the user decides when). Otherwise give full absolute paths. Resolve them when you generate the handoff; never hardcode one person's local path in shared source or docs.
- Stages never merge: planning, generation, technical check, visual approval, promotion, runtime integration/fit.

## Choosing what to make (sets of related images)
Do not ask the user which item is next. Run the project's *next* command; it answers in this order, and you say what it chose in one line:
1. **Review or recover first.** Drafts awaiting review, `needs_help` and `generating` items come before any new group. Never jump ahead past them.
2. **Backlog caps.** Stop and say so when the configured cap of unreviewed drafts is reached (awaiting-review drafts count).
3. **The next incomplete group**, kept intact; large groups split into equal batches, small groups stay small; the user may override group, directions and maximum batch size.
4. **Reference check** (below). An item with no usable reference gets no prompt and is reported as "needs a reference decision".
- "Missing" means no export and no draft. A prompt pack, a queue line or a short manifest list is not progress; a short manifest list is a record problem, not missing art.
- Report five separate facts per item and never merge them: image exists; approval (approved, user-supplied, reference-only, unrecorded); technically checked; integrated; planner status.
- A new catalog item is offered automatically to every eligible character; it creates no approval and does not mean everyone needs it. Substitutions (one pose standing in for another) are shown as an explicit decision, never counted as the original.

## References (composition only)
Reference 1 = the approved master (identity, costume, scale). Reference 2 = an image of the same kind from the example character (composition, gesture, posture only).
- A reference must have a record in that character's index and its file hash must match the record. Otherwise it is unusable and the planner reports `reference_unusable` with the reason.
- Keep the recorded source status in the prompt and the review page: **approved**, **user-supplied (not an approved pose)**, **linked reference example (not a pose approval)**. Never describe user-supplied art as approved.
- Reference-only images are usable only where a recorded user decision permits it.
- A confirmed nearest-pose reference is labelled "nearest related pose", not "same pose", and the prompt says what it is for (for example composition and kneeling posture) and that the action to draw is different.
- If no reference exists, offer the proposed nearest pose or ask the user for an external image. Never invent one.

## Workflow per batch
**A. Plan.** Run *next*; state the group, the batch numbers, counts and anything blocked. Confirm with the user only when something is ambiguous or the batch is large.
**B. Prepare.** Run *build*. It writes numbered pages (each pose its own job and number), prompts, and a staging folder with copies of the attachments in attachment order. Originals are never moved.
**C. Generate** only if you have an image tool; otherwise stop here and hand over the pages. One image per job; save under the exact filename; retry failures at most twice, then mark `needs_help`. Update records after every image.
**D. Check.** Run *check*: transparency, size, margins, height, filename. Technical pass is not approval. Open the review gallery for the user with a clickable link.
**E. Review and approve.** Present the actual images by number. The user answers per batch or per number ("approve all", "approve 1-6, redo 7 with ..."). Record exact words, date, paths, SHA-256 and scope; approve only what is named. A redo keeps the job number and adds a revision suffix; the earlier draft is kept until the redo is approved or rejected.
**F. Promote** only with explicit approval: verify the hash again, copy (never move) to the export location, update the project's records, run its approval preflight. Integration into the game is a separate step with its own checks.
**G. Clean up.** Remove only files you created that the retention policy calls clutter, after checking nothing references them. When unsure, keep and ask.

## When something goes wrong
- A "transparent" image has a solid or checkerboard background: it is not transparent. Do not cut it out; ask for the original file. Chat-pasted images lose transparency.
- A batch drifts from the master (face, costume, scale): stop, show the problem, offer a prompt revision; never "fix" with edits.
- The tool merges jobs onto one sheet or returns them one at a time: report it; do not invent an image-editing workaround.

## End of session
State what exists (draft, approved, integrated counts), what you did not verify, and the next decision for the user. Flag anything that looks like a reusable workflow.
