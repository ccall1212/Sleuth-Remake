# Male cast: base-model prompts (Kwinn first)

Written 2026-11-16 by Claude. Chris is the example pose set for men and Char for women. Before any of the other men gets a 100-pose
pass, each needs an **approved base model** in the same look as Chris's approved anime v2. The catalog (`assets/characters/pose-catalog.json`)
marks every man below as `needs_base_approval_or_selection`. Production order from the catalog:

| Order | Man | Review # | Identity reference (attach this) |
| ---: | --- | ---: | --- |
| 2 | Kwinn | 07 | `assets/characters/review-v6/sources/selected-party-hm.png`, panel 3 of the 3x2 grid (Selected Party K); also `review-v5/masters/photo-04-k-cheek-scruff-v5.png` |
| 3 | Justin | 02 | `review-v6/sources/selected-party-hm.png`, panel 5 (Selected Party M) |
| 4 | Danny | 03 | `review-v5/masters/photo-03-f-scruff-v5.png`, panel 1 (First B) |
| 5 | Gage | 04 | `review-v5/masters/photo-03-f-scruff-v5.png`, panel 2 (First C) |
| 6 | Robbie | 05 | `review-v6/sources/selected-party-ag.png`, crop x 768-1152, y 0-512 (Selected Party C) |
| 7 | Matt | 09 | `review-v3/masters/photo-04-upper-five-v3.png`, crop x 568-969, y 10-498 (Party B) |
| 8 | John | 21 | `review-v8/masters/john-cartoon-v8.png` (cartoon face revision, still awaiting your review) |

(Chris is order 1 and done.) The current look of all of them is on `assets/characters/review-v8/current-cast-overview.png`.

## The process, one man at a time

1. **Base candidate (this document).** Generate one full-body, south-facing, hands-in-pockets standing idle for the man, one image at a time. You pick
   or reject; say plainly which one you approve (an exact approval quote is recorded, and I never infer approval).
2. **Import the approved base.** I create his folder like Chris's (`masters/model-review-01`, `exports/south`, `metadata`, `drafts`), record the approval, and
   add him to `directional-index.json` and the manifest. Chris's own record is the template.
3. **Pose pass.** Codex's runner builds the queue from the catalog: 81 core poses, 19 Tier 4 poses held (no matching Char art). The male template applies:
   hands in pockets for neutral, nail biting or head scratching with the other hand on the hip for defensive and nervous, crossed legs seated.

## Reusable base-model prompt

Attach **three images**: (1) the man's identity reference from the table, (2) Chris's approved model, `assets/characters/poses/chris/masters/model-review-01/chris-model-v2.png`
(male body, proportions and rendering style), (3) Char's approved likeness, `assets/characters/poses/char/masters/likeness-review-02/char-likeness-v2.png`
(the face style: larger expressive eyes, softly shaded simplified features). Then send, filling the `[...]` parts:

> Create ONE separate full-body transparent PNG game character, **[NAME]**, standing, facing SOUTH (toward the viewer), neutral expression.
>
> REFERENCE 1 is [NAME]'s identity: keep his face, hair, facial hair and costume recognisably the same person and outfit. REFERENCE 2 is Chris's user-approved
> model: use the same male adult body proportions, head-to-body scale, drawing scale and rendering. REFERENCE 3 is Char's approved face style only: larger
> expressive anime eyes, simplified softly shaded nose and face. Do not copy Char's feminine body, hair, clothes or gestures.
>
> IDENTITY: [hair, facial hair, glasses or hat, from the notes below]. COSTUME: [outfit, kept from reference 1]. No hat removal, no props, nothing in his hands.
>
> POSE: hands in the trouser pockets; relaxed, planted stance; both boots on the ground; head level.
>
> STYLE: same richly shaded, outlined anime/cartoon game rendering as Chris (crisp detail, no photoreal skin, no chibi anatomy).
>
> FRAMING: single character, complete from hat or hair to boots, actual PNG alpha transparency with an empty background, clean margins, no floor, furniture,
> scenery, shadow, glow, text or border. Native canvas about 948 x 1659 with the figure about 1564 px tall, the same scale as Chris.

## Per-man notes to paste into IDENTITY and COSTUME

These notes come from the identity data where it exists and from my reading of the current art on the cast overview. **Match the attached image, not my words**;
tell me where my description is wrong.

- **Kwinn (07).** From the data: scruffy goatee plus short scruff around the jaw and both cheeks, in both outfit variants. From the art: dark, swept-up hair; red
  striped waistcoat over a cream shirt with rolled sleeves; dark trousers; brown boots.
- **Justin (02).** Brown hair, clean-shaven, friendly smile; dark long coat over a teal waistcoat with a watch chain; dark trousers.
- **Danny (03).** Dark hair, round glasses; gray jacket and trousers, teal tie and waistcoat; slim build.
- **Gage (04).** Short light-brown hair, clean-shaven; blue waistcoat over a white shirt with rolled sleeves; brown trousers and boots.
- **Robbie (05).** Brown hair, full beard; dark blue tweed coat over a burgundy waistcoat; brown trousers.
- **Matt (09).** Brown hair, round glasses, short beard; olive-green waistcoat over a cream shirt with rolled sleeves; brown trousers.
- **John (21).** From the data: receding close-cropped hair, dark rectangular glasses, long dark goatee; taller than Jessica; cartoon facial features like the established
  cast, not a realistic photo face. From the art: navy mansion coat and waistcoat, gray trousers, brown shoes.

## What to send back

For each candidate, the image, which man it is, and either the approval in your own words or what to change ("rounder eyes", "less red", "taller"). If a result
changes the identity (a different beard, wrong glasses), say so and I will adjust the prompt. When one is approved, tell me and I will import it and start his folder.
