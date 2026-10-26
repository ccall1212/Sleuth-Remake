"""House layout blockout: load, validate and measure a map made of plain rectangles (no art).

The layout is a graph of **screens** (rooms and hall segments), the same idea as
`assets/mansion/fixed-mansion.json`: each screen is 480x360 logical pixels (the game doubles it to
960x720), has walkable rectangles, obstacle rectangles and portals (doors). Field names follow that file
(`walk_regions`, `obstacles`, `portals` with `at`/`target`/`arrival`/`facing`/`side`/`kind`, `spawn`) so one
loader can read both. Extra blockout fields: `role`, `item_slot`, `guest_spots`, `secret`, and optional parallel label lists
`obstacle_kinds` / `guest_spot_kinds` (one string per obstacle / guest spot, e.g. "bookshelf", "seat") and `guest_spot_facing` (per guest spot: "north", "east",
"south" or "west", "any", or a list of 2-3 sides such as ["north", "east"]: the way a guest standing there may face).

Backgrounds are painted *afterwards* to match this layout, so doors never have to be moved to fit art.

Step cost: walking between two points on one screen costs `ceil(distance / px_per_step)` steps (taxicab),
and taking a door costs 1 step. `px_per_step` is an assumption (default 24); the original needed about
19 steps per room-to-room transition, and the danger clock counts steps (see DANGER_CLOCK_SPEC.md).
"""
from __future__ import annotations

import heapq
import json
import math
from pathlib import Path
from typing import Iterable

from .model import ROOM_COUNT

SCREEN_W, SCREEN_H = 480, 360
ROLES = ("room", "hall", "secret")
KINDS = ("door", "front_door", "secret_exit")
SIDES = ("north", "east", "south", "west")
DEFAULT_PX_PER_STEP = 24
MIN_GUEST_SPOTS = 2


def valid_facing(value) -> bool:
    """A guest spot facing: one side, "any", or a list of 2-3 distinct sides in north/east/south/west order."""
    if value == "any" or value in SIDES:
        return True
    if isinstance(value, list) and 2 <= len(value) <= 3 and len(set(value)) == len(value):
        return all(v in SIDES for v in value) and value == sorted(value, key=SIDES.index)
    return False


