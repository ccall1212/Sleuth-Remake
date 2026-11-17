extends SceneTree
## Ambushes require an isolated encounter with the physically present culprit.
const Session = preload("res://src/mystery/house_case_session.gd")
var layout: Dictionary
var painted_layout: Dictionary
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 25:
		failures.append(label)

func session(seed_value := 2, painted := false, isolation := 0.0) -> RefCounted:
	var s = Session.new()
	var map: Dictionary = (painted_layout if painted else layout).duplicate(true)
	check(s.begin(seed_value, map, "hard"), "Danger case binds layout")
	s.enable_runtime(map, {"guest_leave": 0, "activity_redraw": 0, "question_refusal": 0,
		"entry_death": 1, "culprit_question_death": 1, "stalking_isolation_chance": isolation})
	return s

func stage(s: RefCounted, id: String, people: Array) -> void:
	# Temporary test staging, completed before any runtime action.
	for g in s.runtime.guests:
		g.screen = "test-staging"
	for person in range(s.runtime.guests.size()):
		var elsewhere: String = s.room_ids[(person + 1) % s.room_ids.size()]
		if elsewhere == id:
			elsewhere = str(s.room_ids[(person + 2) % s.room_ids.size()])
		s.runtime.guests[person].screen = id if person in people else elsewhere
		s.runtime.choose_spot(person)
		s.runtime.roll_activity(person)
	check(s.runtime.guests.filter(func(g): return g.screen == id).size() == people.size(), "Fixture has exact encounter occupancy")

