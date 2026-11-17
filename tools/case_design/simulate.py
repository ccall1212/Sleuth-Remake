"""Turn-count simulator: a "thorough" bot plays one generated case and reports how long it takes.

A turn is one room change OR one action (question, examine item, examine floor, take an item,
assemble, accuse, one probe of the secret panel). Everything random uses `Rng(version, seed, "sim")`,
so a case always replays to the same result.

House model
  * Rooms 0..R-2 are ordinary; room R-1 (`case.hidden_room`) is the hidden room.
  * Every ordinary room opens onto a central hall. The player starts in the hall. Hall -> room costs
    1 turn, room -> other room costs 2 (room -> hall -> room).
  * The hidden room opens only from ENTRY_ROOM (room 0): each panel probe costs 1 turn (the panel
    sits at one of 7 columns, probed in random order, so 1..7 probes), then 1 turn to step in. Once
    found, the panel stays open: later entries cost 1 turn. Leaving back to room 0 costs 1 turn.

Guests
  * After EVERY player turn each guest jumps, with probability `guest_move`, to a random room. The
    hidden room is chosen with weight `hidden_weight` relative to 1 for every ordinary room (guests
    were seen in the secret corridor in the original). Each guest "stares at the floor" in a given
    turn with probability `stare`, rerolled every turn, wherever they are. The player sees who is
    staring before acting.
  * A question needs the guest in the same room. With probability `refuse` the guest refuses.

Bot ("thorough")
  * It only uses what a player can know: statements heard, the glass, item and floor examinations,
    and plain elimination. It accuses `solve.candidates(...)[0]` only when exactly one is left and
    never reads `case.culprit` while playing (only the final win check compares it).
  * Interpretation notes (the spec left these open):
      - A floor examination while a guest in the room is visibly staring is conclusive, so a
        "nothing unusual" result there clears the room. The bot never examines the floor in
        staring mode without a staring guest (that could never succeed, and the result would be
        ambiguous), so the "at most twice otherwise" retry of the brief is not used.
      - If every ordinary room has been cleared, the murder room must be the hidden room. A guest
        staring inside the hidden room reveals it directly; this is only the fallback. Likewise, if
        every ordinary item except the glass slot was examined and none was the weapon, the weapon
        is in the hidden room.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from .model import Case, Claim
from .rng import Rng
from .solve import candidates

HALL = -1              # location id of the central hall (a node, not a room)
ENTRY_ROOM = 0         # the only room with the secret panel
PANEL_COLUMNS = 7
QUESTION_TRIES = 3     # per guest, per room visit
HIDDEN_AFTER_PASSES = 3  # visit the hidden room anyway after this many full tours of the house


@dataclass(frozen=True)
class Params:
    guest_move: float = 0.35
    refuse: float = 0.25
    stare: float = 0.12
    hidden_weight: float = 1.0   # weight of the hidden room when a guest picks a room to move to
    max_turns: int = 3000


@dataclass
class Result:
    won: bool
    turns: int
    questions: int
    refusals: int
    rooms_entered: int
    turn_unique_culprit: Optional[int]
    turn_weapon_found: Optional[int]
    turn_murder_room_found: Optional[int]
    turns_after_weapon_found: Optional[int]
    timed_out: bool
    accused: Optional[int]
    unique_before_all_heard: bool = False   # culprit became unique before every suspect was questioned


class _TimedOut(Exception):
    """Raised inside the simulation when the turn budget runs out."""


def _threshold(p: float) -> int:
    """Roll limit for a 1-in-a-million roll; matches `Rng.chance` (below 1e6 < int(p * 1e6))."""
    return int(p * 1_000_000) if 0 < p < 1 else (1_000_000 if p >= 1 else 0)


class _Game:
    def __init__(self, case: Case, params: Params) -> None:
        self.case = case
        self.p = params
        self.rng = Rng(case.version, case.seed, "sim")
        self.hidden = case.hidden_room
        self.ordinary = list(range(self.hidden))
        self._move_limit = _threshold(params.guest_move)
        self._stare_limit = _threshold(params.stare)
        w = max(0.0, params.hidden_weight)
        self._hidden_limit = _threshold(w / (len(self.ordinary) + w))   # chance a mover picks the hidden room

        # World state.
        self.pos = HALL
        self.guest_pos = list(case.guest_start)
        self.staring = [False] * case.n
        self._roll_staring()
        panel = self.rng.below(PANEL_COLUMNS)
        order = self.rng.shuffle(range(PANEL_COLUMNS))
        self.probes_needed = order.index(panel) + 1     # probes until the right column
        self.panel_open = False

        # Bookkeeping.
        self.turns = 0
        self.questions = 0
        self.refusals = 0
        self.rooms_entered = 0

        # What the bot knows.
        self.heard: dict[int, Claim] = {}
        self.has_glass = False
        self.glass_slot: Optional[int] = None           # room the glass was taken from
        self.items_examined: set[int] = set()
        self.cleared: set[int] = set()                  # rooms whose floor is known clean
        self.murder_room: Optional[int] = None
        self.weapon_room: Optional[int] = None
        self.hidden_visited = False

        # Milestones for the result.
        self.turn_unique: Optional[int] = None
        self.unique_before_all = False
        self.turn_weapon: Optional[int] = None
        self.turn_murder: Optional[int] = None

    # --- time and guests ---------------------------------------------------------------------
    def _roll_staring(self) -> None:
        self.staring = [self.rng.below(1_000_000) < self._stare_limit for _ in range(self.case.n)]

    def _tick(self) -> None:
        """One player turn has passed: guests may wander, and the staring flags are rerolled."""
        if self.turns >= self.p.max_turns:
            raise _TimedOut
        self.turns += 1
        for g in range(self.case.n):
            x = self.rng.u64()                          # one hash feeds both rolls (speed)
            if (x & 0xFFFFFFFF) % 1_000_000 < self._move_limit:
                if self.rng.below(1_000_000) < self._hidden_limit:
                    self.guest_pos[g] = self.hidden
                else:
                    self.guest_pos[g] = self.rng.below(self.hidden)
            self.staring[g] = (x >> 32) % 1_000_000 < self._stare_limit

    # --- movement ----------------------------------------------------------------------------
    def _enter(self, room: int) -> None:
        self.pos = room
        self.rooms_entered += 1

    def _goto(self, target: int) -> None:
        """Walk (and probe, if needed) to `target`, paying the turns."""
        if self.pos == target:
            return
        if target == self.hidden:
            self._goto(ENTRY_ROOM)
            if not self.panel_open:
                for _ in range(self.probes_needed):    # one probe per turn, random column order
                    self._tick()
                self.panel_open = True
            self._tick()
            self._enter(self.hidden)
            self.hidden_visited = True
            return
        if self.pos == self.hidden:
            self._tick()                                # back out into room 0
            self._enter(ENTRY_ROOM)
        elif self.pos != HALL:
            self._tick()                                # room -> hall
            self.pos = HALL
        if self.pos == target:
            return
        self._tick()                                    # hall -> room
        self._enter(target)

    # --- knowledge ---------------------------------------------------------------------------
    def _note_progress(self) -> None:
        """Record milestones and run the elimination rules after any new information."""
        if self.murder_room is None and all(r in self.cleared for r in self.ordinary):
            self.murder_room = self.hidden              # nowhere else is left
        if self.weapon_room is None and self.has_glass:
            unchecked = [r for r in self.ordinary
                         if r not in self.items_examined and r != self.glass_slot]
            if not unchecked:
                self.weapon_room = self.hidden
        if self.murder_room is not None and self.turn_murder is None:
            self.turn_murder = self.turns
        if self.weapon_room is not None and self.turn_weapon is None:
            self.turn_weapon = self.turns
        if self.turn_unique is None and len(self._candidates()) == 1:
            self.turn_unique = self.turns
            self.unique_before_all = len(self.heard) < self.case.n

    def _candidates(self) -> list[int]:
        return candidates(self.case.n, self.heard, self.murder_room)

    def _done_searching(self) -> bool:
        return (self.murder_room is not None and self.weapon_room is not None
                and len(self._candidates()) == 1)

    # --- single actions (each costs one turn) ------------------------------------------------
    def _take_glass(self, room: int) -> None:
        self._tick()
        self.has_glass = True
        self.glass_slot = room
        self._note_progress()

    def _examine_item(self, room: int) -> None:
        self._tick()
        self.items_examined.add(room)
        if room == self.case.weapon_room:               # the examination reveals the weapon
            self.weapon_room = room
        self._note_progress()

    def _examine_floor(self, room: int) -> None:
        """Only called when the answer is conclusive (lens, or a staring guest is in the room)."""
        if self.case.trace_mode == "lens":
            revealed = room == self.case.murder_room
        else:
            revealed = room == self.case.murder_room and any(
                self.guest_pos[g] == room and self.staring[g] for g in range(self.case.n))
        self._tick()
        if revealed:
            self.murder_room = room
        else:
            self.cleared.add(room)
        self._note_progress()

    def _question(self, guest: int, tries: dict[int, int]) -> None:
        tries[guest] = tries.get(guest, 0) + 1
        self.questions += 1
        refused = self.rng.chance(self.p.refuse)
        if refused:
            self.refusals += 1
        self._tick()
        if not refused:
            self.heard[guest] = self.case.claims[guest]
            self._note_progress()

    # --- one visit to a room -----------------------------------------------------------------
    def _next_action(self, room: int, tries: dict[int, int]):
        """The next useful thing to do in this room, as a callable, or None when finished."""
        if room == self.case.glass_room and not self.has_glass:      # the glass is in plain sight
            return lambda: self._take_glass(room)
        if self.has_glass:
            if room not in self.items_examined and room != self.glass_slot:
                return lambda: self._examine_item(room)
            if self.murder_room is None and room not in self.cleared:
                if self.case.trace_mode == "lens":
                    return lambda: self._examine_floor(room)
                if any(self.guest_pos[g] == room and self.staring[g] for g in range(self.case.n)):
                    return lambda: self._examine_floor(room)
        for g in range(self.case.n):
            if (g not in self.heard and self.guest_pos[g] == room
                    and tries.get(g, 0) < QUESTION_TRIES):
                return lambda g=g: self._question(g, tries)
        return None

    def _work_room(self, room: int) -> None:
        tries: dict[int, int] = {}
        while not self._done_searching():
            action = self._next_action(room, tries)
            if action is None:
                return
            action()

    def _visit(self, room: int) -> None:
        self._goto(room)
        self._work_room(room)

    # --- the whole game ----------------------------------------------------------------------
    def _search(self) -> None:
        order: list[int] = []
        passes = 0
        while not self._done_searching():
            if not order:
                if passes > 0 and not self.hidden_visited and (
                        not self.has_glass or passes >= HIDDEN_AFTER_PASSES):
                    self._visit(self.hidden)           # the glass (or some clue) must be in there
                    if self._done_searching():
                        return
                order = self.rng.shuffle(self.ordinary)
                passes += 1
            self._visit(order.pop(0))

    def _win_sequence(self) -> int:
        """Take the weapon, assemble in the murder room, accuse. Returns the accused suspect."""
        accused = self._candidates()[0]
        self._goto(self.weapon_room)
        self._tick()                                   # take the weapon
        self._goto(self.murder_room)
        self._tick()                                   # assemble
        self._tick()                                   # accuse
        return accused

    def play(self) -> Result:
        accused: Optional[int] = None
        timed_out = False
        try:
            self._search()
            accused = self._win_sequence()
        except _TimedOut:
            timed_out = True
        won = accused is not None and accused == self.case.culprit   # the only use of culprit
        after = None if self.turn_weapon is None else self.turns - self.turn_weapon
        return Result(
            won=won, turns=self.turns, questions=self.questions, refusals=self.refusals,
            rooms_entered=self.rooms_entered, turn_unique_culprit=self.turn_unique,
            turn_weapon_found=self.turn_weapon, turn_murder_room_found=self.turn_murder,
            turns_after_weapon_found=after, timed_out=timed_out, accused=accused,
            unique_before_all_heard=self.unique_before_all,
        )


def play(case: Case, params: Params = Params()) -> Result:
    """Play one case with the thorough bot and report the turns it needed."""
    return _Game(case, params).play()
