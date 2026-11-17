"""Join calibrated painted geometry to authored guest slots for an opt-in case.

Guest anchors, foreground polygons, artwork and door/collision coordinates are
preserved. Only interaction approaches and provisional gold item-marker positions
are derived from reachable floor; these are separate from the visual anchors.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from collections import deque
from pathlib import Path

from build_painted_house import in_polygon, in_rect
from import_house_guests import validate_import

ROOT = Path(__file__).resolve().parents[1]
PAINTED = Path('assets/maps/house-02.painted.layout.json')
GUESTS = Path('assets/maps/house-02.guest-positions.json')
OUTPUT = Path('assets/maps/house-02.investigation.layout.json')
GRID = 4


def is_open(screen, point):
    inside = any(in_polygon(point, poly) for poly in screen['walk_polygons'])
    inside = inside or any(in_rect(point, rect) for rect in screen.get('door_access_regions', []))
    return inside and not any(in_rect(point, rect, True) for rect in screen['obstacles'])


def connected_floor(screen):
    """Four-pixel reachability with midpoint checks, seeded from the real spawn."""
    points = {(x,y) for x in range(2,480,GRID) for y in range(2,360,GRID) if is_open(screen,(x,y))}
    if not points:
        raise ValueError(screen['id'] + ': no open floor')
    start = min(points, key=lambda p: (math.dist(p,screen['spawn']), p))
    if math.dist(start, screen['spawn']) > 6:
        raise ValueError(screen['id'] + ': spawn cannot connect to floor graph')
    reached, queue = {start}, deque([start])
    while queue:
        x,y = queue.popleft()
        for dx,dy in ((0,-GRID),(GRID,0),(0,GRID),(-GRID,0)):
            other = (x+dx,y+dy)
            if other in points and other not in reached and is_open(screen,(x+dx/2,y+dy/2)):
                reached.add(other)
                queue.append(other)
    return sorted(reached)


def approach(screen, slot, reachable):
    anchor = slot['at']
    # Stay on reachable floor, not inside a seat/table collider. A little room
    # around the approach prevents choosing a point exactly against furniture.
    roomy = [p for p in reachable if all(is_open(screen,(p[0]+dx,p[1]+dy))
                                       for dx,dy in ((-2,0),(2,0),(0,-2),(0,2)))]
    return min(roomy or reachable, key=lambda p: (math.dist(p,anchor),p))


def furniture_distance(point, screen):
    distances = [math.hypot(max(x-point[0],0,point[0]-x-w), max(y-point[1],0,point[1]-y-h))
                 for x,y,w,h in screen['obstacles']]
    return min(distances, default=40)


def item_position(screen, reachable):
    doors = [p['at'] for p in screen['portals']]
    contacts = [s['interaction_at'] for s in screen['guest_slots']]
    def clearance(point, anchors):
        return min((math.dist(point,a) for a in anchors), default=480)
    candidates = [p for p in reachable if clearance(p,doors) >= 32 and clearance(p,contacts) >= 32
                  and all(is_open(screen,(p[0]+dx,p[1]+dy)) for dx,dy in ((-4,0),(4,0),(0,-4),(0,4)))]
    if not candidates:
        candidates = [p for p in reachable if clearance(p,doors) >= 24]
    if not candidates:
        raise ValueError(screen['id'] + ': no reachable item position away from door thresholds')
    # Prefer an obvious floor marker near furnishing, rather than borrowing a
    # pre-painting item point whose art/obstacle assumptions are now obsolete.
    return min(candidates, key=lambda p: (abs(furniture_distance(p,screen)-16)+math.dist(p,(240,220))*.15,p))


def build_layout(painted, guests, preview, source_guest_sha256=''):
    result = copy.deepcopy(painted)
    rooms = {r['id']:r for r in guests['rooms']}
    if set(rooms) != {s['id'] for s in result['screens']}:
        raise ValueError('Painted room IDs and guest export must match')
    warnings = []
    slot_count, mask_count, item_count = 0,0,0
    for screen in result['screens']:
        room = rooms[screen['id']]
        if screen['background_sha256'] != room['image_sha256']:
            raise ValueError(screen['id'] + ': guest export belongs to a different painting')
        reachable = connected_floor(screen)
        slots = copy.deepcopy(room['guest_spots'])
        for slot in slots:
            slot['interaction_at'] = list(approach(screen,slot,reachable))
            slot['interaction_distance'] = round(math.dist(slot['at'],slot['interaction_at']),3)
            slot['preview_activity'] = slot['activity']
            # Both approved preview characters must actually have the activity
            # for this posture/facing. For example, no north chair nap exists.
            available = []
            requested = ('idle','read','sleep') if slot['posture'] == 'seated' else ('idle','read','look_up','look_down')
            for activity in requested:
                if all(any(p['posture']==slot['posture'] and p['facing']==slot['facing'] and p['activity']==activity
                           for p in poses) for poses in preview['actors'].values()):
                    available.append(activity)
            slot['activities'] = available
            if not available:
                raise ValueError(slot['id'] + ': no supported activities')
            if slot['interaction_distance'] > 48:
                warnings.append(slot['id'] + ': interaction approach is %.1f pixels from its visual anchor.' % slot['interaction_distance'])
        screen['guest_slots'] = slots
        screen['guest_spots'] = [s['at'] for s in slots]
        screen['guest_spot_kinds'] = ['seat' if s['posture']=='seated' else 'stand' for s in slots]
        screen['guest_spot_facing'] = [s['facing'] for s in slots]
        screen['foreground_masks'] = copy.deepcopy(room['foreground_masks'])
        slot_count += len(slots)
        mask_count += len(room['foreground_masks'])
        if screen['role'] != 'hall':
            screen['item_slot'] = list(item_position(screen,reachable))
            screen['item_slot_status'] = 'provisional_reachable_floor_marker'
            item_count += 1
        else:
            screen.pop('item_slot',None)
    if slot_count < 6:
        raise ValueError('The six-suspect case needs at least six authored guest slots')
    result.update(mode='painted_investigation',
                  source_guest_positions='res://'+GUESTS.as_posix(),
                  source_guest_positions_sha256=source_guest_sha256,
                  calibration='User-authored guest anchors/masks preserved; reachable interaction approaches and item floor markers are provisional.',
                  investigation_validation={'guest_slots':slot_count,'foreground_masks':mask_count,'item_slots':item_count,
                                            'approach_grid':GRID,'warnings':warnings})
    return result


def build(root=ROOT, output=None):
    painted = json.loads((root/PAINTED).read_text(encoding='utf-8'))
    guests = validate_import(json.loads((root/GUESTS).read_text(encoding='utf-8')), root=root)
    preview = json.loads((root/'assets/rooms/house-02/furnishing-review/guest-preview-data.json').read_text(encoding='utf-8'))
    result = build_layout(painted,guests,preview,hashlib.sha256((root/GUESTS).read_bytes()).hexdigest())
    destination = Path(output) if output else root/OUTPUT
    destination.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/OUTPUT)
    args=parser.parse_args()
    result=build(output=args.output)
    print(json.dumps(result['investigation_validation'],indent=2))


if __name__=='__main__':
    main()
