extends SceneTree
## Ordinary snapshots cap occupancy; alibi claims are history, not spawn groups.
const Session = preload("res://src/mystery/house_case_session.gd")
const Case = preload("res://src/mystery/generated_case.gd")
const World = preload("res://src/mystery/house_runtime.gd")
var checks := 0
var failures: Array[String] = []
var false_pairs := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and failures.size() < 25: failures.append(message)

func _initialize() -> void: call_deferred("run")

func signature(world: RefCounted) -> String:
	return JSON.stringify(world.guests.map(func(g): return [g.screen, g.position, g.facing, g.staring]))

func validate(world: RefCounted) -> void:
	for guest in world.guests:
		check(world.room_occupancy(str(guest.screen)) <= 2, "Every ordinary room and hall has at most two guests")
		check(world.geometry.is_open(guest.screen, guest.get("interaction_at", guest.position)), "Capped placement remains on usable floor")

func run() -> void:
	for path in ["res://assets/maps/house-02.layout.json", "res://assets/maps/house-02.investigation.layout.json"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var binding = Session.new()
		check(binding.begin(1, layout), "Layout binds rooms")
		for difficulty in ["easy", "normal", "hard"]:
			for seed_value in range(30):
				var data: Dictionary = Case.generate(seed_value, 6, difficulty)
				# Deliberately request the worst crowd; staging must repair it.
				data.guest_start.fill(0)
				var before := JSON.stringify(data)
				var rules := {"guest_leave": 1, "activity_redraw": 1, "entry_death": 0, "culprit_question_death": 0}
				var a = World.new(data, binding.room_ids, layout, rules)
				var b = World.new(data, binding.room_ids, layout, rules)
				validate(a)
				check(signature(a) == signature(b), "Initial staging replays by seed")
				for person in range(data.claims.size()):
					var partner: Variant = data.claims[person].partner
					if partner != null:
						check(a.guests[person].screen != a.guests[int(partner)].screen, "Claimed partners start apart, even false one-way claims")
						if person == data.culprit: false_pairs += 1
				for snapshot in range(12):
					a.advance_to((snapshot + 1) * 50)
					b.advance_to((snapshot + 1) * 50)
					a.update_guest_snapshot()
					b.update_guest_snapshot()
					validate(a)
					check(signature(a) == signature(b), "Repeated movement/isolation snapshots replay")
				check(JSON.stringify(data) == before, "Spawn repair and relocation never change case facts or claims")
		var gathering = Session.new()
		gathering.begin(2, layout)
		gathering.enable_runtime(layout, {"entry_death": 0, "culprit_question_death": 0})
		gathering.progress.carried = gathering.data.weapon_room
		gathering.enter_screen(str(gathering.room_ids[0]))
		check(gathering.assemble(), "Gathering remains possible")
		check(gathering.runtime.guests.all(func(g): return g.screen == str(gathering.progress.screen)), "Gathering explicitly bypasses ordinary two-guest cap")
	check(false_pairs > 0, "Tests include killers with false paired alibis")
	print(JSON.stringify({"checks": checks, "false_paired_claims": false_pairs, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
