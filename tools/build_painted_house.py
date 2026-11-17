"""Calibrate an opt-in walking preview to approved artwork and user door points.

Art is never modified. Original house-02 remains a separate, unchanged blockout.
The masks below are initial floor/furniture measurements, not guest placements.
"""
import hashlib
import json
import math
from pathlib import Path

from check_image_approval import check

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / 'assets/rooms/house-02/furnishing-review'
POSITIONS = ROOT / 'assets/maps/house-02.door-positions.json'
OUTPUT = ROOT / 'assets/maps/house-02.painted.layout.json'

# Coordinates describe painted floor contacts in the common 480x360 world.
MASKS = {
    'library': ([(50, 118), (426, 118), (478, 298), (478, 320), (2, 320), (2, 298)],
                [(101, 137, 147, 69), (18, 249, 130, 46), (365, 236, 73, 59),
                 (427, 254, 29, 41), (438, 159, 42, 111), (401, 96, 25, 30), (54, 109, 26, 20)]),
    'kitchen': ([(62, 121), (420, 121), (477, 284), (477, 290), (3, 290), (3, 284)],
                [(70, 145, 60, 41), (130, 159, 25, 27), (12, 218, 96, 48),
                 (330, 197, 100, 65), (349, 176, 30, 27), (402, 113, 32, 38), (49, 110, 30, 22)]),
    'room': ([(50, 130), (430, 130), (478, 290), (478, 302), (2, 302), (2, 290)],
             [(176, 127, 104, 73), (153, 118, 31, 30), (274, 118, 28, 30),
              (10, 153, 62, 47), (34, 222, 50, 40), (78, 223, 34, 32),
              (360, 115, 60, 40), (437, 202, 40, 67)]),
    'room_2': ([(48, 110), (427, 110), (478, 303), (2, 303)],
               [(174, 205, 132, 52), (197, 177, 83, 32), (182, 128, 44, 50),
                (252, 128, 44, 50), (62, 108, 83, 28), (11, 175, 44, 84),
                (145, 106, 24, 19)]),
    'room_3': ([(60, 117), (420, 117), (478, 304), (2, 304)],
               [(100, 114, 71, 80), (178, 112, 29, 27), (349, 123, 78, 59),
                (330, 242, 95, 52), (356, 218, 32, 29), (19, 262, 40, 35)]),
    'room_4': ([(75, 139), (419, 139), (478, 285), (2, 285)],
               [(116, 145, 129, 78), (142, 216, 27, 30), (193, 216, 27, 30),
                (103, 111, 275, 31), (40, 115, 41, 61), (388, 98, 43, 47), (417, 139, 30, 28)]),
    'room_5': ([(52, 136), (428, 136), (478, 291), (2, 291)],
               [(133, 169, 217, 86), (82, 117, 67, 17), (353, 113, 72, 24)]),
    'room_6': ([(30, 150), (450, 150), (478, 322), (2, 322)],
               [(36, 148, 28, 27), (108, 148, 28, 12), (344, 148, 28, 12),
                (416, 148, 28, 27), (64, 151, 40, 26), (376, 151, 40, 26)]),
    'secret_passage': ([(12, 175), (468, 175), (478, 198), (2, 198)],
                       [(65, 167, 90, 10), (280, 168, 43, 9), (380, 169, 28, 8),
                        (100, 192, 95, 8), (210, 194, 74, 6)]),
    'hall_2': ([(178, 73), (303, 73), (478, 305), (478, 352), (2, 352), (2, 305)],
               [(112, 132, 28, 25), (341, 132, 28, 25)]),
    'room_7': ([(45, 132), (433, 132), (478, 284), (2, 284)],
               [(60, 115, 360, 16), (14, 239, 72, 47), (145, 242, 55, 43), (275, 243, 53, 43)])
}

# Actual floor/arch mouths measured from the approved paintings. The user's
# original marker remains portal.at; these are separate walking thresholds.
NORTH_THRESHOLDS = {
    'kitchen--door': 124,
    'room_3--door_2': 121,
    'room_5--door_2': 132,
    'room_6--door': 150,
    'hall_2--door_2': 80,
}


def walking_threshold(screen, portal):
    x, y = portal['at']
    fx, fy = portal['facing']
    threshold = [x - fx * 12, y - fy * 12]
    if fx:
        threshold[1] += 24
        trigger_ends = [threshold[0]-fx*6, x+fx*8]
        trigger = [min(trigger_ends), threshold[1]-30, abs(trigger_ends[1]-trigger_ends[0]), 60]
        ends = [threshold[0]-fx*64, threshold[0]+fx*8]
        access = [min(ends), threshold[1]-30, abs(ends[1]-ends[0]), 60]
    else:
        if fy < 0:
            threshold[1] = NORTH_THRESHOLDS.get(portal['id'], threshold[1])
        trigger_ends = [threshold[1]-fy*6, y+fy*8]
        trigger = [threshold[0]-28, min(trigger_ends), 56, abs(trigger_ends[1]-trigger_ends[0])]
        ends = [threshold[1]-fy*64, threshold[1]+fy*8]
        access = [threshold[0]-28, min(ends), 56, abs(ends[1]-ends[0])]
    # The north dining doorway has a shorter final approach behind the table;
    # the rest of the route goes around its solid body, not through it.
    approach_distance = 28 if portal['id'] == 'room_5--door_2' else 48
    portal['activation_at'] = threshold
    portal['trigger_region'] = trigger
    portal['approach_start'] = [threshold[0]-fx*approach_distance, threshold[1]-fy*approach_distance]
    screen['door_access_regions'].append(access)


