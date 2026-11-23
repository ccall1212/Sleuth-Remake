# Approval, validation and retention

## Technical validation (never approval)
- Opens in the expected format; real alpha channel (a solid black or checkerboard background is baked pixels, not transparency: reject it). Alpha 240-254 on the subject is normal for some generators and not a failure.
- Canvas within tolerance of the master; subject not touching or within a few pixels of an edge; standing height within the project tolerance; filename matches the job.
- Faint haze pixels (alpha 1-30) under a few percent of the canvas.
- Compute and store SHA-256 for every candidate.
- Do not edit images to make them pass. Report and let the user decide.

## Review gallery
One index.html: approved reference first, neutral grey backing (say it is not part of the file), each candidate with name, job id, check results; failures and missing jobs listed. Open it for the user and give the link.

## Approval record (per file or scoped batch)
`status`, `date`, exact user quote, file path, SHA-256, scope (what is approved and what is not: poses, costume, runtime fit, furniture fit), conditions. Approval of a base model does not approve poses; approval of a pose does not approve its integration. Partial approval is recorded per file.

## Promotion
Verify the hash matches the approved record, copy to the approved/export location with the project naming, update manifests and indexes, run the project's approval preflight, and never touch the draft that was approved except to mark it.

## Retention
Keep approved results, masters, necessary references and metadata, reusable instructions and meaningful decisions. Do not keep every prompt, correction, rejected rendition or preview. Remove only clutter you created, after checking references. Keep ambiguous files and ask.
