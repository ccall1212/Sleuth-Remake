extends SceneTree
## The accusation room is the room where everyone was gathered; every outcome still works.
const Session = preload("res://src/mystery/house_case_session.gd")
var checks := 0
var failures: Array[String] = []
var layout: Dictionary

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 30: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func gathered(seed_value: int, room_index: int, hold_true_weapon: bool) -> RefCounted:
	var s = Session.new()
	check(s.begin(seed_value, layout, "normal"), "Case starts")
	s.enable_runtime(layout, {"question_refusal": 0.0, "entry_death": 0.0, "culprit_question_death": 0.0, "guest_leave": 0.0})
	var screen_id: String = str(s.room_ids[room_index])
	var holder: int = int(s.data.weapon_room)
	if not hold_true_weapon:
		for id in s.items:
			if id != int(s.data.weapon_room) and id != int(s.data.glass_room) and str(s.items[id].screen) != "":
				holder = id
				break
	s.enter_screen(str(s.items[holder].screen))
	s.take_item(holder)
	s.enter_screen(screen_id)
	check(s.assemble(), "Gathering succeeds in " + screen_id)
	return s

func run() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	for seed_value in range(6):
		var probe = Session.new()
		probe.begin(seed_value, layout, "normal")
		var crime: int = int(probe.data.murder_room)
		var culprit: int = int(probe.data.culprit)
		var innocent: int = (culprit + 1) % 6
		var wrong_room := -1
		for index in range(probe.room_ids.size() - 1):
			if index != crime and index not in probe.data.no_item_rooms:
				wrong_room = index
				break
		var s = gathered(seed_value, crime, true)
		check(s.accuse(culprit).result == "solved", "Right person, gathered in the crime room, true weapon: solved")
		s = gathered(seed_value, wrong_room, true)
		check(s.accuse(culprit).result == "wrong_room", "Right person gathered in the wrong room keeps the wrong_room outcome")
		s = gathered(seed_value, crime, true)
		check(s.accuse(innocent).result == "wrong_person", "Wrong person, right gathering room: wrong_person")
		s = gathered(seed_value, wrong_room, true)
		check(s.accuse(innocent).result == "both_wrong", "Wrong person and wrong room: both_wrong")
		s = gathered(seed_value, crime, false)
		check(s.accuse(culprit).result == "wrong_weapon", "Right person and room with a decoy in hand: wrong_weapon")
		s = gathered(seed_value, crime, true)
		check(s.accuse(-1).result == "blocked" or s.accuse(99).result == "blocked", "Invalid suspect is blocked")
		var ungathered = Session.new()
		ungathered.begin(seed_value, layout, "normal")
		check(ungathered.accuse(culprit).result == "blocked", "Accusing before gathering is blocked")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
