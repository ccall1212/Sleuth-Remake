extends SceneTree
const Session = preload("res://src/mystery/house_case_session.gd")
var checks := 0
var failures: Array[String] = []
var layout: Dictionary

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and failures.size() < 25:
		failures.append(message)

func session(seed_value := 2, difficulty := "normal", overrides := {}) -> RefCounted:
	var result = Session.new()
	result.begin(seed_value, layout, difficulty)
	result.enable_runtime(layout, overrides)
	return result

func signature(world: RefCounted) -> String:
	var guests: Array = []
	for g in world.guests:
		guests.append([g.screen, g.position, g.facing, g.staring, g.move_rng.counter, g.activity_rng.counter])
	return JSON.stringify([world.steps, world.warning_at, world.stalking_at, world.phase_history, guests])

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.layout.json"))
	var still := {"guest_leave": 0, "activity_redraw": 0, "question_refusal": 0}
	var s = session(2, "normal", still)
	var world: RefCounted = s.runtime
	check(world.warning_at >= 140 and world.warning_at <= 200, "Warning threshold stays in seeded range")
	check(world.stalking_at - world.warning_at >= 80 and world.stalking_at - world.warning_at <= 115, "Stalking gap stays in seeded range")
	world.advance_to(world.warning_at - 1)
	check(world.phase() == "calm", "Calm before exact warning threshold")
	world.advance_to(world.warning_at)
	check(world.phase() == "suspicious", "Warning starts at exact threshold")
	world.advance_to(world.stalking_at)
	check(world.phase() == "stalking" and world.phase_history == ["calm", "suspicious", "stalking"], "Phase warnings occur once in order")
	var remembered := signature(world)
	world.advance_to(world.steps)
	check(signature(world) == remembered, "Idle frames do not change time or guests")
	world.rules.entry_death = 1
	world.enter_player_screen(world.halls[0])
	for unused in range(100):
		check(not world.enter_player_screen(world.halls[0]) and not world.dead, "Halls never roll entry death")
	check(world.entry_rolls == 0, "No hall entry-roll RNG consumption")
	var safe_questions := session(2, "normal", {"guest_leave": 0, "culprit_question_death": 1, "question_refusal": 0})
	safe_questions.runtime.advance_to(safe_questions.runtime.warning_at)
	var culprit: int = safe_questions.data.culprit
	var hall: String = safe_questions.runtime.halls[0]
	safe_questions.runtime.guests[culprit].screen = hall
	safe_questions.enter_screen(hall)
	safe_questions.question(culprit)
	check(safe_questions.active() and safe_questions.progress.heard.has(str(culprit)), "Hall questioning is safe even for the culprit after warning")
	check(safe_questions.runtime.question_rolls == 0, "Hall questioning does not consume an ambush roll")
	for carrying in [false, true]:
		var ambushed := session(2, "normal", {"warning_min": 1, "warning_max": 1, "stalking_gap_min": 1, "stalking_gap_max": 1, "entry_death": 1, "guest_leave": 0, "stalking_isolation_chance": 0})
		if carrying:
			ambushed.enter_screen(ambushed.room_ids[ambushed.data.glass_room])
			ambushed.take_item()
			ambushed.enter_screen(ambushed.room_ids[ambushed.data.weapon_room])
			ambushed.inspect_item()
			ambushed.take_item()
		for person in range(ambushed.runtime.guests.size()):
			ambushed.runtime.guests[person].screen = ambushed.room_ids[0] if person == ambushed.data.culprit else ambushed.room_ids[1 + person % (ambushed.room_ids.size() - 1)]
		for person in range(ambushed.runtime.guests.size()):
			ambushed.runtime.choose_spot(person)
		var result: Dictionary = ambushed.observe_world(2, ambushed.room_ids[0])
		check(result.get("result") == "ambushed" and not ambushed.active(), "Stalking room entry alone with present culprit can end the case")
		check(result.message_key == ("ambush_grab" if carrying else "ambush_locked"), "Weapon in hand selects distinct authored ambush scene")
		check(str(ambushed.data.cast[ambushed.data.culprit]) in result.message and str(ambushed.room_names[ambushed.data.murder_room]) in result.message and ambushed.item_name(ambushed.data.weapon_room) in result.message, "Ambush reveals full solution")
		var frozen := signature(ambushed.runtime)
		ambushed.observe_world(1000, hall)
		check(signature(ambushed.runtime) == frozen, "Terminal ambush freezes runtime")
	var questioned := session(2, "normal", {"guest_leave": 0, "culprit_question_death": 1, "question_refusal": 0})
	for person in range(questioned.runtime.guests.size()):
		questioned.runtime.guests[person].screen = questioned.room_ids[0] if person == questioned.data.culprit else questioned.room_ids[1 + person % (questioned.room_ids.size() - 1)]
	for person in range(questioned.runtime.guests.size()):
		questioned.runtime.choose_spot(person)
	questioned.runtime.advance_to(questioned.runtime.warning_at)
	questioned.enter_screen(questioned.guest_screen(questioned.data.culprit))
	questioned.question(questioned.data.culprit)
	check(questioned.progress.outcome == "ambushed", "Culprit questioning becomes dangerous at suspicion before stalking")
	var refused := session(7, "normal", {"guest_leave": 0, "question_refusal": 1})
	refused.enter_screen(refused.guest_screen(0))
	refused.question(0)
	check(refused.progress.heard.is_empty(), "Refusal does not add unspoken account")
	refused.runtime.rules.question_refusal = 0
	var answer: String = refused.question(0)
	var recap: String = refused.question(0)
	check(not answer.is_empty() and recap == refused.question(0) and refused.progress.heard["0"] == refused.data.claims[0], "Answer facts and seeded recaps stay stable after refusal")
	check(refused.runtime.steps == 0, "Questioning and inspection do not add walking steps")
	var hard := session(2, "hard", {"guest_leave": 0, "activity_redraw": 0, "stare_share": 0, "hard_murder_pull": 1, "hall_share": 1})
	var crime: String = hard.room_ids[hard.data.murder_room]
	for person in range(6):
		hard.runtime.guests[person].screen = hard.room_ids[(hard.data.murder_room + 1) % hard.room_ids.size()]
		hard.runtime.guests[person].staring = false
		check(hard.runtime.choose_destination(person) == crime, "Hard pull precedes hall selection")
	hard.progress.glass = true
	hard.enter_screen(crime)
	hard.inspect_floor(true)
	check(hard.progress.crime_room == null, "Hard floor check cannot inject a fake staring flag")
	hard.runtime.guests[0].screen = crime
	hard.runtime.roll_activity(0)
	check(hard.runtime.guests[0].staring, "Idle guest in murder room always stares on Hard")
	hard.inspect_floor()
	check(hard.progress.crime_room == hard.data.murder_room, "Hard trace requires a real live staring guest")
	# Per-step simulation must replay identically across renderer frame batches.
	var a := session(23, "hard")
	var b := session(23, "hard")
	a.runtime.advance_to(500)
	for step in range(1, 501):
		b.runtime.advance_to(step)
	check(signature(a.runtime) == signature(b.runtime), "Frame batching does not change seeded guest/clock outcomes")
	# Rejected walking behaviour: no guest may move or change activity mid-room.
	var snapshot_case := session(9, "hard", {"guest_leave": 1, "activity_redraw": 1, "hard_murder_pull": 1, "entry_death": 0})
	var snap: RefCounted = snapshot_case.runtime
	var crime_id: String = snapshot_case.room_ids[snapshot_case.data.murder_room]
	var elsewhere: String = snapshot_case.room_ids[(snapshot_case.data.murder_room + 1) % snapshot_case.room_ids.size()]
	for person in range(6):
		snap.guests[person].screen = elsewhere
		snap.choose_spot(person)
		snap.roll_activity(person)
	var original_case: Dictionary = snapshot_case.data.duplicate(true)
	var guests_before := JSON.stringify(snap.guests.map(func(g): return [g.screen, g.position, g.facing, g.staring]))
	snap.advance_to(100)
	check(JSON.stringify(snap.guests.map(func(g): return [g.screen, g.position, g.facing, g.staring])) == guests_before, "Walking in a room never moves guests or changes their activity, even at forced probability")
	snap.enter_player_screen(snap.halls[0])
	check(JSON.stringify(snap.guests.map(func(g): return [g.screen, g.position, g.facing, g.staring])) == guests_before, "Hall entry does not resample guest snapshots")
	snap.enter_player_screen(snapshot_case.room_ids[0])
	check(snap.guest_snapshots == 1, "Entering a room resolves exactly one guest snapshot")
	check(snap.room_occupancy(crime_id) == 2, "Hard pull fills murder room to two guests without crowding")
	for guest in snap.guests:
		check(snap.room_occupancy(str(guest.screen)) <= 2, "Room entry snapshot respects the two-guest limit")
		if guest.screen == crime_id:
			check(guest.staring, "Hard murder-room guests retain floor inspection activity")
		check(snap.geometry.is_open(guest.screen, guest.position), "Snapshot guest is placed on valid open floor")
		check(not guest.has("moving") and not guest.has("path"), "Guest has no walking or path state")
	var loaded := JSON.stringify(snap.guests.map(func(g): return [g.screen, g.position, g.facing, g.staring]))
	snap.advance_to(1000)
	snap.enter_player_screen(snap.player_screen)
	check(JSON.stringify(snap.guests.map(func(g): return [g.screen, g.position, g.facing, g.staring])) == loaded and snap.guest_snapshots == 1, "Snapshot stays fixed for the entire visit despite further walking or repeated inspection sync")
	check(snapshot_case.data == original_case, "Relocation never edits alibis or truth")
	# Same seed, entries and elapsed steps give identical room snapshots.
	a.runtime.enter_player_screen(a.room_ids[0])
	b.runtime.enter_player_screen(b.room_ids[0])
	check(signature(a.runtime) == signature(b.runtime), "Entry snapshot replay is independent of frame batching")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
