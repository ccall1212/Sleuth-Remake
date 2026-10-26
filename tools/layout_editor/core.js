'use strict';
/* Layout editor core: pure functions, no DOM. Mirrors tools/case_design/layout.py.
   Screen frame is 480x360 (centre 240,180), y grows downward. */

const SCREEN_W = 480;
const SCREEN_H = 360;
const ROLES = ['room', 'hall', 'secret'];
const KINDS = ['door', 'front_door', 'secret_exit'];
const SIDES = ['north', 'east', 'south', 'west'];
const SIDE_VEC = { north: [0, -1], east: [1, 0], south: [0, 1], west: [-1, 0] };
const ROOM_COUNT = { 4: 7, 5: 8, 6: 10, 7: 11, 8: 12 };
const MIN_GUEST_SPOTS = 2;
const ARRIVAL_OFFSET = 16;
const PLAN_GAP = 40;
const DEFAULT_PANEL_COLUMNS = [60, 110, 160, 210, 260, 310, 360];

const clone = (o) => JSON.parse(JSON.stringify(o));
const rnd = Math.round;
const normRot = (r) => (((rnd((r || 0) / 90) * 90) % 360) + 360) % 360;

/* ---------- rotation ---------- */

function rotatePoint(p, rot) {
  const x = p[0], y = p[1];
  switch (normRot(rot)) {
    case 90: return [rnd(240 - (y - 180) * 4 / 3), rnd(180 + (x - 240) * 3 / 4)];
    case 180: return [rnd(480 - x), rnd(360 - y)];
    case 270: return [rnd(240 + (y - 180) * 4 / 3), rnd(180 - (x - 240) * 3 / 4)];
    default: return [x, y];
  }
}

function rotateRect(r, rot) {
  if (normRot(rot) === 0) return r.slice();
  const a = rotatePoint([r[0], r[1]], rot);
  const b = rotatePoint([r[0] + r[2], r[1] + r[3]], rot);
  return [Math.min(a[0], b[0]), Math.min(a[1], b[1]),
    Math.max(1, Math.abs(a[0] - b[0])), Math.max(1, Math.abs(a[1] - b[1]))];
}

function rotateSide(side, rot) {
  const i = SIDES.indexOf(side);
  if (i < 0) return side;
  return SIDES[(i + normRot(rot) / 90) % 4];
}

function oppositeSide(side) { return rotateSide(side, 180); }

function rotateFacing(f, rot) {
  const fx = f[0], fy = f[1];
  switch (normRot(rot)) {
    case 90: return [0 - fy, fx];
    case 180: return [0 - fx, 0 - fy];
    case 270: return [fy, 0 - fx];
    default: return [fx, fy];
  }
}

/* ---------- lookups ---------- */

function screenById(layout, id) { return layout.screens.find((s) => s.id === id) || null; }
function byIdMap(layout) { const m = {}; layout.screens.forEach((s) => { m[s.id] = s; }); return m; }
function portalsOf(s) { return s.portals || []; }
function rotOf(s) { return normRot(s && s.plan ? s.plan.rot : 0); }

function findPortal(layout, pid) {
  for (const s of layout.screens) {
    for (const p of portalsOf(s)) if (p.id === pid) return { screen: s, portal: p };
  }
  return null;
}

/* The portal in p.target that this door connects to (explicit link, else inferred). */
function partnerOf(layout, s, p) {
  const t = screenById(layout, p.target);
  if (!t || t === s) return null;
  const tp = portalsOf(t);
  let q = tp.find((x) => x.link === p.id);
  if (q) return q;
  if (p.link) {
    q = tp.find((x) => x.id === p.link);
    if (q) return q;
  }
  if ((p.kind || 'door') !== 'door') return null;
  return tp.find((x) => x.target === s.id && (x.kind || 'door') === 'door' && !x.link) || null;
}

function largestRegion(s) {
  let best = null, area = -1;
  for (const r of s.walk_regions || []) {
    if (r[2] * r[3] > area) { area = r[2] * r[3]; best = r; }
  }
  return best || [0, 0, SCREEN_W, SCREEN_H];
}

/* ---------- open-floor tests ---------- */