func guests(world: RefCounted) -> String:
	return JSON.stringify(world.guests.map(func(g): return [g.screen, g.position, g.facing, g.staring, g.get("slot_id", ""), g.get("activity", ""), g.move_rng.counter, g.activity_rng.counter]))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.layout.json"))
	painted_layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	for painted in [false, true]:
		for encounter in ["absent", "crowded", "alone", "hall"]:
			var s := session(2, painted)
			var world: RefCounted = s.runtime
			world.advance_to(world.stalking_at)
			var culprit: int = s.data.culprit
			var other := (culprit + 1) % 6
			var room: String = world.halls[0] if encounter == "hall" else s.room_ids[0]
			var people: Array = [] if encounter == "absent" else ([culprit, other] if encounter == "crowded" else [culprit])
			stage(s, room, people)
			var eligible: bool = encounter == "alone"
			check(world.can_ambush(room) == eligible, "Eligibility reflects culprit, bystanders and safe hall")
			world.player_screen = s.room_ids[1]
			check(world.enter_player_screen(room) == eligible, "Forced entry death still requires isolated actual encounter")
			check(world.entry_rolls == (1 if eligible else 0), "Unsafe entry roll consumed only for eligible encounter")
			var q := session(2, painted)
			q.runtime.advance_to(q.runtime.warning_at)
			stage(q, room, people)
			check((q.runtime.question(culprit, room) == "ambush") == eligible, "Forced culprit-question death requires isolation even after suspicion")
			check(q.runtime.question_rolls == (1 if eligible else 0), "Question death RNG not consumed in protected encounter")
		for chance in [0.0, 1.0]:
			var s := session(7, painted, chance)
			var world: RefCounted = s.runtime
			world.rules.entry_death = 0
			world.rules.culprit_question_death = 0
			var culprit: int = s.data.culprit
			var people: Array = [culprit, (culprit + 1) % 6]
			var room: String = s.room_ids[0]
			stage(s, room, people)
			var truth: Dictionary = s.data.duplicate(true)
			var culprit_at: Vector2 = world.guests[culprit].position
			var before := guests(world)
			world.advance_to(world.stalking_at + 24)
			check(guests(world) == before and world.isolation_rng.counter == 0, "Stalking never clears a room while it is being viewed")
			world.enter_player_screen(world.halls[0])
			check(guests(world) == before and world.isolation_rng.counter == 0, "Hall entry does not resample isolation")
			world.enter_player_screen(room)
			var expected := 1 if chance == 1 else 2
			check(world.guests.filter(func(g): return g.screen == room).size() == expected, "Isolation 0/1 controls relocation of bystanders")
			check(world.guests[culprit].position == culprit_at and world.guests[culprit].screen == room, "Isolation never moves culprit")
			check(not world.dead, "Isolation chance is not an automatic death chance")
			check(s.data == truth, "Isolation never changes alibis or truth")
			var snapshot := guests(world)
			world.advance_to(world.steps + 100)
			world.enter_player_screen(room)
			check(guests(world) == snapshot and world.guest_snapshots == 1, "Loaded visit cannot clear or relocate a second time")
			for person in range(world.guests.size()):
				var g: Dictionary = world.guests[person]
				check(g.screen != "test-staging", "Every guest remains assigned to a real room")
				if painted:
					var matches: Array = world.geometry.screens[g.screen].guest_slots.filter(func(slot): return slot.id == g.slot_id)
					check(matches.size() == 1, "Isolated bystander occupies a compatible authored slot")
					check(g.posture != "seated" or s.data.cast[person] in ["Char", "Chris"], "Isolation respects standing-only cast")
				else:
					check(world.geometry.is_open(g.screen, g.position), "Legacy isolation uses open-floor contacts")
				if g.screen == s.room_ids[s.data.murder_room]:
					check(g.staring, "Hard murder-room clue remains visible")
		# No eligible destination must leave bystanders present and protective.
		var full := session(11, painted, 1)
		full.runtime.advance_to(full.runtime.stalking_at)
		var room: String = full.room_ids[0]
		stage(full, room, [full.data.culprit, (full.data.culprit + 1) % 6])
		for id in full.runtime.geometry.screens:
			if id == room:
				continue
			if painted:
				full.runtime.geometry.screens[id].guest_slots = []
			else:
				full.runtime.geometry.screens[id].walk_regions = []
				full.runtime.geometry.screens[id].door_access_regions = []
		check(not full.runtime.enter_player_screen(room), "No free destination means bystander stays and prevents ambush")
		check(not full.runtime.can_ambush(room), "Isolation cannot invent space or remove a guest")
	# The grab scene uses the actual held evidence item (the glass is a tool, not evidence), rather
	# than naming the true weapon in hands that may contain something else.
	for carrying in ["empty", "glass", "ordinary", "weapon"]:
		var s := session(2, true)
		var held: Variant = null
		if carrying == "glass": held = s.data.glass_room
		elif carrying == "weapon": held = s.data.weapon_room
		elif carrying == "ordinary":
			for id in s.items:
				if id not in [s.data.glass_room, s.data.weapon_room]:
					held = id
					break
		if held != null:
			s.enter_screen(s.room_ids[held])
			s.take_item(held)
		var evidence: Variant = null if carrying == "glass" else held
		check(s.progress.carried == evidence and s.progress.glass == (carrying == "glass") and s.runtime.weapon_carried == (carrying == "weapon"), "Only true held weapon accelerates danger; the glass tool is never carried")
		var room: String = s.room_ids[0]
		stage(s, room, [s.data.culprit])
		s.runtime.advance_to(s.runtime.stalking_at)
		s.runtime.player_screen = s.runtime.halls[0]
		var ending: Dictionary = s.observe_world(s.runtime.steps, room)
		check(ending.get("result") == "ambushed", "Actual isolated room entry triggers each inventory ambush")
		check(ending.get("message_key") == ("ambush_locked" if evidence == null else "ambush_grab"), "Grab applies to every held evidence item; the glass tool alone stays locked")
		if evidence != null:
			var narrative: String = str(ending.message).split("\n\n")[0]
			check(narrative.contains(s.item_name(held)), "Grab narration names what was actually held")
			if held != s.data.weapon_room:
				check(not narrative.contains(s.item_name(s.data.weapon_room)), "Grab does not falsely put true weapon into player hands")
	# Independent seeded isolation stream replays; it never changes clock thresholds.
	var isolated_count := 0
	for seed_value in range(40):
		var a := session(seed_value, true, 0.5)
		var b := session(seed_value, true, 0.5)
		for s in [a, b]:
			s.runtime.rules.entry_death = 0
			stage(s, s.room_ids[0], [s.data.culprit, (s.data.culprit + 1) % 6])
			s.runtime.advance_to(s.runtime.stalking_at + 12)
			s.runtime.enter_player_screen(s.room_ids[0])
		check(guests(a.runtime) == guests(b.runtime), "Isolation snapshots replay from seed")
		check(a.runtime.warning_at == b.runtime.warning_at and a.runtime.stalking_at == b.runtime.stalking_at, "Isolation uses no clock RNG")
		if a.runtime.can_ambush(a.room_ids[0]):
			isolated_count += 1
	check(isolated_count > 0 and isolated_count < 40, "Default 50% isolation produces both seeded outcomes")
	print(JSON.stringify({"checks": checks, "isolated_cases": isolated_count, "sample_cases": 40, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
