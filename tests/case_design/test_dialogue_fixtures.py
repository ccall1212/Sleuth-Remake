import json
from pathlib import Path

from case_design.export_dialogue_fixtures import DEFAULT_OUT, build


def test_committed_fixtures_are_current():
    assert json.loads(Path(DEFAULT_OUT).read_text(encoding="utf-8")) == build()


def test_fixtures_cover_both_claim_kinds_and_every_personality_without_blank_text():
    data = build()
    asks = [a for c in data["cases"] for a in c["asks"]]
    assert {a["claim_kind"] for a in asks} == {"solo", "pair"}
    assert {a["personality"] for a in asks} == {"warm", "nervous", "proud", "guarded", "hot_tempered", "curious", "fragile", "calm"}
    assert all(a["first"].strip() and a["repeat"].strip() and "{" not in a["first"] + a["repeat"] for a in asks)
    assert all(a["first"] != a["repeat"] for a in asks)
