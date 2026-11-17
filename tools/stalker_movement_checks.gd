extends SceneTree
## The stalking murderer never lingers in a hall, moves often and tends to meet the player alone in a room (2026-11-17).
const Session = preload("res://src/mystery/house_case_session.gd")
var checks := 0
var failures: Array[String] = []
var layout: Dictionary

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 30: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func start(seed_value: int) -> RefCounted:
	var s = Session.new()
	check(s.begin(seed_value, layout, "normal"), "Case starts")
	s.enable_runtime(layout, {"question_refusal": 0.0, "entry_death": 0.0, "culprit_question_death": 0.0})
	return s

func run() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	var stuck := 0
	var present := 0
	var alone := 0
	var trials := 0
	var calm_in_hall := 0
	for seed_value in range(12):
		var s = start(seed_value)
		var world = s.runtime
		var culprit: int = int(s.data.culprit)
		var rooms: Array = world.room_ids.duplicate()
		for trial in range(40):
			var target: String = str(rooms[trial % rooms.size()])
			world.player_screen = str(rooms[(trial + 3) % rooms.size()])
			if world.player_screen == target: world.player_screen = str(rooms[(trial + 4) % rooms.size()])
			# Stalking: the murderer starts in a hall.
			world.danger_clock = float(world.stalking_at)
			world.guests[culprit].screen = str(world.halls[0])
			world.steps += 25
			world.enter_player_screen(target)
			trials += 1
			if world.guests[culprit].screen in world.halls: stuck += 1
			if world.guests[culprit].screen == target: present += 1
			if world.can_ambush(target): alone += 1
			world.player_screen = ""
			# Calm: ordinary snapshot behaviour is unchanged (a hall stays possible).
			world.danger_clock = 0.0
			world.guests[culprit].screen = str(world.halls[0])
			world.steps += 25
			world.last_guest_snapshot_step = world.steps - 25
			world.enter_player_screen(target)
			if world.guests[culprit].screen in world.halls: calm_in_hall += 1
			world.player_screen = ""
	check(stuck == 0, "A stalking murderer is never left in a hall (%d of %d)" % [stuck, trials])
	check(float(present) / trials > 0.30, "The stalker is in the entered room often (%.0f%%)" % (100.0 * present / trials))
	check(float(alone) / trials > 0.15, "The stalker is alone with the player often enough for an ambush roll (%.0f%%)" % (100.0 * alone / trials))
	check(calm_in_hall > 0, "Before stalking, the murderer can still be in a hall (unchanged behaviour)")
	print(JSON.stringify({"checks": checks, "failures": failures, "stuck": stuck, "present_pct": snappedf(100.0 * present / trials, 0.1), "alone_pct": snappedf(100.0 * alone / trials, 0.1), "trials": trials}))
	quit(0 if failures.is_empty() else 1)
