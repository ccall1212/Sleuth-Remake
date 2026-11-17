extends RefCounted
## Seeded initial floor placement; does not alter an item's assigned room or truth.
const Layout = preload("res://src/blockout/house_layout.gd")
const Case = preload("res://src/mystery/generated_case.gd")
const Approach = preload("res://src/blockout/ambush_approach.gd")
const GRID := 8.0
const BOUNDS := Rect2(0, 0, 480, 360)
const DIRECTIONS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
static var geometries: Dictionary = {}
static var pools: Dictionary = {}

static func geometry(layout: Dictionary, key: String) -> RefCounted:
	if geometries.has(key): return geometries[key]
	var result := Layout.new()
	result.data = layout
	for screen in layout.screens:
		result.screens[str(screen.id)] = screen
		if screen.has("walk_polygons"):
			var polygons: Array[PackedVector2Array] = []
			for raw in screen.walk_polygons:
				var polygon := PackedVector2Array()
				for point in raw: polygon.append(Layout.point(point))
				polygons.append(polygon)
			result.floor_polygons[str(screen.id)] = polygons
	geometries[key] = result
	return result

static func safe(at: Vector2, model: RefCounted, id: String, guest_clearance := 24.0) -> bool:
	if at.x < 16 or at.x > 464 or at.y < 24 or at.y > 344: return false
	for offset in [Vector2.ZERO, Vector2(-6,0), Vector2(6,0), Vector2(0,-6), Vector2(0,6)]:
		if not model.is_open(id, at + offset): return false
	var screen: Dictionary = model.screens[id]
	for portal in screen.get("portals", []):
		if at.distance_to(Layout.point(portal.get("activation_at", portal.at))) < 24: return false
		if portal.has("trigger_region") and Layout.rectangle(portal.trigger_region).grow(6).has_point(at): return false
	for slot in screen.get("guest_slots", []):
		if at.distance_to(Layout.point(slot.get("interaction_at", slot.at))) < guest_clearance: return false
		if at.distance_to(Layout.point(slot.at)) < guest_clearance: return false
	for mask in screen.get("foreground_masks", []):
		if float(mask.depth_y) < at.y: continue
		var polygon := PackedVector2Array()
		for point in mask.polygon: polygon.append(Layout.point(point))
		for offset in [Vector2.ZERO, Vector2(-6,-6), Vector2(6,-6), Vector2(0,-12), Vector2(-6,0), Vector2(6,0)]:
			if Geometry2D.is_point_in_polygon(at + offset, polygon): return false
	return true

static func reachable(model: RefCounted, id: String) -> Array[Vector2]:
	var spawn := Layout.point(model.screens[id].spawn)
	var start := Vector2.INF
	var nearest := INF
	var snapped := (spawn / GRID).round() * GRID
	for y in range(-3,4):
		for x in range(-3,4):
			var at := snapped + Vector2(x,y) * GRID
			var distance := at.distance_squared_to(spawn)
			if distance < nearest and BOUNDS.has_point(at) and Approach.segment_open(model,id,spawn,at):
				start = at
				nearest = distance
	if start == Vector2.INF: return []
	var visited := {start: true}
	var queue: Array[Vector2] = [start]
	var cursor := 0
	while cursor < queue.size():
		var at := queue[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next: Vector2 = at + direction * GRID
			if not visited.has(next) and BOUNDS.has_point(next) and Approach.segment_open(model,id,at,next):
				visited[next] = true
				queue.append(next)
	return queue

static func candidates(layout: Dictionary, screen_id: String) -> Array:
	var key := JSON.stringify(layout).sha256_text()
	var pool_key := key + ":" + screen_id
	if pools.has(pool_key): return pools[pool_key]
	var model := geometry(layout,key)
	if not model.screens.has(screen_id): return []
	var available: Array = []
	var connected := reachable(model,screen_id)
	# E favours a nearby guest within 44px. Keep initial items outside that
	# interaction radius when room space permits; a tight passage may relax it.
	for at in connected:
		if safe(at,model,screen_id,48.0): available.append(at)
	if available.is_empty():
		for at in connected:
			if safe(at,model,screen_id): available.append(at)
	if available.is_empty():
		var screen: Dictionary = model.screens[screen_id]
		var fallback := Layout.point(screen.get("item_slot",screen.spawn))
		if safe(fallback,model,screen_id) and connected.any(func(p): return p.distance_to(fallback) <= GRID):
			available.append(fallback)
	pools[pool_key] = available
	return available

static func choose(layout: Dictionary, screen_id: String, seed_value: int) -> Vector2:
	var available := candidates(layout,screen_id)
	if available.is_empty():
		push_error("No safe initial item location in " + screen_id)
		return Vector2.INF
	return Case.stream(seed_value,"item_positions/" + screen_id).choice(available)
