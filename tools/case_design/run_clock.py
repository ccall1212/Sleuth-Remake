"""Run the step-clock simulator over generated cases and print a markdown table.

    python -m case_design.run_clock [--seeds 1000] [--out docs/case-design/simulation_clock_results.json]

Run it from the `tools/` folder (or anywhere, with `tools/` on the path).
"""
from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    __package__ = "case_design"

from case_design.generate import generate
from case_design.model import DIFFICULTIES, SUSPECT_RANGE
from case_design.simulate_clock import ClockParams, ClockResult, params_for, play_clock

DEFAULT_OUT = Path(__file__).resolve().parents[2] / "docs" / "case-design" / "simulation_clock_results.json"


def percentile(values: list[int], q: float) -> int:
    values = sorted(values)
    return values[max(0, math.ceil(q * len(values)) - 1)]


def summarize(results: list[ClockResult]) -> dict:
    count = len(results)
    steps = [r.steps for r in results]
    wins = [r for r in results if r.won]
    won_steps = [r.steps for r in wins]
    return {
        "games": count,
        "win_rate": len(wins) / count,
        "died": sum(r.died for r in results) / count,
        "timed_out": sum(r.timed_out for r in results) / count,
        "reached_suspicion": sum(r.steps >= r.onset for r in results) / count,
        "reached_stalking": sum(r.steps >= r.stalking for r in results) / count,
        "steps_mean_all": statistics.fmean(steps),
        "steps_median_won": statistics.median(won_steps) if won_steps else None,
        "steps_p90_won": percentile(won_steps, 0.9) if won_steps else None,
        "questions_mean": statistics.fmean(r.questions for r in results),
        "rooms_entered_mean": statistics.fmean(r.rooms_entered for r in results),
    }


def run(seeds: int, params: ClockParams = ClockParams()) -> dict[str, dict]:
    table: dict[str, dict] = {}
    for n in range(SUSPECT_RANGE[0], SUSPECT_RANGE[1] + 1):
        for difficulty in DIFFICULTIES:
            results = [play_clock(generate(seed, n, difficulty), params_for(difficulty, params)) for seed in range(seeds)]
            table[f"{n}/{difficulty}"] = summarize(results)
    return table


def markdown(table: dict[str, dict]) -> str:
    head = ("| suspects | difficulty | win | died | timed out | reached stalking | median steps (won) "
            "| p90 steps (won) | questions | rooms entered |\n"
            "|---|---|---|---|---|---|---|---|---|---|\n")
    rows = []
    for key, s in table.items():
        n, difficulty = key.split("/")
        med = "-" if s["steps_median_won"] is None else f"{s['steps_median_won']:.0f}"
        p90 = "-" if s["steps_p90_won"] is None else str(s["steps_p90_won"])
        rows.append(f"| {n} | {difficulty} | {s['win_rate']:.1%} | {s['died']:.1%} | {s['timed_out']:.1%} "
                    f"| {s['reached_stalking']:.1%} | {med} | {p90} | {s['questions_mean']:.1f} "
                    f"| {s['rooms_entered_mean']:.1f} |")
    return head + "\n".join(rows)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seeds", type=int, default=1000)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args(argv)
    params = ClockParams()
    table = run(args.seeds, params)
    print(markdown(table))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"_meta": {"seeds": args.seeds, "params": params.__dict__}, **table},
                                   indent=2) + "\n", encoding="utf-8")
    print(f"\nWrote {args.out}")


if __name__ == "__main__":
    main()
