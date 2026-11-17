"""Typed data for one generated case.

Everything here is plain data. `generate.py` builds a `Case`; `solve.py` reasons only about what a
player can discover from one; `simulate.py` plays it. Observed original behavior is cited in
`Claude observations/ORIGINAL_GAMEPLAY_OBSERVATIONS.md`; decisions are in the brainstorm.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

VERSION = 2   # 2: the murder room is never the secret room
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

# Lens model (user, 2026-11-16): every item has a wound kind. The lens shows a "stain" on the murder weapon and on
# decoy items; the wound kind (revealed with the murder room) says which stained item is the weapon.
ITEM_KINDS = ("blunt", "sharp", "heavy")


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
    item_kinds: tuple[str, ...] = ()    # wound kind of each room's item (blunt, sharp, heavy); empty on old cases
    decoy_rooms: tuple[int, ...] = ()   # rooms whose item also shows a stain but is not the weapon
    no_item_rooms: tuple[int, ...] = ()  # rooms that can never hold an evidence item (the Front Entry); the murder room is independent
    weapon_certain: bool = True         # Easy: the lens names the weapon outright; otherwise it only shows "a stain"

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
    def wound(self) -> Optional[str]:
        """The kind of blow, learned with the murder room: the weapon's kind."""
        return self.item_kinds[self.weapon_room] if self.item_kinds else None

    @property
    def stained_rooms(self) -> tuple[int, ...]:
        """Rooms whose item shows a stain under the lens (the weapon and the decoys)."""
        return tuple(sorted({self.weapon_room, *self.decoy_rooms}))

    @property
    def hidden_room(self) -> int:
        return len(self.rooms) - 1

    def to_dict(self) -> dict:
        data = {
            "version": self.version, "seed": self.seed, "difficulty": self.difficulty,
            "cast": list(self.cast), "personalities": list(self.personalities),
            "rooms": list(self.rooms),
            "claims": [{"room": c.room, "partner": c.partner} for c in self.claims],
            "culprit": self.culprit, "murder_room": self.murder_room,
            "weapon_room": self.weapon_room, "glass_room": self.glass_room,
            "trace_mode": self.trace_mode, "guest_start": list(self.guest_start),
            "item_kinds": list(self.item_kinds), "decoy_rooms": list(self.decoy_rooms),
            "weapon_certain": self.weapon_certain,
        }
        if self.no_item_rooms:                       # only present when a house forbids item rooms (older fixtures stay valid)
            data["no_item_rooms"] = list(self.no_item_rooms)
        return data

    @staticmethod
    def from_dict(d: dict) -> "Case":
        return Case(
            version=d["version"], seed=d["seed"], difficulty=d["difficulty"],
            cast=tuple(d["cast"]), personalities=tuple(d["personalities"]), rooms=tuple(d["rooms"]),
            claims=tuple(Claim(c["room"], c["partner"]) for c in d["claims"]),
            culprit=d["culprit"], murder_room=d["murder_room"], weapon_room=d["weapon_room"],
            glass_room=d["glass_room"], trace_mode=d["trace_mode"], guest_start=tuple(d["guest_start"]),
            item_kinds=tuple(d.get("item_kinds", ())), decoy_rooms=tuple(d.get("decoy_rooms", ())),
            weapon_certain=d.get("weapon_certain", True), no_item_rooms=tuple(d.get("no_item_rooms", ())),
        )
