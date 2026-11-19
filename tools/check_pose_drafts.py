"""Read-only QA for user-generated pose drafts.

    python tools/check_pose_drafts.py <slug> [--html]

Checks every PNG in assets/characters/poses/<slug>/drafts/pack-01/ against prompts.json and writes only
drafts/pack-01/review/status.json (and review/index.html with --html). Images are never modified.
Thresholds follow pose_runner.finish(): alpha extrema, bbox at alpha>128, occupied standing height.
"""
from __future__ import annotations

import hashlib
import html
import json
import sys
from pathlib import Path

from PIL import Image

Image.MAX_IMAGE_PIXELS = None

ROOT = Path(__file__).resolve().parents[1]
POSES = ROOT / "assets/characters/poses"

CONFIG = {
    "kwinn": {"master": "assets/characters/poses/kwinn/masters/model-review-02/kwinn-model-v1.png", "canvas": (985, 1597), "height": 1572},
    "sarah-jo": {"master": "assets/characters/poses/sarah-jo/masters/model-review-07/sarah-jo-model-v1.webp", "canvas": (987, 1593), "height": 1590},
}

CANVAS_TOL = 0.12
EDGE_MARGIN = 8
MIN_TRANSPARENT = 0.15
HAZE_MAX = 0.06
HEIGHT_WARN = 0.06
HEIGHT_FAIL = 0.10
SOLID_ALPHA = 128
HAZE_LOW, HAZE_HIGH = 1, 30


def check(name: str, status: str, message: str) -> dict:
    return {"name": name, "status": status, "message": message}


def posture_of(pose_id: str) -> str:
    return pose_id.split("_", 1)[0]


def analyze(path: Path, job: dict | None, cfg: dict) -> tuple[list[dict], dict]:
    """Return (checks, info) for one draft. Opens the file read-only."""
    info = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "size": None}
    results: list[dict] = []
    try:
        with Image.open(path) as img:
            img.load()
            fmt, mode, size = img.format, img.mode, img.size
            image = img.copy()
    except Exception as exc:  # noqa: BLE001
        return [check("png", "fail", f"cannot open as image: {exc}")], info
    info["size"] = list(size)
    if fmt != "PNG":
        results.append(check("png", "fail", f"format is {fmt}, expected PNG"))
    else:
        results.append(check("png", "pass", "opens as PNG"))

    w, h = size
    total = w * h
    if mode != "RGBA":
        results.append(check("alpha", "fail", f"mode {mode}, expected RGBA with real transparency"))
        alpha = None
    else:
        alpha = image.getchannel("A")
        hist = alpha.histogram()
        amin = next(i for i, c in enumerate(hist) if c)
        frac0 = hist[0] / total
        if amin != 0:
            results.append(check("alpha", "fail", f"no transparent pixels (alpha min {amin})"))
        elif frac0 < MIN_TRANSPARENT:
            results.append(check("alpha", "fail", f"only {frac0:.1%} fully transparent (need {MIN_TRANSPARENT:.0%})"))
        else:
            results.append(check("alpha", "pass", f"RGBA, {frac0:.1%} fully transparent"))
        haze = sum(hist[HAZE_LOW:HAZE_HIGH + 1]) / total
        if haze > HAZE_MAX:
            results.append(check("haze", "warn", f"faint haze: {haze:.1%} of pixels at alpha {HAZE_LOW}-{HAZE_HIGH}"))
        else:
            results.append(check("haze", "pass", f"faint haze {haze:.1%}"))

    cw, ch = cfg["canvas"]
    dw, dh = abs(w / cw - 1), abs(h / ch - 1)
    if dw > CANVAS_TOL or dh > CANVAS_TOL:
        results.append(check("canvas", "warn", f"canvas {w}x{h} differs from master {cw}x{ch} by more than {CANVAS_TOL:.0%}"))
    else:
        results.append(check("canvas", "pass", f"canvas {w}x{h} vs master {cw}x{ch}"))

    bounds = alpha.point(lambda p: 255 if p > SOLID_ALPHA else 0).getbbox() if alpha else None
    if alpha is None:
        results.append(check("margins", "fail", "no alpha channel to measure the figure"))
    elif not bounds:
        results.append(check("margins", "fail", "no occupied pixels (alpha>128)"))
    else:
        x0, y0, x1, y1 = bounds
        gaps = {"left": x0, "top": y0, "right": w - x1, "bottom": h - y1}
        touching = [k for k, v in gaps.items() if v <= 0]
        near = [k for k, v in gaps.items() if 0 < v <= EDGE_MARGIN]
        if touching:
            results.append(check("margins", "fail", f"cropped: figure touches {', '.join(touching)} edge"))
        elif near:
            results.append(check("margins", "warn", f"figure within {EDGE_MARGIN}px of {', '.join(near)} edge"))
        else:
            results.append(check("margins", "pass", f"clear margins (min {min(gaps.values())}px)"))

    pose_id = job["pose_id"] if job else ""
    if job and pose_id.startswith("standing_"):
        if not bounds:
            results.append(check("height", "fail", "cannot measure height"))
        else:
            occ = bounds[3] - bounds[1]
            err = abs(occ / cfg["height"] - 1)
            msg = f"occupied height {occ}px vs master {cfg['height']}px ({occ / cfg['height'] - 1:+.1%})"
            status = "pass" if err <= HEIGHT_WARN else ("warn" if err <= HEIGHT_FAIL else "fail")
            results.append(check("height", status, msg))
    elif job:
        results.append(check("height", "pass", f"height check skipped for {posture_of(pose_id)}"))
    else:
        results.append(check("height", "pass", "height check skipped (unmatched file)"))
    return results, info


