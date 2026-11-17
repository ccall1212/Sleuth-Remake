extends RefCounted
## Geometry and traversal only. No case, clock, personality or save-game rules.

const DEFAULT_PATH := "res://assets/maps/house-02.layout.json"
const DOOR_RADIUS := 11.0
var data: Dictionary = {}
var screens: Dictionary = {}
var floor_polygons: Dictionary = {}
var current_id := ""
var position := Vector2.ZERO
var walked_pixels := 0.0
var steps := 0
var room_entries := 0
var visited: Dictionary = {}
var error := ""
var notice := ""
var last_trip_steps := 0
var _trip_start_pixels := 0.0
var _door_lock := 0.0
var transitions_locked := false

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func rectangle(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

func load_layout(path := DEFAULT_PATH) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		error = "Could not read a layout object: " + path
		return false
	data = parsed
	screens.clear()
	floor_polygons.clear()
	for screen in data.get("screens", []):
		if screens.has(screen.get("id", "")):
			error = "Duplicate screen ID"
			return false
		screens[screen.id] = screen
		if screen.has("walk_polygons"):
			var polygons: Array[PackedVector2Array] = []
			for raw in screen.walk_polygons:
				var polygon := PackedVector2Array()
				for vertex in raw:
					polygon.append(point(vertex))
				polygons.append(polygon)
			floor_polygons[screen.id] = polygons
	var problems := validate()
	if not problems.is_empty():
		error = "\n".join(problems)
		return false
	reset()
	return true

func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not screens.has(data.get("start", "")):
		problems.append("Starting screen is missing")
	if float(data.get("px_per_step", 0)) <= 0:
		problems.append("px_per_step must be positive")
	for id in screens:
		var screen: Dictionary = screens[id]
		if not is_open(id, point(screen.get("spawn", [0, 0]))):
			problems.append(str(id) + ": spawn is blocked")
		for portal in screen.get("portals", []):
			if not screens.has(portal.get("target", "")):
				problems.append(str(id) + ": unknown door target")
			elif not is_open(portal.target, point(portal.arrival)):
				problems.append(str(id) + ": blocked door arrival")
		for pair in [["obstacle_kinds", "obstacles"], ["guest_spot_kinds", "guest_spots"], ["guest_spot_facing", "guest_spots"]]:
			if screen.has(pair[0]) and screen[pair[0]].size() != screen.get(pair[1], []).size():
				problems.append(str(id) + ": mismatched " + str(pair[0]))
	return problems

func reset() -> void:
	transitions_locked = false
	current_id = str(data.start)
	position = point(screens[current_id].spawn)
	walked_pixels = 0
	steps = 0
	room_entries = 0
	_trip_start_pixels = 0
	last_trip_steps = 0
	_door_lock = 0
	visited = {current_id: true}
	notice = "Walk toward a cyan doorway to change screens."

func screen() -> Dictionary:
	return screens.get(current_id, {})

func is_open(id: String, p: Vector2) -> bool:
	if not screens.has(id):
		return false
	var inside := false
	if floor_polygons.has(id):
		for polygon in floor_polygons[id]:
			if Geometry2D.is_point_in_polygon(p, polygon):
				inside = true
	else:
		for raw in screens[id].get("walk_regions", []):
			var r := rectangle(raw)
			# Authored door anchors sit exactly on the outer walk boundary.
			if p.x >= r.position.x and p.y >= r.position.y and p.x <= r.end.x and p.y <= r.end.y:
				inside = true
	for raw in screens[id].get("door_access_regions", []):
		var r := rectangle(raw)
		if p.x >= r.position.x and p.y >= r.position.y and p.x <= r.end.x and p.y <= r.end.y:
			inside = true
	if not inside:
		return false
	for raw in screens[id].get("obstacles", []):
		var r := rectangle(raw)
		if p.x > r.position.x and p.y > r.position.y and p.x < r.end.x and p.y < r.end.y:
			return false
	return true

func walk(displacement: Vector2, delta := 1.0 / 60.0) -> bool:
	_door_lock = maxf(0, _door_lock - delta)
	if displacement.is_zero_approx():
		return false
	# Substeps prevent tunnelling through thin furniture at low frame rates.
	var slices := maxi(1, ceili(displacement.length() / 2.0))
	var part := displacement / slices
	for unused in range(slices):
		var before := position
		if is_open(current_id, position + Vector2(part.x, 0)):
			position.x += part.x
		if is_open(current_id, position + Vector2(0, part.y)):
			position.y += part.y
		walked_pixels += position.distance_to(before)
		steps = floori((walked_pixels + 0.0001) / float(data.px_per_step))
		if try_door(displacement.normalized(), before + part):
			return true
	return false

func try_door(direction: Vector2, attempted_position := Vector2.INF) -> bool:
	if transitions_locked:
		return false
	if _door_lock > 0:
		return false
	if attempted_position == Vector2.INF:
		attempted_position = position
	for portal in screen().get("portals", []):
		var at := point(portal.at)
		var facing := point(portal.facing)
		if portal.has("trigger_region") and portal.has("activation_at"):
			# Painted markers can sit on a tall door leaf, above the actual
			# walking surface. Cross a broad, authored floor threshold instead
			# of requiring an exact 11-pixel circle on the wall artwork.
			var region := rectangle(portal.trigger_region)
			var threshold := point(portal.activation_at)
			if (region.has_point(position) or region.has_point(attempted_position)) and direction.dot(facing) > 0.4 and (attempted_position - threshold).dot(facing) >= -0.01:
				_enter(str(portal.target), point(portal.arrival))
				return true
			continue
		# Cross the doorway plane, rather than grabbing the player from nearby.
		# This matters for adjacent doors along the narrow hall.
		if position.distance_to(at) <= DOOR_RADIUS and direction.dot(facing) > 0.4 and (attempted_position - at).dot(facing) >= -0.01:
			_enter(str(portal.target), point(portal.arrival))
			return true
	return false

func _enter(id: String, arrival: Vector2) -> void:
	var previous := str(screen().get("name", current_id))
	last_trip_steps = ceili((walked_pixels - _trip_start_pixels) / float(data.px_per_step))
	_trip_start_pixels = walked_pixels
	current_id = id
	position = arrival
	visited[id] = true
	if screen().get("role") != "hall":
		room_entries += 1
	_door_lock = 0.2
	notice = previous + " → " + str(screen().name)

func inspect_screen(id: String) -> void:
	# Explicit inspection aid; never presented as measured traversal.
	reset()
	current_id = id
	position = point(screen().spawn)
	visited = {id: true}
	notice = "Inspection jump; counters reset."

func secret_panel() -> Vector2:
	var secret: Dictionary = data.get("secret", {})
	if secret.has("panel_at"):
		return point(secret.panel_at)
	var id := str(secret.get("entrance_room", ""))
	if not screens.has(id):
		return Vector2.INF
	var walk: Rect2 = rectangle(screens[id].walk_regions[0])
	# This viewer exposes one reachable panel, without choosing a case seed.
	for column in secret.get("panel_columns", []):
		var p := Vector2(float(column), walk.position.y)
		if is_open(id, p) and is_open(id, p + Vector2(0, 4)):
			return p
	return Vector2.INF

func interact_secret() -> bool:
	if transitions_locked:
		return false
	var secret: Dictionary = data.get("secret", {})
	if current_id == secret.get("entrance_room") and position.distance_to(secret_panel()) <= 26:
		var id := str(secret.screen)
		_enter(id, point(secret.get("passage_arrival", screens[id].spawn)))
		notice = "Secret passage opened (exposed for blockout review)."
		return true
	if current_id == secret.get("screen") and secret.has("return_at") and position.distance_to(point(secret.return_at)) <= 24:
		var id := str(secret.entrance_room)
		_enter(id, point(secret.get("library_arrival", screens[id].spawn)))
		notice = "Secret passage returns to " + str(screen().name)
		return true
	if current_id == secret.get("screen") and position.distance_to(secret_exit()) <= 24:
		var id := str(secret.exit_room)
		_enter(id, point(secret.get("study_arrival", screens[id].spawn)))
		notice = "Secret passage exits into " + str(screen().name)
		return true
	return false

func secret_exit() -> Vector2:
	if data.get("secret", {}).has("exit_at"):
		return point(data.secret.exit_at)
	var id := str(data.get("secret", {}).get("screen", ""))
	if not screens.has(id):
		return Vector2.INF
	var r := rectangle(screens[id].walk_regions[0])
	var middle := r.get_center().y
	for x in range(int(r.end.x) - 12, int(r.position.x), -4):
		var candidate := Vector2(x, middle)
		if is_open(id, candidate):
			return candidate
	return point(screens[id].spawn)
