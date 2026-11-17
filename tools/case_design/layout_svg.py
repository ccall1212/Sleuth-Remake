"""Render a blockout layout to a single-page HTML review (inline SVG, no dependencies).

    python tools/case_design/layout_svg.py [layout.json] [out_dir]

Defaults: assets/maps/house-01.layout.json -> docs/case-design/house-01-blockout/index.html.
Each screen is drawn at half size with its walkable floor, obstacles, doors (arrows to the target screen),
item slot, guest spots and, for the library, the secret-panel columns. The page also lists the step cost
between rooms so hall length can be tuned before any art exists.
"""
from __future__ import annotations

import html
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "case_design"

from case_design import layout as lay

ROOT = Path(__file__).resolve().parents[2]
SCALE = 0.75
COLS = 3
GAP = 24
LABEL_H = 22


def _screen_svg(s: dict, secret: dict | None, names: dict[str, str]) -> str:
    w, h = lay.SCREEN_W * SCALE, lay.SCREEN_H * SCALE
    p = [f'<rect x="0" y="0" width="{w}" height="{h}" fill="#1b1b22" stroke="#555"/>']
    for x, y, rw, rh in s["walk_regions"]:
        p.append(f'<rect x="{x*SCALE}" y="{y*SCALE}" width="{rw*SCALE}" height="{rh*SCALE}" fill="#3a4a3a" stroke="#6a8a6a"/>')
    for x, y, rw, rh in s.get("obstacles", []):
        p.append(f'<rect x="{x*SCALE}" y="{y*SCALE}" width="{rw*SCALE}" height="{rh*SCALE}" fill="#7a5a3a" stroke="#b08a5a"/>')
    if "item_slot" in s:
        x, y = s["item_slot"]
        p.append(f'<polygon points="{x*SCALE},{(y-7)*SCALE} {(x+7)*SCALE},{y*SCALE} {x*SCALE},{(y+7)*SCALE} {(x-7)*SCALE},{y*SCALE}" fill="#e8c040"><title>item slot</title></polygon>')
    for x, y in s.get("guest_spots", []):
        p.append(f'<circle cx="{x*SCALE}" cy="{y*SCALE}" r="{6*SCALE}" fill="#5aa0e0"><title>guest spot</title></circle>')
    sx, sy = s["spawn"]
    p.append(f'<rect x="{(sx-4)*SCALE}" y="{(sy-4)*SCALE}" width="{8*SCALE}" height="{8*SCALE}" fill="none" stroke="#fff"><title>spawn</title></rect>')
    for door in s.get("portals", []):
        x, y = door["at"]
        dx, dy = door["facing"]
        color = {"door": "#e05a5a", "front_door": "#a050c0", "secret_exit": "#40c0a0"}[door.get("kind", "door")]
        p.append(f'<circle cx="{x*SCALE}" cy="{y*SCALE}" r="{7*SCALE}" fill="{color}"/>')
        p.append(f'<line x1="{x*SCALE}" y1="{y*SCALE}" x2="{(x+dx*20)*SCALE}" y2="{(y+dy*20)*SCALE}" stroke="{color}" stroke-width="2"/>')
        label = "front door" if door.get("kind") == "front_door" else names.get(door["target"], door["target"])
        tx = x * SCALE + (-4 if dx > 0 else 4 if dx < 0 else -20)
        ty = y * SCALE + (-8 if dy >= 0 else 14)
        anchor = "end" if dx > 0 else "start"
        p.append(f'<text x="{tx}" y="{ty}" font-size="9" fill="#ddd" text-anchor="{anchor}">{html.escape(label)}</text>')
    if secret and s["id"] == secret["entrance_room"]:
        for cx in secret["panel_columns"]:
            p.append(f'<rect x="{(cx-4)*SCALE}" y="{150*SCALE}" width="{8*SCALE}" height="{6*SCALE}" fill="#40c0a0"><title>secret panel column</title></rect>')
    return "".join(p)


