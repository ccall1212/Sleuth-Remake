import json
import sys
from pathlib import Path

import pytest
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import check_pose_drafts as cpd  # noqa: E402

W, H = 985, 1597
JOBS = [
    {"order": 1, "tier": 1, "pose_id": "standing_idle", "variant_id": "neutral", "save_as": "kwinn_standing_idle_neutral.png"},
    {"order": 2, "tier": 1, "pose_id": "lying_back", "variant_id": "neutral", "save_as": "kwinn_lying_back_neutral.png"},
    {"order": 3, "tier": 2, "pose_id": "standing_wave", "variant_id": "neutral", "save_as": "kwinn_standing_wave_neutral.png"},
]


@pytest.fixture
def env(tmp_path, monkeypatch):
    poses = tmp_path / "assets/characters/poses"
    pack = poses / "kwinn/prompts/pack-01"
    pack.mkdir(parents=True)
    (pack / "prompts.json").write_text(json.dumps({"character": "Kwinn", "jobs": JOBS}), encoding="utf-8")
    monkeypatch.setattr(cpd, "ROOT", tmp_path)
    monkeypatch.setattr(cpd, "POSES", poses)
    return poses / "kwinn/drafts/pack-01"


def figure(path, box, size=(W, H), opaque=False):
    img = Image.new("RGBA", size, (30, 30, 30, 255) if opaque else (0, 0, 0, 0))
    ImageDraw.Draw(img).rectangle(box, fill=(200, 50, 50, 255))
    img.save(path)


def run(drafts, name):
    drafts.mkdir(parents=True, exist_ok=True)
    return drafts


def results(env, filename):
    report = cpd.build_report("kwinn")
    entry = next(e for e in report["jobs"] if e["save_as"] == filename)
    return entry, {r["name"]: r for r in entry["results"]}


def test_good_standing_passes(env):
    env.mkdir(parents=True)
    figure(env / JOBS[0]["save_as"], (300, 12, 700, 12 + 1572))
    entry, r = results(env, JOBS[0]["save_as"])
    assert entry["present"] and entry["overall"] == "pass", entry["results"]
    assert len(entry["sha256"]) == 64


def test_cropped_fails(env):
    env.mkdir(parents=True)
    figure(env / JOBS[0]["save_as"], (300, 0, 700, 1572))
    entry, r = results(env, JOBS[0]["save_as"])
    assert r["margins"]["status"] == "fail" and entry["overall"] == "fail"


def test_opaque_fails(env):
    env.mkdir(parents=True)
    figure(env / JOBS[0]["save_as"], (300, 12, 700, 1584), opaque=True)
    entry, r = results(env, JOBS[0]["save_as"])
    assert r["alpha"]["status"] == "fail" and entry["overall"] == "fail"


def test_short_standing_not_pass(env):
    env.mkdir(parents=True)
    figure(env / JOBS[2]["save_as"], (300, 100, 700, 100 + 1000))
    entry, r = results(env, JOBS[2]["save_as"])
    assert r["height"]["status"] in ("warn", "fail")
    assert r["height"]["status"] == "fail"


def test_lying_skips_height(env):
    env.mkdir(parents=True)
    figure(env / JOBS[1]["save_as"], (100, 600, 880, 900))
    entry, r = results(env, JOBS[1]["save_as"])
    assert r["height"]["status"] == "pass" and "height check skipped for lying" in r["height"]["message"]
    assert entry["overall"] == "pass"


def test_unmatched_reported(env, capsys):
    env.mkdir(parents=True)
    figure(env / "random_name.png", (300, 12, 700, 1584))
    report = cpd.build_report("kwinn")
    assert [u["file"] for u in report["unmatched"]] == ["random_name.png"]
    assert report["unmatched"][0]["note"] == "unmatched file"


def test_missing_drafts_folder(env, capsys):
    assert cpd.main(["kwinn", "--html"]) == 0
    assert "no drafts yet" in capsys.readouterr().out
    assert not env.exists()


def test_unknown_slug_and_missing_prompts(env):
    assert cpd.main(["nobody"]) == 2
    (cpd.POSES / "kwinn/prompts/pack-01/prompts.json").unlink()
    assert cpd.main(["kwinn"]) == 2


def test_html_and_status_written(env):
    env.mkdir(parents=True)
    figure(env / JOBS[0]["save_as"], (300, 12, 700, 1584))
    original = (env / JOBS[0]["save_as"]).read_bytes()
    assert cpd.main(["kwinn", "--html"]) == 0
    assert (env / "review/status.json").is_file()
    page = (env / "review/index.html").read_text(encoding="utf-8")
    assert "Not generated yet" in page and "../" + JOBS[0]["save_as"] in page and "base64" not in page
    assert (env / JOBS[0]["save_as"]).read_bytes() == original
