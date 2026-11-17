"""The painted case retains authored geometry while providing reachable actions."""
import copy
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import pytest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('build_house_investigation',ROOT/'tools/build_house_investigation.py')
builder=importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


@pytest.fixture(scope='module')
def inputs():
    painted=json.loads((ROOT/builder.PAINTED).read_text())
    guests=json.loads((ROOT/builder.GUESTS).read_text())
    preview=json.loads((ROOT/'assets/rooms/house-02/furnishing-review/guest-preview-data.json').read_text())
    return painted,guests,preview


@pytest.fixture(scope='module')
def investigation(inputs):
    return builder.build_layout(*inputs)


def test_authored_guest_slots_masks_and_painted_geometry_are_preserved(inputs,investigation):
    painted,guests,_=inputs
    by_room={r['id']:r for r in guests['rooms']}
    assert investigation['presentation']==painted['presentation']
    assert investigation['mode']=='painted_investigation'
    assert investigation['secret']==painted['secret']
    assert investigation['start']==painted['start']
    count=0
    for old,new in zip(painted['screens'],investigation['screens']):
        for key in ('portals','obstacles','obstacle_kinds','walk_polygons','door_access_regions','spawn','background','background_sha256'):
            assert old[key]==new[key],(new['id'],key)
        source=by_room[new['id']]
        assert new['foreground_masks']==source['foreground_masks']
        assert len(new['guest_slots'])==len(source['guest_spots'])
        for authored,native in zip(source['guest_spots'],new['guest_slots']):
            assert {k:native[k] for k in authored}==authored
            assert native['preview_activity']==authored['activity']
            assert native['facing']==authored['facing']
            assert native['posture']==authored['posture']
        count+=len(new['portals'])
        assert new['guest_spots']==[s['at'] for s in new['guest_slots']]
        assert new['guest_spot_facing']==[s['facing'] for s in new['guest_slots']]
    assert count==24
    report=investigation['investigation_validation']
    assert report['guest_slots']==55
    assert report['foreground_masks']==19
    assert report['item_slots']==10
    assert not report['warnings']


def test_all55_guest_interactions_and10_item_markers_reachable(investigation):
    guests,items=0,0
    for screen in investigation['screens']:
        connected=set(builder.connected_floor(screen))
        for slot in screen['guest_slots']:
            p=tuple(slot['interaction_at'])
            assert p in connected,slot['id']
            assert builder.is_open(screen,p),slot['id']
            assert math.dist(p,slot['at'])<=48,slot['id']
            guests+=1
        if screen['role']=='hall':
            assert 'item_slot' not in screen
        else:
            p=tuple(screen['item_slot'])
            assert p in connected
            assert screen['item_slot_status']=='provisional_reachable_floor_marker'
            assert all(math.dist(p,d['at'])>=24 for d in screen['portals'])
            items+=1
    assert guests==55 and items==10


def test_selected_activities_have_compatible_existing_poses(inputs,investigation):
    preview=inputs[2]
    for screen in investigation['screens']:
        for slot in screen['guest_slots']:
            assert 'idle' in slot['activities']
            assert 'read' in slot['activities']
            for activity in slot['activities']:
                for actor,poses in preview['actors'].items():
                    assert any(p['facing']==slot['facing'] and p['posture']==slot['posture'] and p['activity']==activity for p in poses),(actor,slot['id'],activity)
            if slot['facing']=='north':
                assert 'sleep' not in slot['activities']
                assert 'look_down' not in slot['activities']


def test_layout_builder_does_not_mutate_sources(inputs):
    before=copy.deepcopy(inputs)
    first=builder.build_layout(*inputs)
    assert inputs==before
    assert first==builder.build_layout(*inputs)


def test_real_build_checks_hashes_and_preserves_existing_painted_file(tmp_path):
    before=hashlib.sha256((ROOT/builder.PAINTED).read_bytes()).hexdigest()
    destination=tmp_path/'case.layout.json'
    generated=builder.build(output=destination)
    assert json.loads(destination.read_text())==generated
    assert generated['source_guest_positions_sha256']==hashlib.sha256((ROOT/builder.GUESTS).read_bytes()).hexdigest()
    assert hashlib.sha256((ROOT/builder.PAINTED).read_bytes()).hexdigest()==before


def test_wrong_art_revision_is_rejected(inputs):
    painted,guests,preview=copy.deepcopy(inputs)
    guests['rooms'][0]['image_sha256']='0'*64
    with pytest.raises(ValueError,match='different painting'):
        builder.build_layout(painted,guests,preview)


def test_missing_rooms_are_rejected(inputs):
    painted,guests,preview=copy.deepcopy(inputs)
    guests['rooms'].pop()
    with pytest.raises(ValueError,match='must match'):
        builder.build_layout(painted,guests,preview)
