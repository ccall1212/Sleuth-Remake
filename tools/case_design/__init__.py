"""Reference case generator, solver and simulator for Mansion Mystery.

Pure Python, no Godot. Rules come from `Claude observations/ORIGINAL_GAMEPLAY_OBSERVATIONS.md` and
the decisions at the end of `docs/GAME_DESIGN_BRAINSTORM.md`. See docs/case-design/GENERATOR_SPEC.md.
"""
from .generate import generate
from .model import Case, Claim
from .solve import candidates, problems, solve

__all__ = ["Case", "Claim", "candidates", "generate", "problems", "solve"]