function inside(rect, x, y, pad) {
  pad = pad || 0;
  return rect[0] - pad <= x && x <= rect[0] + rect[2] + pad && rect[1] - pad <= y && y <= rect[1] + rect[3] + pad;
}
function inWalk(s, x, y, pad) { return (s.walk_regions || []).some((r) => inside(r, x, y, pad)); }
function inObstacle(s, x, y) {
  return (s.obstacles || []).some((r) => r[0] < x && x < r[0] + r[2] && r[1] < y && y < r[1] + r[3]);
}
function openFloor(s, x, y) { return inWalk(s, x, y) && !inObstacle(s, x, y); }
function rectOk(r) {
  return r[2] > 0 && r[3] > 0 && r[0] >= 0 && r[1] >= 0 && r[0] + r[2] <= SCREEN_W && r[1] + r[3] <= SCREEN_H;
}

/* Nearest open floor to pt on screen s: clamp into the nearest walk region, then nudge out of obstacles. */
function toOpenFloor(s, pt) {
  const regs = s.walk_regions || [];
  if (!regs.length) return [rnd(pt[0]), rnd(pt[1])];
  let best = null, bd = Infinity;
  for (const r of regs) {
    const cx = Math.min(Math.max(pt[0], r[0]), r[0] + r[2]);
    const cy = Math.min(Math.max(pt[1], r[1]), r[1] + r[3]);
    const d = Math.abs(cx - pt[0]) + Math.abs(cy - pt[1]);
    if (d < bd) { bd = d; best = [cx, cy]; }
  }
  best = [rnd(best[0]), rnd(best[1])];
  if (!inObstacle(s, best[0], best[1])) return best;
  const cands = [];
  for (const o of s.obstacles || []) {
    if (!(o[0] < best[0] && best[0] < o[0] + o[2] && o[1] < best[1] && best[1] < o[1] + o[3])) continue;
    cands.push([o[0] - 1, best[1]], [o[0] + o[2] + 1, best[1]], [best[0], o[1] - 1], [best[0], o[1] + o[3] + 1]);
  }
  let out = best, od = Infinity;
  for (const c of cands) {
    if (!openFloor(s, c[0], c[1])) continue;
    const d = Math.abs(c[0] - best[0]) + Math.abs(c[1] - best[1]);
    if (d < od) { od = d; out = c; }
  }
  return out;
}

/* ---------- arrivals ---------- */

function refreshArrival(layout, s, p) {
  const t = screenById(layout, p.target);
  if (!t || t === s) return;
  const q = partnerOf(layout, s, p);
  if (!q || !q.at) return;
  const f = q.facing || SIDE_VEC[q.side] || [0, 0];
  p.arrival = toOpenFloor(t, [q.at[0] - f[0] * ARRIVAL_OFFSET, q.at[1] - f[1] * ARRIVAL_OFFSET]);
}

function recomputeArrivals(layout) {
  for (const s of layout.screens) for (const p of portalsOf(s)) refreshArrival(layout, s, p);
  return layout;
}

/* ---------- baking ---------- */

function bakeLayout(layout) {
  const out = clone(layout);
  const rots = {};
  out.screens.forEach((s) => { rots[s.id] = rotOf(s); });
  for (const s of out.screens) {
    const rot = rots[s.id];
    for (const p of portalsOf(s)) {
      const trot = rots[p.target] || 0;
      if (p.arrival && trot) p.arrival = rotatePoint(p.arrival, trot); // overwritten below when partnered
    }
    if (!rot) continue;
    s.walk_regions = (s.walk_regions || []).map((r) => rotateRect(r, rot));
    s.obstacles = (s.obstacles || []).map((r) => rotateRect(r, rot));
    if (s.spawn) s.spawn = rotatePoint(s.spawn, rot);
    if (s.item_slot) s.item_slot = rotatePoint(s.item_slot, rot);
    if (s.guest_spots) s.guest_spots = s.guest_spots.map((g) => rotatePoint(g, rot));
    for (const p of portalsOf(s)) {
      if (p.at) p.at = rotatePoint(p.at, rot);
      if (p.facing) p.facing = rotateFacing(p.facing, rot);
      if (p.side) p.side = rotateSide(p.side, rot);
    }
    if (s.role === 'hall' && (rot === 90 || rot === 270)) {
      if (s.orientation === 'ew') s.orientation = 'ns';
      else if (s.orientation === 'ns') s.orientation = 'ew';
    }
  }
  const sec = out.secret;
  if (sec) {
    const er = rots[sec.entrance_room] || 0;
    if (er) {
      sec.panel_wall = rotateSide(sec.panel_wall, er);
      const ent = screenById(out, sec.entrance_room);
      if (ent) {
        const r = largestRegion(ent);
        const horiz = sec.panel_wall === 'north' || sec.panel_wall === 'south';
        const a = horiz ? r[0] : r[1];
        const len = horiz ? r[2] : r[3];
        sec.panel_columns = [1, 2, 3, 4, 5, 6, 7].map((i) => rnd(a + len * i / 8));
      }
    }
  }
  recomputeArrivals(out);
  return out;
}

