"""Validate a room-editor download for native fit previews; never promote artwork.

The input's authored slots and masks are preserved. Current indexed PNGs remain
unchanged, including poses whose older approval records use a legacy format.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
import tempfile
from pathlib import Path

from check_image_approval import check as approval_check

ROOT = Path(__file__).resolve().parents[1]
REVIEW = Path('assets/rooms/house-02/furnishing-review')
OUTPUT = Path('assets/maps/house-02.guest-positions.json')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def point(value, extent=(480, 360)):
    return (isinstance(value, list) and len(value) == 2
            and all(number(v) and 0 <= v <= limit for v, limit in zip(value, extent)))


def local_path(root, value):
    require(isinstance(value, str), 'Asset path must be text')
    candidate = (root / value.removeprefix('res://')).resolve()
    require(candidate.is_relative_to(root.resolve()), 'Asset path escapes project: ' + value)
    require(candidate.is_file(), 'Asset is missing: ' + value)
    return candidate


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def polygon_area(points):
    return abs(sum(a[0]*b[1] - b[0]*a[1]
                   for a, b in zip(points, points[1:] + points[:1]))) / 2


def self_crosses(points):
    def side(a, b, c):
        return (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0])
    edges = list(zip(points, points[1:] + points[:1]))
    for i, (a, b) in enumerate(edges):
        for j, (c, d) in enumerate(edges):
            if j <= i + 1 or (i == 0 and j == len(edges)-1):
                continue
            if side(a,b,c)*side(a,b,d) < 0 and side(c,d,a)*side(c,d,b) < 0:
                return True
    return False


def asset_approval(root, row):
    """Check existing exact evidence; report legacy evidence without inventing it."""
    owners = [row]
    if row.get('landmark_record'):
        owners.append(json.loads(local_path(root, row['landmark_record']).read_text(encoding='utf-8')))
    for owner in owners:
        if owner.get('image_approval'):
            approval_check(owner, root)
            files = owner['image_approval']['files']
            if any(local_path(root, f['path']) == local_path(root, row['export'])
                   and f['sha256'] == row['export_sha256'] for f in files):
                return {'status': 'exact_record_preflight_passed'}
    # The earliest seven Char poses predate the generic preflight schema.
    for owner in owners:
        legacy = owner.get('approval_record', {})
        if (legacy.get('decision') == 'approved_pose_samples'
                and row['pose_id'] in legacy.get('pose_ids', [])):
            scoped = {'image_approval': {
                'status': 'approved', 'evidence': {k: legacy.get(k) for k in ('date','source','quote')},
                'scope': legacy.get('scope'),
                'files': [{'path': row['export'], 'sha256': row['export_sha256']}],
            }}
            approval_check(scoped, root)
            return {'status': 'legacy_exact_record_preflight_passed',
                    'note': 'Existing legacy approval normalized in memory; no approval metadata changed.'}
    require(row.get('approval') in ('approved', 'user_supplied_added_to_project'),
            'Pose is not selected as approved in the current index: ' + row['pose_id'])
    return {'status': 'legacy_index_approval_only',
            'note': 'Existing indexed preview asset. Exact dated generic approval evidence is absent; no new approval inferred.'}


def validate_import(data, *, root=ROOT, source_sha256=''):
    require(isinstance(data, dict) and data.get('schema') == 'house02-guest-placement-v1', 'Unexpected guest-placement schema')
    require(data.get('coordinates') == [480, 360], 'Expected 480x360 coordinates')
    require(isinstance(data.get('rooms'), list), 'Rooms must be a list')
    batch = json.loads((root / REVIEW / 'batch.json').read_text(encoding='utf-8'))
    rooms = {r['id']: r for r in batch['records']}
    ids = [r.get('id') for r in data['rooms'] if isinstance(r, dict)]
    require(len(ids) == len(rooms) and len(set(ids)) == len(ids) and set(ids) == set(rooms), 'Room IDs must match all approved rooms exactly once')
    preview = json.loads((root / REVIEW / 'guest-preview-data.json').read_text(encoding='utf-8'))
    require(number(preview.get('adult_height')) and preview['adult_height'] > 0, 'Invalid shared actor height')
    indexes = {}
    for actor in preview['actors']:
        slug = actor.lower()
        index = json.loads((root / f'assets/characters/poses/{slug}/directional-index.json').read_text(encoding='utf-8'))
        indexes[actor] = {p['pose_id']: p for p in index['assets']}
    result = copy.deepcopy(data)
    result.update(source_status=data.get('status'), status='preview_pending_fit', adult_height=preview['adult_height'],
                  imported_source_sha256=source_sha256)
    warnings = []
    all_ids = set()
    checked = {}
    for room in result['rooms']:
        approved = rooms[room['id']]
        require(room.get('image') == approved['image'], room['id'] + ': artwork path changed')
        require(room.get('image_sha256') == approved['sha256'], room['id'] + ': artwork revision changed')
        require(digest(local_path(root, approved['path'])) == approved['sha256'], room['id'] + ': room image hash changed')
        approval_check(approved, root)
        require(isinstance(room.get('guest_spots'), list) and isinstance(room.get('foreground_masks'), list), room['id'] + ': invalid slot/mask lists')
        for slot in room['guest_spots']:
            require(isinstance(slot, dict) and isinstance(slot.get('id'), str) and slot['id'] and slot['id'] not in all_ids, 'Duplicate or missing guest/mask ID')
            all_ids.add(slot['id'])
            require(point(slot.get('at')) and point(slot.get('floor_at')), slot['id'] + ': invalid anchor/floor point')
            require(number(slot.get('depth_y')) and 0 <= slot['depth_y'] <= 360, slot['id'] + ': invalid sorting depth')
            actor = slot.get('preview_actor')
            require(actor in indexes, slot['id'] + ': unknown preview character')
            candidates = [p for p in preview['actors'][actor] if p['pose_id'] == slot.get('pose_id')]
            require(len(candidates) == 1 and slot['pose_id'] in indexes[actor], slot['id'] + ': unknown pose')
            p, row = candidates[0], indexes[actor][slot['pose_id']]
            require(all(slot.get(k) == p[k] for k in ('posture','activity','facing')), slot['id'] + ': pose does not match posture/activity/facing')
            require(slot.get('anchor_kind') == ('seat' if slot['posture'] == 'seated' else 'feet'), slot['id'] + ': wrong contact kind')
            require(slot.get('source_contact') == p['contact'], slot['id'] + ': contact measurement changed')
            require(p['source'] == row['export'] and p['sha256'] == row['export_sha256'], slot['id'] + ': preview/index revision mismatch')
            source = local_path(root, p['source'])
            require(digest(source) == p['sha256'], slot['id'] + ': pose PNG hash changed')
            require(point(p['contact'], p['size']) and number(p['standing_reference']) and p['standing_reference'] > 0, slot['id'] + ': invalid render measurement')
            scale = preview['adult_height'] / p['standing_reference']
            floor = [slot['at'][i] + (p['feet'][i]-p['contact'][i])*scale for i in range(2)]
            require(all(abs(a-b) < .001 for a,b in zip(floor,slot['floor_at'])), slot['id'] + ': exported floor point differs from measured pose')
            require(abs(slot['depth_y']-slot['at'][1]) < .001, slot['id'] + ': sorting depth must follow authored contact')
            identity = (actor, slot['pose_id'])
            if identity not in checked:
                checked[identity] = asset_approval(root, row)
                if checked[identity]['status'] == 'legacy_index_approval_only':
                    warnings.append(f'{actor}/{slot["pose_id"]}: legacy index approval; generic approval evidence needs reconciliation before future promotion.')
            slot['render'] = {k: copy.deepcopy(p[k]) for k in ('source','sha256','size','contact','standing_reference')}
            slot['render']['approval_preflight'] = checked[identity]
        for mask in room['foreground_masks']:
            require(isinstance(mask, dict) and isinstance(mask.get('id'), str) and mask['id'] and mask['id'] not in all_ids, 'Duplicate or missing guest/mask ID')
            all_ids.add(mask['id'])
            poly = mask.get('polygon')
            require(isinstance(poly, list) and len(poly) >= 3 and all(point(p) for p in poly), mask['id'] + ': invalid polygon')
            require(polygon_area(poly) > .01, mask['id'] + ': degenerate polygon')
            require(number(mask.get('depth_y')) and 0 <= mask['depth_y'] <= 360, mask['id'] + ': invalid mask depth')
            if self_crosses(poly):
                warnings.append(mask['id'] + ': polygon self-crosses; preserved for visual review.')
    result['validation'] = {'room_count': len(result['rooms']),
                            'guest_spots': sum(len(r['guest_spots']) for r in result['rooms']),
                            'foreground_masks': sum(len(r['foreground_masks']) for r in result['rooms']),
                            'warnings': warnings,
                            'scope': 'Exact artwork revisions and measured browser-preview geometry; not final furniture fit or gameplay integration.'}
    return result


def import_file(source, destination, *, root=ROOT):
    raw = Path(source).read_bytes()
    result = validate_import(json.loads(raw), root=root, source_sha256=hashlib.sha256(raw).hexdigest())
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', newline='\n', dir=destination.parent,
                                         prefix=destination.name+'.', suffix='.tmp', delete=False) as handle:
            temporary = handle.name
            json.dump(result, handle, indent=2, ensure_ascii=False)
            handle.write('\n')
        os.replace(temporary, destination)
    finally:
        if temporary and Path(temporary).exists():
            Path(temporary).unlink()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Guest positions and masks downloaded from the room editor')
    parser.add_argument('--output', type=Path, default=ROOT / OUTPUT)
    args = parser.parse_args()
    try:
        result = import_file(args.source, args.output)
    except (ValueError, TypeError, KeyError, OSError) as exc:
        parser.exit(1, 'GUEST_IMPORT_BLOCKED: '+str(exc)+'\n')
    print(json.dumps(result['validation'], indent=2))


if __name__ == '__main__':
    main()
