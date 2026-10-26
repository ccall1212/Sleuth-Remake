"""Work out each guest spot's kind and facing from the furniture around it, so nobody labels them by hand.

    python tools/case_design/auto_label.py in.json out.json

Needs `obstacle_kinds` (what each obstacle is). Rewrites `guest_spot_kinds` and `guest_spot_facing`; positions are
never moved. Rules (user, 2026-10-26):

* **Wall furniture is faced from the room's open side.** A bookshelf on the north wall gets a north-facing
  browse spot; east-wall books an east-facing one, and so on. The same goes for windows, fireplaces, pantries,
  wardrobes, dressers and sideboards.
* **Seats are sat on, facing away from the wall.** A spot within `SEAT_REACH` px of a stool, chair, armchair, sofa,
  bench or bed is a `seat`. A seat on the east wall faces west. A free-standing seat faces the nearest table,
  desk, coffee table or fireplace, or "any" if there is none.
* **Tables are faced from beside them** (the guest looks at the table).
* **Everything else is a plain standing spot with facing "any".**
Spots only describe the place; personalities pick among the allowed directions later.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Optional

SEAT_REACH = 16        # a spot this close to seating furniture is sitting on it
NEAR = 30              # how far from furniture a spot still counts as using it
WALL_TOL = 10          # furniture this close to a wall edge is "on" that wall
FOCAL_REACH = 100      # a free-standing seat only faces a table or fireplace this close

SEATING = {"stool", "chair", "armchair", "sofa", "bench", "bed"}
TABLES = {"table", "dining_table", "coffee_table", "console_table", "desk", "island", "counter"}
BROWSE = {"bookshelf", "shelf", "pantry", "wardrobe", "dresser", "sideboard"}
OPPOSITE = {"north": "south", "south": "north", "east": "west", "west": "east"}


def _bounds(screen: dict) -> tuple[float, float, float, float]:
    regions = screen["walk_regions"]
    x0 = min(r[0] for r in regions)
    y0 = min(r[1] for r in regions)
    x1 = max(r[0] + r[2] for r in regions)
    y1 = max(r[1] + r[3] for r in regions)
    return x0, y0, x1, y1


def wall_of(rect: list[int], screen: dict) -> Optional[str]:
    """The wall an obstacle stands against, or None when it is free-standing."""
    x0, y0, x1, y1 = _bounds(screen)
    x, y, w, h = rect
    gaps = {"north": y - y0, "south": y1 - (y + h), "west": x - x0, "east": x1 - (x + w)}
    touching = {side: abs(g) for side, g in gaps.items() if abs(g) <= WALL_TOL}
    if not touching:
        return None
    if len(touching) == 1:
        return next(iter(touching))
    horizontal = w >= h                       # in a corner, a wide piece belongs to the north/south wall
    candidates = [side for side in touching if (side in ("north", "south")) == horizontal] or list(touching)
    return min(candidates, key=lambda side: touching[side])
    horizontal = w >= h                       # a wide piece belongs to a north/south wall
    for side in tied:
        if (side in ("north", "south")) == horizontal:
            return side
    return tied[0]


def _distance(pt: list[int], rect: list[int]) -> float:
    x, y = pt
    rx, ry, w, h = rect
    dx = max(rx - x, 0, x - (rx + w))
    dy = max(ry - y, 0, y - (ry + h))
    return (dx * dx + dy * dy) ** 0.5


def _toward(frm: list[float], to: list[float]) -> str:
    dx, dy = to[0] - frm[0], to[1] - frm[1]
    if abs(dx) > abs(dy):
        return "east" if dx > 0 else "west"
    return "south" if dy > 0 else "north"


def _nearest_point(pt: list[float], rect: list[int]) -> list[float]:
    x, y = pt
    rx, ry, w, h = rect
    return [min(max(x, rx), rx + w), min(max(y, ry), ry + h)]


def _toward_rect(pt: list[float], rect: list[int]) -> str:
    """Direction from a point to the nearest edge of a rectangle (a long table is faced across its short side)."""
    return _toward(pt, _nearest_point(pt, rect))


def _centre(rect: list[int]) -> list[float]:
    return [rect[0] + rect[2] / 2, rect[1] + rect[3] / 2]


def _in_front(pt: list[int], rect: list[int], wall: str) -> bool:
    """True when the spot is on the open side of a wall piece (so it faces the wall to use it)."""
    x, y = pt
    rx, ry, w, h = rect
    if wall == "north":
        return y >= ry + h - 2 and rx - 24 <= x <= rx + w + 24
    if wall == "south":
        return y <= ry + 2 and rx - 24 <= x <= rx + w + 24
    if wall == "west":
        return x >= rx + w - 2 and ry - 24 <= y <= ry + h + 24
    return x <= rx + 2 and ry - 24 <= y <= ry + h + 24


def label_spot(screen: dict, pt: list[int]) -> tuple[str, object]:
    kinds = screen["obstacle_kinds"]
    best: Optional[tuple[float, int]] = None
    for i, rect in enumerate(screen["obstacles"]):
        d = _distance(pt, rect)
        if d <= NEAR and (best is None or d < best[0]):
            best = (d, i)
    if best is None:
        return "stand", "any"
    d, i = best
    rect, kind = screen["obstacles"][i], kinds[i]
    wall = wall_of(rect, screen)
    if kind in SEATING and d <= SEAT_REACH:
        if wall:
            return "seat", OPPOSITE[wall]
        focal = None
        for r, k in zip(screen["obstacles"], kinds):
            if k in TABLES or k == "fireplace":
                dist = _distance(_centre(rect), r) if r is not rect else 1e9
                if dist <= FOCAL_REACH and (focal is None or dist < focal[0]):
                    focal = (dist, r)
        if not focal:
            return "seat", "any"
        c = _centre(rect)
        look = _toward_rect(c, focal[1])
        dx, dy = _nearest_point(c, focal[1])[0] - c[0], _nearest_point(c, focal[1])[1] - c[1]
        if rect[2] >= 1.5 * rect[3]:            # a wide seat (sofa, bench) faces across its length
            return "seat", ("south" if dy > 0 else "north") if dy else "any"
        if rect[3] >= 1.5 * rect[2]:
            return "seat", ("east" if dx > 0 else "west") if dx else "any"
        return "seat", look
    if kind in BROWSE or kind in ("window", "fireplace", "stairs"):
        label = "browse" if kind in BROWSE else kind
    elif kind in TABLES:
        label = "table"
    else:
        return "stand", "any"
    if wall and _in_front(pt, rect, wall):
        return label, wall
    return label, _toward_rect(pt, rect)


def auto_label(layout: dict) -> dict:
    """Fill guest_spot_kinds and guest_spot_facing for every screen that has obstacle_kinds."""
    for screen in layout["screens"]:
        if "obstacle_kinds" not in screen or len(screen["obstacle_kinds"]) != len(screen["obstacles"]):
            continue
        labelled = [label_spot(screen, pt) for pt in screen.get("guest_spots", [])]
        screen["guest_spot_kinds"] = [k for k, _ in labelled]
        screen["guest_spot_facing"] = [f for _, f in labelled]
    return layout


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2
    layout = json.loads(Path(argv[0]).read_text(encoding="utf-8"))
    Path(argv[1]).write_text(json.dumps(auto_label(layout), indent=1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
