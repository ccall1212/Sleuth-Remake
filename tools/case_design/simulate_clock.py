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
    refuse: float = 0.22
    hidden_weight: float = 1.0
    onset_range: tuple[int, int] = (140, 200)
    gap_range: tuple[int, int] = (80, 115)
    death_per_entry: float = 0.10
    culprit_question_death: float = 0.10
    max_steps: int = 4000


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
        if self.steps >= self.stalking and self.rng.chance(self.c.death_per_entry):
            self.death_step = self.steps
            raise _Died

    def _question(self, guest: int, tries: dict[int, int]) -> None:
        if (self.steps >= self.onset and guest == self.case.culprit
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

    def _take_weapon_mark(self) -> None:
        if self.step_weapon is None and self.turn_weapon is not None:
            self.step_weapon = self.steps

    def _note_progress(self) -> None:
        super()._note_progress()
        self._take_weapon_mark()

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
                           steps_after_weapon_found=after)


def play_clock(case: Case, params: ClockParams = ClockParams()) -> ClockResult:
    return _ClockGame(case, params).play_clock()
