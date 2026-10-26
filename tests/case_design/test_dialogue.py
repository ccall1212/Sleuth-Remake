import copy
import re

import pytest

from case_design import dialogue, validate_dialogue
from case_design.dialogue import DialogueError, compose_reply, render
from case_design.rng import Rng

DATA = dialogue.load()
PERSONALITIES = dialogue.PERSONALITY_IDS
SLOTS = {
    "speaker": "Mrs. Hale",
    "room": "library",
    "partner": "Colonel Ward",
    "victim": "Lord Ashby",
    "other": "Miss Finch",
    "weapon": "candlestick",
    "chosen_room": "conservatory",
}


def _bad(mutate):
    data = copy.deepcopy(DATA)
    mutate(data)
    return validate_dialogue.problems(data)


# --- the shipped data -----------------------------------------------------------------------

def test_shipped_dialogue_is_valid():
    assert validate_dialogue.problems(DATA) == []
    assert validate_dialogue.main([]) == 0


def test_every_personality_has_every_line_type_with_six_variants():
    assert sorted(DATA["personalities"]) == sorted(PERSONALITIES)
    for pid in PERSONALITIES:
        for kind in dialogue.PERSONALITY_LINES:
            assert len(DATA["personalities"][pid][kind]) >= 6, (pid, kind)


def test_every_line_renders_with_the_full_slot_set():
    for lines in DATA["personalities"].values():
        for variants in lines.values():
            for template in variants:
                text = render(template, **SLOTS)
                assert "{" not in text and "}" not in text


def test_refusals_can_always_be_asked_again():
    cue = re.compile(r"again|later|back|another time|moment|shortly|not yet|not now|once more|try|soon|little while|ask me", re.I)
    for pid, lines in DATA["personalities"].items():
        for template in lines["refusal"]:
            assert cue.search(template), (pid, template)


def test_system_ranks_are_five_new_titles():
    ranks = DATA["system"]["ranks"]
    assert len(ranks) == 5 and len(set(ranks)) == 5
    assert not any("sleuth" in rank.lower() for rank in ranks)


# --- the validator catches mistakes ---------------------------------------------------------

def test_validator_flags_missing_line_type_and_too_few_variants():
    assert _bad(lambda d: d["personalities"]["warm"].pop("refusal"))
    assert _bad(lambda d: d["personalities"]["warm"]["opening"].pop())


def test_validator_flags_bad_slots_and_braces():
    assert _bad(lambda d: d["personalities"]["warm"]["opening"].__setitem__(0, "{speaker} frowns, {room}"))
    assert _bad(lambda d: d["personalities"]["warm"]["claim_solo"].__setitem__(0, "Alone all evening in the library."))
    assert _bad(lambda d: d["personalities"]["warm"]["repeat_lead"].__setitem__(0, "As I said, {oops"))
    assert _bad(lambda d: d["personalities"]["warm"]["confession_defiant"].__setitem__(
        0, '{speaker} says, "Fine, I did it. {victim} died in the {room}."'))  # no {weapon}


def test_validator_flags_banned_guilt_long_and_duplicate_lines():
    assert _bad(lambda d: d["personalities"]["calm"]["commentary_self"].__setitem__(0, "Mind your own business, please."))
    assert _bad(lambda d: d["personalities"]["calm"]["commentary_self"].__setitem__(0, "Nobody here is guilty of anything."))
    assert _bad(lambda d: d["personalities"]["calm"]["commentary_self"].__setitem__(0, "Word " * 60))
    assert _bad(lambda d: d["personalities"]["calm"]["repeat_close"].__setitem__(
        0, DATA["personalities"]["warm"]["repeat_close"][0]))
    assert _bad(lambda d: d["personalities"]["calm"]["commentary_self"].__setitem__(0, "She is quite tired."))


def test_validator_flags_system_mistakes():
    assert _bad(lambda d: d["system"]["ranks"].pop())
    assert _bad(lambda d: d["system"]["ranks"].__setitem__(0, "Master Sleuth"))
    assert _bad(lambda d: d["system"]["win"].__setitem__(0, "The case is closed, {culprit}."))
    assert _bad(lambda d: d["system"]["item_flavor_generic"].pop())
    assert _bad(lambda d: d["system"].pop("secret_panel"))


