extends SceneTree
const Placement = preload("res://src/mystery/house_item_placement.gd")
const Case = preload("res://src/mystery/generated_case.gd")
var checks := 0
var failures: Array[String] = []
var sample: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 30: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var truth: Dictionary = Case.generate(42)
	for path in ["res://assets/maps/house-02.layout.json", "res://assets/maps/house-02.investigation.layout.json"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var original := JSON.stringify(layout)
		var geometry := Placement.geometry(layout,original.sha256_text())
		for screen in layout.screens:
			if screen.role == "hall": continue
			var candidates := Placement.candidates(layout,str(screen.id))
			check(not candidates.is_empty(), "Room has safe randomized floor positions: " + str(screen.id))
			var reachable := Placement.reachable(geometry,str(screen.id))
			var roomy: Array = reachable.filter(func(p): return Placement.safe(p,geometry,str(screen.id),48.0))
			check(roomy.is_empty() or candidates.all(func(p): return Placement.safe(p,geometry,str(screen.id),48.0)), "Prefer positions beyond guest interaction radius whenever available")
			for candidate in candidates:
				check(Placement.safe(candidate,geometry,str(screen.id)), "Candidates avoid furniture, guest contacts, door triggers and foreground masks")
				check(candidate in reachable or reachable.any(func(p): return p.distance_to(candidate) <= Placement.GRID), "Candidate belongs to spawn-connected floor")
			var seen := {}
			for seed_value in range(100):
				var at := Placement.choose(layout,str(screen.id),seed_value)
				check(at == Placement.choose(layout,str(screen.id),seed_value), "Same seed/layout repeats exact location")
				check(at in candidates and Placement.safe(at,geometry,str(screen.id)), "Chosen position is safe for that room")
				seen[at] = true
			check(seen.size() > 1, "Different cases vary initial item position in " + str(screen.id))
			if path.contains("investigation"): sample[str(screen.id)] = {"safe_positions": candidates.size(), "sampled_positions": seen.size()}
		check(JSON.stringify(layout) == original, "Placement never rewrites authored room layout")
		var first_room: String = str(layout.screens[0].id)
		var first := Placement.choose(layout,first_room,42)
		var changed: Dictionary = layout.duplicate(true)
		changed.screens[0].obstacles.append([first.x-12,first.y-12,24,24])
		var moved := Placement.choose(changed,first_room,42)
		check(moved != first and moved.is_finite(), "Layout changes invalidate cached candidate pools")
	check(Case.generate(42) == truth, "Position streams never change generated facts")
	print(JSON.stringify({"checks": checks, "failures": failures, "painted_rooms":sample}))
	quit(0 if failures.is_empty() else 1)