/* ---------- problems / step costs ---------- */

function roomsSummary(layout) {
  const roles = layout.screens.map((s) => s.role);
  const n = (k) => roles.filter((r) => r === k).length;
  return { ordinary: n('room'), halls: n('hall'), secret: n('secret') };
}

function reachable(layout) {
  const by = byIdMap(layout);
  const seen = new Set([layout.start]);
  const stack = [layout.start];
  const sec = layout.secret;
  while (stack.length) {
    const cur = stack.pop();
    const nxt = portalsOf(by[cur]).map((p) => p.target);
    if (sec && cur === sec.entrance_room) nxt.push(sec.screen);
    for (const t of nxt) if (by[t] && !seen.has(t)) { seen.add(t); stack.push(t); }
  }
  return seen;
}

function problems(layout) {
  const out = [];
  const screens = layout.screens || [];
  const by = byIdMap(layout);
  if (Object.keys(by).length !== screens.length) out.push('duplicate screen ids');
  if (!by[layout.start]) out.push('start screen missing');
  for (const s of screens) {
    const sid = s.id;
    if (!ROLES.includes(s.role)) out.push(`${sid}: bad role ${JSON.stringify(s.role)}`);
    if (!(s.walk_regions || []).length) out.push(`${sid}: no walk regions`);
    for (const r of (s.walk_regions || []).concat(s.obstacles || [])) {
      if (!rectOk(r)) out.push(`${sid}: rectangle [${r.join(', ')}] outside the ${SCREEN_W}x${SCREEN_H} screen`);
    }
    if (!s.spawn || !openFloor(s, s.spawn[0], s.spawn[1])) out.push(`${sid}: spawn is not on open floor`);
    for (const p of portalsOf(s)) {
      if (!p.target) { out.push(`${sid}: portal ${p.id} is not linked`); continue; }
      const tgt = by[p.target];
      if (!tgt) { out.push(`${sid}: portal ${p.id} targets unknown screen ${p.target}`); continue; }
      if (!KINDS.includes(p.kind || 'door')) out.push(`${sid}: portal ${p.id} has bad kind ${JSON.stringify(p.kind)}`);
      if (!inWalk(s, p.at[0], p.at[1], 14)) out.push(`${sid}: portal ${p.id} is not at the edge of walkable floor`);
      if (inObstacle(s, p.at[0], p.at[1])) out.push(`${sid}: portal ${p.id} is inside an obstacle`);
      if (!p.arrival || !openFloor(tgt, p.arrival[0], p.arrival[1])) out.push(`${sid}: portal ${p.id} arrives off the floor of ${p.target}`);
      if ((p.kind || 'door') === 'door' && !portalsOf(tgt).some((q) => q.target === sid)) {
        out.push(`${sid}: portal ${p.id} has no door back from ${p.target}`);
      }
    }
    if (s.role !== 'hall') {
      const sp = s.item_slot;
      if (!sp || !openFloor(s, sp[0], sp[1])) out.push(`${sid}: item slot is not on open floor`);
    }
    if (s.role === 'room' || s.role === 'secret') {
      const spots = s.guest_spots || [];
      if (spots.length < MIN_GUEST_SPOTS) out.push(`${sid}: needs ${MIN_GUEST_SPOTS} guest spots`);
      for (const g of spots) if (!openFloor(s, g[0], g[1])) out.push(`${sid}: guest spot [${g.join(', ')}] is not on open floor`);
    }
  }
  const sec = layout.secret;
  if (sec) {
    for (const key of ['entrance_room', 'exit_room', 'screen']) {
      if (!by[sec[key]]) out.push(`secret: unknown ${key}`);
    }
    if ((sec.panel_columns || []).length !== 7) out.push('secret: exactly 7 panel columns expected');
  }
  if (by[layout.start]) {
    const seen = reachable(layout);
    for (const sid of Object.keys(by)) if (!seen.has(sid)) out.push(`${sid}: unreachable from the start`);
  }
  const counts = roomsSummary(layout);
  for (const n of layout.supports_suspects || []) {
    if (!(n in ROOM_COUNT)) out.push(`supports_suspects: ${n} is outside 4-8`);
    else if (counts.ordinary + counts.secret !== ROOM_COUNT[n]) {
      out.push(`layout has ${counts.ordinary + counts.secret} rooms but ${n} suspects need ${ROOM_COUNT[n]}`);
    }
  }
  return out;
}

