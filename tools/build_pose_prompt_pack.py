"""Plan-driven pose prompt packs for the user's own image tool (any character with a profile.json).

    python tools/build_pose_prompt_pack.py kwinn                      # whole plan; the next incomplete group is flagged NEXT
    python tools/build_pose_prompt_pack.py sarah-jo --group reveal    # only that group's batches
    python tools/build_pose_prompt_pack.py kwinn --directions east west --max-batch 6
    python tools/build_pose_prompt_pack.py kwinn --dry-run            # print the plan, write nothing

The order, group batching and progress come from assets/characters/poses/tools/pose_planning.py, which reads the pose catalog, the
production plan (assets/characters/poses/production-plan.json), the character profile and the character's real files and records.
A prompt pack is NOT progress: status comes from exports/, drafts/ and queue.json, never from this tool's own output.
No images are generated or edited here. Drafts need the user's explicit approval before import (docs/IMAGE_ASSET_WORKFLOW.md).

Each job is a separate image. Reference 1 is the approved base model (identity, scale); reference 2 is an approved SAME-POSE image of the
example character of the body template (Chris for men, Char for women) used for composition only.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import shutil
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "assets/characters/poses/tools"))
import pose_planning as pp  # noqa: E402

SEATED_NOTE = " Cross the legs only if that keeps the approved chair orientation and natural anatomy; otherwise keep both feet down."
FEMALE_NOTE = " Keep the long skirt hanging naturally; the legs are hidden by the dress except the boots."


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def orientation(entry: dict, pron: str) -> str:
    direction = pp.direction_of(entry)
    named = {"south": "toward the viewer (SOUTH)", "east": "screen RIGHT (EAST)", "west": "screen LEFT (WEST)",
             "north": f"AWAY from the viewer (NORTH), showing {pron} BACK"}
    if direction in named:
        return named[direction]
    if entry.get("body_axis"):
        return f"lying on body axis {entry['body_axis']}, head toward {entry['head_direction']}"
    return named["south"]


def pose_text(profile: dict, entry: dict) -> str:
    text = entry["male_template"] if profile["body"] == "male" else entry["female_template"]
    if profile["body"] == "female":
        text += FEMALE_NOTE
    elif entry["pose_id"].startswith("seated"):
        text += SEATED_NOTE
    return text


def single_prompt(profile: dict, entry: dict, owner: str, kind: str = "same_pose") -> str:
    who, pron = profile["name"].upper(), ("his" if profile["body"] == "male" else "her")
    ref2 = owner.title()
    ref_line = (f"REFERENCE 2 is {ref2}'s approved NEAREST related pose, NOT the same pose: use it only for body mechanics, canvas and rendering; the action to draw is described in POSE below."
                if kind == "nearest" else
                f"REFERENCE 2 is {ref2}'s approved SAME-POSE image: use it for pose composition, gesture and expression timing ONLY.")
    return f"""Create ONE separate full-body transparent PNG game character pose of {who}, {entry['pose_id']}, variant {entry['variant_id']}.
