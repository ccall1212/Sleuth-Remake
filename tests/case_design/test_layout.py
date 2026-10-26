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
    next(s for s in bad["screens"] if s["id"] == "hall_2")["portals"] = [
        p for p in next(s for s in bad["screens"] if s["id"] == "hall_2")["portals"] if p["target"] != "study"]
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
