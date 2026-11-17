extends SceneTree
const Session = preload("res://src/mystery/house_case_session.gd")
const Case = preload("res://src/mystery/generated_case.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and failures.size() < 20:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func equip(session: RefCounted, wrong_weapon := false) -> void:
	var id: int = session.data.weapon_room
	if wrong_weapon:
		for candidate in session.items:
			if candidate not in [session.data.weapon_room, session.data.glass_room]:
				id = candidate
				break
	session.enter_screen(session.room_ids[id])
	session.take_item(id)

func run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.layout.json"))
	for seed_value in range(40):
		for difficulty in ["easy", "normal"]:
			var session = Session.new()
			check(session.begin(seed_value, layout, difficulty), "Six-suspect case binds to house02")
			check(session.room_names[session.binding.kitchen] == "Study", "Accounts use actual map names, not cosmetic generator labels")
			check(not session.progress.glass and session.progress.heard.is_empty() and session.progress.crime_room == null and session.progress.weapon == null, "Fresh notebook contains no hidden evidence")
			check(not session.assemble(), "Assembly needs a non-glass held item")
			check(session.accuse(0, 0).result == "blocked", "No early accusation")
			session.enter_screen(session.room_ids[session.data.weapon_room])
			session.take_item()
			check(session.progress.carried == session.data.weapon_room and session.progress.weapon == null, "Any item can be taken before identification")
			session.inspect_item()
			session.inspect_floor()
			check(session.progress.weapon == null and session.progress.crime_room == null, "Close inspection requires glass")
			session.drop_item(session.items[session.data.weapon_room].position)
			session.enter_screen(session.room_ids[session.data.glass_room])
			session.take_item()
			check(session.progress.glass, "Glass is discoverable and collectible")
			check(not session.assemble(), "Glass takes the carrying slot but cannot assemble")
			for person in range(6):
				session.enter_screen(session.room_ids[session.data.guest_start[person]])
				var text: String = session.question(person)
				var known: Dictionary = session.progress.heard[str(person)].duplicate(true)
				var recap: String = session.question(person)
				check(not text.is_empty() and recap == session.question(person) and session.progress.heard[str(person)] == known, "Repeated recaps preserve facts and seeded voice")
			for room in range(session.room_ids.size()):
				session.enter_screen(session.room_ids[room])
				session.inspect_floor()
				session.inspect_item()
			check(session.progress.crime_room == session.data.murder_room and session.progress.wound == session.items[session.data.weapon_room].kind, "Murder-room discovery supplies the actual catalog weapon's wound kind")
			check(session.progress.weapon == (session.data.weapon_room if difficulty == "easy" else null), "Only Easy explicitly identifies the weapon")
			check(session.progress.carried == session.data.glass_room, "Inspection never replaces the held glass")
			var matching_items: Array = []
			for key in session.progress.items_seen:
				var seen: Dictionary = session.progress.items_seen[key]
				if seen.get("stain") == "present" and seen.kind == session.progress.wound:
					matching_items.append(int(key))
			check(matching_items == [session.data.weapon_room], "Learned stain and wound evidence identifies exactly one item")
			check(difficulty == "easy" or not session.notebook().contains("Identified weapon:"), "Normal notebook leaves weapon deduction to player")
			var possible: Array = Case.candidates(6, session.progress.heard, session.progress.crime_room)
			check(possible == [session.data.culprit], "Learned evidence alone produces one reconstruction")
			session.enter_screen(session.room_ids[matching_items[0]])
			session.take_item(matching_items[0])
			check(session.progress.glass and session.last_message_key == "hands_full", "Take cannot silently replace the held glass")
			session.drop_item(session.items[matching_items[0]].position)
			session.take_item(matching_items[0])
			check(not session.progress.glass and session.progress.carried == matching_items[0], "Dropping glass permits carrying deduced item")
			check(session.assemble(), "Carried true weapon permits assembly")
			check(session.accuse(possible[0], session.progress.crime_room).result == "solved", "Accusation from discovered evidence wins")
			check(not session.active(), "Solved case ends")
			for wrong in [[true, false, "wrong_room"], [false, true, "wrong_person"], [false, false, "both_wrong"], [true, true, "wrong_weapon"]]:
				var other = Session.new()
				other.begin(seed_value, layout, difficulty)
				equip(other, wrong[2] == "wrong_weapon")
				check(other.progress.heard.is_empty() and other.progress.crime_room == null and other.assemble(), "Assembly has no all-accounts or known-room checklist")
				var suspect: int = other.data.culprit if wrong[0] else (other.data.culprit + 1) % 6
				var room: int = other.data.murder_room if wrong[1] else (other.data.murder_room + 1) % other.room_ids.size()
				var result: Dictionary = other.accuse(suspect, room)
				check(result.result == wrong[2] and not other.active(), "Correct terminal wrong-accusation outcome")
				check(str(other.data.cast[other.data.culprit]) in result.message and str(other.room_names[other.data.murder_room]) in result.message, "Loss reveals the full solution")
				check(other.accuse(other.data.culprit, other.data.murder_room).result == "blocked", "Wrong accusation cannot be retried")
	var hard = Session.new()
	hard.begin(1, layout, "hard")
	hard.enter_screen(hard.room_ids[hard.data.glass_room])
	hard.take_item()
	hard.enter_screen(hard.room_ids[hard.data.murder_room])
	hard.inspect_floor(false)
	check(hard.progress.crime_room == null, "Hard clue waits for the future staring simulation")
	hard.inspect_floor(true)
	check(hard.progress.crime_room == hard.data.murder_room, "Hard trace can be observed while staring")
	print(JSON.stringify({"checks": checks, "cases": 80, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