/* Shortest step count between room spawns. Result keys are "src|dst". */
function stepCosts(layout, pxPerStep) {
  const pps = pxPerStep || 24;
  const by = byIdMap(layout);
  const rooms = layout.screens.filter((s) => s.role === 'room').map((s) => s.id);
  const walk = (a, b) => Math.max(1, Math.ceil((Math.abs(a[0] - b[0]) + Math.abs(a[1] - b[1])) / pps));
  const key = (sid, pos) => sid + '|' + pos[0] + '|' + pos[1];
  const result = {};
  for (const src of rooms) {
    const sp = by[src].spawn;
    if (!sp) continue;
    const nodes = new Map();
    nodes.set(key(src, sp), { sid: src, pos: sp, d: 0, done: false });
    for (;;) {
      let cur = null;
      for (const n of nodes.values()) if (!n.done && (!cur || n.d < cur.d)) cur = n;
      if (!cur) break;
      cur.done = true;
      for (const p of portalsOf(by[cur.sid])) {
        if (p.kind === 'secret_exit' || !by[p.target] || !p.arrival || !p.at) continue;
        const nd = cur.d + walk(cur.pos, p.at) + 1;
        const k = key(p.target, p.arrival);
        const ex = nodes.get(k);
        if (!ex) nodes.set(k, { sid: p.target, pos: p.arrival, d: nd, done: false });
        else if (nd < ex.d && !ex.done) ex.d = nd;
      }
    }
    for (const dst of rooms) {
      if (dst === src || !by[dst].spawn) continue;
      let best = null;
      for (const n of nodes.values()) {
        if (n.sid !== dst) continue;
        const c = n.d + walk(n.pos, by[dst].spawn);
        if (best === null || c < best) best = c;
      }
      if (best !== null) result[src + '|' + dst] = best;
    }
  }
  return result;
}

function summary(layout, pxPerStep) {
  const pps = pxPerStep || 24;
  const costsObj = stepCosts(layout, pps);
  const costs = Object.values(costsObj).sort((a, b) => a - b);
  const rooms = layout.screens.filter((s) => s.role === 'room').map((s) => s.id);
  return Object.assign({ id: layout.id }, roomsSummary(layout), {
    room_to_room_steps_min: costs.length ? costs[0] : null,
    room_to_room_steps_median: costs.length ? costs[Math.floor(costs.length / 2)] : null,
    room_to_room_steps_max: costs.length ? costs[costs.length - 1] : null,
    px_per_step: pps,
    problems: problems(layout),
    rooms: rooms,
    matrix: costsObj,
  });
}

/* ---------- editing helpers (mutate the layout they are given) ---------- */

function slug(base) {
  const s = String(base || 'screen').toLowerCase().replace(/[^a-z0-9_]+/g, '_').replace(/^_+|_+$/g, '');
  return s || 'screen';
}

function uniqueId(layout, base) {
  const b = slug(base);
  const taken = new Set(layout.screens.map((s) => s.id));
  if (!taken.has(b)) return b;
  let n = 2;
  while (taken.has(b + '_' + n)) n++;
  return b + '_' + n;
}

