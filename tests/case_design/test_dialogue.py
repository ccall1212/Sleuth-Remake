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
    "chosen_weapon": "paperweight",
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


def test_refusals_are_silent_narration_that_never_coach_the_player_or_sound_final():
    """User, 2026-11-16: refusals stay as a little friction but are silent narration (the game never shows the question, so nobody
    is quoted), with no hint to ask again, no theatrical clutter and nothing final."""
    coaching = re.compile(r"ask|again|come back|later|another time|try me|once more|in a (little )?while|give me a (moment|minute)", re.I)
    final = re.compile(r"(never|ever|forever)", re.I)
    for pid, lines in DATA["personalities"].items():
        refusals = lines["refusal"]
        assert len(refusals) == 6
        for template in refusals:
            assert '"' not in template, (pid, template)             # no quoted speech: we do not know the question
            assert not coaching.search(template), (pid, template)
            assert not final.search(template), (pid, template)
            assert len(template) <= 100, (pid, len(template), template)


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


def test_validator_flags_lines_too_long_once_slots_are_filled():
    # 230 raw characters pass the raw limit, but six slots at worst-case width push it past the expanded limit.
    filler = "x" * 170
    line = "{speaker} says: " + filler + " {victim} {room} {weapon} {speaker} {victim}."
    assert len(line) <= validate_dialogue.MAX_LENGTH
    errs = _bad(lambda d: d["personalities"]["warm"]["confession_defiant"].__setitem__(0, line))
    assert any("worst-case slots" in e for e in errs)


def test_warnings_state_the_murderers_mood_in_plain_words():
    system = DATA["system"]
    assert all("The murderer is suspicious of you" in line for line in system["warning_suspicious"])
    assert all("The murderer is stalking you" in line for line in system["warning_stalking"])
    assert _bad(lambda d: d["system"]["warning_suspicious"].__setitem__(0, "A cold feeling creeps over you."))


def test_text_colours_follow_the_users_scheme():
    styles = DATA["styles"]
    colors = styles["colors"]
    assert styles["system"]["warning_suspicious"] == "yellow"
    assert styles["system"]["warning_stalking"] == "orange"
    for key in ("floor_blood", "weapon_blood"):
        assert styles["system"][key] == "red"
    for key in ("ambush_locked", "ambush_grab"):
        assert styles["personality_lines"][key] == "red"
    assert styles["runtime_text"]["ambush_result"] == "red"
    assert {colors["yellow"], colors["orange"], colors["red"]} and len({colors["yellow"], colors["orange"], colors["red"]}) == 3


def test_validator_flags_bad_styles():
    assert _bad(lambda d: d["styles"]["colors"].__setitem__("red", "red"))
    assert _bad(lambda d: d["styles"]["system"].__setitem__("no_such_key", "red"))
    assert _bad(lambda d: d["styles"]["system"].__setitem__("floor_blood", "purple"))


def test_lens_and_carrying_lines_exist_and_the_stain_lines_never_name_the_weapon():
    system = DATA["system"]
    for key in ("lens_stain", "lens_clean", "wound_blunt", "wound_sharp", "wound_heavy", "hands_full", "take_item", "take_glass",
                "drop_item", "drop_glass", "assemble_need_item"):
        assert key in system and len(system[key]) >= 3
    assert len(system["lens_stain"]) >= 6 and len(system["lens_clean"]) >= 4
    assert not any(k in system for k in ("assemble_need_weapon_found", "assemble_need_weapon_carried", "get_refused_not_weapon", "carrying_limit"))
    # a stain looks the same on the weapon and on decoys, so it must not call the item the weapon or the murder
    assert not any(w in line.lower() for line in system["lens_stain"] for w in ("murder weapon", "weapon that", "killed", "murder"))
    # wound hints say the kind of blow and never point at an item
    assert all("{" not in line for key in ("wound_blunt", "wound_sharp", "wound_heavy") for line in system[key])


def test_lens_stain_is_orange_so_it_does_not_read_as_the_weapon_and_wound_hints_are_red():
    styles = DATA["styles"]["system"]
    assert styles["lens_stain"] == "orange"            # shown on the weapon and on decoys alike
    for key in ("wound_blunt", "wound_sharp", "wound_heavy"):
        assert styles[key] == "red"
    assert styles["weapon_blood"] == "red"             # Easy names the weapon outright, so red stays correct there


def test_every_personality_corrects_the_weapon_in_six_distinct_lines():
    p = DATA["personalities"]
    seen = set()
    for name, lines in p.items():
        variants = lines["culprit_corrects_weapon"]
        assert len(variants) == 6
        for line in variants:
            assert all(slot in line for slot in ("{speaker}", "{victim}", "{weapon}", "{chosen_weapon}"))
            assert line not in seen
            seen.add(line)
