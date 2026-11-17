import random

import pytest

from case_design import Case, Claim, candidates, generate, problems, solve
from case_design.model import DEFAULT_POOL, DIFFICULTIES, PERSONALITIES, SUSPECT_RANGE

SEEDS = range(0, 400)
COUNTS = range(SUSPECT_RANGE[0], SUSPECT_RANGE[1] + 1)


@pytest.mark.parametrize("difficulty", DIFFICULTIES)
@pytest.mark.parametrize("n", COUNTS)
def test_every_case_is_fair_and_unique(n, difficulty):
    for seed in SEEDS:
        case = generate(seed, n, difficulty)
        assert problems(case) == [], (seed, n, difficulty, problems(case))
        assert solve(case) == [case.culprit]


def test_same_seed_gives_identical_case():
    for n in COUNTS:
        for difficulty in DIFFICULTIES:
            assert generate(77, n, difficulty) == generate(77, n, difficulty)
            assert generate(77, n, difficulty).to_dict() == Case.from_dict(
                generate(77, n, difficulty).to_dict()).to_dict()


def test_changing_the_cast_pool_never_changes_the_mystery():
    other = tuple(reversed(DEFAULT_POOL))
    for seed in SEEDS:
        a = generate(seed, 6, "normal")
        b = generate(seed, 6, "normal", pool=other)
        assert (a.culprit, a.murder_room, a.weapon_room, a.glass_room, a.claims) == (
            b.culprit, b.murder_room, b.weapon_room, b.glass_room, b.claims)


def test_changing_voices_never_changes_the_mystery():
    flat = ["calm"] * 6
    for seed in SEEDS:
        a = generate(seed, 6, "hard")
        b = generate(seed, 6, "hard", personalities=flat)
        assert (a.culprit, a.murder_room, a.weapon_room, a.glass_room, a.claims, a.guest_start) == (
            b.culprit, b.murder_room, b.weapon_room, b.glass_room, b.claims, b.guest_start)


def test_difficulty_does_not_move_the_four_independent_choices_between_easy_and_normal():
    # Easy and Normal share the same hidden-room rule, so only the decoy chance differs.
    for seed in SEEDS:
        a = generate(seed, 6, "easy")
        b = generate(seed, 6, "normal")
        assert (a.culprit, a.murder_room, a.weapon_room, a.glass_room) == (
            b.culprit, b.murder_room, b.weapon_room, b.glass_room)


def test_culprit_murder_room_weapon_and_glass_look_independent():
    # Chi-square-free sanity check: every pairing of values occurs, and the rare coincidence of
    # weapon room and murder room happens at roughly 1 / room_count.
    same = 0
    total = 4000
    culprit_by_room: dict[tuple[int, int], int] = {}
    for seed in range(total):
        c = generate(seed, 6, "normal")
        same += c.weapon_room == c.murder_room
        culprit_by_room[(c.culprit, c.murder_room)] = culprit_by_room.get((c.culprit, c.murder_room), 0) + 1
    rate = same / total
    assert 0.07 < rate < 0.14, rate                       # expected 1/9 for 9 ordinary rooms
    assert len(culprit_by_room) == 6 * 9                  # every culprit and murder-room pairing appears


def test_alibi_shapes_across_counts():
    for n in COUNTS:
        solos_seen = set()
        for seed in range(300):
            case = generate(seed, n, "normal")
            innocents = [s for s in range(n) if s != case.culprit]
            solos = [s for s in innocents if case.claims[s].partner is None]
            pairs = [s for s in innocents if case.claims[s].partner is not None]
            assert len(pairs) % 2 == 0 and len(pairs) >= 2
            assert len(solos) <= 2
            solos_seen.add(len(solos))
        assert solos_seen                                  # at least one shape observed


def test_decoy_means_two_people_name_the_same_partner():
    for seed in range(300):
        case = generate(seed, 6, "hard")
        target = case.claims[case.culprit].partner
        namers = [s for s in range(case.n) if case.claims[s].partner == target]
        assert len(namers) == 2                            # culprit and the target's real partner
        assert case.claims[case.culprit].room != case.claims[target].room


def test_easy_never_uses_a_decoy_when_a_solo_exists():
    for seed in range(300):
        case = generate(seed, 6, "easy")
        target = case.claims[case.culprit].partner
        assert case.claims[target].partner is None         # six suspects always have one solo here? no:
        # (guaranteed only when a solo exists; six suspects have 5 innocents, so exactly one solo)


def test_house_rules_by_difficulty():
    for seed in range(400):
        for difficulty in ("easy", "normal"):
            c = generate(seed, 7, difficulty)
            assert c.hidden_room not in (c.glass_room, c.weapon_room, c.murder_room)
            assert c.trace_mode == "lens"
        hard = generate(seed, 7, "hard")
        assert hard.trace_mode == "staring"
    assert any(generate(s, 7, "hard").glass_room == generate(s, 7, "hard").hidden_room for s in range(400))


