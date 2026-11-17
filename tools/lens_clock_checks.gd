extends SceneTree
const World = preload("res://src/mystery/house_runtime.gd")
const Case = preload("res://src/mystery/generated_case.gd")
var checks := 0
var failures: Array[String] = []
var layout: Dictionary
var ids: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func world(extra := {}) -> RefCounted:
	var overrides := {"question_refusal": 0, "entry_death": 0, "culprit_question_death": 0,
		"stalking_isolation_chance": 0}
	overrides.merge(extra, true)
	return World.new(Case.generate(19), ids, layout, overrides)

func signature(w: RefCounted) -> String:
	return JSON.stringify(w.guests.map(func(g): return [g.screen, g.position, g.activity, g.staring, g.move_rng.counter, g.activity_rng.counter]))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	for screen in layout.screens:
		if screen.role == "room": ids.append(screen.id)
	for screen in layout.screens:
		if screen.role == "secret": ids.append(screen.id)
	var w = world()
	check(w.rules.weapon_clock_multiplier == 2.0 and w.rules.question_refusal == 0, "Weapon multiplier is configurable with independent refusal override")
	var defaults = World.new(Case.generate(19), ids, layout)
	check(defaults.rules.question_refusal == 0.10, "Approved silent refusal rate is ten percent")
	w.advance_to(30)
	check(w.steps == 30 and w.danger_clock == 30.0, "Empty-hand movement counts once in both clocks")
	w.set_weapon_carried(true)
	w.advance_to(45)
	check(w.steps == 45 and w.danger_clock == 60.0, "True weapon doubles danger only, not physical steps")
	w.set_weapon_carried(false)
	w.advance_to(50)
	check(w.steps == 50 and w.danger_clock == 65.0, "Drop restores normal future rate without reversing danger")
	w.advance_to(50)
	check(w.danger_clock == 65.0, "Repeated observe and no walking never advance clock")
	w.set_weapon_carried(true)
	check(w.danger_clock == 65.0 and w.warning_lines.is_empty(), "Pickup is silent and cannot change past walking")
	w.advance_to(51)
	check(w.danger_clock == 67.0, "Only subsequent walking is weighted")
	var fractional = world({"weapon_clock_multiplier": 1.5})
	fractional.set_weapon_carried(true)
	fractional.advance_to(3)
	check(fractional.steps == 3 and fractional.danger_clock == 4.5, "Fractional tuning retains its accumulated remainder")
	for seed_value in range(10):
		var batched = World.new(Case.generate(seed_value), ids, layout, {"stalking_isolation_chance": 0})
		var individual = World.new(Case.generate(seed_value), ids, layout, {"stalking_isolation_chance": 0})
		batched.set_weapon_carried(true)
		individual.set_weapon_carried(true)
		batched.advance_to(100)
		for step in range(1, 101): individual.advance_to(step)
		check(batched.danger_clock == individual.danger_clock and batched.phase_history == individual.phase_history, "Clock is frame-batch independent")
		check(signature(batched) == signature(individual), "Weighted danger does not visibly move guests during visit")
	var onset = world({"warning_min": 4, "warning_max": 4, "stalking_gap_min": 4, "stalking_gap_max": 4})
	onset.set_weapon_carried(true)
	onset.advance_to(2)
	check(onset.phase() == "suspicious" and onset.steps == 2, "Weighted clock reaches seeded warning threshold")
	onset.advance_to(4)
	check(onset.phase() == "stalking" and onset.steps == 4, "Weighted clock reaches stalking without extra movement")
	var normal = world({"warning_min": 10000, "warning_max": 10000})
	var fast = world({"warning_min": 10000, "warning_max": 10000})
	fast.set_weapon_carried(true)
	normal.advance_to(40)
	fast.advance_to(40)
	normal.update_guest_snapshot()
	fast.update_guest_snapshot()
	check(signature(normal) == signature(fast) and fast.last_guest_snapshot_step == 40, "Guest snapshot probabilities use physical elapsed steps")
	var guarded = world({"entry_death": 1.0, "culprit_question_death": 1.0})
	guarded.set_weapon_carried(true)
	guarded.advance_to(1000)
	var culprit: int = guarded.data.culprit
	var room: String = ids[0]
	for guest in guarded.guests: guest.screen = room
	check(not guarded.can_ambush(room) and guarded.question(culprit, room) == "answer", "Witnesses still prevent accelerated-clock ambush")
	var hall: String = guarded.halls[0]
	guarded.guests[culprit].screen = hall
	check(not guarded.can_ambush(hall) and guarded.question(culprit, hall) == "answer", "Halls remain safe while weapon is held")
	guarded.guests[culprit].screen = ids[1]
	check(guarded.can_ambush(ids[1]) and guarded.question(culprit, ids[1]) == "ambush", "Accelerated clock still permits ambush only when alone with killer")
	var before: float = guarded.danger_clock
	guarded.finished = true
	guarded.advance_to(2000)
	check(guarded.danger_clock == before and guarded.steps == 1000, "Gathering or terminal freeze stops both clocks")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