def render(layout: dict) -> str:
    screens = layout["screens"]
    names = {s["id"]: s["name"] for s in screens}
    secret = layout.get("secret")
    w, h = lay.SCREEN_W * SCALE, lay.SCREEN_H * SCALE
    rows = (len(screens) + COLS - 1) // COLS
    total_w = COLS * (w + GAP) + GAP
    total_h = rows * (h + GAP + LABEL_H) + GAP
    body = []
    for i, s in enumerate(screens):
        x = GAP + (i % COLS) * (w + GAP)
        y = GAP + (i // COLS) * (h + GAP + LABEL_H)
        body.append(f'<g transform="translate({x},{y})"><text x="0" y="14" font-size="13" fill="#eee">{html.escape(s["name"])} <tspan fill="#888" font-size="10">({s["role"]})</tspan></text>'
                    f'<g transform="translate(0,{LABEL_H})">{_screen_svg(s, secret, names)}</g></g>')
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total_w} {total_h}" width="100%">{"".join(body)}</svg>'
    summ = lay.summary(layout)
    costs = lay.step_costs(layout)
    rooms = [s["id"] for s in screens if s["role"] == "room"]
    head = "".join(f"<th>{html.escape(names[r])}</th>" for r in rooms)
    trs = "".join(
        f"<tr><th>{html.escape(names[a])}</th>" + "".join(
            f"<td>{'' if a == b else costs.get((a, b), '-')}</td>" for b in rooms) + "</tr>" for a in rooms)
    probs = "".join(f"<li>{html.escape(p)}</li>" for p in summ["problems"]) or "<li>none</li>"
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>House 01 blockout</title>
<style>:root{{--bg:#101014;--fg:#e6e6ea;--mut:#9a9aa6}}body{{background:var(--bg);color:var(--fg);font:14px system-ui,sans-serif;margin:0;padding:16px}}
h1{{font-size:20px}}table{{border-collapse:collapse;font-size:12px}}td,th{{border:1px solid #333;padding:3px 6px;text-align:right}}th{{text-align:left;color:var(--mut)}}
.legend span{{display:inline-block;margin-right:14px}}i{{display:inline-block;width:12px;height:12px;vertical-align:-2px;margin-right:4px}}</style></head><body>
<h1>{html.escape(layout.get('id', 'layout'))}: blockout (no art)</h1>
<p class="legend"><span><i style="background:#3a4a3a"></i>walkable floor</span><span><i style="background:#7a5a3a"></i>furniture / obstacle</span>
<span><i style="background:#e05a5a"></i>door</span><span><i style="background:#a050c0"></i>front door (locked)</span><span><i style="background:#40c0a0"></i>secret panel column / exit</span>
<span><i style="background:#e8c040"></i>item slot</span><span><i style="background:#5aa0e0"></i>guest spot</span></p>
<p>{summ['ordinary']} rooms + {summ['secret']} secret passage, {summ['halls']} hall screens. Supports: {layout.get('supports_suspects')} suspects.
Door-to-door step cost uses {summ['px_per_step']} px per step (assumption). Room to room: min {summ['room_to_room_steps_min']},
median {summ['room_to_room_steps_median']}, max {summ['room_to_room_steps_max']} steps (the original measured about 19 for one room to the next).</p>
<p>Layout problems: </p><ul>{probs}</ul>
{svg}
<h2>Steps between rooms (spawn to spawn, obstacles ignored)</h2><table><tr><th></th>{head}</tr>{trs}</table>
</body></html>
"""


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    src = Path(argv[0]) if argv else ROOT / "assets" / "maps" / "house-01.layout.json"
    out_dir = Path(argv[1]) if len(argv) > 1 else ROOT / "docs" / "case-design" / "house-01-blockout"
    layout = lay.load(src)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "index.html").write_text(render(layout), encoding="utf-8")
    print(out_dir / "index.html")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