def overall(results: list[dict]) -> str:
    states = {r["status"] for r in results}
    return "fail" if "fail" in states else ("warn" if "warn" in states else "pass")


def build_report(slug: str) -> dict | None:
    """Return the status dict, or None when the drafts folder is missing. Raises SystemExit(2) on setup errors."""
    if slug not in CONFIG:
        print(f"unknown slug: {slug} (known: {', '.join(CONFIG)})")
        raise SystemExit(2)
    cfg = CONFIG[slug]
    pack = POSES / slug / "prompts/pack-01/prompts.json"
    if not pack.is_file():
        print(f"missing prompts.json: {pack}")
        raise SystemExit(2)
    jobs = json.loads(pack.read_text(encoding="utf-8"))["jobs"]
    drafts = POSES / slug / "drafts/pack-01"
    if not drafts.is_dir():
        return None
    files = {p.name: p for p in drafts.iterdir() if p.is_file() and p.suffix.lower() == ".png"}
    by_save = {j["save_as"]: j for j in jobs}
    entries = []
    for job in sorted(jobs, key=lambda j: j["order"]):
        entry = {"order": job["order"], "tier": job["tier"], "pose_id": job["pose_id"], "variant_id": job["variant_id"],
                 "save_as": job["save_as"], "present": job["save_as"] in files, "results": [], "overall": None, "sha256": None, "size": None}
        if entry["present"]:
            entry["results"], info = analyze(files[job["save_as"]], job, cfg)
            entry["overall"] = overall(entry["results"])
            entry["sha256"], entry["size"] = info["sha256"], info["size"]
        entries.append(entry)
    unmatched = []
    for name in sorted(files):
        if name in by_save:
            continue
        results, info = analyze(files[name], None, cfg)
        unmatched.append({"file": name, "note": "unmatched file", "results": results, "overall": overall(results),
                          "sha256": info["sha256"], "size": info["size"]})
    present = [e for e in entries if e["present"]]
    counts = {"total": len(jobs), "present": len(present),
              "pass": sum(e["overall"] == "pass" for e in present),
              "warn": sum(e["overall"] == "warn" for e in present),
              "fail": sum(e["overall"] == "fail" for e in present),
              "unmatched": len(unmatched)}
    return {"slug": slug, "master": cfg["master"], "counts": counts, "jobs": entries, "unmatched": unmatched}