def test_validator_reference_folder_check(tmp_path):
    line = DATA["personalities"]["proud"]["commentary_self"][0]
    (tmp_path / "ref.txt").write_text(line.upper(), encoding="utf-8")
    assert validate_dialogue.problems(DATA, tmp_path)
    (tmp_path / "ref.txt").write_text("nothing in common with the dataset at all really", encoding="utf-8")
    assert validate_dialogue.problems(DATA, tmp_path) == []


# --- render ---------------------------------------------------------------------------------

def test_render_fills_slots_and_ignores_extras():
    assert render("{speaker} sits in the {room}.", speaker="Ann", room="den", other="x") == "Ann sits in the den."


def test_render_missing_slot_is_a_clear_error():
    with pytest.raises(DialogueError, match="room"):
        render("In the {room}.", speaker="Ann")


def test_render_stray_brace_is_an_error():
    for bad in ("Oh {no", "Oh no}", "Oh {} no", "Oh {two words} no"):
        with pytest.raises(DialogueError):
            render(bad, room="den")


# --- compose_reply --------------------------------------------------------------------------

def _reply(pid, kind, repeat, pick, **overrides):
    slots = {k: SLOTS[k] for k in ("speaker", "room", "partner", "victim", "other")}
    slots.update(overrides)
    return compose_reply(DATA, pid, kind, slots, repeat, pick)


@pytest.mark.parametrize("pid", PERSONALITIES)
@pytest.mark.parametrize("kind", ["solo", "pair"])
@pytest.mark.parametrize("repeat", [False, True])
def test_compose_reply_is_clean_and_names_room_and_partner(pid, kind, repeat):
    rng = Rng(1, 7, f"{pid}:{kind}:{repeat}")
    for _ in range(60):
        text = _reply(pid, kind, repeat, rng.below)
        assert "{" not in text and "}" not in text
        assert SLOTS["room"] in text
        if kind == "pair":
            assert SLOTS["partner"] in text
        assert text.count('"') == 2  # one quoted block
        if repeat:
            assert text.startswith('"') and text.endswith(('."', '!"', '?"', '..."'))
        else:
            assert SLOTS["speaker"] in text


def test_repeat_is_shorter_than_first_answer_on_average():
    firsts = repeats = 0
    for pid in PERSONALITIES:
        rng = Rng(1, 3, pid)
        for _ in range(40):
            firsts += len(_reply(pid, "solo", False, rng.below))
            repeats += len(_reply(pid, "solo", True, rng.below))
    assert repeats < firsts


def test_same_pick_gives_same_reply():
    def pick(n):
        return 2 % n

    for pid in PERSONALITIES:
        assert _reply(pid, "pair", False, pick) == _reply(pid, "pair", False, pick)
        assert _reply(pid, "solo", True, pick) == _reply(pid, "solo", True, pick)
    rng_a, rng_b = Rng(1, 9, "x"), Rng(1, 9, "x")
    assert _reply("warm", "solo", False, rng_a.below) == _reply("warm", "solo", False, rng_b.below)


def test_different_personalities_never_share_an_opening():
    for index in range(6):
        openings = {pid: DATA["personalities"][pid]["opening"][index] for pid in PERSONALITIES}
        assert len(set(openings.values())) == len(PERSONALITIES)
        replies = {pid: _reply(pid, "solo", False, lambda n, i=index: i % n) for pid in PERSONALITIES}
        assert len(set(replies.values())) == len(PERSONALITIES)


def test_commentary_needing_a_missing_slot_is_skipped():
    slots = {"speaker": "Ann", "room": "den"}
    for pid in PERSONALITIES:
        for index in range(6):
            text = compose_reply(DATA, pid, "solo", slots, False, lambda n, i=index: i % n)
            assert "{" not in text


def test_bad_claim_kind_and_bad_pick_are_errors():
    with pytest.raises(DialogueError):
        _reply("warm", "duo", False, lambda n: 0)
    with pytest.raises(DialogueError):
        _reply("warm", "solo", False, lambda n: n)
