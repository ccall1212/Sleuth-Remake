import json
from pathlib import Path

from case_design.export_case_fixtures import DEFAULT_OUT, build


def test_committed_case_fixtures_are_current():
    assert json.loads(Path(DEFAULT_OUT).read_text(encoding="utf-8")) == build()


def test_fixtures_include_the_lens_fields():
    cases = build()["cases"]
    assert len(cases) == 900
    assert all({"item_kinds", "decoy_rooms", "weapon_certain"} <= set(c) for c in cases)
    assert all(c["weapon_certain"] == (c["difficulty"] == "easy") for c in cases)
