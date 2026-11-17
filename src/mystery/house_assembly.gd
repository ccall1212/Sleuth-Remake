extends RefCounted
## Temporary final-gathering contacts. Never changes the user's authored slots.
const Layout = preload("res://src/blockout/house_layout.gd")
const SEPARATION := 48.0
const FLOOR_CLEARANCE := 8.0
const DOOR_CLEARANCE := 30.0
static var plans: Dictionary = {}

static func safe_contact(geometry: RefCounted, id: String, at: Vector2) -> bool:
	for y in [-FLOOR_CLEARANCE, 0.0, FLOOR_CLEARANCE]:
		for x in [-FLOOR_CLEARANCE, 0.0, FLOOR_CLEARANCE]:
			if not geometry.is_open(id, at + Vector2(x, y)):
				return false
	var feet := Rect2(at - Vector2.ONE * FLOOR_CLEARANCE, Vector2.ONE * FLOOR_CLEARANCE * 2.0)
	for raw in geometry.screens[id].get("obstacles", []):
		if feet.intersects(Layout.rectangle(raw)):
			return false
	for portal in geometry.screens[id].get("portals", []):
		var threshold := Layout.point(portal.get("activation_at", portal.at))
		if at.distance_to(threshold) < DOOR_CLEARANCE:
			return false
	return true

static func separated(at: Vector2, chosen: Array, player: Vector2) -> bool:
	if at.distance_to(player) < SEPARATION:
		return false
	for other in chosen:
		if at.distance_to(other) < SEPARATION:
			return false
	return true

static func room_plan(geometry: RefCounted, id: String, count: int) -> Dictionary:
	var candidates: Array[Vector2] = []
	for y in range(136, 321, 8):
		for x in range(32, 449, 8):
			var at := Vector2(x, y)
			if safe_contact(geometry, id, at):
				candidates.append(at)
	if candidates.is_empty():
		return {}
	var player: Vector2 = candidates[0]
	for at in candidates:
		if at.distance_squared_to(Vector2(240, 280)) < player.distance_squared_to(Vector2(240, 280)):
			player = at
	# Keep guests on the player's connected floor component, not isolated
	# pockets that happen to pass a single-point collision check.
	var floor_points := {}
	for at in candidates:
		floor_points[at] = true
	var reachable := {player: true}
	var queue: Array[Vector2] = [player]
	var cursor := 0
	while cursor < queue.size():
		var at: Vector2 = queue[cursor]
		cursor += 1
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var next: Vector2 = at + direction * 8
			if floor_points.has(next) and not reachable.has(next):
				reachable[next] = true
				queue.append(next)
	candidates = candidates.filter(func(at): return reachable.has(at))
	var chosen: Array[Vector2] = []
	var sources: Array[String] = []
	# Keep exact existing standing contacts when their clearance fits a gathering.
	for slot in geometry.screens[id].get("guest_slots", []):
		var at := Layout.point(slot.at)
		var on_component := candidates.any(func(p): return p.distance_to(at) <= 6)
		if slot.posture == "standing" and on_component and safe_contact(geometry, id, at) and separated(at, chosen, player):
			chosen.append(at)
			sources.append(str(slot.id))
			if chosen.size() == count:
				break
	while chosen.size() < count:
		var best := Vector2.INF
		var score := -1.0
		for at in candidates:
			if not separated(at, chosen, player):
				continue
			var nearest: float = at.distance_to(player)
			for other in chosen:
				nearest = minf(nearest, at.distance_to(other))
			if nearest > score:
				score = nearest
				best = at
		if best == Vector2.INF:
			return {}
		chosen.append(best)
		sources.append("")
	var slots: Array = []
	for index in range(chosen.size()):
		var at: Vector2 = chosen[index]
		slots.append({"id": "assembly-%s-%d" % [id, index], "at": [at.x, at.y],
			"interaction_at": [at.x, at.y], "facing": "south", "posture": "standing", "activity": "idle",
			"source_slot": sources[index], "status": "temporary_assembly_contact"})
	return {"room": id, "player_at": [player.x, player.y], "slots": slots}

static func prepare(geometry: RefCounted, count: int, room_id: String) -> Dictionary:
	if count <= 0 or count > 16:
		return {"error": "The gathering has an unsupported number of guests."}
	if not geometry.screens.has(room_id):
		return {"error": "The current room is unavailable for gathering."}
	var key := JSON.stringify(geometry.data).sha256_text() + ":" + str(count) + ":" + room_id
	if plans.has(key):
		return plans[key].duplicate(true)
	var result := room_plan(geometry, room_id, count)
	if not result.is_empty():
		plans[key] = result.duplicate(true)
		return result
	return {"error": "There isn't enough clear floor here to gather everyone safely. You remain in this room."}
