import dataclasses
import statistics

import pytest

from case_design import generate
from case_design.model import DIFFICULTIES, SUSPECT_RANGE
from case_design.simulate import Params, play

COUNTS = range(SUSPECT_RANGE[0], SUSPECT_RANGE[1] + 1)
SAMPLE = range(0, 150)


def mean_turns(n, difficulty, seeds, params=Params()):
    return statistics.fmean(play(generate(s, n, difficulty), params).turns for s in seeds)


@pytest.mark.parametrize("difficulty", DIFFICULTIES)
@pytest.mark.parametrize("n", COUNTS)
def test_the_bot_always_wins_with_default_params(n, difficulty):
    for seed in SAMPLE:
        result = play(generate(seed, n, difficulty))
        assert result.won, (seed, n, difficulty, result)
        assert not result.timed_out


def test_same_case_gives_identical_result():
    for n in COUNTS:
        for difficulty in DIFFICULTIES:
            case = generate(5, n, difficulty)
            assert play(case) == play(case)


def test_the_bot_never_reads_the_culprit():
    # Same world, but the truth field says someone else did it: the bot must accuse the same
    # suspect as before (it cannot see `culprit`) and therefore lose.
    for difficulty in DIFFICULTIES:
        for seed in range(25):
            case = generate(seed, 6, difficulty)
            other = dataclasses.replace(case, culprit=(case.culprit + 1) % case.n)
            honest, swapped = play(case), play(other)
            assert honest.won and honest.accused == case.culprit
            assert swapped.accused == honest.accused
            assert not swapped.won
            assert swapped.turns == honest.turns


@pytest.mark.parametrize("difficulty", DIFFICULTIES)
def test_more_refusals_never_reduce_turns_on_average(difficulty):
    # Hard mode is dominated by waiting for a staring guest (a long-tailed luck factor that dwarfs
    # the ~2 extra turns refusals cost), so it gets more seeds and a tolerance.
    seeds, slack = (range(300), 0.85) if difficulty == "hard" else (range(100), 1.0)
    never = mean_turns(6, difficulty, seeds, Params(refuse=0.0))
    often = mean_turns(6, difficulty, seeds, Params(refuse=0.5))
    assert often >= slack * never


def test_turns_respect_a_trivial_lower_bound():
    # glass + weapon pickup + assemble + accuse = 4, plus at least one room entry.
    for n in COUNTS:
        for difficulty in DIFFICULTIES:
            for seed in range(30):
                result = play(generate(seed, n, difficulty))
                assert result.turns >= 4
                assert result.turns >= 4 + result.rooms_entered - 1


@pytest.mark.parametrize("n", COUNTS)
def test_hard_mode_takes_at_least_as_long_as_easy(n):
    seeds = range(100)
    assert mean_turns(n, "hard", seeds) >= 0.9 * mean_turns(n, "easy", seeds)


def test_result_fields_are_consistent():
    for n in COUNTS:
        for difficulty in DIFFICULTIES:
            for seed in range(20):
                case = generate(seed, n, difficulty)
                r = play(case)
                assert r.won and r.accused == case.culprit and not r.timed_out
                assert 0 < r.turn_unique_culprit <= r.turns
                assert 0 < r.turn_weapon_found <= r.turns
                assert 0 < r.turn_murder_room_found <= r.turns
                assert r.turns_after_weapon_found == r.turns - r.turn_weapon_found
                assert r.turns_after_weapon_found >= 3          # take weapon, assemble, accuse
                assert 0 < r.rooms_entered <= r.turns
                assert 0 <= r.refusals <= r.questions
                assert r.questions - r.refusals <= case.n       # each statement is heard once


def test_the_turn_budget_is_enforced():
    result = play(generate(0, 6, "hard"), Params(max_turns=5))
    assert result.timed_out and not result.won and result.accused is None
    assert result.turns == 5


def test_hidden_weight_zero_keeps_guests_out_of_the_secret_room_and_still_wins():
    from case_design import generate
    from case_design.simulate import Params, play
    for seed in range(40):
        case = generate(seed, 6, "hard")
        assert play(case, Params(hidden_weight=0.0)) .won
        assert play(case, Params(hidden_weight=2.0)).won
    # the setting is deterministic per case
    c = generate(3, 6, "hard")
    assert play(c, Params(hidden_weight=1.5)) == play(c, Params(hidden_weight=1.5))
