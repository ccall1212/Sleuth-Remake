/* Generic guest slots, character fit previews and non-destructive foreground masks. */
(() => {
  'use strict';
  const rooms = JSON.parse(document.getElementById('room-data').textContent);
  const art = JSON.parse(document.getElementById('guest-preview-data').textContent);
  const ns = 'http://www.w3.org/2000/svg';
  const states = [];
  const status = document.getElementById('guest-status');
  function node(tag, attrs = {}, text = '') {
    const n = document.createElementNS(ns, tag);
    Object.entries(attrs).forEach(([k, v]) => n.setAttribute(k, v));
    if (text) n.textContent = text;
    return n;
  }
  function optionSelect(label, values, parent) {
    const select = document.createElement('select');
    select.setAttribute('aria-label', label);
    values.forEach(([name, value]) => select.add(new Option(name, value)));
    parent.append(select);
    return select;
  }
  function button(text, parent, action) {
    const b = document.createElement('button');
    b.type = 'button'; b.textContent = text;
    b.addEventListener('click', action); parent.append(b); return b;
  }
  const pointOK = p => Array.isArray(p) && p.length === 2 &&
    p.every(Number.isFinite) && p[0] >= 0 && p[0] <= 480 && p[1] >= 0 && p[1] <= 360;
  function key(s) { return `house02-guests-v1:${s.room.id}:${s.room.sha256}`; }
  function save(s) {
    try { localStorage.setItem(key(s), JSON.stringify({ spots: s.spots, masks: s.masks })); }
    catch (_) { status.textContent = 'Browser storage unavailable; download before closing this tab.'; return; }
    status.textContent = `${states.reduce((n, v) => n + v.spots.length, 0)} guest slots · ${states.reduce((n, v) => n + v.masks.length, 0)} foreground masks. Saved in this browser.`;
  }
  function pose(spot) {
    return art.actors[spot.preview_actor].find(p => p.posture === spot.posture && p.facing === spot.facing && p.activity === spot.activity);
  }
  function floorAt(spot) {
    const p = pose(spot);
    const scale = art.adult_height / p.standing_reference;
    return [spot.at[0] + (p.feet[0] - p.contact[0]) * scale,
      spot.at[1] + (p.feet[1] - p.contact[1]) * scale];
  }
  function syncMaskDepth(s) {
    const mask = s.masks.find(m => m.id === s.selectedMask);
    s.depth.value = mask ? mask.depth_y : '';
  }
  function draw(s) {
    if (s.maskSelect) {
      if (!s.masks.some(m => m.id === s.selectedMask)) {
        s.selectedMask = s.masks.at(-1)?.id || '';
        if (s.mode !== 'mask' && s.mode !== 'depth') syncMaskDepth(s);
      }
      s.maskSelect.replaceChildren();
      s.masks.forEach((m, index) => s.maskSelect.add(new Option(`Mask ${index + 1}`, m.id)));
      s.maskSelect.value = s.selectedMask;
    }
    s.svg.replaceChildren();
    const defs = node('defs'); s.svg.append(defs);
    // Seated feet extend beyond the chair. Sort by the seat contact so that
    // the chair front still covers its occupant; standing contacts are feet.
    const events = s.spots.map(spot => ({ type: 'guest', value: spot, depth: spot.at[1] }));
    s.masks.forEach((mask, index) => {
      const clipId = `${s.room.id}-mask-${index}`;
      const clip = node('clipPath', { id: clipId, clipPathUnits: 'userSpaceOnUse' });
      clip.append(node('polygon', { points: mask.polygon.map(p => p.join(',')).join(' ') }));
      defs.append(clip);
      events.push({ type: 'mask', value: mask, clipId, depth: mask.depth_y });
    });
    events.sort((a, b) => a.depth - b.depth || (a.type === 'guest' ? -1 : 1));
    for (const event of events) {
      if (event.type === 'mask') {
        s.svg.append(node('image', { href: s.room.image, x: 0, y: 0, width: 480, height: 360,
          preserveAspectRatio: 'none', 'clip-path': `url(#${event.clipId})`, 'pointer-events': 'none' }));
        continue;
      }
      const spot = event.value, p = pose(spot), scale = art.adult_height / p.standing_reference;
      const group = node('g', { 'data-spot': spot.id });
      group.append(node('image', { href: p.url, x: spot.at[0] - p.contact[0] * scale,
        y: spot.at[1] - p.contact[1] * scale, width: p.size[0] * scale, height: p.size[1] * scale,
        preserveAspectRatio: 'none', 'pointer-events': 'none' }));
      s.svg.append(group);
    }
    if (s.mode !== 'none') {
      s.spots.forEach((spot, index) => {
        s.svg.append(node('circle', { cx: spot.at[0], cy: spot.at[1], r: 4, fill: spot.id === s.selected ? '#fff085' : '#8affb4',
          stroke: '#10151e', 'stroke-width': 1, 'data-spot': spot.id }));
        s.svg.append(node('text', { x: spot.at[0] + 5, y: spot.at[1] - 5, fill: 'white', stroke: '#10151e',
          'stroke-width': 1.5, 'paint-order': 'stroke', 'font-size': 7, 'pointer-events': 'none' }, String(index + 1)));
      });
      s.masks.forEach((mask, index) => {
        s.svg.append(node('polygon', { points: mask.polygon.map(p => p.join(',')).join(' '),
          fill: '#f1aa441f', stroke: '#ffbd68', 'stroke-width': .7, 'pointer-events': 'none' }));
        s.svg.append(node('text', { x: mask.polygon[0][0], y: mask.polygon[0][1] - 3,
          fill: '#ffdf9b', 'font-size': 7, 'pointer-events': 'none' }, `Mask ${index + 1}`));
      });
    }
    if (s.draft.length) s.svg.append(node('polyline', { points: s.draft.map(p => p.join(',')).join(' '),
      fill: '#ffbb5544', stroke: '#ffe18a', 'stroke-width': 1, 'pointer-events': 'none' }));
    const spot = s.spots.find(v => v.id === s.selected);
    s.note.textContent = s.mode === 'depth' ? 'Click the floor at the furniture front edge, then continue drawing the mask corners. Existing corners are kept.' :
      s.mode === 'mask' ? `Click polygon corners around the furniture FRONT only. ${s.draft.length} corners. Finish mask when ready.` :
      spot ? `${spot.posture === 'seated' ? 'Seat anchor (provisional fit)' : 'Feet anchor'} · ${spot.at.join(', ')} · ${spot.facing}` : 'Add a generic guest slot, then choose Char or Chris to check its fit.';
  }
  function setMode(s, mode, keepDraft = false) {
    if (mode !== 'none') {
      const doorButton = s.article.querySelector('.door-controls button');
      if (doorButton && doorButton.getAttribute('aria-pressed') === 'true') doorButton.click();
    }
    s.mode = mode; if (!keepDraft) s.draft = []; s.dragging = false;
    // A previous mask's depth must not silently carry into a new polygon.
    if (mode === 'mask' && !keepDraft) s.depth.value = '';
    else if (mode !== 'mask' && mode !== 'depth') syncMaskDepth(s);
    s.stage.classList.toggle('guest-editing', mode !== 'none');
    s.modeLabel.textContent = mode === 'none' ? 'View only' : mode === 'mask' ? 'Drawing foreground mask' : mode === 'depth' ? 'Pick furniture front edge' : 'Placing guests';
    draw(s);
  }
  function syncChoices(s) {
    const selected = s.spots.find(v => v.id === s.selected);
    s.slot.replaceChildren();
    s.spots.forEach((spot, index) => s.slot.add(new Option(`Guest slot ${index + 1}`, spot.id)));
    s.slot.value = s.selected;
    if (!selected) return;
    s.actor.value = selected.preview_actor; s.posture.value = selected.posture;
    s.facing.value = selected.facing;
    const available = art.actors[selected.preview_actor].filter(p => p.posture === selected.posture && p.facing === selected.facing);
    s.activity.replaceChildren();
    available.forEach(p => s.activity.add(new Option(p.activity.replaceAll('_', ' '), p.activity)));
    s.activity.value = selected.activity;
  }
  rooms.forEach(room => {
    const article = document.getElementById(room.id), stage = article.querySelector('.stage');
    const controls = document.createElement('div'); controls.className = 'guest-controls';
    stage.before(controls);
    const s = { room, article, stage, svg: node('svg', { viewBox: '0 0 480 360', preserveAspectRatio: 'none',
      class: 'guest-overlay', 'aria-label': `${room.name} character and foreground preview` }),
      spots: [], masks: [], selected: '', mode: 'none', draft: [], dragging: false };
    states.push(s); stage.append(s.svg);
    try {
      const stored = JSON.parse(localStorage.getItem(key(s)) || 'null');
      if (stored && Array.isArray(stored.spots)) s.spots = stored.spots.filter(v => pointOK(v.at) && art.actors[v.preview_actor] && pose(v));
      if (stored && Array.isArray(stored.masks)) s.masks = stored.masks.filter(v => Array.isArray(v.polygon) && v.polygon.length >= 3 &&
        v.polygon.every(pointOK) && Number.isFinite(v.depth_y) && v.depth_y >= 0 && v.depth_y <= 360);
    } catch (_) { /* Malformed data does not prevent reviewing the rooms. */ }
    s.selected = s.spots[0]?.id || '';
    const label = document.createElement('strong'); label.textContent = 'Guest & foreground preview'; controls.append(label);
    button('Place guests', controls, () => setMode(s, 'guest'));
    button('Draw foreground mask', controls, () => setMode(s, 'mask'));
    button('View scene', controls, () => setMode(s, 'none'));
    s.modeLabel = document.createElement('span'); s.modeLabel.textContent = 'View only'; controls.append(s.modeLabel);
    const options = document.createElement('div'); options.className = 'guest-options'; controls.append(options);
    s.slot = optionSelect(`${room.name} guest slot`, [], options);
    s.actor = optionSelect(`${room.name} preview character`, [['Char', 'Char'], ['Chris', 'Chris']], options);
    s.posture = optionSelect(`${room.name} posture`, [['Standing', 'standing'], ['Seated', 'seated']], options);
    s.facing = optionSelect(`${room.name} facing`, ['south', 'east', 'west', 'north'].map(v => [v, v]), options);
    s.activity = optionSelect(`${room.name} activity`, [['idle', 'idle']], options);
    button('Add guest slot', options, () => {
      const actor = s.actor.value, posture = s.posture.value, facing = s.facing.value;
      const p = art.actors[actor].find(p => p.posture === posture && p.facing === facing && p.activity === 'idle');
      const spot = { id: `${room.id}-guest-${crypto.randomUUID()}`, at: [240, 240], preview_actor: actor,
        posture, facing, activity: p.activity, anchor_kind: posture === 'seated' ? 'seat' : 'feet' };
      s.spots.push(spot); s.selected = spot.id; syncChoices(s); setMode(s, 'guest'); save(s);
    });
    button('Remove selected slot', options, () => {
      s.spots = s.spots.filter(v => v.id !== s.selected); s.selected = s.spots[0]?.id || '';
      syncChoices(s); draw(s); save(s);
    });
    s.slot.addEventListener('change', () => { s.selected = s.slot.value; syncChoices(s); draw(s); });
    for (const control of [s.actor, s.posture, s.facing, s.activity]) control.addEventListener('change', () => {
      const spot = s.spots.find(v => v.id === s.selected); if (!spot) return;
      Object.assign(spot, { preview_actor: s.actor.value, posture: s.posture.value, facing: s.facing.value, activity: s.activity.value });
      if (!pose(spot)) spot.activity = 'idle';
      spot.anchor_kind = spot.posture === 'seated' ? 'seat' : 'feet';
      syncChoices(s); draw(s); save(s);
    });
    const masks = document.createElement('div'); masks.className = 'mask-options'; controls.append(masks);
    s.maskSelect = optionSelect(`${room.name} foreground mask`, [], masks);
    s.maskSelect.addEventListener('change', () => {
      s.selectedMask = s.maskSelect.value;
      syncMaskDepth(s);
      draw(s);
    });
    const depthLabel = document.createElement('label'); depthLabel.textContent = 'Furniture front depth y '; masks.append(depthLabel);
    s.depth = document.createElement('input'); s.depth.type = 'number'; s.depth.min = '0'; s.depth.max = '360'; s.depth.step = '.1';
    s.depth.placeholder = 'auto'; s.depth.setAttribute('aria-label', `${room.name} furniture front depth`); depthLabel.append(s.depth);
    button('Pick furniture front edge', masks, () => setMode(s, 'depth', s.mode === 'mask'));
    button('Finish mask', masks, () => {
      if (s.draft.length < 3) { s.note.textContent = 'A mask needs at least three corners.'; return; }
      const automatic = Math.max(...s.draft.map(p => p[1]));
      const depth = s.depth.value === '' ? automatic : Number(s.depth.value);
      if (!Number.isFinite(depth) || depth < 0 || depth > 360) return;
      const mask = { id: `${room.id}-mask-${crypto.randomUUID()}`, polygon: s.draft.map(p => [...p]), depth_y: depth };
      s.masks.push(mask); s.selectedMask = mask.id;
      s.draft = []; setMode(s, 'guest'); draw(s); save(s);
    });
    button('Undo corner', masks, () => { s.draft.pop(); draw(s); });
    button('Apply front depth', masks, () => {
      const mask = s.masks.find(m => m.id === s.selectedMask), depth = Number(s.depth.value);
      if (mask && s.depth.value !== '' && Number.isFinite(depth) && depth >= 0 && depth <= 360) {
        mask.depth_y = depth; draw(s); save(s);
      }
    });
    button('Use mask bottom edge', masks, () => {
      const mask = s.masks.find(m => m.id === s.selectedMask);
      if (!mask) return;
      mask.depth_y = Math.max(...mask.polygon.map(p => p[1]));
      s.depth.value = mask.depth_y; draw(s); save(s);
    });
    button('Remove selected mask', masks, () => {
      s.masks = s.masks.filter(m => m.id !== s.selectedMask); draw(s); save(s);
    });
    s.note = document.createElement('p'); s.note.className = 'guest-note'; controls.append(s.note);
    stage.addEventListener('placement-mode', e => { if (e.detail === 'doors') setMode(s, 'none'); });
    stage.querySelector('a').addEventListener('click', e => { if (s.mode !== 'none') e.preventDefault(); });
    function point(event) {
      const r = s.svg.getBoundingClientRect();
      return [Math.round(Math.max(0, Math.min(480, (event.clientX-r.left)/r.width*480))*10)/10,
        Math.round(Math.max(0, Math.min(360, (event.clientY-r.top)/r.height*360))*10)/10];
    }
    s.svg.addEventListener('pointerdown', e => {
      if (s.mode === 'none') return;
      e.preventDefault();
      if (s.mode === 'depth') { s.depth.value = point(e)[1]; setMode(s, 'mask', true); return; }
      if (s.mode === 'mask') { s.draft.push(point(e)); draw(s); return; }
      const hit = e.target.closest('[data-spot]');
      if (hit) { s.selected = hit.dataset.spot; syncChoices(s); }
      const spot = s.spots.find(v => v.id === s.selected); if (!spot) return;
      spot.at = point(e); s.dragging = true; s.svg.setPointerCapture(e.pointerId); draw(s); save(s);
    });
    s.svg.addEventListener('pointermove', e => {
      if (!s.dragging || s.mode !== 'guest') return;
      const spot = s.spots.find(v => v.id === s.selected); if (!spot) return;
      spot.at = point(e); draw(s); save(s);
    });
    for (const event of ['pointerup', 'pointercancel', 'lostpointercapture']) s.svg.addEventListener(event, () => { s.dragging = false; });
    syncChoices(s); draw(s);
  });
  document.getElementById('download-guests').addEventListener('click', () => {
    const data = { schema: 'house02-guest-placement-v1', coordinates: [480, 360],
      status: 'user_fit_preview_not_applied_to_game',
      rooms: states.map(s => ({ id: s.room.id, image: s.room.image, image_sha256: s.room.sha256,
        guest_spots: s.spots.map(spot => ({ ...spot, floor_at: floorAt(spot), depth_y: spot.at[1], pose_id: pose(spot).pose_id,
          source_contact: pose(spot).contact, contact_status: pose(spot).contact_status })), foreground_masks: s.masks })) };
    const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)+'\n'], { type: 'application/json' }));
    const link = document.createElement('a'); link.href = url; link.download = 'house-02-guest-positions.json'; link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });
})();
