"""Load and render the case dialogue in assets/dialogue/.

`personalities.json` holds eight voices, each with the same set of line types.
`system.json` holds narrator text that belongs to no one in particular. The line
types, their allowed slots and the slots every variant must use are declared
here once; `validate_dialogue.py` and the tests import them.

Randomness is never drawn in this module. Callers pass `pick(n)`, a callable that
returns an integer in [0, n), so a case can replay exactly (see rng.py: `Rng.below`).
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Callable, Mapping

DEFAULT_DIR = Path(__file__).resolve().parents[2] / "assets" / "dialogue"

PERSONALITY_IDS = ("warm", "nervous", "proud", "guarded", "hot_tempered", "curious", "fragile", "calm")

# line type -> (allowed slots, slots every variant must contain)
_CONFESSION = (("speaker", "victim", "weapon", "room"), ("speaker", "victim", "weapon", "room"))
PERSONALITY_LINES: dict[str, tuple[tuple[str, ...], tuple[str, ...]]] = {
    "opening": (("speaker",), ("speaker",)),
    "claim_solo": (("room",), ("room",)),
    "claim_pair": (("partner", "room"), ("partner", "room")),
    "commentary_victim": (("victim",), ("victim",)),
    "commentary_suspect": (("other", "victim"), ("other",)),
    "commentary_self": ((), ()),
    "refusal": (("speaker",), ("speaker",)),
    "repeat_lead": ((), ()),
    "repeat_close": ((), ()),
    "confession_defiant": _CONFESSION,
    "confession_remorseful": _CONFESSION,
    "confession_triumphant": _CONFESSION,
    "confession_furious": _CONFESSION,
    "confession_resigned": _CONFESSION,
    "ambush_locked": (("speaker", "victim", "room", "weapon"), ("speaker", "victim", "room", "weapon")),
    "ambush_grab": (("speaker", "weapon"), ("speaker", "weapon")),
    "culprit_corrects_room": (
        ("speaker", "victim", "weapon", "room", "chosen_room"),
        ("speaker", "victim", "weapon", "room", "chosen_room"),
    ),
    "culprit_corrects_person": (("speaker", "victim", "weapon", "room"), ("speaker", "victim", "weapon", "room")),
    # Right person and room, wrong item in hand (user, 2026-11-16): `weapon` is the true weapon, `chosen_weapon` the item carried.
    "culprit_corrects_weapon": (
        ("speaker", "victim", "weapon", "room", "chosen_weapon"),
        ("speaker", "victim", "weapon", "chosen_weapon"),
    ),
}

# Line types where talking about guilt or confessing is expected.
GUILT_OK_TYPES = frozenset(
    {k for k in PERSONALITY_LINES if k.startswith(("confession_", "ambush_", "culprit_corrects_"))}
)

# system key -> (allowed slots, minimum variants; 0 means "a single string")
SYSTEM_LINES: dict[str, tuple[tuple[str, ...], int]] = {
    "guest_list_header": ((), 0),
    "assemble_ok": (("room",), 3),
    "assemble_need_item": ((), 3),
    "accuse_need_assembly": ((), 0),
    "accuse_wrong_both": (("culprit", "victim", "true_room", "chosen_room"), 3),
    "win": (("culprit", "victim", "moves", "rank"), 3),
    "ranks": ((), 5),
    "warning_suspicious": ((), 3),
    "warning_stalking": ((), 3),
    "floor_nothing": ((), 3),
    "floor_nothing_unwatched": ((), 3),
    "floor_blood": (("room",), 3),
    "weapon_blood": (("weapon",), 3),
    "item_flavor_generic": ((), 12),
    "lens_stain": (("item",), 6),
    "lens_clean": (("item",), 4),
    "wound_blunt": ((), 3),
    "wound_sharp": ((), 3),
    "wound_heavy": ((), 3),
    "hands_full": (("item",), 3),
    "take_item": (("item",), 3),
    "take_glass": ((), 3),
    "drop_item": (("item",), 3),
    "drop_glass": ((), 3),
    # Messages the game asks for that were still placeholders (user screenshots, 2026-11-16)
    "item_needs_glass": (("item",), 3),
    "inspect_glass": ((), 3),
    "no_item": ((), 3),
    "no_floor": ((), 3),
    "floor_needs_glass": ((), 3),
    "floor_inconclusive": ((), 3),
    "drop_blocked": ((), 3),
    "no_held_item": ((), 3),
    "investigation_ended": ((), 3),
    "case_closed": ((), 3),
    "case_ended": ((), 3),
    "truth_summary": (("culprit", "victim", "weapon", "true_room"), 3),
    "too_far_to_hear": (("speaker",), 3),
    "front_stoop": ((), 3),
    "secret_panel": ((), 3),
}

_SLOT = re.compile(r"\{(\w+)\}")


class DialogueError(ValueError):
    """A template could not be rendered or the data is malformed."""


def load(path: str | Path | None = None) -> dict:
    """Return {"personalities": {...}, "system": {...}} plus "styles" when styles.json exists.

    `path` is the dialogue directory; by default `assets/dialogue` next to this repo's tools/.
    """
    base = Path(path) if path is not None else DEFAULT_DIR
    out = {}
    for key in ("personalities", "system"):
        with open(base / f"{key}.json", encoding="utf-8") as handle:
            out[key] = json.load(handle)
    styles = base / "styles.json"
    if styles.exists():                       # optional: text colours (yellow, orange, red) for the game to apply
        with open(styles, encoding="utf-8") as handle:
            out["styles"] = json.load(handle)
    return out


def slots_in(template: str) -> list[str]:
    """Slot names used by a template, in order, repeats included."""
    return _SLOT.findall(template)


def render(template: str, **slots: object) -> str:
    """Fill `{slot}` markers. Raises DialogueError for a missing slot or a stray brace.

    Slots that the template does not use are ignored.
    """
    missing = sorted({name for name in slots_in(template) if name not in slots})
    if missing:
        raise DialogueError(f"missing slot(s) {missing} for template: {template!r}")
    if "{" in _SLOT.sub("", template) or "}" in _SLOT.sub("", template):
        raise DialogueError(f"stray brace in template: {template!r}")
    return _SLOT.sub(lambda m: str(slots[m.group(1)]), template)


def _after_lead(core: str, template: str) -> str:
    """Lowercase the first letter of `core` so it follows a lead-in ending in a comma."""
    if template.startswith("{") or re.match(r"I\b", template) or not core:
        return core
    return core[0].lower() + core[1:]


def compose_reply(
    data: Mapping,
    personality: str,
    claim_kind: str,
    slots: Mapping[str, object],
    repeat: bool,
    pick: Callable[[int], int],
) -> str:
    """Build one full answer to "where were you?".

    claim_kind is "solo" or "pair". First ask:  opening + "core commentary" (the quoted speech
    is one block: the claim, then one commentary sentence). Repeat:  "lead core close" with no
    opening. `slots` may carry speaker, room, partner, victim and other; commentary types that
    use a slot missing from `slots` are skipped. `pick(n)` must return an int in [0, n).
    """
    if claim_kind not in ("solo", "pair"):
        raise DialogueError(f"claim_kind must be 'solo' or 'pair', got {claim_kind!r}")
    lines = data["personalities"][personality]

    def choose(kind: str) -> str:
        options = lines[kind]
        index = pick(len(options))
        if not 0 <= index < len(options):
            raise DialogueError(f"pick returned {index} for {len(options)} options")
        return options[index]

    claim_template = choose(f"claim_{claim_kind}")
    core = render(claim_template, **slots)
    if repeat:
        lead = render(choose("repeat_lead"), **slots)
        close = render(choose("repeat_close"), **slots)
        return f'"{lead} {_after_lead(core, claim_template)} {close}"'

    opening = render(choose("opening"), **slots)
    kinds = [
        kind
        for kind in ("commentary_victim", "commentary_suspect", "commentary_self")
        if all(name in slots for name in PERSONALITY_LINES[kind][0])
    ]
    commentary = render(choose(kinds[pick(len(kinds))]), **slots)
    return f'{opening} "{core} {commentary}"'
