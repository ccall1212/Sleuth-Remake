"""Run the turn simulator over many generated cases and print a markdown table.

    python -m case_design.run_sim [--seeds 1000] [--out docs/case-design/simulation_results.json]

Run it from the `tools/` folder (or anywhere, with `tools/` on the path).
"""
from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from pathlib import Path

if __package__ in (None, ""):                           # allow `python tools/case_design/run_sim.py`
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "case_design"

from case_design.generate import generate
from case_design.model import DIFFICULTIES, SUSPECT_RANGE
from case_design.simulate import Params, Result, play

DEFAULT_OUT = Path(__file__).resolve().parents[2] / "docs" / "case-design" / "simulation_results.json"


def percentile(sorted_values: list[int], q: float) -> int:
    """Nearest-rank percentile of an already sorted list."""
    return sorted_values[max(0, math.ceil(q * len(sorted_values)) - 1)]


def summarize(results: list[Result]) -> dict:
    turns = sorted(r.turns for r in results)
    after = [r.turns_after_weapon_found for r in results if r.turns_after_weapon_found is not None]
    count = len(results)
    return {
        "games": count,
        "win_rate": sum(r.won for r in results) / count,
        "timeouts": sum(r.timed_out for r in results),
        "turns_mean": statistics.fmean(turns),
        "turns_median": statistics.median(turns),
        "turns_p90": percentile(turns, 0.9),
        "turns_max": turns[-1],
        "questions_mean": statistics.fmean(r.questions for r in results),
        "refusals_mean": statistics.fmean(r.refusals for r in results),
        "turns_after_weapon_mean": statistics.fmean(after) if after else None,
        "unique_before_all_questioned": sum(r.unique_before_all_heard for r in results) / count,
    }


def run(seeds: int, params: Params = Params()) -> dict[str, dict]:
    table: dict[str, dict] = {}
    for n in range(SUSPECT_RANGE[0], SUSPECT_RANGE[1] + 1):
        for difficulty in DIFFICULTIES:
            results = [play(generate(seed, n, difficulty), params) for seed in range(seeds)]
            table[f"{n}/{difficulty}"] = summarize(results)
    return table


def markdown(table: dict[str, dict]) -> str:
    head = ("| suspects | difficulty | win | mean | median | p90 | max | questions | refusals "
            "| turns after weapon | unique before all questioned |\n"
            "|---|---|---|---|---|---|---|---|---|---|---|\n")
    rows = []
    for key, s in table.items():
        n, difficulty = key.split("/")
        rows.append(
            f"| {n} | {difficulty} | {s['win_rate']:.1%} | {s['turns_mean']:.1f} "
            f"| {s['turns_median']:.0f} | {s['turns_p90']} | {s['turns_max']} "
            f"| {s['questions_mean']:.1f} | {s['refusals_mean']:.1f} "
            f"| {s['turns_after_weapon_mean']:.1f} | {s['unique_before_all_questioned']:.1%} |")
    return head + "\n".join(rows)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seeds", type=int, default=1000, help="seeds 0..N-1 per cell")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="JSON results file")
    args = parser.parse_args(argv)
    table = run(args.seeds)
    print(markdown(table))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"_meta": {"seeds": args.seeds, "params": Params().__dict__}, **table},
                                   indent=2) + "\n", encoding="utf-8")
    print(f"\nWrote {args.out}")


if __name__ == "__main__":
    main()