function uniquePortalId(layout, base) {
  const taken = new Set();
  layout.screens.forEach((s) => portalsOf(s).forEach((p) => taken.add(p.id)));
  if (!taken.has(base)) return base;
  let n = 2;
  while (taken.has(base + '_' + n)) n++;
  return base + '_' + n;
}

function newScreen(kind, id, name) {
  const base = { id: id, name: name || id, floor: 0, obstacles: [], portals: [] };
  if (kind === 'room') {
    return Object.assign(base, { role: 'room', walk_regions: [[24, 150, 432, 172]], spawn: [240, 235],
      item_slot: [380, 285], guest_spots: [[120, 235], [240, 290], [380, 200]] });
  }
  if (kind === 'hall_ew') {
    return Object.assign(base, { role: 'hall', orientation: 'ew', walk_regions: [[16, 170, 448, 50]], spawn: [240, 195],
      guest_spots: [[90, 195], [240, 195], [390, 195]] });
  }
  if (kind === 'hall_ns') {
    return Object.assign(base, { role: 'hall', orientation: 'ns', walk_regions: [[190, 24, 100, 312]], spawn: [240, 180],
      guest_spots: [[240, 80], [240, 180], [240, 290]] });
  }
  if (kind === 'secret') {
    return Object.assign(base, { role: 'secret', walk_regions: [[16, 150, 448, 60]], spawn: [40, 180],
      item_slot: [420, 180], guest_spots: [[120, 180], [240, 180], [360, 180]] });
  }
  throw new Error('unknown screen kind ' + kind);
}

function doorAt(s, side, along) {
  const r = largestRegion(s);
  const cl = (v, a, b) => Math.min(Math.max(v, a), b);
  if (side === 'north' || side === 'south') {
    return [rnd(cl(along, r[0], r[0] + r[2])), side === 'north' ? r[1] : r[1] + r[3]];
  }
  return [side === 'west' ? r[0] : r[0] + r[2], rnd(cl(along, r[1], r[1] + r[3]))];
}

function addDoor(layout, screenId, side, along) {
  const s = screenById(layout, screenId);
  if (!s) throw new Error('no screen ' + screenId);
  if (!SIDES.includes(side)) throw new Error('bad side ' + side);
  const at = doorAt(s, side, along);
  const p = { id: uniquePortalId(layout, screenId + '--door'), at: at, target: '', arrival: at.slice(),
    facing: SIDE_VEC[side].slice(), side: side, kind: 'door' };
  if (!s.portals) s.portals = [];
  s.portals.push(p);
  return p;
}

function moveDoor(layout, portalId, side, along) {
  const f = findPortal(layout, portalId);
  if (!f) return null;
  const p = f.portal;
  const s = f.screen;
  side = side || p.side;
  p.at = doorAt(s, side, along);
  p.side = side;
  p.facing = SIDE_VEC[side].slice();
  const q = partnerOf(layout, s, p);
  if (q) refreshArrival(layout, findPortal(layout, q.id).screen, q);
  return p;
}

function unlinkDoor(layout, pid) {
  const f = findPortal(layout, pid);
  if (!f) return false;
  const p = f.portal;
  if ((p.kind || 'door') !== 'door') return false;
  const q = partnerOf(layout, f.screen, p);
  for (const x of [p, q]) {
    if (!x) continue;
    x.target = '';
    delete x.link;
    x.arrival = x.at ? x.at.slice() : [0, 0];
  }
  return true;
}

function linkDoors(layout, idA, idB) {
  const a = findPortal(layout, idA), b = findPortal(layout, idB);
  if (!a || !b || a.screen === b.screen) return false;
  a.portal.kind = 'door';
  b.portal.kind = 'door';
  unlinkDoor(layout, idA);
  unlinkDoor(layout, idB);
  a.portal.target = b.screen.id; a.portal.link = b.portal.id;
  b.portal.target = a.screen.id; b.portal.link = a.portal.id;
  refreshArrival(layout, a.screen, a.portal);
  refreshArrival(layout, b.screen, b.portal);
  return true;
}

function removeDoor(layout, pid) {
  const f = findPortal(layout, pid);
  if (!f) return false;
  unlinkDoor(layout, pid);
  f.screen.portals = f.screen.portals.filter((p) => p.id !== pid);
  return true;
}

