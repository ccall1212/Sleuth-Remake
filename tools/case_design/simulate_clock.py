"""Step-clock simulator: the same thorough bot, but in the NEW game's time model.

Differences from `simulate.py` (which counts room changes and actions):
  * Time is counted in **steps**. A room-to-hall leg costs `leg_steps`, an action (question, examine,
    take, assemble, accuse) costs `action_steps`, a secret-panel probe costs 1.
  * Guests relocate at `guest_leave` per step (measured: about 1%), going to the hall with probability
    `hall_share` or to a random room (the hidden room weighted by `hidden_weight`). A staring flag is
    redrawn on relocation or at `activity_redraw` per step; a guest stares with probability `stare_share`
    (measured: 27% of sightings). The bot also questions guests it meets in the hall.
  * Danger clock (see docs/case-design/DANGER_CLOCK_SPEC.md; numbers measured in the original):
    suspicion at a step drawn from `onset_range`, stalking `gap_range` steps later. While stalking, every
    room entered kills the player with probability `death_per_entry` (halls are safe). After suspicion,
    questioning the culprit kills with probability `culprit_question_death` (proposed, one observed case).
  * The bot is naive about danger: it keeps its normal search. Win rates are therefore a floor for a
    player who rushes once warned.

Everything random uses `Rng(version, seed, "sim")`, so a case always replays to the same result.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from .model import Case
from .simulate import (ENTRY_ROOM, HALL, HIDDEN_AFTER_PASSES, PANEL_COLUMNS, QUESTION_TRIES, _Game,
                       _TimedOut, _threshold, Params)


class _Died(Exception):
    """The murderer got the player."""


@dataclass(frozen=True)
class ClockParams:
    leg_steps: int = 10
    action_steps: int = 2
    guest_leave: float = 0.01
    hall_share: float = 0.45
    stare_share: float = 0.27
    murder_room_stare: Optional[float] = None   # stare share for a guest standing in the murder room (default: same)
    activity_redraw: float = 0.004
    murder_room_pull: float = 0.0   # extra chance a relocating guest heads for the murder room
    refuse: float = 0.10                 # silent refusals: decided 10% (user, 2026-11-16); the original measured about 22%
    hidden_weight: float = 1.0
    onset_range: tuple[int, int] = (140, 200)
    gap_range: tuple[int, int] = (80, 115)
    death_per_entry: float = 0.10
    culprit_question_death: float = 0.10
    max_steps: int = 4000
    early_carry: bool = False              # the bot takes the weapon as soon as it knows it, then keeps working while carrying it
    weapon_clock_multiplier: float = 2.0   # the danger clock runs this much faster while the true weapon is in hand (user, 2026-11-16)


@dataclass
class ClockResult:
    won: bool
    died: bool
    timed_out: bool
    steps: int
    onset: int
    stalking: int
    death_step: Optional[int]
    questions: int
    refusals: int
    rooms_entered: int
    steps_after_weapon_found: Optional[int]
    items_examined: int = 0
    step_first_stain: Optional[int] = None     # first time the lens showed a stain
    step_wound_known: Optional[int] = None     # when the murder room (and with it the wound kind) was found
    carried_weapon: bool = False
    first_stained_room: Optional[int] = None   # the first stained item the lens showed (a sloppy player would take it)


# Hard difficulty bias (user decision 2026-10-26): relocating guests head for the murder room 30% of the
# time and a guest standing there always stares, so the staring-guest clue stays findable inside the clock.
HARD_BIAS = {"murder_room_pull": 0.3, "murder_room_stare": 1.0}


def params_for(difficulty: str, base: ClockParams = ClockParams()) -> ClockParams:
    """Clock parameters for a difficulty: Hard adds the murder-room bias."""
    if difficulty == "hard":
        return ClockParams(**{**base.__dict__, **HARD_BIAS})
    return base


class _ClockGame(_Game):
    def __init__(self, case: Case, cp: ClockParams) -> None:
        super().__init__(case, Params(refuse=cp.refuse, hidden_weight=cp.hidden_weight))
        self.c = cp
        self.steps = 0
        self.clock = 0.0                      # danger clock; runs faster while the true weapon is carried
        self.carrying_weapon = False
        self.stained_seen: dict[int, str] = {}
        self.step_first_stain: Optional[int] = None
        self.step_wound_known: Optional[int] = None
        self.first_stained_room: Optional[int] = None
        self.onset = self.rng.randint(*cp.onset_range)
        self.stalking = self.onset + self.rng.randint(*cp.gap_range)
        self.death_step: Optional[int] = None
        self.step_weapon: Optional[int] = None
        self.guest_pos = [HALL if self.rng.chance(cp.hall_share) else p for p in case.guest_start]
        self.staring = [self._stare_roll(g) for g in range(case.n)]

    # --- time ----------------------------------------------------------------------------------
    def _relocate(self) -> int:
        r = self.rng.below(1_000_000)
        if r < _threshold(self.c.hall_share):
            return HALL
        if self.c.murder_room_pull and self.rng.chance(self.c.murder_room_pull):
            return self.case.murder_room
        if self.rng.below(1_000_000) < self._hidden_limit:
            return self.hidden
        return self.rng.below(self.hidden)

    def _stare_roll(self, g: int) -> bool:
        share = self.c.stare_share
        if self.c.murder_room_stare is not None and self.guest_pos[g] == self.case.murder_room:
            share = self.c.murder_room_stare
        return self.rng.chance(share)

    def _tick(self, cost: Optional[int] = None) -> None:
        cost = self.c.action_steps if cost is None else cost
        if self.steps + cost > self.c.max_steps:
            raise _TimedOut
        self.turns += 1
        self.steps += cost
        self.clock += cost * (self.c.weapon_clock_multiplier if self.carrying_weapon else 1.0)
        p_move = _threshold(1 - (1 - self.c.guest_leave) ** cost)
        p_act = _threshold(1 - (1 - self.c.activity_redraw) ** cost)
        for g in range(self.case.n):
            x = self.rng.u64()
            moved = (x & 0xFFFFFFFF) % 1_000_000 < p_move
            if moved:
                self.guest_pos[g] = self._relocate()
            if moved or (x >> 32) % 1_000_000 < p_act:
                self.staring[g] = self._stare_roll(g)

    # --- danger --------------------------------------------------------------------------------
    def _enter(self, room: int) -> None:
        super()._enter(room)
        if self.clock >= self.stalking and self.rng.chance(self.c.death_per_entry):
            self.death_step = self.steps
            raise _Died

    def _question(self, guest: int, tries: dict[int, int]) -> None:
        if (self.clock >= self.onset and guest == self.case.culprit
                and self.rng.chance(self.c.culprit_question_death)):
            self.death_step = self.steps
            raise _Died
        super()._question(guest, tries)

    # --- movement ------------------------------------------------------------------------------
    def _hall_work(self) -> None:
        tries: dict[int, int] = {}
        for g in range(self.case.n):
            while (g not in self.heard and self.guest_pos[g] == HALL
                   and tries.get(g, 0) < QUESTION_TRIES and not self._done_searching()):
                self._question(g, tries)

    def _goto(self, target: int) -> None:
        if self.pos == target:
            return
        if target == self.hidden:
            self._goto(ENTRY_ROOM)
            if not self.panel_open:
                for _ in range(self.probes_needed):
                    self._tick(1)
                self.panel_open = True
            self._tick(1)
            self._enter(self.hidden)
            self.hidden_visited = True
            return
        if self.pos == self.hidden:
            self._tick(1)
            self._enter(ENTRY_ROOM)
        elif self.pos != HALL:
            self._tick(self.c.leg_steps)
            self.pos = HALL
            self._hall_work()
        if self.pos == target:
            return
        self._tick(self.c.leg_steps)
        self._enter(target)

    # --- the lens (user, 2026-11-16): a stain is not yet "the weapon" ----------------------------------------
    def _examine_item(self, room: int) -> None:
        case = self.case
        self._tick()
        self.items_examined.add(room)
        if case.weapon_certain or not case.item_kinds:        # Easy (and old cases): the lens names the weapon
            if room == case.weapon_room:
                self.weapon_room = room
                if self.step_first_stain is None:
                    self.step_first_stain = self.steps
        elif room in case.stained_rooms:                      # otherwise it shows only a stain; the item's kind is visible
            self.stained_seen[room] = case.item_kinds[room]
            if self.first_stained_room is None:
                self.first_stained_room = room
            if self.step_first_stain is None:
                self.step_first_stain = self.steps
        self._note_progress()

    def _note_progress(self) -> None:
        case = self.case
        if self.murder_room is None and all(r in self.cleared for r in self.ordinary):
            self.murder_room = self.hidden
        if self.murder_room is not None and self.step_wound_known is None:
            self.step_wound_known = self.steps               # the murder room's trace also tells the wound kind
        if self.weapon_room is None and self.has_glass:
            if case.weapon_certain or not case.item_kinds:
                if not [r for r in self.ordinary if r not in self.items_examined and r != self.glass_slot]:
                    self.weapon_room = self.hidden
            elif self.murder_room is not None:
                matches = [r for r, kind in self.stained_seen.items() if kind == case.wound]
                if matches:
                    self.weapon_room = matches[0]
                elif not [r for r in self.ordinary if r not in self.items_examined and r != self.glass_slot]:
                    self.weapon_room = self.hidden
        if self.murder_room is not None and self.turn_murder is None:
            self.turn_murder = self.turns
        if self.weapon_room is not None and self.turn_weapon is None:
            self.turn_weapon = self.turns
        if self.turn_unique is None and len(self._candidates()) == 1:
            self.turn_unique = self.turns
            self.unique_before_all = len(self.heard) < self.case.n
        if self.weapon_room is not None and self.step_weapon is None:
            self.step_weapon = self.steps

    def _take_weapon(self) -> None:
        self._goto(self.weapon_room)
        self._tick()                                          # drop the glass (free) and take the weapon
        self.carrying_weapon = True
        self.has_glass = False                                # the glass was dropped: no more lens work while carrying

    def _search(self) -> None:
        order: list[int] = []
        passes = 0
        while not self._done_searching():
            if not order:
                if passes > 0 and not self.hidden_visited and (
                        not self.has_glass or passes >= HIDDEN_AFTER_PASSES):
                    self._visit(self.hidden)
                    if self._done_searching():
                        return
                order = self.rng.shuffle(self.ordinary)
                passes += 1
            self._visit(order.pop(0))
            if (self.c.early_carry and not self.carrying_weapon and self.weapon_room is not None
                    and self.murder_room is not None and not self._done_searching()):
                self._take_weapon()                           # carry early, keep questioning: the stalker speeds up

    def _win_sequence(self) -> int:
        """Take the weapon if not already carried (the glass is dropped), assemble in the murder room, accuse."""
        accused = self._candidates()[0]
        if not self.carrying_weapon:
            self._take_weapon()
        self._goto(self.murder_room)
        self._tick()                                          # assemble
        self._tick()                                          # accuse
        return accused

    def play_clock(self) -> ClockResult:
        accused: Optional[int] = None
        timed_out = died = False
        try:
            self._search()
            accused = self._win_sequence()
        except _TimedOut:
            timed_out = True
        except _Died:
            died = True
        won = accused is not None and accused == self.case.culprit
        after = None if self.step_weapon is None else self.steps - self.step_weapon
        return ClockResult(won=won, died=died, timed_out=timed_out, steps=self.steps, onset=self.onset,
                           stalking=self.stalking, death_step=self.death_step, questions=self.questions,
                           refusals=self.refusals, rooms_entered=self.rooms_entered,
                           steps_after_weapon_found=after, items_examined=len(self.items_examined),
                           step_first_stain=self.step_first_stain, step_wound_known=self.step_wound_known,
                           carried_weapon=self.carrying_weapon, first_stained_room=self.first_stained_room)


def play_clock(case: Case, params: ClockParams = ClockParams()) -> ClockResult:
    return _ClockGame(case, params).play_clock()
