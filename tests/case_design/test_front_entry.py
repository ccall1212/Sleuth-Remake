"""The Front Entry can never hold an evidence item (user rule, 2026-11-17); the murder room stays independent of it."""
import json
from pathlib import Path

from case_design import generate
from case_design.export_case_fixtures import FRONT_ENTRY_OUT, FRONT_ENTRY_ROOMS, build_front_entry
from case_design.model import DIFFICULTIES
from case_design.solve import problems

SEEDS = range(600)


def _cases():
    return [generate(seed, 6, d, no_item_rooms=FRONT_ENTRY_ROOMS) for d in DIFFICULTIES for seed in SEEDS]


def test_no_item_lands_in_the_front_entry():
    for case in _cases():
        assert case.weapon_room not in FRONT_ENTRY_ROOMS
        assert case.glass_room not in FRONT_ENTRY_ROOMS
        assert not set(case.decoy_rooms) & set(FRONT_ENTRY_ROOMS)


def test_cases_stay_fair_and_solvable():
    for case in _cases():
        assert problems(case) == [], (case.seed, case.difficulty, problems(case))


def test_the_murder_room_may_still_be_the_front_entry():
    rooms = {c.murder_room for c in _cases()}
    assert set(FRONT_ENTRY_ROOMS) <= rooms


def test_the_restriction_does_not_move_the_unrestricted_choices():
    for seed in range(60):
        a, b = generate(seed, 6, "normal"), generate(seed, 6, "normal", no_item_rooms=FRONT_ENTRY_ROOMS)
        assert (a.culprit, a.murder_room, a.claims, a.cast) == (b.culprit, b.murder_room, b.claims, b.cast)


def test_front_entry_fixture_is_current():
    assert json.loads(Path(FRONT_ENTRY_OUT).read_text(encoding="utf-8")) == build_front_entry()
