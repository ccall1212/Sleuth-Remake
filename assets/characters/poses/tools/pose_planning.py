"""Shared, read-only pose planning for any character (Chris, Char, Kwinn, Sarah Jo, ...).

It never writes files and never generates images. It combines:
  * assets/characters/pose-catalog.json            what poses exist (directions, variants, tiers, optional eligibility)
  * assets/characters/poses/production-plan.json   group order, batching defaults, backlog caps, reference policy
  * assets/characters/poses/<slug>/profile.json    one character's generation facts
  * the character's real files and records (directional-index.json, queue.json, production-manifest.json, exports/, drafts/, metadata/)
to answer: the ordered job list, what state each job is really in, what needs review or recovery FIRST, which group is next, how to batch it,
whether the backlog cap stops production, and where the production records disagree.

Every job carries five separate facts and they are never merged:
  exists      an image file is in exports/ (or a draft is in drafts/)
  approval    approved | user_supplied | reference_only | unrecorded | substituted | none   (from the directional index, never from the folder)
  technical   pass | fail | measured | none        (recorded checks or recorded measurements; not approval)
  integrated  the game's runtime-integration status for that pose, if any   (not approval, not fit)
  status      what the planner does with it: complete | review | recover | generating | reference_only | substituted | missing | skipped
A prompt pack is not progress. A manifest list that is shorter than the files is a record problem, not missing artwork.
"""
from __future__ import annotations

import hashlib
import json
import math
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
POSES = ROOT / "assets/characters/poses"
CATALOG = ROOT / "assets/characters/pose-catalog.json"
PLAN = POSES / "production-plan.json"
RUNTIME = POSES / "runtime-integration.json"
DIRECTIONS = ("north", "east", "south", "west")
EXPORT_DIRS = ("north", "east", "south", "west", "murderer-reveal", "lying")
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]*$")


