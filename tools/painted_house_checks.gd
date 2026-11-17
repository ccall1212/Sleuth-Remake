extends SceneTree
const Layout = preload("res://src/blockout/house_layout.gd")
const RoomTexture = preload("res://src/blockout/approved_room_texture.gd")
const PATH := "res://assets/maps/house-02.painted.layout.json"
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func route(model: RefCounted, target: Vector2) -> Array[Vector2]:
	var start: Vector2 = model.position
	var queue: Array[Vector2] = [start]
	var previous := {start: Vector2.INF}
	var index := 0
	var end := Vector2.INF
	while index < queue.size():
		var p := queue[index]
		index += 1
		if p.distance_to(target) <= 3.0:
			end = p
			break
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var next: Vector2 = p + direction * 4
			if not previous.has(next) and model.is_open(model.current_id, next) and model.is_open(model.current_id, p + direction * 2):
				queue.append(next)
				previous[next] = p
	if end == Vector2.INF: return []
	var path: Array[Vector2] = []
	while end != start:
		path.push_front(end)
		end = previous[end]
	return path

func follow(model: RefCounted, path: Array[Vector2], room: String) -> void:
	for p in path:
		if model.current_id != room: break
		model.walk(p - model.position, 0.05)

func run() -> void:
	var model = Layout.new()
	check(model.load_layout(PATH), "Painted layout validates: " + model.error)
	if not failures.is_empty():
		print(JSON.stringify({"checks": checks, "failures": failures}))
		quit(1)
		return
	var positions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.door-positions.json"))
	var markers := {}
	for room in positions.rooms:
		for m in room.markers: markers[m.id] = m
	var doors := 0
	for id in model.screens:
		var screen: Dictionary = model.screens[id]
		check(FileAccess.get_sha256(screen.background) == screen.background_sha256, str(id) + ": approved image hash")
		check(RoomTexture.load_approved(screen.background, screen.background_sha256) != null, str(id) + ": approved room texture loads")
		check(screen.guest_spots.is_empty(), str(id) + ": guest placements explicitly deferred")
		for portal in screen.portals:
			doors += 1
			check(Layout.point(portal.at) == Layout.point(markers[portal.id].at), str(portal.id) + ": exact user coordinates")
			model.inspect_screen(id)
			var path := route(model, Layout.point(portal.at))
			check(not path.is_empty(), str(portal.id) + ": reachable around furniture")
			follow(model, path, id)
			if model.current_id == id:
				model.walk(Layout.point(portal.facing) * 10, 0.3)
			check(model.current_id == portal.target, str(portal.id) + ": walked through correct connection (room " + model.current_id + " at " + str(model.position) + ")")
			check(model.position.distance_to(Layout.point(portal.arrival)) < 0.01, str(portal.id) + ": paired arrival")
			check(model.is_open(model.current_id, model.position), str(portal.id) + ": open arrival")
	check(doors == 24, "All24 directed doors tested")
	# Reproduce the natural carpet approaches, not just a route that can find
	# a circuitous way around a false wall beside the door.
	for id in ["hall_2", "room_2"]:
		for portal in model.screens[id].portals:
			if portal.side not in ["east", "west"]: continue
			var at: Vector2 = Layout.point(portal.at)
			var facing: Vector2 = Layout.point(portal.facing)
			var floor_at := at + Vector2(0, 34)
			var start := floor_at - facing * 60
			model.inspect_screen(id)
			model.position = start
			var clear := model.is_open(id, start)
			for step in range(1, 31):
				var point := start + facing * step * 2
				clear = clear and model.is_open(id, point)
				model.walk(facing * 2, 0.05)
			for step in range(1, 18):
				var point := floor_at - Vector2(0, step * 2)
				clear = clear and model.is_open(id, point)
				model.walk(Vector2(0, -2), 0.05)
			check(clear, str(portal.id) + ": carpet approach has no false collision")
			model.walk(facing * 4, 0.3)
			check(model.current_id == portal.target, str(portal.id) + ": natural carpet approach enters door")
	check(model.is_open("room_2", Vector2(425, 210)), "Removed living-room console no longer blocks floor")
	check(not model.is_open("hall_2", Vector2(125, 145)), "Hall console itself remains solid")
	check(model.secret_panel() == Layout.point(markers["library-secret-panel"].at), "Library panel matches user position")
	check(model.secret_exit() == Layout.point(markers["passage-study-exit"].at), "Study panel matches user position")
	for item in [
		["library", model.secret_panel(), "secret_passage"],
		["secret_passage", Layout.point(model.data.secret.return_at), "library"],
		["secret_passage", model.secret_exit(), "kitchen"]]:
		model.inspect_screen(item[0])
		var path := route(model, item[1])
		check(not path.is_empty(), str(item[0]) + ": panel approachable")
		follow(model, path, item[0])
		check(model.interact_secret(), str(item[0]) + ": E uses panel")
		check(model.current_id == item[2], "Secret panel correct destination")
		check(model.is_open(model.current_id, model.position), "Secret arrival open")
	print(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