def render_html(report: dict, review_dir: Path) -> str:
    import os
    slug, c = report["slug"], report["counts"]
    drafts = review_dir.parent

    def badge(status: str) -> str:
        return f'<span class="b {status}">{status}</span>'

    def card(name: str, title: str, sub: str, entry: dict) -> str:
        rel = Path(os.path.relpath(drafts / name, review_dir)).as_posix()
        msgs = "".join(f'<li class="{r["status"]}">{badge(r["status"])} <b>{html.escape(r["name"])}</b> {html.escape(r["message"])}</li>' for r in entry["results"])
        return (f'<article class="card" data-state="{entry["overall"]}"><img src="{html.escape(rel)}" alt="{html.escape(name)}" loading="lazy">'
                f'<h3>{html.escape(title)} {badge(entry["overall"])}</h3><p class="sub">{html.escape(sub)}<br><code>{html.escape(name)}</code></p><ul>{msgs}</ul></article>')

    cards = [card(e["save_as"], f'{e["order"]}. {e["pose_id"]}', f'{e["variant_id"]} - tier {e["tier"]}', e) for e in report["jobs"] if e["present"]]
    cards += [card(u["file"], u["file"], "unmatched file", u) for u in report["unmatched"]]
    missing = "".join(f'<li>{e["order"]}. {html.escape(e["pose_id"])} ({html.escape(e["variant_id"])}) - <code>{html.escape(e["save_as"])}</code></li>' for e in report["jobs"] if not e["present"])
    master_rel = Path(os.path.relpath(ROOT / report["master"], review_dir)).as_posix()
    return f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(slug)} draft review</title>
<style>body{{font:14px system-ui;background:#1d242b;color:#eee6d6;margin:20px}}h1{{margin:0 0 6px}}.counts span{{margin-right:14px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px}}.card{{background:#2b343d;border:1px solid #5b6772;border-radius:8px;padding:10px}}
.card img{{width:100%;height:340px;object-fit:contain;background:#7d858a;border-radius:4px}}h3{{margin:8px 0 2px;font-size:15px}}.sub{{margin:0 0 6px;color:#b9ac8a;font-size:12px;overflow-wrap:anywhere}}
ul{{list-style:none;padding:0;margin:0;font-size:12px}}li{{margin:2px 0}}.b{{display:inline-block;padding:0 6px;border-radius:9px;font-size:11px;color:#111}}.pass{{--c:#6fcf7f}}.warn{{--c:#f0c24b}}.fail{{--c:#ef6b5f}}.b{{background:var(--c)}}
button{{padding:6px 12px;font:inherit;margin-right:6px}}code{{background:#151b21;padding:1px 5px;border-radius:3px}}.master{{max-width:260px}}</style>
<h1>{html.escape(slug)} / draft review (pack 01)</h1>
<p class="counts"><span>Present {c["present"]} of {c["total"]}</span><span>{badge("pass")} {c["pass"]}</span><span>{badge("warn")} {c["warn"]}</span><span>{badge("fail")} {c["fail"]}</span><span>unmatched {c["unmatched"]}</span></p>
<p>Technical checks only; visual review and approval are yours. <button onclick="f('all')">All</button><button onclick="f('warn')">Warnings</button><button onclick="f('fail')">Failures</button></p>
<h2>Master (comparison)</h2><div class="card master"><img src="{html.escape(master_rel)}" alt="master"><p class="sub"><code>{html.escape(report["master"])}</code></p></div>
<h2>Drafts</h2><div class="grid">{"".join(cards) or "<p>No drafts present.</p>"}</div>
<h2>Not generated yet</h2><ol>{missing or "<li>None</li>"}</ol>
<script>function f(m){{document.querySelectorAll('.grid .card').forEach(c=>{{c.style.display=(m==='all'||c.dataset.state===m)?'':'none'}})}}</script></html>'''


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    want_html = "--html" in args
    args = [a for a in args if a != "--html"]
    if len(args) != 1:
        print("usage: check_pose_drafts.py <slug> [--html]")
        return 2
    try:
        report = build_report(args[0])
    except SystemExit as exc:
        return int(exc.code or 2)
    if report is None:
        print("no drafts yet")
        return 0
    review = POSES / args[0] / "drafts/pack-01/review"
    review.mkdir(parents=True, exist_ok=True)
    (review / "status.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if want_html:
        (review / "index.html").write_text(render_html(report, review), encoding="utf-8")
    c = report["counts"]
    print(f"present {c['present']} of {c['total']}: pass {c['pass']}, warn {c['warn']}, fail {c['fail']}, unmatched {c['unmatched']}")
    for e in report["jobs"]:
        if e["present"]:
            print(f"  [{e['overall']}] {e['save_as']}: " + "; ".join(r["message"] for r in e["results"] if r["status"] != "pass"))
    for u in report["unmatched"]:
        print(f"  unmatched file: {u['file']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
