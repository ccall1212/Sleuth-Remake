"""Small, version-stable random streams.

Python's `random` module does not promise identical output across releases for
helpers such as `shuffle` and `choice`. Cases must replay exactly from a seed, so
we derive each named stream from SHA-256 and use only integer arithmetic.
"""
from __future__ import annotations

import hashlib
from typing import Sequence, TypeVar

T = TypeVar("T")


class Rng:
    """A deterministic stream keyed by (version, seed, name)."""

    def __init__(self, version: int, seed: int, name: str) -> None:
        self._key = f"mm-case:{version}:{seed}:{name}".encode("utf-8")
        self._counter = 0

    def u64(self) -> int:
        block = hashlib.sha256(self._key + self._counter.to_bytes(8, "big")).digest()
        self._counter += 1
        return int.from_bytes(block[:8], "big")

    def below(self, n: int) -> int:
        """Uniform integer in [0, n). The modulo bias is below 2**-40 for n <= 2**24."""
        if n <= 0:
            raise ValueError("below() needs a positive bound")
        return self.u64() % n

    def randint(self, low: int, high: int) -> int:
        return low + self.below(high - low + 1)

    def chance(self, p: float) -> bool:
        if p <= 0:
            return False
        if p >= 1:
            return True
        return self.below(1_000_000) < int(p * 1_000_000)

    def choice(self, items: Sequence[T]) -> T:
        return items[self.below(len(items))]

    def shuffle(self, items: Sequence[T]) -> list[T]:
        """Return a shuffled copy (Fisher-Yates)."""
        result = list(items)
        for i in range(len(result) - 1, 0, -1):
            j = self.below(i + 1)
            result[i], result[j] = result[j], result[i]
        return result