function defaultSecret(layout, screenId) {
  const rooms = layout.screens.filter((s) => s.role === 'room').map((s) => s.id);
  return { screen: screenId, entrance_room: rooms[0] || '', exit_room: rooms[1] || rooms[0] || '',
    panel_wall: 'north', panel_columns: DEFAULT_PANEL_COLUMNS.slice() };
}

function ensureSecret(layout) {
  const sc = layout.screens.find((s) => s.role === 'secret');
  if (sc && !layout.secret) layout.secret = defaultSecret(layout, sc.id);
  return layout.secret;
}

function removeScreen(layout, id) {
  layout.screens = layout.screens.filter((s) => s.id !== id);
  for (const s of layout.screens) s.portals = portalsOf(s).filter((p) => p.target !== id);
  if (layout.start === id) layout.start = layout.screens.length ? layout.screens[0].id : '';
  const sec = layout.secret;
  if (sec) {
    if (sec.screen === id) delete layout.secret;
    else {
      const first = (layout.screens.find((s) => s.role === 'room') || {}).id || '';
      if (sec.entrance_room === id) sec.entrance_room = first;
      if (sec.exit_room === id) sec.exit_room = first;
    }
  }
  return layout;
}

/* Rename a screen id, updating every reference. Returns the id actually used. */
function renameScreen(layout, oldId, newId) {
  const s = screenById(layout, oldId);
  if (!s) return oldId;
  const want = slug(newId);
  if (want === oldId) return oldId;
  const others = layout.screens.filter((x) => x !== s);
  let id = want, n = 2;
  while (others.some((x) => x.id === id)) id = want + '_' + n++;
  s.id = id;
  for (const x of layout.screens) for (const p of portalsOf(x)) if (p.target === oldId) p.target = id;
  if (layout.start === oldId) layout.start = id;
  const sec = layout.secret;
  if (sec) for (const k of ['screen', 'entrance_room', 'exit_room']) if (sec[k] === oldId) sec[k] = id;
  return id;
}

/* ---------- plan geometry and auto-arrange ---------- */

function tileDims(rot) { return normRot(rot) % 180 === 0 ? [480, 360] : [360, 480]; }

function tileRect(s) {
  const pl = s.plan || { x: 0, y: 0, rot: 0 };
  const d = tileDims(pl.rot);
  const cx = pl.x + 240, cy = pl.y + 180;
  return { x: cx - d[0] / 2, y: cy - d[1] / 2, w: d[0], h: d[1] };
}

function setTileTopLeft(s, x, y) {
  if (!s.plan) s.plan = { x: 0, y: 0, rot: 0 };
  const d = tileDims(s.plan.rot);
  s.plan.x = x + d[0] / 2 - 240;
  s.plan.y = y + d[1] / 2 - 180;
}

