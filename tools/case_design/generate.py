"""Case generator.

Every random decision uses its own named stream (see rng.py), so changing one thing never moves
another. Independence is a design decision (brainstorm, 2026-10-25): culprit, murder room, weapon
room and glass room are chosen separately; they only share *rules*, never random state.

Alibi structure (observed in the original, observations sections 12 and 18):
  * the innocents form mutual partner pairs plus zero to two solo people;
  * the culprit claims to have been with an innocent who does **not** return the claim;
  * decoy (harder): the culprit names someone who is already half of a different pair, in a
    different room, so two people name the same partner.
"""
from __future__ import annotations

from typing import Optional, Sequence

from .model import (Case, Claim, DEFAULT_POOL, DIFFICULTIES, HIDDEN_ROOM_NAME, ITEM_KINDS, PERSONALITIES,
                    ROOM_COUNT, ROOM_POOL, SUSPECT_RANGE, VERSION)
from .rng import Rng

SETTINGS = {
    # decoy: chance the culprit uses the double-claim decoy
    # hidden_ok: may the glass or weapon be in the secret room? (the murder room never is)
    # trace: how the murder room is confirmed ("lens" = always a lens trace, "staring" = original)
    "easy": {"decoy": 0.0, "hidden_ok": False, "trace": "lens", "stained_decoys": 0, "certain": True},
    "normal": {"decoy": 0.5, "hidden_ok": False, "trace": "lens", "stained_decoys": 2, "certain": False},
    "hard": {"decoy": 1.0, "hidden_ok": True, "trace": "staring", "stained_decoys": 2, "certain": False},
}


def _stream(seed: int, name: str) -> Rng:
    return Rng(VERSION, seed, name)


def solo_count(innocents: int, rng: Rng) -> int:
    """Number of solo innocents. 0-2, parity fixed by the head count, at least one pair remains."""
    options = [s for s in (0, 1, 2) if (innocents - s) % 2 == 0 and (innocents - s) // 2 >= 1]
    if len(options) == 1 or rng.chance(0.6):
        return options[0]
    return options[1]


def generate(seed: int, suspects: int = 6, difficulty: str = "normal",
             pool: Sequence[str] = DEFAULT_POOL,
             personalities: Optional[Sequence[str]] = None,
             no_item_rooms: Sequence[int] = ()) -> Case:
    if difficulty not in DIFFICULTIES:
        raise ValueError(f"unknown difficulty {difficulty!r}")
    low, high = SUSPECT_RANGE
    if not low <= suspects <= high:
        raise ValueError(f"suspects must be {low}-{high}")
    if len(pool) < suspects + 1:
        raise ValueError("the character pool is too small")
    cfg = SETTINGS[difficulty]
    room_total = ROOM_COUNT[suspects]
    hidden = room_total - 1
    ordinary = list(range(hidden))                       # rooms people can claim or be found in
    anywhere = list(range(room_total)) if cfg["hidden_ok"] else ordinary

    # --- cast (its own stream: swapping the pool never changes the mystery) -------------------
    cast_rng = _stream(seed, "cast")
    cast = tuple(cast_rng.shuffle(pool)[: suspects + 1])   # last name is the victim

    # --- the four independent choices ---------------------------------------------------------
    culprit = _stream(seed, "culprit").below(suspects)
    murder_room = _stream(seed, "crime_room").choice(ordinary)   # never the secret room (user, 2026-10-26)
    item_rooms = [r for r in anywhere if r not in no_item_rooms]   # rooms that may hold an evidence item
    weapon_room = _stream(seed, "weapon").choice(item_rooms)
    glass_room = _stream(seed, "glass").choice([r for r in item_rooms if r != weapon_room])

    # --- the lens: item kinds, the wound, and stained decoys (own streams; never touch the four choices above) ---
    items = _stream(seed, "items")
    kinds = [items.choice(ITEM_KINDS) for _ in range(room_total)]
    wound = kinds[weapon_room]
    stains = _stream(seed, "stains")
    decoy_pool = [r for r in ordinary if r not in (weapon_room, glass_room) and r not in no_item_rooms]
    decoys = sorted(stains.shuffle(decoy_pool)[: cfg["stained_decoys"]])
    for r in decoys:                                      # a decoy must be of a different kind, or the clue could not tell it apart
        if kinds[r] == wound:
            kinds[r] = stains.choice([k for k in ITEM_KINDS if k != wound])

    # --- alibis --------------------------------------------------------------------------------
    rng = _stream(seed, "alibis")
    innocents = rng.shuffle([s for s in range(suspects) if s != culprit])
    solos = solo_count(len(innocents), rng)
    pair_count = (len(innocents) - solos) // 2
    claimable = rng.shuffle([r for r in ordinary if r != murder_room])
    claims: dict[int, Claim] = {}
    pair_rooms: dict[int, int] = {}          # member -> room, for pair members
    solo_rooms: dict[int, int] = {}
    cursor = 0
    for p in range(pair_count):
        a, b = innocents[2 * p], innocents[2 * p + 1]
        room = claimable[cursor]
        cursor += 1
        claims[a] = Claim(room, b)
        claims[b] = Claim(room, a)
        pair_rooms[a] = pair_rooms[b] = room
    for k in range(solos):
        s = innocents[2 * pair_count + k]
        room = claimable[cursor]
        cursor += 1
        claims[s] = Claim(room, None)
        solo_rooms[s] = room

    members = list(pair_rooms)
    use_decoy = rng.chance(cfg["decoy"])
    if use_decoy:
        target = rng.choice(members)
        others = [r for r in ordinary if r not in (murder_room, pair_rooms[target])]
        claimed_room = rng.choice(others)
    elif solo_rooms:
        target = rng.choice(list(solo_rooms))
        claimed_room = solo_rooms[target]
    else:
        target = rng.choice(members)
        claimed_room = pair_rooms[target]
    claims[culprit] = Claim(claimed_room, target)

    # --- staging and voice (cosmetic streams) --------------------------------------------------
    stage = _stream(seed, "staging")
    names = stage.shuffle(ROOM_POOL)[: hidden]
    rooms = tuple(names) + (HIDDEN_ROOM_NAME,)
    # Guests can be found anywhere, including the secret room (observed in games 3 and 14).
    guest_start = tuple(stage.choice(list(range(room_total))) for _ in range(suspects))
    if personalities is None:
        vr = _stream(seed, "voice")
        chosen: list[str] = []
        while len(chosen) < suspects:
            p = vr.choice(PERSONALITIES)
            if chosen.count(p) < 2:
                chosen.append(p)
        personalities = chosen

    return Case(
        version=VERSION, seed=seed, difficulty=difficulty, cast=cast,
        personalities=tuple(personalities), rooms=rooms,
        claims=tuple(claims[s] for s in range(suspects)), culprit=culprit,
        murder_room=murder_room, weapon_room=weapon_room, glass_room=glass_room,
        trace_mode=cfg["trace"], guest_start=guest_start,
        item_kinds=tuple(kinds), decoy_rooms=tuple(decoys), weapon_certain=cfg["certain"], no_item_rooms=tuple(no_item_rooms),
    )
