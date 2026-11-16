"""Export questioning-dialogue fixtures so another implementation (the GDScript game) can prove it renders identical text.

    python tools/case_design/export_dialogue_fixtures.py [out.json]

For each generated case, every suspect is "asked" twice: ask 0 (first question) and ask 1 (a repeat). The text comes from
`dialogue.compose_reply` with these fixed conventions, which the game must reproduce exactly:

* pick stream:   Rng(case.version, case.seed, "dialogue/<suspect index>/<ask number>").below   (SHA-256 streams, same as the case)
* slots:         speaker = cast[suspect]; room = rooms[claim.room]; partner = cast[claim.partner] when there is one;
                 victim = cast[-1]; other = cast[(suspect + 1) % suspects]
* claim kind:    "pair" when the claim names a partner, else "solo"
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "case_design"

from case_design import dialogue, generate
from case_design.rng import Rng

DEFAULT_OUT = Path(__file__).resolve().parents[2] / "docs" / "case-design" / "dialogue_fixtures.json"
SEEDS = range(0, 12)
CASES = ((6, "easy"), (6, "normal"), (6, "hard"))


def build() -> dict:
    data = dialogue.load()
    cases = []
    for seed in SEEDS:
        for suspects, difficulty in CASES:
            case = generate(seed, suspects, difficulty)
            asks = []
            for who in range(case.n):
                claim = case.claims[who]
                slots = {"speaker": case.cast[who], "room": case.rooms[claim.room], "victim": case.cast[-1],
                         "other": case.cast[(who + 1) % case.n]}
                if claim.partner is not None:
                    slots["partner"] = case.cast[claim.partner]
                kind = "pair" if claim.partner is not None else "solo"
                texts = []
                for ask in (0, 1):
                    pick = Rng(case.version, case.seed, f"dialogue/{who}/{ask}").below
                    texts.append(dialogue.compose_reply(data, case.personalities[who], kind, slots, ask > 0, pick))
                asks.append({"suspect": who, "personality": case.personalities[who], "claim_kind": kind,
                             "slots": slots, "first": texts[0], "repeat": texts[1]})
            cases.append({"seed": seed, "suspects": suspects, "difficulty": difficulty, "asks": asks})
    return {"_meta": {"version": 2, "pick_stream": "dialogue/<suspect>/<ask>", "cases": len(cases)}, "cases": cases}


def main(argv: list[str]) -> int:
    out = Path(argv[0]) if argv else DEFAULT_OUT
    out.write_text(json.dumps(build(), indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
