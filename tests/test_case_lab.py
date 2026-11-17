"""Generated-case fairness, state, and bound Godot controls; no artwork required."""
import json
from pathlib import Path

import server


def test_case_lab_engine_checks():
    configured = server.config()
    godot = configured.get('godot')
    assert godot and Path(godot).is_file(), 'Configure Godot before running the lab checks'
    result = server.run_bounded(
        [godot, '--headless', '--path', str(server.ROOT),
         '--script', 'tools/case_lab_checks.gd'], server.ROOT, 20)
    assert result['ok'], result
    report = json.loads((server.ROOT / 'test-results/case-lab-checks.json').read_text())
    assert report['ok'] and report['seeds'] == 200 and report['families'] == 2 and report['case_signatures'] > 90
    assert report['checks'] >= 2500 and not report['failures']


def test_case_lab_launcher_rejects_arbitrary_scenes_and_seeds():
    for mode, seed in [('other_scene', 1), ('case_lab', -1), ('case_lab', 2147483648)]:
        result = server.launch_remake(mode=mode, case_seed=seed)
        assert not result['ok']
