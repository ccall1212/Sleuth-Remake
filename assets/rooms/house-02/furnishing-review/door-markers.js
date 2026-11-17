/* Review-only placement. Never writes to the playable map. */
(() => {
  'use strict';
  const rooms = JSON.parse(document.getElementById('room-data').textContent);
  const ns = 'http://www.w3.org/2000/svg';
  const state = new Map();
  const notice = document.getElementById('placement-status');
  function svgNode(tag, attrs) {
    const el = document.createElementNS(ns, tag);
    Object.entries(attrs).forEach(([key, value]) => el.setAttribute(key, value));
    return el;
  }
  function key(room) { return `house02-doors-v1:${room.id}:${room.sha256}`; }
  function validPoint(value) {
    return Array.isArray(value) && value.length === 2 &&
      value.every(Number.isFinite) && value[0] >= 0 && value[0] <= 480 && value[1] >= 0 && value[1] <= 360;
  }
  function updateStatus() {
    const all = [...state.values()].flatMap(s => s.markers);
    notice.textContent = `${all.filter(m => m.placed).length} / ${all.length} markers placed. Changes stay in this browser until you download the JSON.`;
  }
  function save(s) {
    try {
      localStorage.setItem(key(s.room), JSON.stringify(s.markers));
      updateStatus();
    } catch (_) {
      notice.textContent = 'Browser storage unavailable. Download the JSON before closing this tab.';
    }
  }
  function draw(s) {
    s.svg.replaceChildren();
    s.markers.forEach((m, index) => {
      const group = svgNode('g', { 'data-index': index, class: 'door-marker' });
      const selected = index === s.select.selectedIndex;
      group.append(svgNode('circle', {
        cx: m.at[0], cy: m.at[1], r: selected ? 6 : 5,
        fill: m.placed ? '#7cfaac' : '#f4c56e', stroke: '#10151e', 'stroke-width': 1.5
      }));
      const text = svgNode('text', {
        x: Math.min(470, Math.max(10, m.at[0])),
        y: m.at[1] < 25 ? m.at[1] + 15 : m.at[1] - 9,
        'text-anchor': m.at[0] > 360 ? 'end' : m.at[0] < 120 ? 'start' : 'middle',
        fill: 'white', stroke: '#10151e', 'stroke-width': 2, 'paint-order': 'stroke', 'font-size': 8
      });
      text.textContent = m.label;
      group.append(text);
      s.svg.append(group);
    });
    const m = s.markers[s.select.selectedIndex];
    s.readout.textContent = m ? `${m.placed ? 'Placed' : 'Old placeholder'} · x ${m.at[0]}, y ${m.at[1]}` : '';
  }
  function place(s, event) {
    const rect = s.svg.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const m = s.markers[s.select.selectedIndex];
    if (!m) return;
    m.at = [
      Math.round(Math.max(0, Math.min(480, (event.clientX - rect.left) / rect.width * 480)) * 10) / 10,
      Math.round(Math.max(0, Math.min(360, (event.clientY - rect.top) / rect.height * 360)) * 10) / 10
    ];
    m.placed = true;
    draw(s);
    save(s);
  }
  rooms.forEach(room => {
    const article = document.getElementById(room.id);
    const stage = article.querySelector('.stage');
    const svg = article.querySelector('svg');
    const controls = article.querySelector('.door-controls');
    if (!room.markers.length) return;
    let markers = room.markers.map(m => ({ ...m, at: [...m.at], placed: m.placed === true }));
    try {
      const stored = JSON.parse(localStorage.getItem(key(room)) || 'null');
      if (Array.isArray(stored)) markers = markers.map(m => {
        const saved = stored.find(v => v.id === m.id && validPoint(v.at));
        const baselinePlaced = m.placed && saved && saved.at[0] === m.at[0] && saved.at[1] === m.at[1];
        return saved ? { ...m, at: saved.at, placed: saved.placed === true || baselinePlaced } : m;
      });
    } catch (_) { /* Keep safe defaults for malformed/disabled storage. */ }
    const select = document.createElement('select');
    select.setAttribute('aria-label', `${room.name} door destination`);
    markers.forEach(m => select.add(new Option(m.label, m.id)));
    const toggle = document.createElement('button');
    toggle.textContent = 'Place doors';
    toggle.setAttribute('aria-pressed', 'false');
    const readout = document.createElement('span');
    readout.className = 'coordinates';
    const reset = document.createElement('button');
    reset.textContent = 'Reset selected marker';
    reset.disabled = true;
    const s = { room, markers, stage, svg, select, readout, editing: false, dragging: false };
    state.set(room.id, s);
    controls.append(toggle, select, reset, readout);
    toggle.addEventListener('click', () => {
      s.editing = !s.editing;
      stage.classList.toggle('editing', s.editing);
      toggle.textContent = s.editing ? 'Finish placing' : 'Place doors';
      toggle.setAttribute('aria-pressed', String(s.editing));
      select.disabled = !s.editing;
      reset.disabled = !s.editing;
      stage.dispatchEvent(new CustomEvent('placement-mode', { detail: s.editing ? 'doors' : 'none' }));
    });
    reset.addEventListener('click', () => {
      const index = select.selectedIndex;
      s.markers[index].at = [...room.markers[index].at];
      s.markers[index].placed = room.markers[index].placed === true;
      draw(s);
      save(s);
    });
    select.disabled = true;
    select.addEventListener('change', () => draw(s));
    stage.querySelector('a').addEventListener('click', e => { if (s.editing) e.preventDefault(); });
    svg.addEventListener('pointerdown', e => {
      if (!s.editing) return;
      e.preventDefault();
      const marker = e.target.closest('g[data-index]');
      if (marker) select.selectedIndex = Number(marker.dataset.index);
      s.dragging = true;
      svg.setPointerCapture(e.pointerId);
      place(s, e);
    });
    svg.addEventListener('pointermove', e => { if (s.editing && s.dragging) place(s, e); });
    svg.addEventListener('pointerup', () => { s.dragging = false; });
    svg.addEventListener('pointercancel', () => { s.dragging = false; });
    svg.addEventListener('lostpointercapture', () => { s.dragging = false; });
    draw(s);
  });
  document.getElementById('download-doors').addEventListener('click', () => {
    const payload = {
      schema: 'house02-door-placement-v1', coordinates: [480, 360],
      status: 'user_placement_for_review_not_applied_to_game',
      rooms: [...state.values()].map(s => ({
        id: s.room.id, image: s.room.image, image_sha256: s.room.sha256,
        markers: s.markers.map(({ id, kind, target, side, at, placed }) => ({ id, kind, target, side, at, placed }))
      }))
    };
    const url = URL.createObjectURL(new Blob([JSON.stringify(payload, null, 2) + '\n'], { type: 'application/json' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = 'house-02-door-positions.json';
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });
  updateStatus();
})();
