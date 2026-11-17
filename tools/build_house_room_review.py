"""Build the local room-art review and user-operated doorway placement page."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'assets/rooms/house-02/furnishing-review'


def build():
    batch = json.loads((FOLDER / 'batch.json').read_text(encoding='utf-8'))
    layout = json.loads((FOLDER / 'layout-proposal.json').read_text(encoding='utf-8'))
    previews = json.loads((FOLDER / 'guest-preview-data.json').read_text(encoding='utf-8'))
    screens = {s['id']: s for s in layout['screens']}
    names = {s['id']: s['name'] for s in layout['screens']}
    imported = {}
    positions_path = ROOT / 'assets/maps/house-02.door-positions.json'
    if batch.get('door_placement', {}).get('status') == 'user_export_received' and positions_path.is_file():
        positions = json.loads(positions_path.read_text(encoding='utf-8'))
        imported = {r['id']: r for r in positions['rooms']}
    rooms = []
    for record in batch['records']:
        room = dict(record)
        room['markers'] = [dict(id=p['id'], kind='door', target=p['target'],
                                side=p['side'], at=p['at'],
                                label=f"{names[p['target']]} ({p['side']})")
                           for p in screens[record['id']]['portals']]
        if record['id'] == 'library':
            room['markers'].append(dict(id='library-secret-panel', kind='secret_panel',
                                        target='secret_passage', side='north', at=[360, 64],
                                        label='Hidden passage panel'))
        if record['id'] == 'secret_passage':
            room['markers'] += [
                dict(id='passage-library-panel', kind='secret_return', target='library',
                     side='west', at=[30, 180], label='Library panel'),
                dict(id='passage-study-exit', kind='secret_exit', target='kitchen',
                     side='east', at=[436, 179], label='Study panel')]
        if record['id'] in imported:
            saved_room = imported[record['id']]
            assert saved_room['image_sha256'] == record['sha256']
            saved_markers = {m['id']: m for m in saved_room['markers']}
            accepted = batch['door_placement'].get('unchanged_accepted', [])
            for marker in room['markers']:
                saved = saved_markers[marker['id']]
                marker['at'] = saved['at']
                marker['placed'] = saved['placed'] or marker['id'] in accepted
        rooms.append(room)
    esc = html.escape
    head = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>House 02 · Rooms, guests and foreground masks</title>
<style>*{box-sizing:border-box}body{margin:0;background:#10151e;color:#e9e7e1;font:16px system-ui,sans-serif}
header,main{max-width:1280px;margin:auto;padding:24px}h1{font-size:28px;margin:0 0 10px}p{line-height:1.55;color:#bbc4d2}
nav{display:flex;flex-wrap:wrap;gap:8px;background:#10151ef5;padding:12px 0}a{color:#edc788}
nav a,button,select{padding:9px 13px;border:1px solid #4e5a6b;border-radius:7px;background:#202a39;color:#f4e6c9;text-decoration:none}
button,select{cursor:pointer}button[aria-pressed=true]{background:#345941}.notice{padding:12px 16px;background:#2b2720;border-left:3px solid #d2a457}
article{padding:12px 0 40px;scroll-margin-top:12px;border-top:1px solid #354252}h2{font-size:24px;margin:16px 0 6px}
.stage{position:relative;line-height:0}img{display:block;width:100%;height:auto;background:#19222e;border-radius:6px}
svg{position:absolute;inset:0;width:100%;height:100%;display:none;pointer-events:none}
.editing .door-overlay{display:block;pointer-events:auto;cursor:crosshair;touch-action:none;z-index:3}.door-marker{cursor:grab}
.guest-overlay{display:block;z-index:2}.guest-editing .guest-overlay{pointer-events:auto;cursor:crosshair;touch-action:none}
.guest-controls{padding:14px;background:#192331;border:1px solid #344759;border-radius:8px;margin:10px 0}
.guest-controls strong{display:block;margin-bottom:10px}.guest-controls button{margin:3px}
.guest-options,.mask-options{display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin-top:8px}
.mask-options input{width:85px;padding:6px;background:#10151e;color:white;border:1px solid #536070}
.guest-note{font-size:13px;margin-bottom:0}.guest-controls span{color:#a7c7d8;font-size:13px}
.door-controls{display:flex;align-items:center;gap:10px;flex-wrap:wrap;padding:10px 0}.coordinates,.meta{font-size:13px;color:#98a8ba}
details{margin-top:12px}details img{max-width:800px;margin-top:12px}.label{color:#eac079}
</style><header><h1>House 02 · Guest placement and foreground masks</h1>
<p>Room artwork review and door placement. Accepted positions can still be adjusted here for a subsequent revision.</p>
<div class="notice">Choose <b>Place doors</b> on a room, select a destination, then click the floor at the door's threshold or drag its marker.
Green means placed; amber means an old placeholder. Position each marker where the player's feet should trigger the transition.
The original coordinates do not constrain your placement. Hidden passage panels can be positioned too.</div>
<p>Your changes save in this browser, separately for each exact image revision. When finished, download the positions and provide that JSON for integration.
This editor does not change the playable map or approve other artwork.</p>
<button id="download-doors" type="button">Download door positions</button>
<p id="placement-status" role="status"></p><nav>'''
    head += ''.join(f'<a href="#{r["id"]}">{esc(r["name"])}</a>' for r in rooms)
    parts = [head + '''</nav><div class="notice"><b>Guest placement:</b> choose Char or Chris, posture and facing, then Add guest slot.
Click or drag its anchor: feet for standing, seat for seated. Slots are generic placements; the preview character does not lock the case cast.
Seated contacts are provisional estimates. Draw foreground mask polygons around the furniture parts that should cover a guest, then Finish mask.
Each new mask defaults to its own bottom edge for depth. Guests whose anchor (feet when standing, seat when seated) is behind that depth are covered; guests in front remain visible.
Use mask bottom edge repairs a selected mask's depth; a custom furniture front depth can also be applied.
View scene hides editing outlines. Source artwork is unchanged; masks redraw selected background pixels above the guest.</div>
<p>Character scale uses the shared 80-unit standing reference. Chair-back separation and exact furniture fit need visual review.</p>
<button id="download-guests" type="button">Download guest positions and masks</button>
<p id="guest-status" role="status">Guest placements save automatically in this browser.</p></header><main>''']
    for r in rooms:
        assert (FOLDER / r['image']).is_file()
        assert (FOLDER / r['guide']).is_file()
        connections = ', '.join(m['label'] for m in r['markers'])
        parts.append(f'''<article id="{r['id']}"><h2>{esc(r['name'])}</h2>
<p>{esc(r['notes'])}</p><p class="label">Connections: {esc(connections)}</p>
<div class="door-controls"></div><div class="stage">
<a href="{esc(r['image'], quote=True)}"><img src="{esc(r['image'], quote=True)}" alt="{esc(r['name'])} room candidate"></a>
<svg class="door-overlay" viewBox="0 0 480 360" preserveAspectRatio="none" aria-label="Door position overlay"></svg></div>
<p class="meta">{esc(r['image'])} · {esc(r['status'].replace('_', ' '))}</p>
<details><summary>Earlier furniture proposal — provisional geometry</summary>
<img loading="lazy" src="{esc(r['guide'], quote=True)}" alt="{esc(r['name'])} earlier footprint guide"></details></article>''')
    encoded = json.dumps(rooms, ensure_ascii=False).replace('<', '\\u003c')
    preview_json = json.dumps(previews, ensure_ascii=False).replace('<', '\\u003c')
    parts.append('</main><script type="application/json" id="room-data">' + encoded +
                 '</script><script type="application/json" id="guest-preview-data">' + preview_json +
                 '</script><script src="door-markers.js"></script><script src="guest-placement.js"></script></html>')
    (FOLDER / 'index.html').write_text('\n'.join(parts), encoding='utf-8')
    print(f'Built {len(rooms)} room reviews with {sum(len(r["markers"]) for r in rooms)} door/panel markers.')


if __name__ == '__main__':
    build()
