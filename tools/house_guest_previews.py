"""Read-only measurements of existing Char/Chris exports for placement previews."""
import hashlib
import json
import statistics
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/rooms/house-02/furnishing-review/guest-preview-data.json'


def build():
    data = {'schema': 'house02-guest-previews-v1', 'adult_height': 80, 'actors': {}}
    allowed = {'standing': {'idle', 'read', 'look_up', 'look_down'}, 'seated': {'idle', 'read', 'sleep'}}
    for slug, name in [('char', 'Char'), ('chris', 'Chris')]:
        catalog = json.loads((ROOT / f'assets/characters/poses/{slug}/directional-index.json').read_text())
        assets = catalog['assets']
        standing = next(r for r in assets if r['pose_id'] == 'standing_idle_south')
        with Image.open(ROOT / standing['export']) as im:
            standing_height = im.getchannel('A').point(lambda p: 255 if p >= 128 else 0).getbbox()[3]
            bounds = im.getchannel('A').point(lambda p: 255 if p >= 128 else 0).getbbox()
            standing_height -= bounds[1]
        result = []
        for r in assets:
            posture, activity = r.get('posture'), r.get('activity')
            if activity not in allowed.get(posture, set()):
                continue
            path = ROOT / r['export']
            assert hashlib.sha256(path.read_bytes()).hexdigest() == r['export_sha256']
            with Image.open(path) as im:
                alpha = im.getchannel('A').point(lambda p: 255 if p >= 128 else 0)
                box = alpha.getbbox()
                left, top, right, bottom = box
                axes = []
                for y in range(int(top+(bottom-top)*.3), int(top+(bottom-top)*.55)):
                    row = alpha.crop((left, y, right, y+1)).getbbox()
                    if row: axes.append(left+(row[0]+row[2]-1)/2)
                axis = statistics.median(axes) if axes else (left+right)/2
                contact = [axis, bottom]
                contact_status = 'feet'
                if posture == 'seated':
                    contact = [axis, top+(bottom-top)*.60]
                    contact_status = 'estimated_seat'
                    meta_path = ROOT / r.get('landmark_record', '')
                    if meta_path.is_file():
                        meta = json.loads(meta_path.read_text())
                        if meta.get('export_contact'):
                            contact = meta['export_contact']
                            contact_status = 'existing_provisional_seat'
                result.append({
                    'pose_id': r['pose_id'], 'posture': posture, 'activity': activity,
                    'facing': r['actor_facing'], 'source': r['export'], 'sha256': r['export_sha256'],
                    'url': f'/guest-art/{slug}/{r["pose_id"]}.png', 'size': list(im.size),
                    'bounds': list(box), 'feet': [axis, bottom], 'contact': contact,
                    'contact_status': contact_status,
                    'standing_reference': r.get('standing_reference_height') or standing_height
                })
        data['actors'][name] = result
    OUTPUT.write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8')
    print('Measured', sum(len(v) for v in data['actors'].values()), 'unchanged character exports.')


if __name__ == '__main__':
    build()
