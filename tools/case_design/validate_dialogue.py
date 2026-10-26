"""Validate assets/dialogue/*.json. Exit code 1 when anything is wrong.

    python tools/case_design/validate_dialogue.py [dialogue_dir]

If the environment variable SLEUTH_REFERENCE_DIR names a folder, any line that shares a
6-word run with a file in it (case-insensitive) is also reported. Unset: skipped silently.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

try:
    from . import dialogue as dlg
except ImportError:  # run as a script: python tools/case_design/validate_dialogue.py
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import dialogue as dlg

MAX_LENGTH = 240
MAX_EXPANDED = 270   # after slots are filled with worst-case values (names the player types, long rooms)
SLOT_WIDTH = {"weapon": 24, "rank": 24, "moves": 5}
DEFAULT_SLOT_WIDTH = 16
MIN_VARIANTS = 6

BANNED_PHRASES = (
    "mind your own business", "inquisition", "ironclad alibi", "perfect alibi", "sniveling",
    "sycophant", "soft spot", "peddle parking tickets", "better off dead", "Goodbye, inspector",
    "brilliant deduction", "slipshod", "baited breath", "Master Sleuth", "Professional Sleuth",
    "Bumbling Sleuth", "nearsighted", "traces of blood on it", "the only decent thing",
)
GUILT_WORDS = re.compile(r"\b(guilty|innocen\w*|i did it|i killed|i confess|murderer|culprit)\b", re.I)
# Speakers, victims and suspects have no fixed gender, so no line may assume one.
PRONOUNS = re.compile(r"\b(he|she|his|hers?|him|himself|herself)\b", re.I)
SENTENCE_END = (".", "!", "?", "...", "…")
_WORDS = re.compile(r"[a-z0-9']+")
REFERENCE_RUN = 6


def _strings(value) -> list[str]:
    return [value] if isinstance(value, str) else list(value)


def _check_text(where: str, text: str, allowed: tuple[str, ...], required: tuple[str, ...]) -> list[str]:
    errors = []
    used = dlg.slots_in(text)
    for name in sorted(set(used) - set(allowed)):
        errors.append(f"{where}: slot {{{name}}} not allowed here: {text!r}")
    for name in required:
        if name not in used:
            errors.append(f"{where}: must contain {{{name}}}: {text!r}")
    if "{" in dlg._SLOT.sub("", text) or "}" in dlg._SLOT.sub("", text):
        errors.append(f"{where}: stray brace: {text!r}")
    if len(text) > MAX_LENGTH:
        errors.append(f"{where}: {len(text)} characters, max {MAX_LENGTH}: {text!r}")
    expanded = dlg._SLOT.sub(lambda m: "x" * SLOT_WIDTH.get(m.group(1), DEFAULT_SLOT_WIDTH), text)
    if len(expanded) > MAX_EXPANDED:
        errors.append(f"{where}: {len(expanded)} characters with worst-case slots, max {MAX_EXPANDED}: {text!r}")
    lowered = text.lower()
    for phrase in BANNED_PHRASES:
        if phrase.lower() in lowered:
            errors.append(f"{where}: banned phrase {phrase!r}: {text!r}")
    if PRONOUNS.search(text):
        errors.append(f"{where}: gendered pronoun: {text!r}")
    if text != text.strip() or "  " in text:
        errors.append(f"{where}: stray whitespace: {text!r}")
    return errors


def _check_personality_line(where: str, kind: str, text: str) -> list[str]:
    errors = []
    if kind not in dlg.GUILT_OK_TYPES and GUILT_WORDS.search(text):
        errors.append(f"{where}: mentions guilt or innocence outside a confession type: {text!r}")
    lowered = text.lower()
    if kind in ("opening", "repeat_lead") and not text.endswith(","):
        errors.append(f"{where}: must end with a comma: {text!r}")
    if kind in ("opening", "claim_solo", "claim_pair", "commentary_victim", "commentary_suspect",
                "commentary_self", "repeat_lead", "repeat_close") and '"' in text:
        errors.append(f"{where}: no quotation marks allowed in this line type: {text!r}")
    if kind in ("claim_solo", "claim_pair", "commentary_victim", "commentary_suspect",
                "commentary_self", "repeat_close") and not text.endswith(SENTENCE_END):
        errors.append(f"{where}: must end like a sentence: {text!r}")
    if kind in ("claim_solo", "claim_pair") and "evening" not in lowered:
        errors.append(f"{where}: claim must say 'evening': {text!r}")
    if kind == "claim_solo" and "alone" not in lowered:
        errors.append(f"{where}: solo claim must say 'alone': {text!r}")
    if kind == "refusal":
        if re.search(r"\b(alone|evening|never)\b", lowered):
            errors.append(f"{where}: refusal must give no alibi and never say 'never': {text!r}")
        if '"' in text and text.count('"') % 2:
            errors.append(f"{where}: unbalanced quotation marks: {text!r}")
    if kind in dlg.GUILT_OK_TYPES or kind == "refusal":
        if text.count('"') % 2:
            errors.append(f"{where}: unbalanced quotation marks: {text!r}")
    return errors


def _check_personalities(personalities: dict) -> list[str]:
    errors = []
    if sorted(personalities) != sorted(dlg.PERSONALITY_IDS):
        errors.append(f"personalities.json keys {sorted(personalities)} != {sorted(dlg.PERSONALITY_IDS)}")
    for pid in dlg.PERSONALITY_IDS:
        lines = personalities.get(pid)
        if lines is None:
            continue
        if sorted(lines) != sorted(dlg.PERSONALITY_LINES):
            errors.append(f"{pid}: line types differ; missing {sorted(set(dlg.PERSONALITY_LINES) - set(lines))}, "
                          f"unknown {sorted(set(lines) - set(dlg.PERSONALITY_LINES))}")
        for kind, (allowed, required) in dlg.PERSONALITY_LINES.items():
            variants = lines.get(kind)
            if variants is None:
                continue
            if not isinstance(variants, list) or not all(isinstance(v, str) for v in variants):
                errors.append(f"{pid}.{kind}: must be a list of strings")
                continue
            if len(variants) < MIN_VARIANTS:
                errors.append(f"{pid}.{kind}: {len(variants)} variants, need {MIN_VARIANTS}")
            for number, text in enumerate(variants):
                where = f"{pid}.{kind}[{number}]"
                errors += _check_text(where, text, allowed, required)
                errors += _check_personality_line(where, kind, text)
    return errors


def _check_system(system: dict) -> list[str]:
    errors = []
    if sorted(system) != sorted(dlg.SYSTEM_LINES):
        errors.append(f"system.json keys differ; missing {sorted(set(dlg.SYSTEM_LINES) - set(system))}, "
                      f"unknown {sorted(set(system) - set(dlg.SYSTEM_LINES))}")
    for key, (allowed, minimum) in dlg.SYSTEM_LINES.items():
        value = system.get(key)
        if value is None:
            continue
        if minimum == 0:
            if not isinstance(value, str):
                errors.append(f"system.{key}: must be a single string")
                continue
            variants = [value]
        else:
            if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
                errors.append(f"system.{key}: must be a list of strings")
                continue
            variants = value
            exact = key in ("ranks", "item_flavor_generic")
            if len(variants) < minimum or (exact and len(variants) != minimum):
                errors.append(f"system.{key}: {len(variants)} entries, need {'exactly ' if exact else ''}{minimum}")
        for number, text in enumerate(variants):
            errors += _check_text(f"system.{key}[{number}]", text, allowed, allowed)
        if key == "ranks":
            for text in variants:
                if not 2 <= len(text.split()) <= 3:
                    errors.append(f"system.ranks: {text!r} must be 2-3 words")
                if "sleuth" in text.lower():
                    errors.append(f"system.ranks: {text!r} must not use 'Sleuth'")
    return errors


def _check_duplicates(data: dict) -> list[str]:
    seen: dict[str, str] = {}
    errors = []
    items = [
        (f"{pid}.{kind}[{n}]", text)
        for pid, lines in data["personalities"].items()
        for kind, variants in lines.items()
        for n, text in enumerate(variants)
    ] + [
        (f"system.{key}[{n}]", text)
        for key, value in data["system"].items()
        for n, text in enumerate(_strings(value))
    ]
    for where, text in items:
        norm = text.strip().lower()
        if norm in seen:
            errors.append(f"duplicate line: {where} repeats {seen[norm]}: {text!r}")
        else:
            seen[norm] = where
    return errors


def _word_runs(text: str, size: int = REFERENCE_RUN):
    words = _WORDS.findall(text.lower())
    return {tuple(words[i:i + size]) for i in range(len(words) - size + 1)}


def _check_reference(data: dict, folder: Path) -> list[str]:
    reference: set[tuple[str, ...]] = set()
    for path in folder.rglob("*"):
        if path.is_file() and path.stat().st_size < 50_000_000:
            reference |= _word_runs(path.read_bytes().decode("utf-8", errors="ignore"))
    errors = []
    for pid, lines in data["personalities"].items():
        for kind, variants in lines.items():
            for n, text in enumerate(variants):
                if _word_runs(text) & reference:
                    errors.append(f"{pid}.{kind}[{n}]: shares a {REFERENCE_RUN}-word run with SLEUTH_REFERENCE_DIR: {text!r}")
    for key, value in data["system"].items():
        for n, text in enumerate(_strings(value)):
            if _word_runs(text) & reference:
                errors.append(f"system.{key}[{n}]: shares a {REFERENCE_RUN}-word run with SLEUTH_REFERENCE_DIR: {text!r}")
    return errors


def problems(data: dict, reference_dir: str | Path | None = None) -> list[str]:
    """Every problem found in loaded dialogue data (empty list means valid)."""
    errors = _check_personalities(data["personalities"]) + _check_system(data["system"])
    if not errors:  # the duplicate and reference scans assume well-formed data
        errors += _check_duplicates(data)
        if reference_dir:
            errors += _check_reference(data, Path(reference_dir))
    return errors


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    try:
        data = dlg.load(argv[0] if argv else None)
    except (OSError, ValueError) as error:
        print(f"cannot load dialogue: {error}")
        return 1
    found = problems(data, os.environ.get("SLEUTH_REFERENCE_DIR"))
    for line in found:
        print(line)
    if found:
        print(f"{len(found)} problem(s)")
        return 1
    count = sum(len(v) for lines in data["personalities"].values() for v in lines.values())
    print(f"dialogue OK: {len(data['personalities'])} personalities, {count} lines, {len(data['system'])} system keys")
    return 0


if __name__ == "__main__":
    sys.exit(main())
