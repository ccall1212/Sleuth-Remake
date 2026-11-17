import copy
from pathlib import Path

import pytest

from case_design import layout as lay
from case_design.build_house_layout import build
from case_design.model import ROOM_COUNT

SHIPPED = Path(__file__).resolve().parents[2] / "assets" / "maps" / "house-01.layout.json"


def test_built_layout_is_consistent_and_matches_the_shipped_file():
    built = build()
    assert lay.problems(built) == []
    assert lay.load(SHIPPED) == built               # the JSON on disk is what the builder makes


def test_room_counts_match_the_generator_for_six_suspects():
    counts = lay.rooms_summary(build())
    assert counts["ordinary"] + counts["secret"] == ROOM_COUNT[6]
    assert counts["secret"] == 1


def test_every_screen_is_reachable_and_the_secret_passage_only_via_the_panel():
    layout = build()
    assert lay._reachable(layout) == {s["id"] for s in layout["screens"]}
    no_panel = copy.deepcopy(layout)
    no_panel["secret"]["entrance_room"] = "kitchen"          # panel elsewhere: passage still reachable via panel edge
    assert lay._reachable(no_panel) == {s["id"] for s in layout["screens"]}
    no_secret = copy.deepcopy(layout)
    del no_secret["secret"]
    assert "secret_passage" not in lay._reachable(no_secret)


def test_validator_catches_broken_layouts():
    layout = build()
    bad = copy.deepcopy(layout)
    next(s for s in bad["screens"] if s["id"] == "library")["portals"][0]["target"] = "nowhere"
    assert lay.problems(bad)
    bad = copy.deepcopy(layout)
    next(s for s in bad["screens"] if s["id"] == "hall_1")["portals"] = [
        p for p in next(s for s in bad["screens"] if s["id"] == "hall_1")["portals"] if p["target"] != "study"]
    assert any("no door back" in p or "unreachable" in p for p in lay.problems(bad))   # study's door has no partner
    bad = copy.deepcopy(layout)
    next(s for s in bad["screens"] if s["id"] == "kitchen")["spawn"] = [60, 170]       # inside the counter
    assert any("spawn" in p for p in lay.problems(bad))
    bad = copy.deepcopy(layout)
    bad["supports_suspects"] = [8]
    assert any("rooms but" in p for p in lay.problems(bad))


def test_step_costs_are_symmetric_enough_and_grow_with_distance():
    costs = lay.step_costs(build())
    assert costs[("library", "kitchen")] < costs[("library", "study")] < costs[("library", "sewing")]
    for (a, b), c in costs.items():
        assert abs(c - costs[(b, a)]) <= 2                       # door arrivals make it nearly symmetric
    slower = lay.step_costs(build(), px_per_step=12)
    assert all(slower[k] >= v for k, v in costs.items())


def test_halls_are_large_corridors_with_four_to_six_room_doors():
    layout = build()
    halls = [s for s in layout["screens"] if s["role"] == "hall"]
    assert len(halls) == 2
    for hall in halls:
        room_doors = [p for p in hall["portals"] if p["kind"] == "door" and p["target"].startswith(("hall_",)) is False]
        assert 4 <= len(room_doors) <= 6


def test_there_is_a_north_south_hall_with_doors_on_both_side_walls():
    layout = build()
    ns = [s for s in layout["screens"] if s.get("orientation") == "ns"]
    assert len(ns) == 1
    sides = {p["side"] for p in ns[0]["portals"] if p["kind"] == "door"}
    assert {"west", "east"} <= sides
    x, y, w, h = ns[0]["walk_regions"][0]
    assert h > w                                   # tall and narrow


def test_kind_label_lists_must_match_their_items():
    layout = build()
    lib = next(s for s in layout["screens"] if s["id"] == "library")
    lib["obstacle_kinds"] = ["bookshelf"] * len(lib["obstacles"])
    lib["guest_spot_kinds"] = ["stand"] * len(lib["guest_spots"])
    assert lay.problems(layout) == []
    lib["obstacle_kinds"].pop()
    assert any("obstacle_kinds" in p for p in lay.problems(layout))
    lib["obstacle_kinds"].append("bookshelf")
    lib["guest_spot_kinds"].append("seat")
    assert any("guest_spot_kinds" in p for p in lay.problems(layout))


def test_guest_spot_facing_must_be_a_compass_side_per_spot():
    layout = build()
    lib = next(s for s in layout["screens"] if s["id"] == "library")
    lib["guest_spot_facing"] = ["south"] * len(lib["guest_spots"])
    assert lay.problems(layout) == []
    lib["guest_spot_facing"][0] = "up"
    assert any("facing" in p for p in lay.problems(layout))
    lib["guest_spot_facing"][0] = "north"
    lib["guest_spot_facing"].pop()
    assert any("guest_spot_facing has" in p for p in lay.problems(layout))


def test_guest_spot_facing_accepts_any_and_several_sides():
    assert all(lay.valid_facing(v) for v in ("north", "any", ["north", "east"], ["east", "south", "west"]))
    assert not any(lay.valid_facing(v) for v in ("up", [], ["north"], ["east", "north"], ["north", "north"],
                                                  ["north", "east", "south", "west"], ["north", "up"]))
    layout = build()
    lib = next(s for s in layout["screens"] if s["id"] == "library")
    lib["guest_spot_facing"] = ["any"] * len(lib["guest_spots"])
    lib["guest_spot_facing"][0] = ["north", "east"]
    assert lay.problems(layout) == []
    lib["guest_spot_facing"][1] = ["east", "north"]          # wrong order
    assert any("facing" in p for p in lay.problems(layout))


HOUSE_02 = Path(__file__).resolve().parents[2] / "assets" / "maps" / "house-02.layout.json"


def test_house_02_is_consistent_and_fits_six_suspects():
    layout = lay.load(HOUSE_02)
    assert lay.problems(layout) == []
    counts = lay.rooms_summary(layout)
    assert counts == {"ordinary": 9, "halls": 1, "secret": 1}
    assert layout["supports_suspects"] == [6]
    assert counts["ordinary"] + counts["secret"] == ROOM_COUNT[6]


def test_house_02_labels_and_facings_are_complete_and_wall_aware():
    layout = lay.load(HOUSE_02)
    for s in layout["screens"]:
        assert len(s["obstacle_kinds"]) == len(s["obstacles"])
        assert len(s["guest_spot_kinds"]) == len(s["guest_spots"]) == len(s["guest_spot_facing"])
        for kind, facing in zip(s["guest_spot_kinds"], s["guest_spot_facing"]):
            if kind == "stand":
                assert facing == "any"                      # plain standing places may face any way
            assert lay.valid_facing(facing)
