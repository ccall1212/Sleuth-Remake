# Batch generation

**References.** Reference 1 = the approved base model (identity, costume, proportions, rendering). Reference 2 = an already-approved image of the *same kind and direction* of another asset
(composition, gesture, camera only). Say so in the prompt and tell the generator not to copy reference 2's identity.

**Prompt skeleton** (one job): what is being made; reference roles; identity lock (concrete visible features, written from the actual approved image, not from memory); the pose/content;
the facing or angle; scale and framing (native canvas, occupied height, margins); output rules (one subject, real alpha, no background, shadow, text); "draft, not approval".

**Batches.** Group 8 related jobs. A shared header (identity, scale, output rules) plus one short line per job keeps long batches consistent and short. Number the attachments in the order the prompt names them.
If the tool cannot return separate images reliably, fall back to one job per message and tell the user the time cost.

**State.** Use the project's queue/manifest. Minimum fields per job: id, filename, status (queued, generating, draft, needs_help, approved, imported), attempts, references with hashes, notes, timestamp.
Update after each image. Respect backlog caps (unreviewed drafts) from the project config.

**Filenames.** Follow the project convention exactly; refuse to overwrite; include the revision suffix for retries.

**No image tool?** Produce: the prompt text, the exact list of attachment files in order, the target filenames and folder, and the next command or step. State plainly that nothing was generated.