def test_partial_knowledge_never_rules_out_the_culprit():
    rng = random.Random(1)
    for seed in range(300):
        for difficulty in DIFFICULTIES:
            case = generate(seed, rng.randint(4, 8), difficulty)
            heard = {s: case.claims[s] for s in range(case.n) if rng.random() < 0.6}
            room = case.murder_room if rng.random() < 0.5 else None
            assert case.culprit in candidates(case.n, heard, room)


def test_hearing_everyone_is_always_enough():
    for seed in range(300):
        case = generate(seed, 8, "hard")
        assert candidates(case.n, dict(enumerate(case.claims)), case.murder_room) == [case.culprit]


def test_problems_catches_broken_cases():
    good = generate(5, 6, "normal")
    # culprit's partner returns the claim
    t = good.claims[good.culprit].partner
    claims = list(good.claims)
    claims[t] = Claim(good.claims[good.culprit].room, good.culprit)
    bad = Case(**{**good.__dict__, "claims": tuple(claims)})
    assert problems(bad)
    # an innocent claims the murder room
    claims = list(good.claims)
    s = next(i for i in range(good.n) if i != good.culprit and good.claims[i].partner is None) \
        if any(i != good.culprit and good.claims[i].partner is None for i in range(good.n)) else None
    if s is not None:
        claims[s] = Claim(good.murder_room, None)
        assert problems(Case(**{**good.__dict__, "claims": tuple(claims)}))
    # glass and weapon in the same slot
    assert problems(Case(**{**good.__dict__, "glass_room": good.weapon_room}))


def test_rejects_bad_arguments():
    with pytest.raises(ValueError):
        generate(1, 3, "normal")
    with pytest.raises(ValueError):
        generate(1, 9, "normal")
    with pytest.raises(ValueError):
        generate(1, 6, "impossible")
    with pytest.raises(ValueError):
        generate(1, 6, "normal", pool=DEFAULT_POOL[:5])


def test_personalities_come_from_the_eight_and_repeat_at_most_twice():
    for seed in range(200):
        case = generate(seed, 8, "normal")
        assert set(case.personalities) <= set(PERSONALITIES)
        assert all(case.personalities.count(p) <= 2 for p in PERSONALITIES)


def test_guests_can_start_in_the_secret_room():
    # Observed in the original (games 3 and 14): guests are sometimes found in the secret corridor.
    seen = sum(1 for s in range(400) if generate(s, 6, "normal").hidden_room in generate(s, 6, "normal").guest_start)
    assert seen > 50
    for s in range(400):
        c = generate(s, 6, "normal")
        assert all(0 <= r < len(c.rooms) for r in c.guest_start)
        assert all(cl.room != c.hidden_room for cl in c.claims)   # statements still never name it


def test_murder_room_is_never_the_secret_room_on_any_difficulty():
    # User decision 2026-10-26: no murder in the secret passage (never seen in the original).
    for difficulty in DIFFICULTIES:
        for n in COUNTS:
            for seed in range(200):
                c = generate(seed, n, difficulty)
                assert c.murder_room != c.hidden_room
    bad = generate(5, 6, "hard")
    assert problems(Case(**{**bad.__dict__, "murder_room": bad.hidden_room}))


def test_lens_model_is_fair_on_every_case_and_easy_stays_certain():
    from case_design.solve import weapon_candidates
    for difficulty in DIFFICULTIES:
        for n in COUNTS:
            for seed in range(150):
                c = generate(seed, n, difficulty)
                assert len(c.item_kinds) == len(c.rooms)
                assert weapon_candidates(c.item_kinds, c.stained_rooms, c.wound) == [c.weapon_room]   # the wound singles out the weapon
                assert c.glass_room not in c.stained_rooms and c.hidden_room not in c.decoy_rooms
                if difficulty == "easy":
                    assert c.weapon_certain and c.decoy_rooms == ()
                else:
                    assert not c.weapon_certain and len(c.decoy_rooms) == 2
                    assert all(c.item_kinds[r] != c.wound for r in c.decoy_rooms)


def test_lens_streams_never_move_the_mystery_and_cases_round_trip():
    for seed in range(100):
        a = generate(seed, 6, "normal")
        assert Case.from_dict(a.to_dict()) == a
        easy = generate(seed, 6, "easy")
        assert (a.culprit, a.murder_room, a.weapon_room, a.glass_room) == (
            easy.culprit, easy.murder_room, easy.weapon_room, easy.glass_room)
        assert easy.item_kinds[easy.weapon_room] == a.item_kinds[a.weapon_room]               # the wound is the same on every difficulty


def test_problems_catches_a_decoy_that_hides_the_weapon():
    c = generate(5, 6, "normal")
    clash = Case(**{**c.__dict__, "item_kinds": tuple(c.wound if r == c.decoy_rooms[0] else k for r, k in enumerate(c.item_kinds))})
    assert any("wound's kind" in p for p in problems(clash))
