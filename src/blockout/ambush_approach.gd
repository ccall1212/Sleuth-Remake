extends RefCounted
## Presentation-only, in-room route for the exceptional killer approach.
## Never calls walk(), enters another room, or changes case/geometry state.
const GRID := 8.0
const SAMPLE := 2.0
const SNAP_LIMIT := 48.0
const MIN_DISTANCE := 20.0
const MAX_DISTANCE := 34.0
const ROOM_BOUNDS := Rect2(0, 0, 480, 360)
const DIRECTIONS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

static func crosses_obstacle(start: Vector2, finish: Vector2, box: Rect2) -> bool:
	# Clip against the open rectangle interior. This also catches obstacles
	# thinner than the regular floor sampling interval.
	var low := 0.0
	var high := 1.0
	var delta := finish - start
	for axis in [0, 1]:
		if is_zero_approx(delta[axis]):
			if start[axis] <= box.position[axis] or start[axis] >= box.end[axis]:
				return false
			continue
		var first: float = (box.position[axis] - start[axis]) / delta[axis]
		var last: float = (box.end[axis] - start[axis]) / delta[axis]
		low = maxf(low, minf(first, last))
		high = minf(high, maxf(first, last))
		if low >= high: return false
	return high > 0.0 and low < 1.0

static func segment_open(geometry: RefCounted, room_id: String, start: Vector2, finish: Vector2) -> bool:
	for raw in geometry.screens.get(room_id, {}).get("obstacles", []):
		if crosses_obstacle(start, finish, Rect2(raw[0], raw[1], raw[2], raw[3])):
			return false
	var samples := maxi(1, ceili(start.distance_to(finish) / SAMPLE))
	for index in range(samples + 1):
		var at := start.lerp(finish, float(index) / samples)
		if not ROOM_BOUNDS.has_point(at) or not geometry.is_open(room_id, at):
			return false
	return true

static func start_contact(geometry: RefCounted, room_id: String, source: Vector2) -> Vector2:
	var source_open: bool = geometry.is_open(room_id, source)
	var center := Vector2(roundf(source.x / GRID), roundf(source.y / GRID)) * GRID
	var best := Vector2.INF
	var best_distance := INF
	for y in range(-6, 7):
		for x in range(-6, 7):
			var at := center + Vector2(x, y) * GRID
			var distance := source.distance_to(at)
			if distance > SNAP_LIMIT or distance >= best_distance:
				continue
			if not ROOM_BOUNDS.has_point(at) or not geometry.is_open(room_id, at):
				continue
			if source_open and not segment_open(geometry, room_id, source, at):
				continue
			best = at
			best_distance = distance
	return best

static func route(geometry: RefCounted, room_id: String, source: Vector2, player: Vector2) -> Array[Vector2]:
	var empty: Array[Vector2] = []
	if not source.is_finite() or not player.is_finite() or not geometry.is_open(room_id, player):
		return empty
	var start := start_contact(geometry, room_id, source)
	if start == Vector2.INF:
		return empty
	var frontier: Array[Vector2] = [start]
	var previous := {start: Vector2.INF}
	var cursor := 0
	var goal := Vector2.INF
	# Breadth-first search selects a short reachable approach on the source side
	# of the player; endpoint spacing leaves both sprites separately readable.
	while cursor < frontier.size():
		var at: Vector2 = frontier[cursor]
		cursor += 1
		var distance := at.distance_to(player)
		if distance >= MIN_DISTANCE and distance <= MAX_DISTANCE:
			goal = at
			break
		for direction in DIRECTIONS:
			var next: Vector2 = at + direction * GRID
			if previous.has(next) or not ROOM_BOUNDS.has_point(next):
				continue
			if segment_open(geometry, room_id, at, next):
				previous[next] = at
				frontier.append(next)
	if goal == Vector2.INF:
		return empty
	var raw: Array[Vector2] = [goal]
	while raw[0] != start:
		raw.push_front(previous[raw[0]])
	if geometry.is_open(room_id, source) and source != start:
		raw.push_front(source)
	# Seated source artwork can overlap furniture. In that case raw starts at
	# the nearest clear floor contact, never with a path through the furniture.
	var result: Array[Vector2] = [raw[0]]
	var index := 0
	while index < raw.size() - 1:
		var next := raw.size() - 1
		while next > index + 1 and not segment_open(geometry, room_id, raw[index], raw[next]):
			next -= 1
		result.append(raw[next])
		index = next
	return result
