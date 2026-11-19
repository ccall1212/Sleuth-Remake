"""Build a copy-and-paste pose prompt pack for one character (for the user's own image tool).

    python tools/build_pose_prompt_pack.py kwinn
    python tools/build_pose_prompt_pack.py sarah-jo

Writes assets/characters/poses/<slug>/prompts/pack-01/{prompts.json,index.html,README.md}. No images are generated or
edited here. Each prompt follows the production wording used for Chris (see assets/characters/poses/tools/pose_runner.py):
the approved base model is reference 1 (identity, scale), and an already-approved SAME-POSE image of the example character of
the same body template is reference 2 (composition and gesture only): Chris for men, Char for women.
Draft results still need the user's explicit approval before import (docs/IMAGE_ASSET_WORKFLOW.md).
"""
from __future__ import annotations

import hashlib
import html
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POSES = ROOT / "assets/characters/poses"
CATALOG = ROOT / "assets/characters/pose-catalog.json"

CHARACTERS = {
    "kwinn": {
        "name": "KWINN", "pronoun": "his", "body": "male", "example": "chris",
        "master": "assets/characters/poses/kwinn/masters/model-review-02/kwinn-model-v1.png",
        "canvas": "985x1597", "height": 1572,
        "identity": ("Kwinn: wavy dark-brown hair swept up and back, warm brown eyes, a wide friendly smile with white teeth, a neat moustache joined to a "
                     "short goatee with light scruff along the jaw, tan skin. Cream collared shirt with the sleeves rolled to the elbow, an ORANGE pinstriped "
                     "waistcoat with four brass buttons and two flap pockets, a PURPLE tie, a gold watch chain looping from a waistcoat button to the pocket on "
                     "screen-LEFT in the south view (his anatomical RIGHT; keep that side across directions, never move it to make it visible), dark brown pleated "
                     "trousers and brown lace-up boots. No hat."),
        "style": "Same richly shaded, outlined anime/cartoon game rendering as the approved Kwinn model (crisp detail, no photoreal skin, no chibi anatomy).",
    },
    "sarah-jo": {
        "name": "SARAH JO", "pronoun": "her", "body": "female", "example": "char",
        "master": "assets/characters/poses/sarah-jo/masters/model-review-07/sarah-jo-model-v1.webp",
        "canvas": "987x1593", "height": 1590,
        "identity": ("Sarah Jo: very short, tousled brown hair (pixie cut) with a few wisps over the forehead, warm brown eyes with fine lashes, a wide open smile, "
                     "tan skin. A gold locket on a thin chain over a cream lace high collar. A pale-blue Victorian dress with big puffed sleeves in textured blue "
                     "fabric, long fitted forearms ending in cream lace cuffs, four gold front buttons, a blue belt, a cream embroidered floral panel down the "
                     "front of the long skirt, draped bustle swags at the sides, tiered ruffled hem, and brown leather ankle boots."),
        "style": "Same richly shaded, outlined anime/cartoon game rendering as the approved Sarah Jo model (crisp detail, no photoreal skin, no chibi anatomy).",
    },
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def orientation(entry: dict, who: dict) -> str:
    direction = (entry.get("directions") or [None])[0]
    pron = who["pronoun"]
    named = {"south": "toward the viewer (SOUTH)", "east": "screen RIGHT (EAST)", "west": "screen LEFT (WEST)",
             "north": f"AWAY from the viewer (NORTH), showing {pron} BACK"}
    if direction in named:
        return named[direction]
    return f"lying on body axis {entry.get('body_axis')}, head toward {entry.get('head_direction')}"


def reference_two(slug: str, entry: dict) -> tuple[str, str]:
    """Approved same-pose image of the example character; falls back to Char's source asset."""
    example = CHARACTERS[slug]["example"]
    pose, variant = entry["pose_id"], entry["variant_id"]
    queue_file = POSES / example / "queue.json"
    if queue_file.exists():
        for job in json.loads(queue_file.read_text(encoding="utf-8")):
            if job["pose_id"] == pose and job["variant_id"] == variant and job.get("approved_export"):
                if (ROOT / job["approved_export"]).is_file():
                    return job["approved_export"], example
    source = entry.get("source_char_asset")
    if source and (ROOT / source).is_file():
        return source, "char"
    raise SystemExit(f"No approved same-pose reference for {pose}/{variant}")


def build_prompt(slug: str, entry: dict, ref2_owner: str) -> str:
    who = CHARACTERS[slug]
    pose_text = entry["male_template"] if who["body"] == "male" else entry["female_template"]
    if who["body"] == "female":
        pose_text += " Keep the long skirt hanging naturally; the legs are hidden by the dress except the boots."
    ref2 = {"chris": "Chris's", "char": "Char's"}[ref2_owner]
    avoid = f"{ref2.rstrip(chr(39) + 's')}'s face, hair, clothing, jewelry, beard or cap"
    return f"""Create ONE separate full-body transparent PNG game character pose of {who['name']}, {entry['pose_id']}, variant {entry['variant_id']}.
REFERENCE 1 is {who['name'].title()}'s USER-APPROVED base model: preserve this exact face, hair, costume colours, body proportions and drawing scale. REFERENCE 2 is {ref2} approved SAME-POSE image: use it for pose composition, gesture and expression timing ONLY. Do not copy {avoid} or anything else about that character's identity.
IDENTITY LOCK: {who['identity']} {who['style']}
POSE: {pose_text}
EXPRESSION: {entry['variant_id']}. Communicate it through eyes, brows, mouth and posture where visible. Suspicious does not mean furious. Nervous is anxious uncertainty, not crying or terror. Neutral has relaxed brows and a small friendly expression where the face is visible.
FACING: the whole body faces {orientation(entry, who)}. Head, chest, hips, knees and feet agree. North must show the actual back with no over-the-shoulder face. Elevated three-quarter mansion camera showing a little crown and shoulder tops. Draw this direction independently; NEVER mirror or flip another pose.
SCALE/FRAMING: reference 1 has a native {who['canvas']} canvas and an occupied standing height of about {who['height']} pixels. Keep that SAME character drawing scale and a comparable portrait canvas. Reference 2 supplies composition, not stature. A standing figure is about {who['height']} pixels tall (within 4 percent) and fully inside clear transparent margins on every side; no cropping. Do not resize a seated, kneeling or lying pose to standing height. Both shoes visible when standing.
OUTPUT: exactly ONE complete character with real PNG alpha transparency (empty outside the silhouette), complete hands, arms, legs and boots, clean margins. No furniture, chair, floor, scenery, shadow, glow, text, labels, borders, grid or extra character. A book or similar prop only when the named action needs it. Return only this image; it is a draft, not an approval.
"""


def filename(slug: str, entry: dict) -> str:
    return f"{slug.replace('-', '_')}_{entry['pose_id']}_{entry['variant_id']}.png"


def build(slug: str) -> Path:
    who = CHARACTERS[slug]
    master = ROOT / who["master"]
    assert master.is_file(), master
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    entries = [e for e in catalog["entries"] if e["tier"] < 4]
    entries.sort(key=lambda e: (e["tier"], e["pose_id"], e["variant_id"]))
    jobs = []
    for order, entry in enumerate(entries, 1):
        ref2, owner = reference_two(slug, entry)
        jobs.append({
            "order": order, "tier": entry["tier"], "pose_id": entry["pose_id"], "variant_id": entry["variant_id"],
            "save_as": filename(slug, entry),
            "attach": [{"role": "reference 1: approved base model", "path": who["master"], "sha256": sha(master)},
                       {"role": f"reference 2: {owner} same-pose composition", "path": ref2, "sha256": sha(ROOT / ref2)}],
            "prompt": build_prompt(slug, entry, owner),
        })
    out = POSES / slug / "prompts/pack-01"
    out.mkdir(parents=True, exist_ok=True)
    (out / "prompts.json").write_text(json.dumps({"character": who["name"].title(), "jobs": jobs}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (out / "README.md").write_text(readme(slug, len(jobs)), encoding="utf-8")
    (out / "index.html").write_text(page(slug, jobs, out), encoding="utf-8")
    return out


def readme(slug: str, count: int) -> str:
    return f"""# {slug}: pose prompt pack 01

{count} core poses (tiers 1-3; tier 4 is held because no matching Char art exists). Open `index.html`, work in tier order.

For each card: (1) attach the two reference images, (2) paste the prompt, (3) save the result with the **exact file name shown** into
`assets/characters/poses/{slug}/drafts/pack-01/` (create the folder), (4) tell Claude the pose is ready. A draft is not approved until you say so
in your own words; Claude then imports it, records the approval and checks size and transparency. Do about eight at a time so reviews stay manageable.
"""


def page(slug: str, jobs: list[dict], out: Path) -> str:
    cards = []
    for job in jobs:
        refs = []
        for item in job["attach"]:
            rel = Path(__import__("os").path.relpath(ROOT / item["path"], out)).as_posix()
            refs.append(f'<figure><img src="{html.escape(rel)}" alt="{html.escape(item["role"])}"><figcaption>{html.escape(item["role"])}<br><small>{html.escape(item["path"])}</small></figcaption></figure>')
        cards.append(f'''<article id="job{job["order"]}"><h2>{job["order"]}. {html.escape(job["pose_id"])} <small>({html.escape(job["variant_id"])}) · tier {job["tier"]}</small></h2>
<p class="save">Save as: <code>{html.escape(job["save_as"])}</code></p><div class="refs">{"".join(refs)}</div>
<textarea readonly rows="9">{html.escape(job["prompt"])}</textarea><p><button onclick="copyPrompt(this)">Copy prompt</button> <label><input type="checkbox" class="done"> generated</label></p></article>''')
    return f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(slug)} pose prompts</title>
<style>body{{font:15px system-ui;background:#1d242b;color:#eee6d6;margin:20px}}header{{max-width:900px}}article{{background:#2b343d;border:1px solid #5b6772;border-radius:8px;padding:14px;margin:16px 0}}
h2{{margin:0 0 6px;font-size:18px}}h2 small{{color:#b9ac8a;font-weight:400}}.refs{{display:flex;gap:14px;flex-wrap:wrap}}figure{{margin:0;width:170px}}img{{width:170px;height:240px;object-fit:contain;background:#7d858a;border-radius:4px}}
figcaption{{font-size:12px;overflow-wrap:anywhere}}textarea{{width:100%;background:#151b21;color:#eee6d6;border:1px solid #5b6772;border-radius:4px;font:12.5px/1.45 ui-monospace,monospace;padding:8px;box-sizing:border-box}}
button{{padding:7px 14px;font:inherit}}.save code{{background:#151b21;padding:2px 6px;border-radius:3px}}</style>
<header><h1>{html.escape(slug)} / pose prompt pack 01</h1><p>{len(jobs)} core poses in tier order. Attach both reference images, paste the prompt, save the PNG under the exact name shown into
<code>assets/characters/poses/{html.escape(slug)}/drafts/pack-01/</code>, then tell Claude. Drafts are not approved art until you approve them in your own words.</p></header>
<main>{"".join(cards)}</main><script>function copyPrompt(b){{const t=b.closest('article').querySelector('textarea');t.select();navigator.clipboard.writeText(t.value);b.textContent='Copied';setTimeout(()=>b.textContent='Copy prompt',1500)}}
document.querySelectorAll('.done').forEach((c,i)=>{{const k='{slug}-done-'+i;c.checked=localStorage.getItem(k)==='1';c.onchange=()=>localStorage.setItem(k,c.checked?'1':'0')}})</script></html>'''


if __name__ == "__main__":
    for target in sys.argv[1:] or list(CHARACTERS):
        print(build(target))