function autoPlan(layout, all) {
  const scr = layout.screens;
  if (!scr.length) return layout;
  if (all) scr.forEach((s) => { delete s.plan; });
  const by = byIdMap(layout);
  const placed = new Set(scr.filter((s) => s.plan).map((s) => s.id));
  const snap = (v) => rnd(v / 20) * 20;
  const isFree = (r) => !scr.some((o) => {
    if (!placed.has(o.id)) return false;
    const t = tileRect(o);
    return r.x < t.x + t.w + PLAN_GAP && t.x < r.x + r.w + PLAN_GAP && r.y < t.y + t.h + PLAN_GAP && t.y < r.y + r.h + PLAN_GAP;
  });
  function place(child, rot, pr, dir) {
    const d = tileDims(rot);
    let x, y;
    if (dir === 'east') { x = pr.x + pr.w + PLAN_GAP; y = pr.y + (pr.h - d[1]) / 2; }
    else if (dir === 'west') { x = pr.x - d[0] - PLAN_GAP; y = pr.y + (pr.h - d[1]) / 2; }
    else if (dir === 'north') { y = pr.y - d[1] - PLAN_GAP; x = pr.x + (pr.w - d[0]) / 2; }
    else { y = pr.y + pr.h + PLAN_GAP; x = pr.x + (pr.w - d[0]) / 2; }
    x = snap(x); y = snap(y);
    const horizAxis = dir === 'north' || dir === 'south';
    for (let k = 0; k < 120; k++) {
      const off = Math.ceil(k / 2) * 20 * (k % 2 ? 1 : -1);
      const r = { x: horizAxis ? x + off : x, y: horizAxis ? y : y + off, w: d[0], h: d[1] };
      if (isFree(r)) { x = r.x; y = r.y; break; }
    }
    child.plan = { x: 0, y: 0, rot: rot };
    setTileTopLeft(child, x, y);
    placed.add(child.id);
  }
  function neighbours(cur) {
    const list = [];
    for (const s of scr) {
      for (const p of portalsOf(s)) {
        const t = by[p.target];
        if (!t || t === s || !p.side) continue;
        if (s === cur) {
          const dir = rotateSide(p.side, rotOf(cur));
          list.push({ child: t, dir: dir, rot: 0 }); // new tiles start unrotated; the user rotates them
        } else if (t === cur) {
          list.push({ child: s, dir: oppositeSide(rotateSide(p.side, rotOf(s))), rot: rotOf(s) });
        }
      }
    }
    return list;
  }
  const startS = by[layout.start] || scr[0];
  const visited = new Set();
  function bfs(root) {
    const queue = [root];
    visited.add(root.id);
    while (queue.length) {
      const cur = queue.shift();
      for (const nb of neighbours(cur)) {
        if (visited.has(nb.child.id)) continue;
        visited.add(nb.child.id);
        if (!placed.has(nb.child.id)) place(nb.child, nb.rot, tileRect(cur), nb.dir);
        queue.push(nb.child);
      }
    }
  }
  if (!placed.has(startS.id)) { startS.plan = { x: 0, y: 0, rot: 0 }; placed.add(startS.id); }
  bfs(startS);
  // anything unreachable goes in a row under everything already placed
  let maxY = -Infinity;
  scr.forEach((s) => { if (placed.has(s.id)) { const t = tileRect(s); maxY = Math.max(maxY, t.y + t.h); } });
  let cx = 0;
  for (const s of scr) {
    if (placed.has(s.id)) continue;
    s.plan = { x: 0, y: 0, rot: 0 };
    setTileTopLeft(s, snap(cx), snap(maxY + PLAN_GAP));
    placed.add(s.id);
    cx += 480 + PLAN_GAP;
    bfs(s);
  }
  return layout;
}

/* ---------- sample ---------- */

function emptyLayout() {
  return { schema_version: 1, id: 'new-house', blockout: true, screen_size: [480, 360], px_per_step: 24,
    supports_suspects: [], start: '', screens: [] };
}

function sampleLayout() {
  const L = emptyLayout();
  L.id = 'sample-3';
  L.start = 'hall';
  L.screens.push(newScreen('hall_ew', 'hall', 'Hall'), newScreen('room', 'library', 'Library'), newScreen('room', 'kitchen', 'Kitchen'));
  const a = addDoor(L, 'hall', 'north', 120), b = addDoor(L, 'library', 'south', 240);
  linkDoors(L, a.id, b.id);
  const c = addDoor(L, 'hall', 'south', 360), d = addDoor(L, 'kitchen', 'north', 240);
  linkDoors(L, c.id, d.id);
  autoPlan(L);
  return L;
}

const LayoutCore = {
  SCREEN_W, SCREEN_H, ROLES, KINDS, SIDES, SIDE_VEC, ROOM_COUNT, PLAN_GAP,
  rotatePoint, rotateRect, rotateSide, oppositeSide, rotateFacing, normRot,
  bakeLayout, recomputeArrivals, refreshArrival, problems, stepCosts, summary, roomsSummary,
  newScreen, addDoor, moveDoor, linkDoors, unlinkDoor, removeDoor, removeScreen, renameScreen,
  uniqueId, uniquePortalId, autoPlan, ensureSecret, defaultSecret, emptyLayout, sampleLayout,
  findPortal, partnerOf, screenById, largestRegion, doorAt, toOpenFloor, openFloor,
  tileDims, tileRect, setTileTopLeft, rotOf, clone,
};
if (typeof module !== 'undefined') module.exports = LayoutCore;
if (typeof window !== 'undefined') window.LayoutCore = LayoutCore;
