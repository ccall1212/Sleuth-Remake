import pytest

from case_design import generate
from case_design.model import DIFFICULTIES
from case_design.simulate_clock import ClockParams, HARD_BIAS, params_for, play_clock

SEEDS = range(0, 120)


def test_same_case_gives_identical_result():
    case = generate(3, 6, "hard")
    assert play_clock(case) == play_clock(case)


@pytest.mark.parametrize("difficulty", DIFFICULTIES)
def test_without_danger_the_bot_never_dies_and_wins(difficulty):
    params = ClockParams(death_per_entry=0.0, culprit_question_death=0.0, max_steps=20000)
    for seed in SEEDS:
        r = play_clock(generate(seed, 6, difficulty), params)
        assert not r.died and not r.timed_out
        assert r.won


def test_deaths_happen_only_after_the_warning_phases():
    for difficulty in DIFFICULTIES:
        for seed in SEEDS:
            r = play_clock(generate(seed, 6, difficulty))
            assert r.stalking - r.onset in range(80, 116)
            assert 140 <= r.onset <= 200
            if r.died:
                assert r.death_step is not None
                assert r.death_step >= r.onset          # culprit questions can kill after suspicion
                assert not r.won


def test_outcomes_are_exclusive():
    for seed in SEEDS:
        r = play_clock(generate(seed, 7, "normal"))
        assert [r.won, r.died, r.timed_out].count(True) <= 1


def test_the_step_budget_is_enforced():
    r = play_clock(generate(0, 6, "hard"), ClockParams(max_steps=30, death_per_entry=0.0,
                                                       culprit_question_death=0.0))
    assert r.timed_out and r.steps <= 30


def test_more_danger_never_helps_on_average():
    safe = sum(play_clock(generate(s, 6, "normal"), ClockParams(death_per_entry=0.0,
                                                                 culprit_question_death=0.0)).won for s in SEEDS)
    risky = sum(play_clock(generate(s, 6, "normal")).won for s in SEEDS)
    assert risky <= safe


def test_pulling_guests_to_the_murder_room_helps_hard_on_average():
    base = sum(play_clock(generate(s, 6, "hard")).won for s in range(300))
    pulled = sum(play_clock(generate(s, 6, "hard"),
                            ClockParams(murder_room_pull=0.3, murder_room_stare=1.0)).won for s in range(300))
    assert pulled > base


def test_hard_gets_the_murder_room_bias_and_other_difficulties_do_not():
    assert params_for("easy") == ClockParams() and params_for("normal") == ClockParams()
    hard = params_for("hard")
    assert (hard.murder_room_pull, hard.murder_room_stare) == (0.3, 1.0) == tuple(HARD_BIAS.values())


def test_hard_with_the_bias_is_winnable_inside_the_clock():
    wins = sum(play_clock(generate(s, 6, "hard"), params_for("hard")).won for s in range(300))
    assert wins / 300 > 0.4