def load(path: str | Path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _inside(rect: list[int], x: float, y: float, pad: float = 0) -> bool:
    rx, ry, rw, rh = rect
    return rx - pad <= x <= rx + rw + pad and ry - pad <= y <= ry + rh + pad


def _in_walk(screen: dict, x: float, y: float, pad: float = 0) -> bool:
    return any(_inside(r, x, y, pad) for r in screen["walk_regions"])


def _in_obstacle(screen: dict, x: float, y: float) -> bool:
    return any(rx < x < rx + rw and ry < y < ry + rh for rx, ry, rw, rh in screen.get("obstacles", []))


def _rect_ok(rect: Iterable[int]) -> bool:
    x, y, w, h = rect
    return w > 0 and h > 0 and x >= 0 and y >= 0 and x + w <= SCREEN_W and y + h <= SCREEN_H


def screens_by_id(layout: dict) -> dict[str, dict]:
    return {s["id"]: s for s in layout["screens"]}


def problems(layout: dict) -> list[str]:
    """Every fault found, empty when the blockout is consistent."""
    out: list[str] = []
    screens = layout["screens"]
    by_id = screens_by_id(layout)
    if len(by_id) != len(screens):
        out.append("duplicate screen ids")
    if layout.get("start") not in by_id:
        out.append("start screen missing")
    for s in screens:
        sid = s["id"]
        if s.get("role") not in ROLES:
            out.append(f"{sid}: bad role {s.get('role')!r}")
        if not s.get("walk_regions"):
            out.append(f"{sid}: no walk regions")
        for r in s.get("walk_regions", []) + s.get("obstacles", []):
            if not _rect_ok(r):
                out.append(f"{sid}: rectangle {r} outside the {SCREEN_W}x{SCREEN_H} screen")
        if "guest_spot_facing" in s:
            facing = s["guest_spot_facing"]
            if len(facing) != len(s.get("guest_spots", [])):
                out.append(f"{sid}: guest_spot_facing has {len(facing)} entries but guest_spots has {len(s.get('guest_spots', []))}")
            for f in facing:
                if not valid_facing(f):
                    out.append(f"{sid}: guest spot facing {f!r} is not a side, 'any' or a list of 2-3 distinct sides")
        for items, kinds in (("obstacles", "obstacle_kinds"), ("guest_spots", "guest_spot_kinds")):
            if kinds in s and len(s[kinds]) != len(s.get(items, [])):
                out.append(f"{sid}: {kinds} has {len(s[kinds])} entries but {items} has {len(s.get(items, []))}")
        spawn = s.get("spawn")
        if spawn is None or not _in_walk(s, *spawn) or _in_obstacle(s, *spawn):
            out.append(f"{sid}: spawn is not on open floor")
        for p in s.get("portals", []):
            tgt = by_id.get(p["target"])
            if tgt is None:
                out.append(f"{sid}: portal {p['id']} targets unknown screen {p['target']}")
                continue
            if p.get("kind", "door") not in KINDS:
                out.append(f"{sid}: portal {p['id']} has bad kind {p.get('kind')!r}")
            if not _in_walk(s, *p["at"], pad=14):
                out.append(f"{sid}: portal {p['id']} is not at the edge of walkable floor")
            if _in_obstacle(s, *p["at"]):
                out.append(f"{sid}: portal {p['id']} is inside an obstacle")
            if not _in_walk(tgt, *p["arrival"]) or _in_obstacle(tgt, *p["arrival"]):
                out.append(f"{sid}: portal {p['id']} arrives off the floor of {p['target']}")
            if p.get("kind") == "door" and not any(q["target"] == sid for q in tgt.get("portals", [])):
                out.append(f"{sid}: portal {p['id']} has no door back from {p['target']}")
        if s["role"] != "hall":
            spot = s.get("item_slot")
            if spot is None or not _in_walk(s, *spot) or _in_obstacle(s, *spot):
                out.append(f"{sid}: item slot is not on open floor")
        if s["role"] in ("room", "secret"):
            spots = s.get("guest_spots", [])
            if len(spots) < MIN_GUEST_SPOTS:
                out.append(f"{sid}: needs {MIN_GUEST_SPOTS} guest spots")
            for g in spots:
                if not _in_walk(s, *g) or _in_obstacle(s, *g):
                    out.append(f"{sid}: guest spot {g} is not on open floor")
    secret = layout.get("secret")
    if secret:
        for key in ("entrance_room", "exit_room", "screen"):
            if secret.get(key) not in by_id:
                out.append(f"secret: unknown {key}")
        if len(secret.get("panel_columns", [])) != 7:
            out.append("secret: exactly 7 panel columns expected")
    # Reachability from the start, counting the secret panel as an edge.
    if layout.get("start") in by_id:
        seen = _reachable(layout)
        for sid in by_id:
            if sid not in seen:
                out.append(f"{sid}: unreachable from the start")
    counts = rooms_summary(layout)
    for n in layout.get("supports_suspects", []):
        if n not in ROOM_COUNT:
            out.append(f"supports_suspects: {n} is outside 4-8")
        elif counts["ordinary"] + counts["secret"] != ROOM_COUNT[n]:
            out.append(f"layout has {counts['ordinary'] + counts['secret']} rooms but {n} suspects need {ROOM_COUNT[n]}")
    return out


def rooms_summary(layout: dict) -> dict:
    roles = [s["role"] for s in layout["screens"]]
    return {"ordinary": roles.count("room"), "halls": roles.count("hall"), "secret": roles.count("secret")}


def _reachable(layout: dict) -> set[str]:
    by_id = screens_by_id(layout)
    seen = {layout["start"]}
    stack = [layout["start"]]
    secret = layout.get("secret")
    while stack:
        cur = stack.pop()
        nxt = [p["target"] for p in by_id[cur].get("portals", [])]
        if secret and cur == secret["entrance_room"]:
            nxt.append(secret["screen"])
        for t in nxt:
            if t in by_id and t not in seen:
                seen.add(t)
                stack.append(t)
    return seen


def _walk_cost(a: list[int], b: list[int], px_per_step: float) -> int:
    return max(1, math.ceil((abs(a[0] - b[0]) + abs(a[1] - b[1])) / px_per_step))


def step_costs(layout: dict, px_per_step: float = DEFAULT_PX_PER_STEP) -> dict[tuple[str, str], int]:
    """Shortest step count from the spawn of each ordinary room to the spawn of every other room.

    Nodes are (screen, point). Walking inside a screen costs taxicab distance / px_per_step (a lower bound:
    obstacles are ignored), a door costs 1."""
    by_id = screens_by_id(layout)
    rooms = [s["id"] for s in layout["screens"] if s["role"] == "room"]
    secret = layout.get("secret")
    result: dict[tuple[str, str], int] = {}

    def doors(sid: str):
        s = by_id[sid]
        for p in s.get("portals", []):
            if p.get("kind") == "secret_exit":
                continue
            yield p["at"], p["target"], p["arrival"]

    for src in rooms:
        start = (src, tuple(by_id[src]["spawn"]))
        dist = {start: 0}
        heap = [(0, start)]
        while heap:
            d, node = heapq.heappop(heap)
            if d > dist.get(node, 1 << 30):
                continue
            sid, pos = node
            for at, target, arrival in doors(sid):
                nd = d + _walk_cost(list(pos), at, px_per_step) + 1
                nn = (target, tuple(arrival))
                if nd < dist.get(nn, 1 << 30):
                    dist[nn] = nd
                    heapq.heappush(heap, (nd, nn))
        for dst in rooms:
            if dst == src:
                continue
            spawn = tuple(by_id[dst]["spawn"])
            best = min((d + _walk_cost(list(pos), list(spawn), px_per_step)
                        for (sid, pos), d in dist.items() if sid == dst), default=None)
            if best is not None:
                result[(src, dst)] = best
    return result


def summary(layout: dict, px_per_step: float = DEFAULT_PX_PER_STEP) -> dict:
    costs = list(step_costs(layout, px_per_step).values())
    costs.sort()
    counts = rooms_summary(layout)
    return {
        "id": layout.get("id"),
        **counts,
        "room_to_room_steps_min": costs[0] if costs else None,
        "room_to_room_steps_median": costs[len(costs) // 2] if costs else None,
        "room_to_room_steps_max": costs[-1] if costs else None,
        "px_per_step": px_per_step,
        "problems": problems(layout),
    }
