extends SceneTree
const Session = preload("res://src/mystery/house_case_session.gd")
const Case = preload("res://src/mystery/generated_case.gd")
var layout: Dictionary
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 25:
		failures.append(label)

func session(seed_value := 2, difficulty := "normal") -> RefCounted:
	var s = Session.new()
	check(s.begin(seed_value, layout, difficulty), "Session begins with real room bindings")
	return s

func equip(s: RefCounted) -> void:
	s.enter_screen(s.room_ids[s.data.glass_room])
	s.take_item(s.data.glass_room)
	s.enter_screen(s.room_ids[s.data.weapon_room])
	s.inspect_item(s.data.weapon_room)
	s.drop_item(s.items[s.data.weapon_room].position)
	s.take_item(s.data.weapon_room)

func carry_item(s: RefCounted, id: int) -> void:
	if s.progress.carried != null:
		s.drop_item(s.held_item().position)
	s.enter_screen(str(s.items[id].screen))
	s.take_item(id)

func guest_state(world: RefCounted) -> String:
	return JSON.stringify(world.guests.map(func(g): return [g.screen, g.position, g.facing, g.kind, g.staring, g.move_rng.counter, g.activity_rng.counter]))

func full_truth(s: RefCounted, text: String) -> void:
	check(str(s.data.cast[s.data.culprit]) in text, "Ending reveals culprit")
	check(str(s.data.cast[-1]) in text, "Ending reveals victim")
	check(str(s.room_names[s.data.murder_room]) in text, "Ending reveals real room")
	check(s.item_name(s.data.weapon_room) in text, "Ending reveals weapon")
	check("{" not in text and "}" not in text, "Ending substitutes every template slot")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.layout.json"))
	for voice in Case.PERSONALITIES:
		var s := session(23)
		s.data.personalities.fill(voice)
		var truth: Dictionary = s.data.duplicate(true)
		for person in range(6):
			s.enter_screen(s.guest_screen(person))
			var first: String = s.question(person)
			check(not first.is_empty() and s.dialogue.last_error.is_empty(), "First authored account renders for " + voice)
			check(s.last_message_group == "personality_lines" and s.last_message_key == "opening", "First success identifies opening message")
			var repeat: String = s.question(person)
			check(first != repeat and repeat == s.question(person), "First answer differs; subsequent recaps are deterministic")
			var claim: Dictionary = s.data.claims[person]
			check(s.progress.heard[str(person)] == claim, "Notebook stores only unchanged claim facts")
			check(str(s.room_names[claim.room]) in first and str(s.room_names[claim.room]) in repeat, "Both answers use actual house room name")
			if claim.partner != null:
				check(str(s.data.cast[claim.partner]) in first and str(s.data.cast[claim.partner]) in repeat, "Both answers retain actual claimed partner")
			check("{" not in first and "{" not in repeat, "No unexpanded dialogue slots")
			check(first not in s.notebook() and repeat not in s.notebook(), "Notebook excludes personality prose")
		check(s.data == truth, "Dialogue does not mutate case truth or claims")
	var refused := session(7)
	refused.enable_runtime(layout, {"guest_leave": 0, "activity_redraw": 0, "question_refusal": 1, "culprit_question_death": 0})
	refused.enter_screen(refused.guest_screen(0))
	var before := guest_state(refused.runtime)
	var progress_before: Dictionary = refused.progress.duplicate(true)
	var denied: String = refused.question(0)
	check(not denied.is_empty() and refused.last_message_key == "refusal", "Refusal uses personality dataset")
	check(not denied.contains('"') and not denied.to_lower().contains("ask me"), "Refusal remains a silent physical response")
	check(refused.progress == progress_before, "Refusal records no unspoken facts")
	refused.runtime.rules.question_refusal = 0
	var retry: String = refused.question(0)
	check(refused.last_message_key == "opening" and retry != denied, "Retry after refusal is the first successful full account")
	var recap: String = refused.question(0)
	check(recap == refused.question(0) and retry != recap, "Successful repeat uses deterministic recap")
	check(guest_state(refused.runtime) == before and refused.runtime.steps == 0, "Dialogue does not change guest poses, staging RNG, or clock")
	var gates := session(5, "hard")
	gates.enter_screen(gates.room_ids[gates.data.weapon_room])
	gates.inspect_item(gates.data.weapon_room)
	check(gates.progress.weapon == null and gates.last_message_key != "item_flavor_generic", "No harmless flavor on unexamined potential weapon")
	gates.take_item(gates.data.weapon_room)
	check(gates.progress.carried == gates.data.weapon_room and gates.last_message_key != "get_refused_not_weapon", "Any item can be picked up before lens inspection")
	gates.drop_item(gates.items[gates.data.weapon_room].position)
	gates.enter_screen(gates.room_ids[gates.data.murder_room])
	gates.inspect_floor()
	check(gates.progress.crime_room == null and gates.progress.clean_floors.is_empty(), "No-glass floor remains inconclusive")
	carry_item(gates, gates.data.glass_room)
	gates.enter_screen(gates.room_ids[gates.data.murder_room])
	var inconclusive: String = gates.inspect_floor(false)
	check(gates.progress.clean_floors.is_empty() and gates.progress.crime_room == null and gates.last_message_key == "floor_inconclusive", "Hard no-staring result never clears a room")
	gates.inspect_floor(true)
	check(gates.progress.crime_room == gates.data.murder_room and gates.last_message_key == "wound_" + str(gates.progress.wound), "Real Hard trace gets authored red wound discovery key")
	gates.enter_screen(gates.room_ids[gates.data.weapon_room])
	gates.inspect_item(gates.data.weapon_room)
	check(gates.last_message_key == "lens_stain" and gates.progress.weapon == null, "Hard lens shows authored orange stain without auto-identifying weapon")
	check(not gates.assemble() and gates.last_message_key == "assemble_need_item", "Assembly rejects glass in the single carrying slot")
	var empty := session(8)
	check(not empty.assemble() and empty.last_message_key == "assemble_need_item", "Assembly empty-hands hint comes from data")
	var clean: int = (gates.data.murder_room + 1) % gates.room_ids.size()
	if clean == gates.data.glass_room or clean == gates.data.weapon_room:
		clean = (clean + 1) % gates.room_ids.size()
	var watched := session(6)
	watched.enable_runtime(layout, {"guest_leave": 0, "activity_redraw": 0})
	carry_item(watched, watched.data.glass_room)
	clean = (watched.data.murder_room + 1) % watched.room_ids.size()
	var clean_id: String = watched.room_ids[clean]
	for g in watched.runtime.guests:
		g.screen = watched.room_ids[watched.data.murder_room]
	watched.enter_screen(clean_id)
	watched.inspect_floor()
	check(watched.last_message_key == "floor_nothing_unwatched" and clean in watched.progress.clean_floors, "No occupants selects unwatched negative floor text")
	watched.runtime.guests[0].screen = clean_id
	watched.runtime.guests[0].staring = false
	watched.inspect_floor()
	check(watched.last_message_key == "floor_nothing", "Any occupant selects watched text even without staring")
	for voice in Case.PERSONALITIES:
		for outcome in ["solved", "wrong_room", "wrong_person", "both_wrong", "wrong_weapon"]:
			var ending := session(19)
			ending.data.personalities[ending.data.culprit] = voice
			equip(ending)
			if outcome == "wrong_weapon":
				var wrong_item: int = range(ending.room_ids.size()).filter(func(id): return id != ending.data.glass_room and id != ending.data.weapon_room)[0]
				carry_item(ending, wrong_item)
			ending.enter_screen("room_4")
			check(ending.assemble(), "Any carried non-glass item permits assembly")
			var assembly: String = ending.assemble_message()
			check(assembly == ending.assemble_message() and ending.progress.assembled, "Assembly text is stable after physical gathering")
			var person: int = ending.data.culprit if outcome in ["solved", "wrong_room", "wrong_weapon"] else (ending.data.culprit + 1) % 6
			var room: int = ending.data.murder_room if outcome in ["solved", "wrong_person", "wrong_weapon"] else (ending.data.murder_room + 1) % ending.room_ids.size()
			var result: Dictionary = ending.accuse(person, room)
			check(result.result == outcome and not ending.active(), "Accusation preserves terminal outcome")
			check(ending.last_message_key == "confession" if outcome == "solved" else ending.last_message_key != "win", "No invented rank or personality-to-pose mapping")
			full_truth(ending, result.message)
		for carrying in ["empty", "weapon", "glass", "other"]:
			var ending := session(13)
			ending.data.personalities[ending.data.culprit] = voice
			if carrying == "weapon":
				equip(ending)
			elif carrying == "glass":
				carry_item(ending, ending.data.glass_room)
			elif carrying == "other":
				var item: int = range(ending.room_ids.size()).filter(func(id): return id != ending.data.glass_room and id != ending.data.weapon_room)[0]
				carry_item(ending, item)
			var result: Dictionary = ending.ambush()
			check(result.message_key == ("ambush_locked" if carrying == "empty" else "ambush_grab"), "Any held item including glass selects matching grab ambush")
			if carrying != "empty": check(ending.held_item().name in result.message, "Grab names actual held item rather than substituting true weapon")
			check(result.message_group == "personality_lines" and ending.progress.outcome == "ambushed", "Ambush metadata preserves red style and terminal state")
			full_truth(ending, result.message)
	var replay := session(23)
	replay.data.personalities.fill("warm")
	replay.enter_screen(replay.guest_screen(0))
	var first: String = replay.question(0)
	replay.begin(23, layout)
	replay.data.personalities.fill("warm")
	replay.enter_screen(replay.guest_screen(0))
	check(first == replay.question(0), "Replaying seed restores first dialogue and cosmetic choice")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
