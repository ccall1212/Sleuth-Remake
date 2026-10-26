"""Independent solver.

It sees only what a player can discover: suspects' statements, and (once found) the murder room.
It never reads `culprit`, `weapon_room` or any other truth field. Rules, from the original's
observed behavior and the design decisions:

  * Exactly one suspect (the culprit) lied; everyone else's statement is true.
  * A true statement naming a partner means the partner says the same room and names them back.
  * A true statement never places an innocent in the murder room (they would have seen the crime).
  * A true statement never names the culprit as the partner (the culprit was at the crime, so the
    claimed company would have been at the murder room, which innocents are never in).

`candidates()` returns every suspect who could be the liar under what is known so far.
A suspect whose statement has not been heard imposes no constraint yet.
"""
from __future__ import annotations

from typing import Mapping, Optional

from .model import Case, Claim


def candidates(n: int, claims: Mapping[int, Claim], murder_room: Optional[int] = None) -> list[int]:
    """Suspects who could be the single liar, given the statements heard so far."""
    result: list[int] = []
    for c in range(n):
        ok = True
        for s, claim in claims.items():
            if s == c:
                continue                                   # the liar's own words are not trusted
            if murder_room is not None and claim.room == murder_room:
                ok = False
                break
            p = claim.partner
            if p is None:
                continue
            if p == c:
                ok = False                                 # an honest person cannot name the liar
                break
            back = claims.get(p)
            if back is not None and (back.partner != s or back.room != claim.room):
                ok = False                                 # their partner did not confirm them
                break
        if ok:
            result.append(c)
    return result


def known_from_case(case: Case) -> tuple[dict[int, Claim], int]:
    """Everything a thorough player can learn: all statements and the murder room."""
    return {s: case.claims[s] for s in range(case.n)}, case.murder_room


def solve(case: Case) -> list[int]:
    claims, room = known_from_case(case)
    return candidates(case.n, claims, room)


def problems(case: Case) -> list[str]:
    """Check a generated case against every rule; an empty list means it is a fair case."""
    out: list[str] = []
    n = case.n
    if solve(case) != [case.culprit]:
        out.append(f"solver finds {solve(case)}, expected [{case.culprit}]")
    # Truth model: innocents are where they say; the culprit is at the murder room.
    for s in range(n):
        claim = case.claims[s]
        if s == case.culprit:
            if claim.partner is None:
                out.append("culprit claims to be alone")
            elif claim.partner == s:
                out.append("culprit names themselves")
            elif case.claims[claim.partner].partner == s:
                out.append("culprit's partner returns the claim")
            if claim.room == case.murder_room:
                out.append("culprit claims to be in the murder room")
            continue
        if claim.room == case.murder_room:
            out.append(f"innocent {s} claims the murder room")
        if claim.partner is not None:
            back = case.claims[claim.partner]
            if claim.partner == case.culprit:
                out.append(f"innocent {s} names the culprit")
            elif back.partner != s or back.room != claim.room:
                out.append(f"innocent {s}'s partner does not agree")
    # Independence and house rules.
    hidden = case.hidden_room
    if case.glass_room == case.weapon_room:
        out.append("glass and weapon share an item slot")
    hidden_ok = case.difficulty == "hard"
    for label, room in (("glass", case.glass_room), ("weapon", case.weapon_room),
                        ("murder room", case.murder_room)):
        if room == hidden and not hidden_ok:
            out.append(f"{label} is in the secret room on {case.difficulty}")
    if any(r == hidden for r in (c.room for c in case.claims)):
        out.append("a statement places someone in the secret room")
    if case.trace_mode != ("staring" if hidden_ok else "lens"):
        out.append("trace mode does not match difficulty")
    return out
