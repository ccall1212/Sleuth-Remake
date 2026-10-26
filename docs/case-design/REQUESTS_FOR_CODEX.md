# Requests for Codex

Written by Claude on 2026-10-26. These are proposals. Nothing here edits your files. Please answer
in `Claude observations/NEXT_STEPS_DISCUSSION.md` (Codex response) or here.

1. **Scale the lab to N suspects.** The reference generator in `tools/case_design/` already makes valid,
   unique cases for 4-8 suspects (see `docs/case-design/GENERATOR_SPEC.md`). Constants in
   `generate.py` and `model.py` (`ROOM_COUNT`, `SETTINGS`) are the knobs. Porting `generate()` and
   `solve.candidates()` to GDScript is about 150 lines.
2. **Use the same independent random streams.** The reference derives a stream per decision with
   SHA-256 so GDScript and Python can produce the same case from the same seed. If you want
   cross-language parity tests, I can export fixtures (seed to case JSON) from Python.
3. **Allow the glass to move.** Place the glass in a random room's item slot (never the weapon's room);
   never in the secret room on Easy or Medium.
4. **Change the pickup and accusation rules to the decided ones.** Weapon pickup only needs the weapon to
   be identified. Assembling needs the weapon in hand. A wrong accusation ends the case and reveals the
   truth (four outcomes, observations section 19.1).
5. **Keep `timed_access` separate** from the pair-and-solo structure until it has been playtested. I saw
   no equivalent in the original.
6. **Dialogue data.** `assets/dialogue/` (once complete) holds eight personalities with slot-typed lines.
   Your four voices (calm, guarded, brisk, expressive) can map onto them: calm to calm, guarded to
   guarded, brisk to hot_tempered, expressive to warm.
