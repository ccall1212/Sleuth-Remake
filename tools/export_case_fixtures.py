"""Export independent Python expectations; never modifies the reference worktree.

Usage: python tools/export_case_fixtures.py --reference <design-worktree>/tools
The reference contains case_design/{generate,model,solve,rng}.py.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('tests/fixtures/case_design_v2.json'))
    args = parser.parse_args()
    sys.path.insert(0, str(args.reference.resolve()))
    from case_design.generate import generate
    from case_design.solve import candidates, problems
    from case_design.rng import Rng

    records = []
    seeds = list(range(50)) + [-1, 999999999, 2147483647]
    for n in range(4, 9):
        for difficulty in ('easy', 'normal', 'hard'):
            for seed in seeds:
                case = generate(seed, n, difficulty)
                assert not problems(case), (seed, n, difficulty)
                heard = {}
                partial = []
                for speaker, claim in enumerate(case.claims):
                    heard[speaker] = claim
                    partial.append(candidates(n, heard))
                records.append({'case': case.to_dict(), 'partial_candidates': partial,
                                'complete_candidates': candidates(n, heard, case.murder_room)})
    rng_records = []
    for seed in seeds[:8] + seeds[-3:]:
        for name in ('cast', 'alibis', 'staging', 'voice'):
            rng = Rng(2, seed, name)
            bounds = [1, 2, 3, 7, 10, 255, 65535, 1000000] * 3
            rng_records.append({'seed': seed, 'stream': name, 'bounds': bounds,
                                'expected': [rng.below(n) for n in bounds]})
    provenance = {f: hashlib.sha256((args.reference/'case_design'/f).read_bytes()).hexdigest()
                  for f in ('generate.py', 'model.py', 'solve.py', 'rng.py')}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'version': 2, 'reference_sha256': provenance,
                                      'rng': rng_records, 'records': records}, separators=(',', ':'))+'\n', encoding='utf-8')
    print(f'Exported {len(records)} cases and {len(rng_records)} RNG sequences to {args.output}')


if __name__ == '__main__':
    main()
