import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_pose_runtime_status as builder  # noqa: E402

POSES = ROOT / "assets" / "characters" / "poses"


def indexes():
    for c in ("char", "chris"):
        yield c, json.loads((POSES / c / "directional-index.json").read_text(encoding="utf-8"))["assets"]


def committed():
    return json.loads(builder.OUT.read_text(encoding="utf-8"))


def test_committed_equals_fresh_build():
    fresh = json.dumps(builder.build(), indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    assert builder.OUT.read_bytes() == fresh.encode("utf-8")


def test_every_pose_exactly_once():
    data = committed()["characters"]
    for c, records in indexes():
        ids = [r["pose_id"] for r in records]
        assert len(ids) == len(set(ids))
        assert sorted(data[c]["poses"]) == sorted(ids)
        assert sum(data[c]["counts"].values()) == len(ids)


def test_integrated_exports_exist():
    data = committed()["characters"]
    for c, records in indexes():
        for r in records:
            if data[c]["poses"][r["pose_id"]]["status"].startswith("integrated_"):
                assert (ROOT / r["export"]).is_file(), r["export"]


def test_lying_only_deferred():
    for c, entry in committed()["characters"].items():
        for pid, v in entry["poses"].items():
            assert pid.startswith("lying_") == (v["status"] == "deferred_bed_interaction"), (c, pid)


def test_future_characters_have_no_poses():
    data = committed()["characters"]
    for c in ("kwinn", "sarah_jo"):
        assert data[c]["status"] == "awaiting_approved_library" and data[c]["poses"] == {}


def test_export_hashes_untouched():
    checked = 0
    for c, records in indexes():
        for r in records:
            if r.get("export_sha256"):
                digest = hashlib.sha256((ROOT / r["export"]).read_bytes()).hexdigest()
                assert digest == r["export_sha256"], r["export"]
                checked += 1
    assert checked > 0
