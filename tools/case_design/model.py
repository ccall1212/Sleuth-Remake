"""Typed data for one generated case.

Everything here is plain data. `generate.py` builds a `Case`; `solve.py` reasons only about what a
player can discover from one; `simulate.py` plays it. Observed original behavior is cited in
`Claude observations/ORIGINAL_GAMEPLAY_OBSERVATIONS.md`; decisions are in the brainstorm.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

VERSION = 1
DIFFICULTIES = ("easy", "normal", "hard")
PERSONALITIES = ("warm", "nervous", "proud", "guarded", "hot_tempered", "curious", "fragile", "calm")

# Characters the user has named so far (docs/CAST_NAME_REVIEW.md). The pool is about 10 in play.
DEFAULT_POOL = ("Char", "Justin", "Danny", "Gage", "Robbie", "Chris", "Kwinn", "Chloe", "Matt",
                "Camille", "Carolyn", "Isabelle", "Sarah Jo", "Jessica", "John")

# Placeholder room names. The last room of every house is the hidden room (secret passage).
ROOM_POOL = ("Library", "Kitchen", "Study", "Parlor", "Dining room", "Ballroom", "Conservatory",
             "Sewing room", "Bedroom", "Gallery", "Pantry", "Bathroom")
HIDDEN_ROOM_NAME = "Secret passage"

# House size by suspect count (rooms including the hidden one): about 0.55-0.7 guests per room.
ROOM_COUNT = {4: 7, 5: 8, 6: 10, 7: 11, 8: 12}
SUSPECT_RANGE = (4, 8)


@dataclass(frozen=True)
class Claim:
    """What a suspect says about the evening: a room, and who they were with (None = alone)."""
    room: int
    partner: Optional[int]


@dataclass(frozen=True)
class Case:
    version: int
    seed: int
    difficulty: str
    cast: tuple[str, ...]               # n suspects, then the victim (always last)
    personalities: tuple[str, ...]      # one per suspect
    rooms: tuple[str, ...]              # room names; the last is the hidden room
    claims: tuple[Claim, ...]           # one per suspect
    culprit: int                        # suspect index
    murder_room: int
    weapon_room: int                    # room whose single carryable item is the weapon
    glass_room: int                     # room whose item slot holds the magnifying glass
    trace_mode: str                     # "lens" (easy, normal) or "staring" (hard)
    guest_start: tuple[int, ...]        # starting room per suspect (they wander later)

    @property
    def n(self) -> int:
        return len(self.claims)

    @property
    def victim(self) -> str:
        return self.cast[-1]

    @property
    def suspects(self) -> tuple[str, ...]:
        return self.cast[:-1]

    @property
    def hidden_room(self) -> int:
        return len(self.rooms) - 1

    def to_dict(self) -> dict:
        return {
            "version": self.version, "seed": self.seed, "difficulty": self.difficulty,
            "cast": list(self.cast), "personalities": list(self.personalities),
            "rooms": list(self.rooms),
            "claims": [{"room": c.room, "partner": c.partner} for c in self.claims],
            "culprit": self.culprit, "murder_room": self.murder_room,
            "weapon_room": self.weapon_room, "glass_room": self.glass_room,
            "trace_mode": self.trace_mode, "guest_start": list(self.guest_start),
        }

    @staticmethod
    def from_dict(d: dict) -> "Case":
        return Case(
            version=d["version"], seed=d["seed"], difficulty=d["difficulty"],
            cast=tuple(d["cast"]), personalities=tuple(d["personalities"]), rooms=tuple(d["rooms"]),
            claims=tuple(Claim(c["room"], c["partner"]) for c in d["claims"]),
            culprit=d["culprit"], murder_room=d["murder_room"], weapon_room=d["weapon_room"],
            glass_room=d["glass_room"], trace_mode=d["trace_mode"], guest_start=tuple(d["guest_start"]),
        )
