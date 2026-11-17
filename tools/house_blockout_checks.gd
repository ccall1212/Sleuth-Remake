extends SceneTree
const Layout = preload("res://src/blockout/house_layout.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func route(model: RefCounted, start: Vector2, target: Vector2) -> Array[Vector2]:
	# Walk the actual floor geometry; no teleport shortcuts through furniture.
	var frontier: Array[Vector2] = [start]
	var previous := {start: Vector2.INF}
	var index := 0
	var end := Vector2.INF
	while index < frontier.size():
		var p := frontier[index]
		index += 1
		if p.distance_to(target) <= 4.0:
			end = p
			break
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var next: Vector2 = p + direction * 4
			var unwanted_door := false
			for portal in model.screen().get("portals", []):
				var doorway: Vector2 = model.point(portal.at)
				var threshold: Vector2 = model.point(portal.get("activation_at", portal.at))
				if target.distance_to(threshold) <= 8 or target.distance_to(doorway) <= 8:
					continue
				if portal.has("trigger_region"):
					# Plan against the same painted floor lane used by real
					# traversal, not the older circle on the door-leaf marker.
					# Parallel/inward travel is safe; an outward crossing of an
					# unrelated doorway would leave the screen before our goal.
					var zone: Rect2 = model.rectangle(portal.trigger_region)
					var facing: Vector2 = model.point(portal.facing)
					if direction.dot(facing) > 0.4:
						for distance in [2.0, 4.0]:
							var attempted: Vector2 = p + direction * distance
							if (zone.has_point(attempted) or zone.has_point(attempted - direction * 2)) and (attempted - threshold).dot(facing) >= -0.01:
								unwanted_door = true
								break
				elif next.distance_to(doorway) < 14:
					unwanted_door = true
				if unwanted_door:
					break
			if not unwanted_door and not previous.has(next) and model.is_open(model.current_id, next):
				frontier.append(next)
				previous[next] = p
	if end == Vector2.INF:
		return []
	var path: Array[Vector2] = []
	while end != start:
		path.push_front(end)
		end = previous[end]
	return path

func walk_path(model: RefCounted, path: Array[Vector2], expected_screen: String) -> void:
	for p in path:
		if model.current_id != expected_screen:
			break
		model.walk(p - model.position, 0.05)

func run() -> void:
	var model = Layout.new()
	check(model.load_layout(), "Layout loads and validates")
	if not failures.is_empty():
		print(JSON.stringify({"checks": checks, "failures": failures, "error": model.error}))
		quit(1)
		return
	check(model.screens.size() == 11, "Nine rooms plus hall and secret")
	check(model.screen().name == "Front Entry", "Start uses authored Front Entry")
	check(model.screens.kitchen.name == "Study", "Names take precedence over legacy IDs")
	var doors := 0
	for id in model.screens:
		for portal in model.screens[id].get("portals", []):
			model.inspect_screen(id)
			var path := route(model, model.position, Layout.point(portal.at))
			check(not path.is_empty(), str(id) + ": doorway reachable around obstacles")
			walk_path(model, path, id)
			if model.current_id == id:
				model.walk(Layout.point(portal.facing) * 4, 0.3)
			if model.current_id != portal.target:
				print("DOOR_DIAGNOSTIC ", id, " position=", model.position, " expected=", portal)
			check(model.current_id == portal.target, str(id) + ": actual walking crosses to " + str(portal.target))
			check(model.position.distance_to(Layout.point(portal.arrival)) < 0.01, "Authored destination arrival preserved")
			check(model.is_open(model.current_id, model.position), "Arrival is on open floor")
			check(model.room_entries == (0 if model.screen().role == "hall" else 1), "Only non-hall arrivals count as room entries")
			var distance: float = model.walked_pixels
			model.walk(Vector2.ZERO, 1)
			check(is_equal_approx(model.walked_pixels, distance), "Standing still never adds walking distance")
			doors += 1
	check(doors == 24, "All 24 directed authored doors exercised")
	# Exact distance and collision checks independent of authored doorway positions.
	var fixture = Layout.new()
	fixture.data = {"start": "a", "px_per_step": 24}
	fixture.screens = {"a": {"name": "Test", "role": "room", "spawn": [24, 24], "walk_regions": [[0, 0, 120, 120]], "obstacles": [[60, 0, 4, 120]], "portals": []}}
	fixture.reset()
	fixture.walk(Vector2(24, 0))
	check(fixture.steps == 1, "24 logical walking pixels equal one step")
	fixture.walk(Vector2(120, 0))
	check(fixture.position.x <= 60, "Large movement cannot tunnel through thin furniture")
	var before: float = fixture.walked_pixels
	fixture.walk(Vector2(48, 0))
	check(is_equal_approx(fixture.walked_pixels, before), "Walking against an obstacle adds no steps")
	fixture.walk(Vector2(0, 24))
	check(fixture.position.y == 48, "Can slide along obstacle boundary")
	fixture.reset()
	fixture.walk(Vector2(-120, 0))
	check(fixture.position.x == 0, "Cannot leave the walk-region union")
	# A real room crossing must not charge the remote arrival coordinate distance.
	model.inspect_screen("room_6")
	var portal: Dictionary = model.screen().portals[0]
	model.position = Layout.point(portal.at)
	check(model.try_door(Layout.point(portal.facing)), "Door can activate at exact anchor")
	check(model.walked_pixels == 0 and model.steps == 0, "Portal teleport adds no walking pixels")
	model.inspect_screen("library")
	var panel: Vector2 = model.secret_panel()
	var panel_path := route(model, model.position, panel)
	check(not panel_path.is_empty(), "Secret panel is reachable without walking through a bookshelf")
	walk_path(model, panel_path, "library")
	check(model.interact_secret() and model.current_id == "secret_passage", "E opens the secret passage")
	var exit_path := route(model, model.position, model.secret_exit())
	check(not exit_path.is_empty(), "Secret passage exit is reachable around crates")
	walk_path(model, exit_path, "secret_passage")
	check(model.interact_secret() and model.current_id == "kitchen", "Secret passage exits into authored Study")
	model.inspect_screen("room_4")
	check(model.steps == 0 and model.room_entries == 0, "Inspection jump resets measurements")
	print(JSON.stringify({"checks": checks, "doors": doors, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