REFERENCE 1 is {profile['name']}'s USER-APPROVED base model: preserve this exact face, hair, costume colours, body proportions and drawing scale. {ref_line} Do not copy {ref2}'s face, hair, clothing, jewelry, beard or cap or anything else about that character's identity.
IDENTITY LOCK: {profile['identity']} {profile['style']}
POSE: {pose_text(profile, entry)}
EXPRESSION: {entry['variant_id']}. Communicate it through eyes, brows, mouth and posture where visible. Suspicious does not mean furious. Nervous is anxious uncertainty, not crying or terror. Neutral has relaxed brows and a small friendly expression where the face is visible.
FACING: the whole body faces {orientation(entry, pron)}. Head, chest, hips, knees and feet agree. North must show the actual back with no over-the-shoulder face. Elevated three-quarter mansion camera showing a little crown and shoulder tops. Draw this direction independently; NEVER mirror or flip another pose.
SCALE/FRAMING: reference 1 has a native {profile['canvas'][0]}x{profile['canvas'][1]} canvas and an occupied standing height of about {profile['standing_height']} pixels. Keep that SAME character drawing scale and a comparable portrait canvas. Reference 2 supplies composition, not stature. A standing figure is about {profile['standing_height']} pixels tall (within 4 percent) and fully inside clear transparent margins on every side; no cropping. Do not resize a seated, kneeling, crouching or lying pose to standing height. Both shoes visible when standing.
OUTPUT: exactly ONE complete character with real PNG alpha transparency (empty outside the silhouette), complete hands, arms, legs and boots, clean margins. No furniture, chair, floor, scenery, shadow, glow, text, labels, borders, grid or extra character. A book or similar prop only when the named action needs it. Return only this image; it is a draft, not an approval.
"""


def combined_prompt(profile: dict, todo: list[dict]) -> str:
    """One message for a whole batch: shared rules once, then one short job per pose, with STOP between jobs."""
    who, pron = profile["name"].upper(), ("his" if profile["body"] == "male" else "her")
    lines = [
        f"Create {len(todo)} SEPARATE full-body transparent PNG game character poses of {who}, one image per numbered job below, in order. "
        f"Each job is its own complete image with real PNG alpha transparency. Never combine jobs on one sheet or grid. Return all {len(todo)} images.",
        "WORK ONE JOB AT A TIME: finish a job, then STOP. Start the next job as a brand-new generation that does not reuse, copy or blend the previous result. Only the attached images and that job's own line apply to it.",
        "",
        "ATTACHED IMAGES (in this order):",
        f"- Image 1: {profile['name']}'s USER-APPROVED base model. Preserve this exact face, hair, costume colours, body proportions and drawing scale in every job.",
    ]
    for n, job in enumerate(todo, 1):
        owner = job["ref_owner"].title()
        if job["ref_kind"] == "nearest":
            lines.append(f"- Image {n + 1}: {owner}'s approved NEAREST related pose for job {n} ({job['entry']['pose_id']}); it is NOT the same pose. Use it only for body mechanics and canvas; the action is described in the job. Do not copy {owner}'s face, hair, clothing, jewelry, beard or cap.")
        else:
            lines.append(f"- Image {n + 1}: {owner}'s approved SAME-POSE image for job {n} ({job['entry']['pose_id']}). Use it for pose composition, gesture and expression timing ONLY; do not copy {owner}'s face, hair, clothing, jewelry, beard or cap.")
    lines += [
        "",
        f"IDENTITY LOCK (all jobs): {profile['identity']} {profile['style']}",
        "EXPRESSION RULES: communicate the named expression through eyes, brows, mouth and posture where visible. Suspicious does not mean furious. Nervous is anxious uncertainty, not crying or terror. Neutral has relaxed brows and a small friendly expression where the face is visible.",
        "FACING RULES: the whole body faces the stated direction; head, chest, hips, knees and feet agree. North shows the actual back with no over-the-shoulder face. Elevated three-quarter mansion camera showing a little crown and shoulder tops. Draw every direction independently; NEVER mirror or flip another pose. East and west seated poses must truly face sideways, not front-facing with the head turned.",
        f"SCALE/FRAMING (all jobs): image 1 has a native {profile['canvas'][0]}x{profile['canvas'][1]} canvas and an occupied standing height of about {profile['standing_height']} pixels. Keep that SAME drawing scale and a comparable portrait canvas for every job. Composition references supply pose, not stature. A standing figure is about {profile['standing_height']} pixels tall (within 4 percent) and fully inside clear transparent margins on all sides; no cropping. Do not resize seated, kneeling, crouching or lying poses to standing height. Both shoes visible when standing.",
        "OUTPUT RULES: exactly ONE complete character per image, with empty transparent space outside the silhouette, complete hands, arms, legs and boots, clean margins. No furniture, chair, floor, scenery, shadow, glow, text, labels, borders, grid or extra character. A book or similar prop only when the named action needs it. These are drafts, not approvals.",
        "",
        "JOBS:",
    ]
    for n, job in enumerate(todo, 1):
        entry = job["entry"]
        lines.append(f"JOB {n}: save as {job['save_as']}. Pose {entry['pose_id']}, expression {entry['variant_id']}. POSE: {pose_text(profile, entry)} FACING: {orientation(entry, pron)}. Composition reference: image {n + 1}.")
        lines.append("STOP. Start a new job." if n < len(todo) else "STOP. All jobs are finished.")
    return "\n".join(lines) + "\n"


def stage_files(profile: dict, slug: str, number: int, todo: list[dict]) -> Path:
    """Copies (never moves) the batch's attachments, numbered in attachment order, into test-results/pose-batches/<slug>/batch-NN/.
    Only files this tool names (NN_base-model.* and NN_composition_*.png) are replaced; any other file in the folder is left alone."""
    root = (ROOT / "test-results/pose-batches" / slug).resolve()
    target = (root / f"batch-{number:02d}").resolve()
    if root not in target.parents:
        raise SystemExit("Refusing to stage outside the character's staging folder")
    target.mkdir(parents=True, exist_ok=True)
    for old in list(target.glob("[0-9][0-9]_base-model.*")) + list(target.glob("[0-9][0-9]_composition_*.png")):
        old.unlink()
    master = ROOT / profile["master"]
    if master.suffix.lower() == ".webp":
        from PIL import Image
        Image.open(master).convert("RGBA").save(target / "01_base-model.png")  # lossless decode; the approved WEBP stays untouched
    else:
        shutil.copyfile(master, target / f"01_base-model{master.suffix}")
    for k, job in enumerate(todo, 2):
        shutil.copyfile(ROOT / job["ref2"], target / f"{k:02d}_composition_{job['entry']['pose_id']}.png")
    return target


# ----------------------------------------------------------------------------------------------- build
OWNED = ("prompts.json", "index.html", "README.md")


def safe_pack_dir(slug: str, pack: str) -> Path:
    if not pp.SLUG.match(pack or ""):
        raise SystemExit(f"Unsafe pack name {pack!r}: use letters, digits and hyphens only")
    out = (pp.POSES / pp.check_slug(slug) / "prompts" / pack).resolve()
    if (pp.POSES / slug / "prompts").resolve() not in out.parents:
        raise SystemExit("Refusing to write outside the character's prompts folder")
    return out


def build(slug: str, group: str | None, directions: list[str] | None, max_batch: int | None, min_batch: int | None,
          include_tier4: bool | None, dry_run: bool, pack: str) -> Path | None:
    profile = pp.load_profile(slug)
    master = ROOT / profile["master"]
    assert master.is_file(), master
    jobs, notes = pp.ordered_jobs(slug, include_tier4=include_tier4, directions=directions)
    prog = pp.progress(slug, jobs)
    for job in jobs:
        job["status"] = prog[job["key"]]["status"]
        job["facts"] = prog[job["key"]]
        ref = pp.resolve_reference(slug, job) if job["status"] == "missing" else {"kind": "not_needed"}
        job["ref"] = ref
        job["ref2"], job["ref_owner"], job["ref_kind"] = ref.get("path"), ref.get("owner", ""), ref["kind"]
        job["ref_ok"] = ref["kind"] in ("override", "same_pose", "fallback", "nearest", "not_needed")
    batches = pp.make_batches(jobs, max_batch, min_batch)
    for number, batch in enumerate(batches, 1):
        for job in batch:
            job["batch"] = number
    batch_cap = max_batch or pp.load_plan()["defaults"]["max_batch"]
    step = pp.next_step(slug, jobs, prog, group, batch_size=min(batch_cap, len([j for j in jobs if j["status"] == "missing"])))
    next_batches = sorted({j["batch"] for j in step["missing"]})
    counts = Counter(j["status"] for j in jobs)
    print(f"{profile['name']}: {len(jobs)} jobs in {len(batches)} batches (max {batch_cap}); status {dict(counts)}")
    if notes["new_families"]:
        print("New catalog families (planned in the last group automatically):", ", ".join(notes["new_families"]))
    if step["attention"]:
        print("REVIEW / RECOVER FIRST (no new group is started until these are handled):")
        for item in step["attention"]:
            print(f"  #{item['order']} {item['key']}: {item['reason']} ({item['path']})")
    log = step["backlog"]
    print(f"Backlog: {log['total']}/{log['cap_total']} unreviewed in total; per character {log['per_character']} (cap {log['cap_per_character']})" + ("  PAUSED" if step["action"] == "paused_backlog_cap" else ""))
    for d in step["decisions"]:
        print(f"DECISION: {d['kind']} {d.get('slot') or d.get('key')}: {d['choice']}")
    print(f"Action: {step['action']}; next group: {step['group_id']}; its unfinished jobs are in batch(es) {next_batches}")
    blocked = [j for j in step["missing"] if not j["ref_ok"]]
    for j in blocked:
        print(f"  needs a reference decision: #{j['order']} {j['entry']['pose_id']} ({j['ref']['kind']}: {j['ref'].get('note')})")
    for number, batch in enumerate(batches, 1):
        flag = "  <- NEXT" if number in next_batches and step["action"] == "generate" else ""
        done = sum(j["status"] != "missing" for j in batch)
        print(f"  batch {number:02d}: {len(batch)} jobs ({done} not missing) groups={sorted({j['group_id'] for j in batch})}{flag}")
    if dry_run:
        return None

    out = safe_pack_dir(slug, pack)
    out.mkdir(parents=True, exist_ok=True)
    shown = [n for n in range(1, len(batches) + 1) if group is None or any(j["group_id"] == group for j in batches[n - 1])]
    nav = " ".join(f'<a href="batch-{n:02d}.html">Batch {n}</a>' for n in shown)
    records = []
    for job in jobs:
        rec = {"order": job["order"], "tier": job["entry"]["tier"], "group": job["group_id"], "batch": job["batch"], "pose_id": job["entry"]["pose_id"],
               "variant_id": job["entry"]["variant_id"], "save_as": job["save_as"], "status": job["status"], "approval": job["facts"]["approval"],
               "technical": job["facts"]["technical"], "integrated": job["facts"]["integrated"], "reference": job["ref"]}
        if job["ref_ok"] and job["status"] == "missing":
            rec["attach"] = [{"role": "reference 1: approved base model", "path": profile["master"], "sha256": sha(master)},
                             {"role": f"reference 2: {job['ref_owner']} {'nearest related pose' if job['ref_kind'] == 'nearest' else 'same-pose composition'}", "path": job["ref2"], "sha256": sha(ROOT / job["ref2"])}]
            rec["prompt"] = single_prompt(profile, job["entry"], job["ref_owner"], job["ref_kind"])
        records.append(rec)
    (out / "prompts.json").write_text(json.dumps({"character": profile["name"], "note": "Status comes from exports/, drafts/ and the index, not from this file.", "jobs": records}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for old in out.glob("batch-[0-9][0-9].html"):
        old.unlink()  # only this tool's own page names; nothing else in the folder is touched
    paused = step["action"] != "generate"
    for number in shown:
        batch = batches[number - 1]
        todo = [j for j in batch if j["status"] == "missing" and j["ref_ok"]]
        generating_here = number in next_batches and not paused
        staged = stage_files(profile, slug, number, todo) if (todo and generating_here) else None
        title = f"batch {number} of {len(batches)}" + ("  (NEXT)" if generating_here else "")
        combined = combined_prompt(profile, todo) if staged is not None else ""
        banner = banner_for(step, number in next_batches)
        (out / f"batch-{number:02d}.html").write_text(page(profile, slug, batch, out, title, nav, combined, staged, banner), encoding="utf-8")
    (out / "index.html").write_text(index_page(profile, slug, jobs, batches, shown, next_batches, step, counts), encoding="utf-8")
    (out / "README.md").write_text(readme(profile, slug, len(jobs), len(batches), next_batches, step), encoding="utf-8")
    return out


def banner_for(step: dict, is_next: bool) -> str:
    if step["action"] == "review_or_recover_first":
        return "REVIEW OR RECOVER FIRST: drafts or recovery jobs exist (" + ", ".join(i["key"] for i in step["attention"][:6]) + "). No new batch is prepared until they are handled."
    if step["action"] == "needs_reference_decision":
        return "NEEDS A REFERENCE DECISION: every unfinished pose in the next group lacks an approved same-pose reference. Confirm a nearest-pose reference in production-plan.json or supply an external reference image."
    if step["action"] == "paused_backlog_cap":
        log = step["backlog"]
        return f"PRODUCTION PAUSED: {log['total']} unreviewed drafts in total (cap {log['cap_total']}, per character cap {log['cap_per_character']}). Review some first."
    return ""


def readme(profile: dict, slug: str, count: int, batches: int, next_batches: list[int], step: dict) -> str:
    return f"""# {slug}: pose prompt pack