def in_rect(p, r, strict=False):
    x, y, w, h = r
    return (x < p[0] < x+w and y < p[1] < y+h) if strict else (x <= p[0] <= x+w and y <= p[1] <= y+h)


def in_polygon(p, poly):
    inside = False
    for a, b in zip(poly, poly[1:] + poly[:1]):
        if (a[1] > p[1]) != (b[1] > p[1]):
            crossing = a[0] + (p[1]-a[1]) * (b[0]-a[0]) / (b[1]-a[1])
            if p[0] < crossing:
                inside = not inside
    return inside


def is_open(s, p):
    inside = in_polygon(p, s['walk_polygons'][0]) or any(in_rect(p, r) for r in s['door_access_regions'])
    return inside and not any(in_rect(p, r, True) for r in s['obstacles'])


def nearest(s, p):
    points = ((x, y) for x in range(4, 479, 2) for y in range(4, 357, 2) if is_open(s, (x, y)))
    return min(points, key=lambda q: math.dist(p, q))


def connect(s, at):
    assert not any(in_rect(at, r, True) for r in s['obstacles']), (s['id'], 'marker in furniture', at)
    q = nearest(s, at)
    # Local doorway/panel approach cutout. Furniture remains solid inside it.
    pad = 7
    left, top = max(0, min(q[0], at[0])-pad), max(0, min(q[1], at[1])-pad)
    right, bottom = min(480, max(q[0], at[0])+pad), min(360, max(q[1], at[1])+pad)
    s['door_access_regions'].append([left, top, right-left, bottom-top])


def build():
    batch = json.loads((REVIEW / 'batch.json').read_text(encoding='utf-8'))
    check(batch, ROOT)
    raw = json.loads(POSITIONS.read_text(encoding='utf-8'))
    assert raw['schema'] == 'house02-door-placement-v1' and raw['coordinates'] == [480, 360]
    placed = {r['id']: r for r in raw['rooms']}
    art = {r['id']: r for r in batch['records']}
    layout = json.loads((ROOT / 'assets/maps/house-02.layout.json').read_text())
    screens = {s['id']: s for s in layout['screens']}
    assert set(placed) == set(screens) == set(art)
    by_id = {}
    for sid, s in screens.items():
        assert placed[sid]['image_sha256'] == art[sid]['sha256']
        poly, furniture = MASKS[sid]
        s['walk_polygons'] = [poly]
        s['door_access_regions'] = []
        s['obstacles'] = list(furniture)
        s['obstacle_kinds'] = ['painted_furniture'] * len(furniture)
        s['background'] = 'res://' + (ROOT / art[sid]['path']).resolve().relative_to(ROOT).as_posix()
        s['background_sha256'] = art[sid]['sha256']
        # Guest placement is a separate user review, not inherited blockout spots.
        s['guest_spots'], s['guest_spot_kinds'], s['guest_spot_facing'] = [], [], []
        s.pop('item_slot', None)
        markers = {m['id']: m for m in placed[sid]['markers']}
        for m in markers.values():
            assert m['placed'] or m['id'] in batch['door_placement']['unchanged_accepted']
            assert len(m['at']) == 2 and all(isinstance(v, (int, float)) and math.isfinite(v) for v in m['at'])
            assert 0 <= m['at'][0] <= 480 and 0 <= m['at'][1] <= 360
            connect(s, m['at'])
        for portal in s['portals']:
            m = markers[portal['id']]
            assert m['target'] == portal['target'] and m['kind'] == 'door'
            portal['at'] = m['at']
            by_id[portal['id']] = portal
            walking_threshold(s, portal)
            if sid in ('hall_2', 'room_2') and portal['side'] in ('east', 'west'):
                # These painted side walls recede diagonally. The old nearest-
                # point cutout missed the carpet below the selected door leaf.
                # Extend an approach from the floor below it, keeping actual
                # furniture solid. Living-room v2 removed the old console.
                x, y = portal['at']
                inward_x = x - portal['facing'][0] * 64
                left, right = max(0, min(x, inward_x)-8), min(480, max(x, inward_x)+8)
                top, bottom = max(0, y-8), min(360, y+46)
                s['door_access_regions'].append([left, top, right-left, bottom-top])
        s['spawn'] = list(nearest(s, (240, 250)))
    for s in screens.values():
        for p in s['portals']:
            other = by_id[p['link']]
            assert other['target'] == s['id']
            inward = [other['activation_at'][i] - other['facing'][i] * 24 for i in range(2)]
            p['arrival'] = list(nearest(screens[p['target']], inward))
    secret = layout['secret']
    all_markers = {m['id']: m for r in placed.values() for m in r['markers']}
    secret['panel_at'] = all_markers['library-secret-panel']['at']
    secret['return_at'] = all_markers['passage-library-panel']['at']
    secret['exit_at'] = all_markers['passage-study-exit']['at']
    secret['passage_arrival'] = list(nearest(screens['secret_passage'], (45, 185)))
    secret['library_arrival'] = list(nearest(screens['library'], (302, 120)))
    secret['study_arrival'] = screens['kitchen']['spawn']
    layout['presentation'] = 'approved_painted_walkthrough'
    layout['source_door_positions'] = 'assets/maps/house-02.door-positions.json'
    layout['calibration'] = 'Painted floor thresholds and broad directional door lanes; original user markers preserved. Guest and item placements are separate.'
    OUTPUT.write_text(json.dumps(layout, indent=2) + '\n', encoding='utf-8')
    print('Built approved painted layout: 11 rooms, 24 directed doors, 3 secret-panel markers.')


if __name__ == '__main__':
    build()
