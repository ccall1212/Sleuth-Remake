"""Export full generated cases as parity fixtures for the GDScript port: python tools/case_design/export_case_fixtures.py [out.json]

900 cases: seeds 0-59 x difficulty (easy, normal, hard) x suspect counts 4-8, every field of `Case.to_dict()`, including the lens
fields (item_kinds, decoy_rooms, weapon_certain). A port is correct when it reproduces every field exactly.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "case_design"

from case_design import generate
from case_design.model import DIFFICULTIES, SUSPECT_RANGE

DEFAULT_OUT = Path(__file__).resolve().parents[2] / "docs" / "case-design" / "case_fixtures.json"
SEEDS = range(0, 60)


def build() -> dict:
    cases = [generate(seed, n, difficulty).to_dict()
             for difficulty in DIFFICULTIES for n in range(SUSPECT_RANGE[0], SUSPECT_RANGE[1] + 1) for seed in SEEDS]
    return {"_meta": {"version": 2, "cases": len(cases), "note": "Case.to_dict() for seeds 0-59, difficulties and 4-8 suspects"}, "cases": cases}


def main(argv: list[str]) -> int:
    out = Path(argv[0]) if argv else DEFAULT_OUT
    out.write_text(json.dumps(build(), separators=(",", ":"), ensure_ascii=False) + "\n", encoding="utf-8")
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
