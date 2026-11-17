#!/usr/bin/env python3
"""Regenerate assets/characters/poses/runtime-integration.json (read-only on all pose art/metadata)."""
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POSES = ROOT / "assets" / "characters" / "poses"
OUT = POSES / "runtime-integration.json"
DIRS = "(north|east|south|west)"
WORLD_PORTRAIT = [
    re.compile(r"^standing_(idle|read|look_up|talk|think|fidget|cross_arms|hands_hips)_%s$" % DIRS),
    re.compile(r"^standing_(look_down|withdraw)_(east|south|west)$"),
    re.compile(r"^seated_(idle|read)_%s$" % DIRS),
    re.compile(r"^seated_sleep_(east|south|west)$"),
]
KNEELING = re.compile(r"^kneeling_reach_(east|south|west)$")
REVEAL = {
    "char": {"standing_threaten_south", "standing_cry_south", "standing_accuse_south",
             "standing_laugh_south", "standing_shrug_south"},
    "chris": {"standing_threaten_south", "standing_cry_south", "standing_accuse_south",
              "standing_laugh_south", "standing_shrug_south", "crouching_cry_south"},
}
NEEDS = {
    "standing_hold_book": "needs a furniture/event hook (bookshelf interaction)",
    "standing_deny": "needs an accusation/interview event hook",
    "standing_startle": "needs a scare/discovery event hook",
    "standing_reach_table": "needs a furniture hook (table interaction)",
    "standing_clasp_hands": "needs a conversation/event hook",
    "standing_lean": "needs a furniture hook (wall/furniture lean)",
}


def classify(character, record):
    pid = record["pose_id"]
    if any(p.match(pid) for p in WORLD_PORTRAIT):
        return {"status": "integrated_world_and_portrait"}
    if KNEELING.match(pid):
        return {"status": "integrated_kneeling_world"}
    if pid in REVEAL.get(character, ()):
        return {"status": "integrated_reveal"}
    if pid.startswith("lying_"):
        return {"status": "deferred_bed_interaction"}
    if record.get("approval") == "reference_only":
        return {"status": "reference_only_not_runtime",
                "needs": "unapproved: reference-only record, excluded from runtime"}
    base = re.sub(r"_(north|east|south|west)$", "", pid)
    return {"status": "not_yet_hooked", "needs": NEEDS.get(base, "needs a furniture/event hook")}


def build():
    characters = {}
    for character in ("char", "chris"):
        index = json.loads((POSES / character / "directional-index.json").read_text(encoding="utf-8"))
        poses = {}
        for record in index["assets"]:
            poses[record["pose_id"]] = classify(character, record)
        counts = Counter(v["status"] for v in poses.values())
        characters[character] = {"poses": poses, "counts": dict(counts)}
    for name in ("kwinn", "sarah_jo"):
        characters[name] = {
            "status": "awaiting_approved_library", "poses": {}, "counts": {},
            "note": "Only drafts/models exist; read this file or the directional index before use.",
        }
    return {
        "schema_version": 1,
        "generated_by": "tools/build_pose_runtime_status.py",
        "note": "Runtime integration status mirroring src/mystery/guest_presentation.gd, "
                "src/mystery/killer_preview_cases.gd and src/blockout/house_investigation.gd. "
                "Derived from directional-index.json; art and metadata are never modified.",
        "characters": characters,
    }


def main():
    text = json.dumps(build(), indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