{count} planned poses in {batches} batches, in the order set by `assets/characters/poses/production-plan.json`.
**Action:** {step['action']}; next group `{step['group_id']}`, batch(es) {next_batches}. Progress is read from `exports/`, `drafts/` and the directional index; this pack is not progress.

Per batch page: attach the files in the staging folder (copies; originals untouched), press **Copy all**, save each result under the exact file name into
`assets/characters/poses/{slug}/drafts/pack-01/`, then ask for the draft check and review gallery. Approve the batch or ask for a redo of a numbered pose in your own words.
Rebuild with `python tools/build_pose_prompt_pack.py {slug}`; options: `--group`, `--directions`, `--max-batch`, `--include-tier4` / `--no-tier4`, `--dry-run`.
"""


CSS = """body{font:15px system-ui;background:#1d242b;color:#eee6d6;margin:20px}header{max-width:900px}article{background:#2b343d;border:1px solid #5b6772;border-radius:8px;padding:14px;margin:16px 0}
h2{margin:0 0 6px;font-size:18px}h2 small{color:#b9ac8a;font-weight:400}.refs{display:flex;gap:14px;flex-wrap:wrap}figure{margin:0;width:170px}img{width:170px;height:240px;object-fit:contain;background:#7d858a;border-radius:4px}
figcaption{font-size:12px;overflow-wrap:anywhere}textarea{width:100%;background:#151b21;color:#eee6d6;border:1px solid #5b6772;border-radius:4px;font:12.5px/1.45 ui-monospace,monospace;padding:8px;box-sizing:border-box}
button{padding:7px 14px;font:inherit}.save code{background:#151b21;padding:2px 6px;border-radius:3px}.nav a{color:#e0c58d;margin-right:12px;white-space:nowrap}
.all{background:#26323b;border:2px solid #c9ab70;border-radius:8px;padding:14px;margin:16px 0}.all li{margin:6px 0}.badge{display:inline-block;border-radius:10px;padding:1px 9px;font-size:12px;margin-left:8px}
.approved{background:#2e6b3d}.draft{background:#8a6d1f}.missing{background:#4a5560}.needs_help{background:#8a2f2f}.skipped{background:#4a5560}tr.next td{background:#3b3320}table{border-collapse:collapse}td,th{padding:4px 10px;border-bottom:1px solid #46525c}"""


def page(profile: dict, slug: str, batch: list[dict], out: Path, title: str, nav: str, combined: str, staged: Path | None, banner: str = "") -> str:
    cards = []
    for job in batch:
        refs = []
        if job["ref_ok"] and job["status"] == "missing":
            for label, path in (("reference 1: approved base model", profile["master"]), (f"reference 2: {job['ref_owner']} " + ("nearest related pose" if job["ref_kind"] == "nearest" else "same-pose composition"), job["ref2"])):
                rel = Path(os.path.relpath(ROOT / path, out)).as_posix()
                refs.append(f'<figure><img src="{html.escape(rel)}" alt="{html.escape(label)}"><figcaption>{html.escape(label)}<br><small>{html.escape(path)}</small></figcaption></figure>')
            prompt = f'<textarea readonly rows="9">{html.escape(single_prompt(profile, job["entry"], job["ref_owner"], job["ref_kind"]))}</textarea><p><button onclick="copyPrompt(this)">Copy this one prompt</button> <small>(for redoing a single pose)</small></p>'
        elif job["status"] == "missing":
            ref = job["ref"]
            prompt = f'<p><b>Needs a reference decision before a prompt is made.</b> {html.escape(str(ref.get("note", "")))} Proposed nearest poses: {html.escape(", ".join(ref.get("proposed") or ["none"]))}. {html.escape(str(ref.get("advice") or ""))}</p>'
        else:
            f = job["facts"]
            prompt = f'<p>approval: <b>{html.escape(str(f["approval"]))}</b> · technical: {html.escape(str(f["technical"]))} · game: {html.escape(str(f["integrated"]))}<br><code>{html.escape(str(f["path"]))}</code></p>'
        cards.append(f'''<article id="job{job['order']}"><h2>{job['order']}. {html.escape(job['entry']['pose_id'])} <small>({html.escape(job['entry']['variant_id'])}) · tier {job['entry']['tier']} · {html.escape(job['group_id'])}</small><span class="badge {job['status']}">{job['status']}</span></h2>
<p class="save">File name: <code>{html.escape(job['save_as'])}</code></p><div class="refs">{''.join(refs)}</div>{prompt}</article>''')
    allinone = ""
    if combined and staged is not None:
        files = "".join(f"<li><code>{html.escape(f.name)}</code></li>" for f in sorted(staged.iterdir()))
        count = sum(1 for j in batch if j["status"] == "missing" and j["ref_ok"])
        allinone = (f'<section class="all"><h2>All {count} unfinished poses at once</h2><ol><li>Attach <b>every file</b> in this folder to one message: '
                    f'<code>{html.escape(staged.relative_to(ROOT).as_posix())}</code> (inside the project folder)<ul>{files}</ul></li><li>Paste the text below (one copy button).</li>'
                    f'<li>Save each returned image with the file name given in its job. Then approve the batch or ask for a redo of one numbered pose.</li></ol>'
                    f'<textarea readonly rows="14" id="all">{html.escape(combined)}</textarea><p><button onclick="copyAll(this)">Copy all prompts</button></p></section>')
    elif banner:
        allinone = f'<section class="all"><h2>{html.escape(banner)}</h2></section>'
    elif not any(j["status"] == "missing" for j in batch):
        allinone = '<section class="all"><h2>Nothing left to generate in this batch</h2><p>Every job already has a draft or an export. Run the draft check and review.</p></section>'
    return f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(slug)} pose prompts - {html.escape(title)}</title><style>{CSS}</style>
<header><h1>{html.escape(slug)} / {html.escape(title)}</h1><p class="nav"><a href="index.html">All batches</a> {nav}</p><p>Drafts are not approved art until you approve them in your own words. Poses are numbered so you can ask for a redo by number.</p></header>
{allinone}<main>{''.join(cards)}</main><script>function copyPrompt(b){{const t=b.closest('article').querySelector('textarea');t.select();navigator.clipboard.writeText(t.value);b.textContent='Copied';setTimeout(()=>b.textContent='Copy this one prompt',1500)}}
function copyAll(b){{const t=document.getElementById('all');t.select();navigator.clipboard.writeText(t.value);b.textContent='Copied';setTimeout(()=>b.textContent='Copy all prompts',1500)}}</script></html>'''


def index_page(profile: dict, slug: str, jobs: list[dict], batches: list[list[dict]], shown: list[int], next_batches: list[int], step: dict, counts: Counter) -> str:
    rows = []
    for number, batch in enumerate(batches, 1):
        done = sum(j["status"] != "missing" for j in batch)
        groups = ", ".join(sorted({j["group_id"] for j in batch}, key=lambda g: min(j["group_index"] for j in batch if j["group_id"] == g)))
        label = f'<a href="batch-{number:02d}.html">Batch {number}</a>' if number in shown else f"Batch {number} (page not built)"
        flag = " (NEXT)" if number in next_batches and step["action"] == "generate" else ""
        rows.append(f'<tr class="{"next" if flag else ""}"><td>{label}{flag}</td><td>{len(batch)} poses</td><td>{done} not missing</td><td>{html.escape(groups)}</td></tr>')
    summary = ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    banner = banner_for(step, False)
    decisions = "".join(f"<li>{html.escape(d['kind'])}: {html.escape(str(d.get('slot') or d.get('key')))}: {html.escape(d['choice'])}</li>" for d in step["decisions"])
    return f'''<!doctype html><html lang="en"><meta charset="utf-8"><title>{html.escape(slug)} pose plan</title><style>{CSS}</style>
<header><h1>{html.escape(slug)} / pose production plan</h1><p>{len(jobs)} poses, {len(batches)} batches. Status read from the character's files and records: {html.escape(summary)}. Action: <b>{html.escape(str(step["action"]))}</b>; next group <b>{html.escape(str(step["group_id"]))}</b>.</p>
{f'<p class="banner"><b>{html.escape(banner)}</b></p>' if banner else ''}{f'<h3>Decisions for you</h3><ul>{decisions}</ul>' if decisions else ''}</header><table><tr><th></th><th></th><th></th><th>Groups</th></tr>{"".join(rows)}</table></html>'''


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("slug", help="character slug with a profile.json (for example kwinn, sarah-jo)")
    ap.add_argument("--group", help="only this production group (see production-plan.json)")
    ap.add_argument("--directions", nargs="+", choices=list(pp.DIRECTIONS), help="only these directions")
    ap.add_argument("--max-batch", type=int, help="largest batch (default from the plan, 8)")
    ap.add_argument("--min-batch", type=int, help="smallest batch before groups are joined (default from the plan)")
    ap.add_argument("--include-tier4", dest="include_tier4", action="store_true", default=None, help="plan the tier-4 catalog poses (default: the plan decides; currently yes)")
    ap.add_argument("--no-tier4", dest="include_tier4", action="store_false", help="leave the tier-4 catalog poses out")
    ap.add_argument("--dry-run", action="store_true", help="print the plan and write nothing")
    ap.add_argument("--pack", default="pack-01", help="output folder name under prompts/")
    args = ap.parse_args()
    out = build(args.slug, args.group, args.directions, args.max_batch, args.min_batch, args.include_tier4, args.dry_run, args.pack)
    if out:
        print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
