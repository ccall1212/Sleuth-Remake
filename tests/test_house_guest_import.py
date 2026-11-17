"""User placement imports preserve authored geometry and fail before replacing data."""
import copy
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
spec = importlib.util.spec_from_file_location('import_house_guests', ROOT / 'tools/import_house_guests.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


@pytest.fixture
def download():
    # This native snapshot is the exact authored export with verified rendering
    # metadata added; it allows tests without a personal Downloads folder.
    data = json.loads((ROOT / importer.OUTPUT).read_text(encoding='utf-8'))
    for room in data['rooms']:
        for slot in room['guest_spots']:
            slot.pop('render', None)
    data.pop('validation', None)
    return data


def test_real_export_preserves_user_geometry_and_validates_current_art(download):
    result = importer.validate_import(download)
    assert result['status'] == 'preview_pending_fit'
    assert result['adult_height'] == 80
    assert result['validation']['room_count'] == 11
    assert result['validation']['guest_spots'] == sum(len(r['guest_spots']) for r in download['rooms'])
    assert result['validation']['foreground_masks'] == sum(len(r['foreground_masks']) for r in download['rooms'])
    statuses = set()
    for before, after in zip(download['rooms'], result['rooms']):
        assert before['foreground_masks'] == after['foreground_masks']
        for original, imported in zip(before['guest_spots'], after['guest_spots']):
            assert {k: imported[k] for k in original} == original
            statuses.add(imported['render']['approval_preflight']['status'])
            assert imported['render']['source'].startswith('assets/characters/poses/')
    assert 'legacy_exact_record_preflight_passed' in statuses
    assert 'exact_record_preflight_passed' in statuses
    assert 'legacy_index_approval_only' in statuses
    assert any('self-crosses' in w for w in result['validation']['warnings'])


@pytest.mark.parametrize('change,match', [
    (lambda d: d.update(schema='other'), 'schema'),
    (lambda d: d.update(coordinates=[960,720]), 'coordinates'),
    (lambda d: d['rooms'].pop(), 'Room IDs'),
    (lambda d: d['rooms'][0].update(image_sha256='0'*64), 'revision'),
    (lambda d: d['rooms'][0]['guest_spots'][0].update(at=[float('nan'),129]), 'anchor/floor'),
    (lambda d: d['rooms'][0]['guest_spots'][0].update(at=[True,129]), 'anchor/floor'),
    (lambda d: d['rooms'][0]['guest_spots'][0].update(at=[481,129]), 'anchor/floor'),
    (lambda d: d['rooms'][0]['guest_spots'][0].update(facing='west'), 'posture/activity/facing'),
    (lambda d: d['rooms'][0]['guest_spots'][0].update(pose_id='not_a_pose'), 'unknown pose'),
    (lambda d: d['rooms'][0]['guest_spots'][0].update(source_contact=[0,0]), 'measurement'),
    (lambda d: d['rooms'][0]['guest_spots'][0].update(floor_at=[0,0]), 'floor point'),
    (lambda d: d['rooms'][0]['guest_spots'][0].update(depth_y=350), 'sorting depth'),
    (lambda d: d['rooms'][0]['guest_spots'][1].update(id=d['rooms'][0]['guest_spots'][0]['id']), 'Duplicate'),
    (lambda d: d['rooms'][0]['foreground_masks'][0].update(polygon=[[1,1],[2,2],[3,3]]), 'degenerate'),
    (lambda d: d['rooms'][0]['foreground_masks'][0].update(depth_y=float('inf')), 'mask depth'),
])
def test_bad_exports_are_rejected(download, change, match):
    change(download)
    with pytest.raises(ValueError, match=match):
        importer.validate_import(download)


def test_changed_png_is_rejected_without_modifying_art(download, monkeypatch):
    real_digest = importer.digest
    monkeypatch.setattr(importer, 'digest', lambda p: '0'*64 if p.name == 'char_standing_read_east_neutral.png' else real_digest(p))
    with pytest.raises(ValueError, match='PNG hash changed'):
        importer.validate_import(download)


def test_atomic_output_retains_previous_snapshot_on_invalid_input(download, tmp_path):
    source, destination = tmp_path/'download.json', tmp_path/'native.json'
    destination.write_text('old snapshot', encoding='utf-8')
    source.write_text('{"schema":"bad"}', encoding='utf-8')
    with pytest.raises(ValueError):
        importer.import_file(source, destination)
    assert destination.read_text() == 'old snapshot'
    source.write_text(json.dumps(download), encoding='utf-8')
    result = importer.import_file(source, destination)
    assert result['imported_source_sha256'] == hashlib.sha256(source.read_bytes()).hexdigest()
    assert json.loads(destination.read_text()) == result
    assert not list(tmp_path.glob('*.tmp'))


def test_path_traversal_is_rejected():
    with pytest.raises(ValueError, match='escapes project'):
        importer.local_path(ROOT, '../outside.png')
