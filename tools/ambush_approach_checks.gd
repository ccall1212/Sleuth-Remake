extends SceneTree
const Approach = preload("res://src/blockout/ambush_approach.gd")
const Layout = preload("res://src/blockout/house_layout.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func validate_path(model: RefCounted, points: Array[Vector2], player: Vector2) -> void:
	check(not points.is_empty(), "A reachable approach has a route")
	if points.is_empty(): return
	check(points[-1].distance_to(player) >= 20 and points[-1].distance_to(player) <= 34, "Killer stops near player without occupying their feet")
	for index in range(points.size()):
		check(model.is_open("test", points[index]), "Every waypoint remains on clear room floor")
		if index > 0:
			check(Approach.segment_open(model, "test", points[index - 1], points[index]), "Every smoothed movement segment avoids furniture")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model := Layout.new()
	model.screens = {"test": {"id": "test", "walk_regions": [[0, 0, 480, 360]], "obstacles": [[180, 40, 72, 220]], "portals": [{"at": [0, 180], "target": "other"}]}}
	model.current_id = "test"
	model.position = Vector2(340, 160)
	model.steps = 7
	model.room_entries = 3
	var before := JSON.stringify(model.screens)
	var source := Vector2(80, 160)
	var player := Vector2(340, 160)
	var points := Approach.route(model, "test", source, player)
	validate_path(model, points, player)
	check(points.is_empty() or points[0] == source, "Open starting contact is preserved")
	check(model.current_id == "test" and model.position == player and model.steps == 7 and model.room_entries == 3, "Planning neither moves the player nor enters a doorway or advances steps")
	check(JSON.stringify(model.screens) == before, "Planning never changes room geometry")
	# A thin wall cannot be skipped between 8px nodes or by path smoothing.
	model.screens.test.obstacles = [[199, -8, 1, 376]]
	check(Approach.route(model, "test", source, player).is_empty(), "Unreachable player behind full thin wall returns no route")
	model.screens.test.obstacles = [[40, 40, 24, 24]]
	points = Approach.route(model, "test", Vector2(52, 52), player)
	validate_path(model, points, player)
	check(points.is_empty() or points[0].distance_to(Vector2(52, 52)) <= 48, "Furniture-overlapping seated start snaps only to nearby clear contact")
	model.screens.test.obstacles = [[0, 0, 480, 360]]
	check(Approach.route(model, "test", source, player).is_empty(), "No clear floor returns no forced path")
	check(Approach.route(model, "test", Vector2.INF, player).is_empty(), "Nonfinite source is rejected")
	model.screens.test.obstacles = []
	points = Approach.route(model, "test", Vector2(312, 160), player)
	validate_path(model, points, player)
	check(points.size() == 1 and points[0] == Vector2(312, 160), "Killer already close needs no forced movement")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
