extends SceneTree
const Layout = preload("res://src/blockout/house_layout.gd")
const Paths = preload("res://tools/painted_house_checks.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model := Layout.new()
	check(model.load_layout("res://assets/maps/house-02.painted.layout.json"), "Painted layout validates")
	var paths := Paths.new()
	var positions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.door-positions.json"))
	var original := {}
	for room in positions.rooms:
		for marker in room.markers:
			original[marker.id] = marker.at
	var crossings := 0
	for id in model.screens:
		for portal in model.screens[id].portals:
			check(portal.at == original[portal.id], str(portal.id) + ": user marker unchanged")
			var facing := Layout.point(portal.facing)
			var tangent := facing.orthogonal()
			var threshold := Layout.point(portal.activation_at)
			for offset in [-15.0, 0.0, 15.0]:
				model.inspect_screen(id)
				var start: Vector2 = Layout.point(portal.approach_start) + tangent * offset
				check(model.is_open(id, start), str(portal.id) + ": natural floor approach open at offset " + str(offset))
				var route: Array = paths.route(model, start)
				check(not route.is_empty() or model.position.distance_to(start) < 3, str(portal.id) + ": natural approach reachable around furniture")
				paths.follow(model, route, id)
				check((model.current_id == id and model.position.distance_to(start) <= 3) or model.current_id == portal.target, str(portal.id) + ": continuous room-floor route reaches intended lane without another door stealing it")
				if model.current_id != id:
					model.inspect_screen(id)
				# Route planning is independent of doorway triggers. Once at the
				# approach, walking straight toward the door is all the player does.
				model.position = start
				var clear := true
				for step in range(40):
					if model.current_id != id:
						break
					clear = clear and model.is_open(id, model.position)
					model.walk(facing * 2, 0.02)
				check(clear and model.current_id == portal.target, str(portal.id) + ": continuous walking crosses intended door at offset " + str(offset))
				if model.current_id == portal.target:
					crossings += 1
					check(model.position.is_equal_approx(Layout.point(portal.arrival)), "Arrival uses opposite painted floor threshold")
					check(model.is_open(model.current_id, model.position), "Paired arrival is open floor")
					var destination := model.current_id
					for frame in range(15):
						model.walk(Vector2.ZERO, 0.02)
					check(model.current_id == destination, "Stationary arrival never bounces back")
			model.inspect_screen(id)
			model.position = threshold - facing * 2
			model.walk(-facing * 4, 0.1)
			check(model.current_id == id, "Walking away from a door does not trigger it")
			model.position = threshold
			model.walk(tangent * 8, 0.1)
			check(model.current_id == id, "Walking along a door lane does not steal into it")
	check(crossings == 72, "All 24 directed doors work at center and both 15px offsets")
	check(not model.is_open("hall_2", Vector2(125, 145)), "Actual hall console remains solid")
	check(not model.is_open("room_5", Vector2(240, 205)), "Dining table body remains solid")
	check(model.is_open("room_5", Vector2(272, 160)), "North dining-door approach is usable floor")
	paths.free()
	print(JSON.stringify({"checks": checks, "crossings": crossings, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
