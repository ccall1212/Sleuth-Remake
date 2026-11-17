"""Author the blockout for the new larger house, `assets/maps/house-01.layout.json`.

    python tools/case_design/build_house_layout.py

One floor with two **large halls** (user, 2026-10-26: corridors with 4-6 doors, like the original's long
corridors, and some north-south). The main hall runs east-west (front door at its west end) with five room doors;
the east hall runs north-south with four room doors (two on each side), joined to the main hall at its north end. 9 ordinary rooms + the secret passage = the 10 rooms a six-suspect case needs
(`model.ROOM_COUNT`). The secret panel is in the library and the passage exits in the sewing room (as observed
in the original). All numbers are placeholders to be tuned in the viewer before any art is painted.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "case_design"

from case_design.layout import problems

OUT = Path(__file__).resolve().parents[2] / "assets" / "maps" / "house-01.layout.json"

HALL_FLOOR = [16, 170, 448, 50]
ROOM_FLOOR = [24, 150, 432, 172]

# (id, name, hall, side, door x along the hall, obstacles, item slot, guest spots)
ROOMS = [
    ("library", "Library", "hall_1", "north", 90, [[40, 156, 120, 26], [300, 156, 110, 26], [200, 250, 90, 36]], [370, 250], [[110, 230], [330, 205], [90, 290]]),
    ("study", "Study", "hall_1", "north", 240, [[300, 156, 120, 30], [40, 156, 100, 26], [90, 250, 120, 40]], [400, 285], [[150, 215], [350, 225], [250, 295]]),
    ("ballroom", "Ballroom", "hall_1", "north", 390, [[28, 156, 90, 50], [360, 156, 90, 50]], [235, 215], [[120, 260], [340, 260], [235, 300]]),
    ("kitchen", "Kitchen", "hall_1", "south", 150, [[36, 160, 150, 30], [300, 160, 130, 30], [200, 260, 100, 40]], [420, 295], [[120, 230], [360, 215], [80, 295]]),
    ("parlor", "Parlor", "hall_1", "south", 330, [[40, 160, 160, 40], [330, 165, 90, 34], [190, 270, 110, 34]], [410, 295], [[140, 235], [370, 240], [80, 295]]),
    ("bedroom", "Bedroom", "hall_2", "west", 110, [[36, 156, 130, 56], [330, 156, 100, 30]], [405, 275], [[200, 250], [350, 235], [90, 290]]),
    ("bathroom", "Bathroom", "hall_2", "east", 110, [[40, 160, 150, 56], [330, 165, 80, 30]], [415, 290], [[140, 270], [330, 250], [250, 300]]),
    ("dining", "Dining room", "hall_2", "west", 250, [[150, 195, 180, 40], [36, 160, 90, 30]], [420, 290], [[110, 250], [370, 250], [250, 300]]),
    ("sewing", "Sewing room", "hall_2", "east", 250, [[40, 160, 100, 30], [300, 165, 110, 34], [190, 270, 100, 30]], [150, 295], [[250, 230], [380, 280], [80, 240]]),
]
HALLS = ["hall_1", "hall_2"]
HALL_NAMES = {"hall_1": "Main hall", "hall_2": "East hall (north-south)"}
NS_FLOOR = [190, 24, 100, 312]   # a vertical corridor: rooms open off its west and east walls
PANEL_COLUMNS = [60, 110, 160, 210, 260, 310, 360]      # x positions along the library's north wall


def _portal(pid, at, target, arrival, facing, side, kind="door"):
    return {"id": pid, "at": at, "target": target, "arrival": arrival, "facing": facing, "side": side, "kind": kind}


def build() -> dict:
    screens: dict[str, dict] = {}
    for h in HALLS:
        if h == "hall_2":
            screens[h] = {"id": h, "name": HALL_NAMES[h], "role": "hall", "orientation": "ns", "floor": 0,
                          "walk_regions": [NS_FLOOR], "obstacles": [], "portals": [], "spawn": [240, 180],
                          "guest_spots": [[240, 80], [240, 180], [240, 290]]}
        else:
            screens[h] = {"id": h, "name": HALL_NAMES[h], "role": "hall", "orientation": "ew", "floor": 0,
                          "walk_regions": [HALL_FLOOR], "obstacles": [], "portals": [], "spawn": [240, 195],
                          "guest_spots": [[90, 195], [240, 195], [390, 195]]}
    for rid, name, hall, side, dx, obstacles, item, spots in ROOMS:
        screens[rid] = {"id": rid, "name": name, "role": "room", "floor": 0, "walk_regions": [ROOM_FLOOR],
                        "obstacles": obstacles, "portals": [], "spawn": [240, 235 if side == "north" else 255],
                        "item_slot": item, "guest_spots": spots}
        if side in ("north", "south"):            # room off an east-west hall
            hall_door = [dx, 170 if side == "north" else 222]
            room_door = ([240, 326], [0, 1], "south") if side == "north" else ([240, 152], [0, -1], "north")
            room_arrive = [240, 300] if side == "north" else [240, 190]
            hall_arrive = [dx, 186] if side == "north" else [dx, 208]
            hall_facing = [0, -1] if side == "north" else [0, 1]
        else:                                     # room off a north-south hall: door on the room's side wall
            hall_door = [190, dx] if side == "west" else [290, dx]
            hall_facing = [-1, 0] if side == "west" else [1, 0]
            # a room west of the hall opens on its east wall and vice versa
            room_door = ([462, 240], [1, 0], "east") if side == "west" else ([18, 240], [-1, 0], "west")
            room_arrive = [440, 240] if side == "west" else [40, 240]
            hall_arrive = [206, dx] if side == "west" else [274, dx]
        screens[rid]["portals"].append(_portal(f"{rid}--{hall}", room_door[0], hall, hall_arrive, room_door[1], room_door[2]))
        screens[hall]["portals"].append(_portal(f"{hall}--{rid}", hall_door, rid, room_arrive, hall_facing, side))
    # The east-west hall ends at the north end of the north-south hall.
    screens["hall_1"]["portals"].append(_portal("hall_1--hall_2", [462, 195], "hall_2", [240, 50], [1, 0], "east"))
    screens["hall_2"]["portals"].append(_portal("hall_2--hall_1", [240, 26], "hall_1", [450, 195], [0, -1], "north"))
    # Front door at the west end of the main hall (locked, no outside route).
    screens["hall_1"]["portals"].append(_portal("hall_1--front_door", [18, 195], "hall_1", [30, 195], [-1, 0], "west", "front_door"))
    # Secret passage: panel in the library, exit into the sewing room (one-way).
    screens["secret_passage"] = {"id": "secret_passage", "name": "Secret passage", "role": "secret", "floor": 0,
                                 "walk_regions": [[16, 150, 448, 60]], "obstacles": [], "portals": [], "spawn": [40, 180],
                                 "item_slot": [420, 180], "guest_spots": [[120, 180], [240, 180], [360, 180]]}
    screens["secret_passage"]["portals"].append(
        _portal("secret_passage--sewing", [462, 180], "sewing", [60, 250], [1, 0], "east", "secret_exit"))
    ids = HALLS + [r[0] for r in ROOMS] + ["secret_passage"]
    return {
        "schema_version": 1,
        "id": "house-01",
        "blockout": True,
        "description": "Blockout for the larger house: plain rectangles, no art. Doors and walkable floor are authoritative; "
                       "backgrounds are painted afterwards to match.",
        "screen_size": [480, 360],
        "px_per_step": 24,
        "supports_suspects": [6],
        "start": "hall_1",
        "secret": {"screen": "secret_passage", "entrance_room": "library", "exit_room": "sewing",
                   "panel_wall": "north", "panel_columns": PANEL_COLUMNS},
        "screens": [screens[i] for i in ids],
    }


def main() -> int:
    layout = build()
    found = problems(layout)
    if found:
        print("\n".join(found))
        return 1
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(layout, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {OUT} ({len(layout['screens'])} screens)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