def read(path: Path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def check_slug(slug: str) -> str:
    if not SLUG.match(slug or ""):
        raise SystemExit(f"Unsafe character name {slug!r}")
    return slug


def load_profile(slug: str) -> dict:
    path = POSES / check_slug(slug) / "profile.json"
    if not path.is_file():
        raise SystemExit(f"No profile for {slug!r}: expected {path.relative_to(ROOT).as_posix()}")
    return read(path)


def profiles() -> list[str]:
    return sorted(p.parent.name for p in POSES.glob("*/profile.json"))


def load_plan() -> dict:
    return read(PLAN)


def load_catalog() -> dict:
    return read(CATALOG)


def family(entry: dict) -> str:
    return f"{entry['posture']}_{entry['activity']}"


def key_of(entry: dict) -> str:
    return f"{entry['pose_id']}|{entry['variant_id']}"


def direction_of(entry: dict):
    return (entry.get("directions") or [None])[0]


def eligible(entry: dict, profile: dict) -> bool:
    """Catalog entries may narrow who they apply to. Default: every character."""
    if entry.get("excluded"):
        return False
    slug = profile["slug"]
    if slug in (entry.get("exclude_characters") or []):
        return False
    only = entry.get("eligible_characters")
    if only and slug not in only:
        return False
    body = entry.get("eligible_body", "any")
    return body in ("any", profile.get("body"))


def apply_override(entry: dict, profile: dict) -> dict:
    """A character may follow an approved equivalent in place of a catalog pose (Kwinn follows Chris's crouching cry)."""
    override = (profile.get("pose_overrides") or {}).get(entry["pose_id"])
    if not override:
        return entry
    return {**entry, "pose_id": override["pose_id"], "male_template": override["pose_text"], "female_template": override["pose_text"],
            "override_ref": override.get("reference"), "overrides": entry["pose_id"]}


def export_subdir(entry: dict, plan: dict) -> str:
    reveal = set(plan.get("reveal_families", []))
    if family(entry) in reveal or entry["pose_id"].startswith("crouching_cry"):
        return "murderer-reveal"
    if entry["posture"] == "lying":
        return "lying"
    return direction_of(entry) or "south"


def file_name(profile: dict, entry: dict) -> str:
    return f"{profile['file_prefix']}_{entry['pose_id']}_{entry['variant_id']}.png"


# ----------------------------------------------------------------------------------------------- the plan
def ordered_jobs(slug: str, include_tier4: bool | None = None, directions: list[str] | None = None) -> tuple[list[dict], dict]:
    """The whole plan for one character in production order, plus bookkeeping: reused slots, excluded slots, and catalog families
    that no group names (those become the automatic last group, so a newly added pose is never silently ignored)."""
    profile, plan, catalog = load_profile(slug), load_plan(), load_catalog()
    defaults = plan["defaults"]
    include_tier4 = defaults.get("include_tier4", True) if include_tier4 is None else include_tier4
    rank = {d: i for i, d in enumerate(defaults["direction_order"])}
    group_of: dict[str, tuple[int, int, dict]] = {}
    for gi, group in enumerate(plan["groups"]):
        for fi, fam in enumerate(group["families"]):
            group_of[fam] = (gi, fi, group)
    tail = {"id": "catalog-additions", "title": "Catalog poses no production group names yet"}
    tail_index = len(plan["groups"])
    jobs, notes = [], {"reused": [], "not_eligible": [], "tier4_left_out": [], "new_families": []}
    new_fams: list[str] = []
    for ci, raw in enumerate(catalog["entries"]):
        if raw["tier"] >= 4 and not include_tier4:
            notes["tier4_left_out"].append(key_of(raw))
            continue
        if raw.get("reuse_from"):
            notes["reused"].append({"key": key_of(raw), "reuse_from": raw["reuse_from"]})
            continue
        if not eligible(raw, profile):
            notes["not_eligible"].append(key_of(raw))
            continue
        if profile.get("base_is_idle_south") and raw["pose_id"] == "standing_idle_south" and raw["variant_id"] == "neutral":
            continue  # the approved base model IS this pose; it is imported, never regenerated
        entry = apply_override(raw, profile)
        fam = family(raw)
        if fam in group_of:
            gi, fi, group = group_of[fam]
        else:
            if fam not in new_fams:
                new_fams.append(fam)
            gi, fi, group = tail_index, new_fams.index(fam), tail
            if fam not in notes["new_families"]:
                notes["new_families"].append(fam)
        direction = direction_of(entry)
        if directions and direction not in directions:
            continue
        jobs.append({"key": key_of(entry), "entry": entry, "catalog_key": key_of(raw), "family": fam, "group_id": group["id"], "group_index": gi,
                     "direction": direction, "save_as": file_name(profile, entry), "export_dir": export_subdir(entry, plan),
                     "_sort": (gi, fi, rank.get(direction, 9), ci)})
    jobs.sort(key=lambda j: j["_sort"])
    for order, job in enumerate(jobs, 1):
        job["order"] = order
        del job["_sort"]
    return jobs, notes


def split_balanced(items: list, max_batch: int) -> list[list]:
    if len(items) <= max_batch:
        return [items]
    parts = math.ceil(len(items) / max_batch)
    base, extra = divmod(len(items), parts)
    out, start = [], 0
    for i in range(parts):
        size = base + (1 if i < extra else 0)
        out.append(items[start:start + size])
        start += size
    return out


def make_batches(jobs: list[dict], max_batch: int | None = None, min_batch: int | None = None) -> list[list[dict]]:
    """Groups stay intact. Big groups split evenly; small groups stay small unless the user raises min_batch."""
    plan = load_plan()
    max_batch = max_batch or plan["defaults"]["max_batch"]
    min_batch = min(min_batch or plan["defaults"].get("min_batch", 1), max_batch)
    by_group: dict[int, list[dict]] = {}
    for job in jobs:
        by_group.setdefault(job["group_index"], []).append(job)
    batches: list[list[dict]] = []
    pending: list[dict] = []
    for gi in sorted(by_group):
        group = by_group[gi]
        if len(group) < min_batch:
            pending += group
            if len(pending) >= min_batch:
                batches += split_balanced(pending, max_batch)
                pending = []
            continue
        batches += split_balanced(pending + group, max_batch)
        pending = []
    if pending:
        batches += split_balanced(pending, max_batch)
    return batches


# ----------------------------------------------------------------------------------------------- real state of every job
def _index(slug: str) -> dict[str, dict]:
    path = POSES / slug / "directional-index.json"
    return {key_of(a): a for a in read(path)["assets"]} if path.is_file() else {}


def _queue(slug: str) -> dict[str, dict]:
    path = POSES / slug / "queue.json"
    return {key_of(j): j for j in read(path)} if path.is_file() else {}


def _exports(slug: str) -> dict[str, Path]:
    found: dict[str, Path] = {}
    for sub in EXPORT_DIRS:
        folder = POSES / slug / "exports" / sub
        if folder.is_dir():
            for path in folder.glob("*.png"):
                found[path.name] = path
    return found


def _drafts(slug: str) -> dict[str, Path]:
    """Draft PNGs by base file name (a revision suffix _r2 counts as the same pose). Earlier model-review drafts have other names and never match."""
    found: dict[str, Path] = {}
    base = POSES / slug / "drafts"
    if base.is_dir():
        for path in sorted(base.rglob("*.png")):
            found.setdefault(re.sub(r"_r\d+$", "", path.stem) + ".png", path)
    return found


def _metadata(slug: str) -> dict[str, dict]:
    """Per-asset metadata JSON by export file name, where it exists (Char and Chris keep some under metadata/)."""
    found: dict[str, dict] = {}
    folder = POSES / slug / "metadata"
    if folder.is_dir():
        for path in folder.rglob("*.json"):
            try:
                data = read(path)
            except ValueError:
                continue
            if isinstance(data, dict) and data.get("pose_id"):
                found[f"{slug}_{data['pose_id']}_{data.get('variant_id', 'neutral')}.png"] = data
    return found


def _decisions(slug: str) -> dict[str, dict]:
    """The user's recorded decisions for this character (`<slug>/decisions.json`), by pose key. A decision carries the user's own words;
    it can only mark a slot as ACCOUNTED FOR (reference_example, substitute_retained). It never creates an approval and never edits the index."""
    path = POSES / slug / "decisions.json"
    return {d["key"]: d for d in read(path)["decisions"]} if path.is_file() else {}


def _integration(slug: str) -> dict[str, str]:
    if not RUNTIME.is_file():
        return {}
    chars = read(RUNTIME).get("characters", {})
    entry = chars.get(slug) or chars.get(slug.replace("-", "_")) or {}
    return {pose: info.get("status") for pose, info in (entry.get("poses") or {}).items()}


def progress(slug: str, jobs: list[dict] | None = None) -> dict[str, dict]:
    """key -> five separate facts plus a planner status. Files and hashes outrank prose; folder presence is NOT approval."""
    jobs = jobs if jobs is not None else ordered_jobs(slug)[0]
    exports, drafts, index, queue = _exports(slug), _drafts(slug), _index(slug), _queue(slug)
    meta, integ = _metadata(slug), _integration(slug)
    out: dict[str, dict] = {}
    for job in jobs:
        name, key = job["save_as"], job["key"]
        rec, q = index.get(key), queue.get(key)
        exists = name in exports
        approval = None
        if exists:
            state = (rec or {}).get("approval")
            approval = {"approved": "approved", "user_supplied_added_to_project": "user_supplied", "reference_only": "reference_only"}.get(state, "unrecorded" if rec is None else str(state))
            if q and q["status"] in ("approved", "imported") and rec is None:
                approval = "approved"  # queue alone is weaker than the index, but better than nothing; reconcile() flags the mismatch
        technical = None
        checks = (q or {}).get("checks")
        if checks and "technical_pass" in checks:
            technical = "pass" if checks["technical_pass"] else "fail"
        elif name in meta and meta[name].get("alpha_extrema") and meta[name].get("canvas"):
            technical = "measured"
        elif rec and rec.get("canvas"):
            technical = "measured"
        fact = {"exists": exists, "approval": approval, "technical": technical, "integrated": integ.get(job["entry"]["pose_id"]),
                "path": exports[name].relative_to(ROOT).as_posix() if exists else None, "source": "exports" if exists else "none"}
        if exists and approval in ("approved", "user_supplied", "unrecorded"):
            fact["status"] = "complete" if approval != "unrecorded" else "review"
        elif exists and approval == "reference_only":
            fact["status"] = "reference_only"
        elif exists:
            fact["status"] = "review"
        elif q and q["status"] == "skipped":
            fact["status"] = "substituted" if "replac" in (q.get("notes") or "").lower() or "substitut" in (q.get("notes") or "").lower() else "skipped"
            fact["note"] = q.get("notes")
        elif name in drafts:
            fact.update({"exists": True, "path": drafts[name].relative_to(ROOT).as_posix(), "source": "drafts", "status": "review"})
        elif q and q["status"] == "needs_help":
            fact["status"] = "recover"
        elif q and q["status"] == "generating":
            fact["status"] = "generating"
        else:
            fact["status"] = "missing"
        decided = _decisions(slug).get(key)
        if decided and fact["status"] in ("reference_only", "substituted", "skipped"):
            fact["status"] = decided["accept_as"]
            fact["decision"] = decided["id"]
        out[key] = fact
    return out


def attention(jobs: list[dict], prog: dict[str, dict]) -> list[dict]:
    """Review and recovery work that must be handled BEFORE any later group is started."""
    items = []
    for j in jobs:
        p = prog[j["key"]]
        if p["status"] in ("review", "recover", "generating"):
            reason = {"review": "a draft or unrecorded export is waiting for review", "recover": "marked needs_help: recover or redo it", "generating": "marked generating: confirm or recover it"}[p["status"]]
            items.append({"order": j["order"], "key": j["key"], "status": p["status"], "path": p["path"], "reason": reason, "group": j["group_id"]})
    return items


def decisions(jobs: list[dict], prog: dict[str, dict], slug: str | None = None) -> list[dict]:
    """Things only the user can decide; informational, they never block the next group."""
    out = []
    catalog_keys = {key_of(e) for e in load_catalog()["entries"]}
    substitutes = []
    if slug:
        substitutes = [k for k, j in _queue(slug).items() if k not in catalog_keys and j["status"] in ("approved", "imported")]
    for j in jobs:
        p = prog[j["key"]]
        if p["status"] == "substituted":
            out.append({"kind": "substituted_slot", "slot": j["key"], "approved_substitute": substitutes, "note": p.get("note"),
                        "choice": "RETAIN the substitute (the slot stays closed and is counted as accounted for, not as a standing pose) or ADD a distinct pose for this slot (the planner then lists it as missing and waits for an image)"})
        elif p["status"] == "reference_only":
            out.append({"kind": "reference_only", "key": j["key"], "path": p["path"],
                        "choice": "approve it as a final pose, or produce a real pose; until then it is not counted as complete"})
    return out


# ----------------------------------------------------------------------------------------------- references
def resolve_reference(slug: str, job: dict) -> dict:
    """Where this job's composition reference comes from. Never invents one and never treats an unapproved image as approved.
    kind: override | same_pose | fallback | blocked_on_example | nearest | needs_decision"""
    profile, plan = load_profile(slug), load_plan()
    entry = job["entry"]
    if entry.get("override_ref") and (ROOT / entry["override_ref"]).is_file():
        return {"kind": "override", "path": entry["override_ref"], "owner": profile.get("composition_example") or slug}
    example = profile.get("composition_example")
    if example:
        name = f"{example}_{entry['pose_id']}_{entry['variant_id']}.png"
        found = _exports(example).get(name)
        rec = _index(example).get(key_of(entry))
        if found and (rec is None or rec.get("approval") in ("approved", "user_supplied_added_to_project")):
            return {"kind": "same_pose", "path": found.relative_to(ROOT).as_posix(), "owner": example}
        source = entry.get("source_char_asset")
        if source and (ROOT / source).is_file() and example != "char":
            return {"kind": "fallback", "path": source, "owner": "char", "note": f"{example} has no approved same-pose image; Char's was used"}
        if example in profiles():
            ex_jobs, _ = ordered_jobs(example)
            if any(k["key"] == job["key"] for k in ex_jobs):
                return {"kind": "blocked_on_example", "owner": example, "note": f"waits for {example}'s approved {entry['pose_id']}"}
    fam = family(entry)
    policy = (plan.get("reference_policy", {}).get("families") or {}).get(fam)
    if policy and policy.get("confirmed"):
        holder = example or slug
        files = _exports(holder)
        records = {Path(r["export"]).name: r for r in _index(holder).values() if r.get("export")}
        direction = direction_of(entry)
        for cand in policy["nearest"]:
            tries = ([direction] if policy.get("same_direction_first") and direction else []) + [None]
            for d in tries:
                prefix = f"{holder}_{cand}" + (f"_{d}_" if d else "_")
                for name, path in sorted(files.items()):
                    rec = records.get(name)
                    if name.startswith(prefix) and (rec is None or rec.get("approval") in ("approved", "user_supplied_added_to_project")):
                        return {"kind": "nearest", "path": path.relative_to(ROOT).as_posix(), "owner": holder,
                                "note": f"NEAREST related pose ({cand}), not the same pose"}
    return {"kind": "needs_decision", "proposed": (policy or {}).get("nearest"), "advice": (policy or {}).get("advice"),
            "note": "No approved same-pose reference exists and no nearest-pose reference is confirmed. Confirm one in production-plan.json or supply an external reference."}


# ----------------------------------------------------------------------------------------------- caps and the next step
def backlog() -> dict:
    """Unreviewed drafts per character and in total. Awaiting-review drafts, needs_help and generating jobs all count."""
    plan = load_plan()["defaults"]
    per = {}
    for slug in profiles():
        jobs, _ = ordered_jobs(slug)
        prog = progress(slug, jobs)
        per[slug] = sum(1 for v in prog.values() if v["status"] in ("review", "recover", "generating") and v["source"] != "exports")
    total = sum(per.values())
    cap_c, cap_t = plan.get("backlog_cap_per_character", 24), plan.get("backlog_cap_total", 48)
    return {"per_character": per, "total": total, "cap_per_character": cap_c, "cap_total": cap_t,
            "paused_characters": sorted(s for s, n in per.items() if n >= cap_c), "paused_total": total >= cap_t}


def next_step(slug: str, jobs: list[dict], prog: dict[str, dict], group: str | None = None, batch_size: int = 0) -> dict:
    """Review/recovery first; then the next incomplete group (or the requested one); stop if a backlog cap is reached."""
    att = attention(jobs, prog)
    log = backlog()
    result = {"attention": att, "decisions": decisions(jobs, prog, slug), "backlog": log, "group_id": None, "missing": [], "action": None}
    if att:
        result["action"] = "review_or_recover_first"
        return result
    over = log["total"] + batch_size > log["cap_total"] or log["per_character"].get(slug, 0) + batch_size > log["cap_per_character"]
    todo = [j for j in jobs if prog[j["key"]]["status"] == "missing" and (group is None or j["group_id"] == group)]
    if not todo:
        result["action"] = "nothing_left" if group is None else "group_complete"
        return result
    gid = todo[0]["group_id"]
    missing = [j for j in todo if j["group_id"] == gid]
    refs = {j["key"]: resolve_reference(slug, j) for j in missing}
    blocked = [j["key"] for j in missing if refs[j["key"]]["kind"] in ("needs_decision", "blocked_on_example")]
    action = "paused_backlog_cap" if over else ("needs_reference_decision" if len(blocked) == len(missing) else "generate")
    result.update({"group_id": gid, "missing": missing, "action": action, "references": refs, "blocked_jobs": blocked})
    return result


# ----------------------------------------------------------------------------------------------- reconciliation (read-only)
def reconcile(slug: str) -> dict:
    """Compare every production record for one character and describe the real state of each pose. Corrects nothing."""
    profile, catalog = load_profile(slug), load_catalog()
    base = POSES / slug
    cat = {key_of(e): e for e in catalog["entries"]}
    jobs, notes = ordered_jobs(slug)
    prog = progress(slug, jobs)
    report: dict = {"character": profile["name"], "slug": slug, "catalog_entries": len(cat), "planned_jobs": len(jobs), "records": {}, "conflicts": [], "notes": [], "decisions": decisions(jobs, prog, slug)}

    exports = _exports(slug)
    index = _index(slug)
    queue = _queue(slug)
    report["records"]["export_pngs"] = len(exports)
    if index:
        report["records"]["directional_index"] = {"assets": len(index), "approval": dict(Counter(a.get("approval") for a in index.values()))}
        bad = [k for k, a in index.items() if a.get("export") and (ROOT / a["export"]).is_file() and a.get("export_sha256") and sha256(ROOT / a["export"]) != a["export_sha256"]]
        gone = [k for k, a in index.items() if a.get("export") and not (ROOT / a["export"]).is_file()]
        if bad:
            report["conflicts"].append({"kind": "index_hash_mismatch", "keys": bad})
        if gone:
            report["conflicts"].append({"kind": "index_path_missing", "keys": gone})
        names = {Path(a["export"]).name for a in index.values() if a.get("export")}
        extra = sorted(set(exports) - names)
        if extra:
            report["conflicts"].append({"kind": "export_not_in_index", "files": extra})
    else:
        report["records"]["directional_index"] = None
    if queue:
        report["records"]["queue"] = {"slots": len(queue), "status": dict(Counter(j["status"] for j in queue.values()))}
        outside = sorted(k for k in queue if k not in cat)
        if outside:
            report["notes"].append({"kind": "queue_slots_outside_catalog", "keys": outside, "explained_by": [queue[k].get("notes") for k in outside]})
        absent = sorted(k for k in cat if k not in queue)
        if absent and not (profile.get("base_is_idle_south")):
            report["notes"].append({"kind": "catalog_slots_not_in_queue", "count": len(absent), "keys": absent[:30]})
        done = {k for k, j in queue.items() if j["status"] in ("approved", "imported")}
        for k in sorted(done):
            path = queue[k].get("approved_export") or queue[k].get("library_path")
            if not path or not (ROOT / path).is_file():
                report["conflicts"].append({"kind": "queue_approved_without_file", "key": k, "path": path})
        if index and done != set(index):
            report["conflicts"].append({"kind": "queue_vs_index", "only_queue": sorted(done - set(index)), "only_index": sorted(set(index) - done)})
    else:
        report["records"]["queue"] = None
    manifest_path = base / "production-manifest.json"
    if manifest_path.is_file():
        man = read(manifest_path)
        approved = man.get("approved_assets")
        info = {"status": man.get("status"), "declared_export_counts": man.get("export_counts"), "approved_assets": None}
        if approved is not None:
            mk = {key_of(a): a for a in approved}
            info["approved_assets"] = len(mk)
            wrong = [k for k, a in mk.items() if (ROOT / a["path"]).is_file() and sha256(ROOT / a["path"]) != a.get("sha256")]
            if wrong:
                report["conflicts"].append({"kind": "manifest_hash_mismatch", "keys": wrong})
            basis = set(index) or {k for k, j in queue.items() if j["status"] in ("approved", "imported")}
            lag = sorted(basis - set(mk))
            if lag:
                report["conflicts"].append({"kind": "manifest_approved_assets_lags", "declared_library": sum((man.get("export_counts") or {}).values()) or None, "listed": len(mk),
                                            "missing_from_list": lag, "resolution": "The files, hashes, index and queue agree on these poses, so the artwork is NOT missing: only the manifest list is short. Appending them is a record fix that waits for the user's go-ahead."})
        report["records"]["manifest"] = info
    else:
        report["records"]["manifest"] = None
    if not index and not queue and not exports:
        report["notes"].append({"kind": "no_production_records", "detail": "No queue, manifest, index or exports: no pose is approved. A prompt pack is not progress."})
    for fam in notes["new_families"]:
        report["notes"].append({"kind": "catalog_family_without_group", "family": fam, "detail": "Planned automatically in the last group 'catalog-additions'."})

    states = Counter(v["status"] for v in prog.values())
    approvals = Counter(v["approval"] or "none" for v in prog.values())
    tech = Counter(v["technical"] or "none" for v in prog.values())
    integ = Counter(v["integrated"] or "none" for v in prog.values() if v["exists"])
    tier = Counter(j["entry"]["tier"] for j in jobs)
    report["five_facts"] = {
        "planned_jobs": len(jobs), "planned_by_tier": dict(sorted(tier.items())),
        "image_exists": sum(1 for v in prog.values() if v["exists"]),
        "approval_of_existing": {k: v for k, v in approvals.items() if k != "none"},
        "technically_checked_of_existing": {k: v for k, v in tech.items() if k != "none"},
        "integrated_status_of_existing": dict(integ),
        "planner_status": dict(states),
    }
    report["summary"] = {"note": "Approval, technical checks and runtime integration are separate. Integration status comes from assets/characters/poses/runtime-integration.json."}
    return report


def format_report(report: dict) -> str:
    lines = [f"# Production record reconciliation: {report['character']}", "", f"Catalog entries: {report['catalog_entries']}; planned jobs: {report['planned_jobs']}"]
    for name, value in report["records"].items():
        lines.append(f"- {name}: {json.dumps(value, ensure_ascii=False)}")
    lines += ["", "Five separate facts about the planned poses:"]
    for name, value in report["five_facts"].items():
        lines.append(f"- {name}: {json.dumps(value, ensure_ascii=False)}")
    lines += ["", f"Conflicts: {len(report['conflicts'])}"]
    for c in report["conflicts"]:
        lines.append(f"- {json.dumps(c, ensure_ascii=False)[:900]}")
    lines += ["", f"Decisions for the user: {len(report['decisions'])}"]
    for d in report["decisions"]:
        lines.append(f"- {json.dumps(d, ensure_ascii=False)[:500]}")
    lines.append("")
    for n in report["notes"]:
        lines.append(f"- note: {json.dumps(n, ensure_ascii=False)[:600]}")
    return "\n".join(lines)
