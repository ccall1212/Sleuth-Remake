extends SceneTree
const Session = preload("res://src/mystery/house_case_session.gd")
const Case = preload("res://src/mystery/generated_case.gd")
var checks := 0
var failures: Array[String] = []
var layout: Dictionary

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 30: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func session(seed_value: int, difficulty := "normal") -> RefCounted:
	var s = Session.new()
	check(s.begin(seed_value, layout, difficulty), "Case starts with kind-compatible catalog")
	s.enable_runtime(layout, {"question_refusal": 0.0, "entry_death": 0.0, "culprit_question_death": 0.0, "guest_leave": 0.0})
	return s

func hold(s: RefCounted, id: int) -> void:
	if s.progress.carried != null:
		s.drop_item(s.runtime.geometry.point(s.runtime.geometry.screens[s.progress.screen].spawn))
	s.enter_screen(str(s.items[id].screen))
	s.take_item(id)

func run() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mystery/house_item_catalog.json"))
	var type_kinds := {}
	for entry in catalog.items: type_kinds[entry.name] = entry.kind
	for difficulty in ["easy", "normal", "hard"]:
		for seed_value in range(12):
			var s = session(seed_value, difficulty)
			var original: Dictionary = s.data.duplicate(true)
			check(s.items.size() == s.room_ids.size() and s.progress.items_seen.is_empty(), "One instance per original slot; notebook starts without unseen truth")
			check(s.notebook().contains("ITEMS / LAST KNOWN LOCATIONS") and not s.notebook().contains("stain: present"), "Fresh notebook reveals no stains")
			var names := {}
			for item in s.items.values():
				names[item.name] = true
				check(item.kind == ("" if item.is_glass else type_kinds[item.name]), "Runtime kind agrees with the actual catalog item type")
			check(names.size() == s.items.size(), "Case item variants have distinct names")
			var glass: int = s.data.glass_room
			hold(s, glass)
			check(s.progress.carried == glass and s.progress.glass and s.held_item().is_glass, "Magnifying glass occupies the sole carrying slot")
			var weapon: int = s.data.weapon_room
			s.enter_screen(s.items[weapon].screen)
			s.take_item(weapon)
			check(s.last_message_key == "hands_full" and s.progress.carried == glass, "Cannot secretly swap glass for any other item")
			var stains: Array = []
			var observed_kinds := {}
			for id in s.items:
				if id == glass: continue
				s.enter_screen(s.items[id].screen)
				s.inspect_item(id)
				var seen: Dictionary = s.progress.items_seen[str(id)]
				check(seen.kind == s.items[id].kind and seen.has("stain"), "Lens records inspected kind and stain fact by stable item ID")
				observed_kinds[id] = seen.kind
				if seen.stain == "present": stains.append(id)
			check(stains.size() == (1 if difficulty == "easy" else 3), "Lens reveals required true-plus-decoy stain count")
			check((s.progress.weapon == weapon) if difficulty == "easy" else s.progress.weapon == null, "Only Easy explicitly identifies weapon")
			s.enter_screen(s.room_ids[s.data.murder_room])
			if difficulty == "hard":
				for guest in s.runtime.guests:
					guest.staring = false
				s.inspect_floor()
				check(s.progress.crime_room == null and s.progress.wound == null, "Hard trace is inconclusive without staring guest")
				s.runtime.guests[0].screen = s.progress.screen
				s.runtime.guests[0].staring = true
			s.inspect_floor()
			check(s.progress.crime_room == s.data.murder_room and s.progress.wound == s.items[weapon].kind, "Murder-room discovery reveals actual weapon type's wound kind")
			if difficulty != "easy":
				check(s.progress.weapon == null and not s.notebook().contains("Identified weapon:"), "Notebook does not automatically solve the stain/wound deduction")
			var candidates: Array = []
			for id in stains:
				if observed_kinds[id] == s.progress.wound: candidates.append(id)
			check(candidates == [weapon], "Observed stain/kind/wound evidence uniquely identifies true item")
			var hall: String = "hall_2"
			s.enter_screen(hall)
			var at: Vector2 = s.runtime.geometry.point(s.runtime.geometry.screens[hall].spawn)
			s.drop_item(at)
			check(not s.progress.glass and s.progress.carried == null and s.items[glass].screen == hall and s.items[glass].position == at, "Dropping glass in hall leaves it exactly there and disables lens")
			check(s.progress.items_seen[str(glass)].screen == hall and not s.progress.items_seen[str(glass)].held, "Notebook tracks dropped glass location")
			s.inspect_floor()
			check(s.last_message_key == "no_floor", "Hall remains a non-clue floor")
			s.take_item(glass)
			check(s.progress.glass and s.items[glass].screen.is_empty(), "Glass can be recovered in a hall")
			s.drop_item(at)
			hold(s, weapon)
			check(s.progress.carried == weapon and not s.progress.glass and s.runtime.weapon_carried, "True weapon occupies same slot and enables clock multiplier")
			s.inspect_floor()
			check(s.last_message_key == "floor_needs_glass", "Carrying weapon cannot use lens")
			s.enter_screen("room_4")
			var kitchen_at: Vector2 = s.runtime.geometry.point(s.runtime.geometry.screens.room_4.spawn)
			s.drop_item(kitchen_at)
			check(not s.runtime.weapon_carried and s.items[weapon].screen == "room_4", "Dropping true weapon updates location and restores clock rate")
			s.take_item(weapon)
			check(s.progress.carried == weapon, "Moved weapon can be picked up away from its origin")
			check(s.data == original, "Inventory and clue observations never alter generated case truth")
	# Any non-glass item permits gathering; final item can change afterward.
	for result in ["solved", "wrong_weapon", "wrong_room", "wrong_person", "both_wrong"]:
		var s = session(8)
		var weapon: int = s.data.weapon_room
		var wrong: int = s.items.keys().filter(func(id): return id != weapon and id != s.data.glass_room)[0]
		hold(s, wrong)
		s.enter_screen("room_4")
		check(s.progress.weapon == null and s.assemble() and s.progress.assembly_room == "room_4", "Any unexamined non-glass item gathers everyone in current room")
		var at: Vector2 = s.runtime.geometry.point(s.runtime.geometry.screens.room_4.spawn)
		s.drop_item(at)
		check(s.accuse(s.data.culprit, s.data.murder_room).result == "blocked", "Empty hands cannot finalize accusation after gathering")
		# Move the desired fixture item into the locked gathering room as test setup.
		var chosen: int = weapon if result == "solved" else wrong
		s.items[chosen].screen = "room_4"
		s.items[chosen].position = at
		s.take_item(chosen)
		var person: int = s.data.culprit if result in ["solved", "wrong_weapon", "wrong_room"] else (s.data.culprit + 1) % 6
		var room: int = s.data.murder_room if result in ["solved", "wrong_weapon", "wrong_person"] else (s.data.murder_room + 1) % s.room_ids.size()
		var ending: Dictionary = s.accuse(person, room)
		check(ending.result == result and not s.active(), "Final accusation selects terminal outcome " + result)
		if result == "wrong_weapon": check(ending.message.contains(s.item_name(wrong)) and ending.message.contains(s.item_name(weapon)), "Wrong-weapon confession names held and actual weapon separately")
	var s = session(17)
	hold(s, s.data.glass_room)
	var held_glass: int = s.progress.carried
	s.drop_item(Vector2.INF)
	check(s.progress.carried == held_glass and s.last_message_key == "drop_blocked", "Non-finite drop cannot lose carried item")
	s.drop_item(Vector2(-50, -50))
	check(s.progress.carried == held_glass and s.last_message_key == "drop_blocked", "Drop outside reachable floor cannot lose carried item")
	check(not s.assemble() and not s.progress.assembled, "Glass cannot gather suspects")
	var glass_name: String = s.held_item().name
	var true_name: String = s.item_name(s.data.weapon_room)
	var ending: Dictionary = s.ambush()
	check(ending.message.contains(glass_name) and ending.message.contains(true_name), "Ambush grabs held glass while truth summary retains actual weapon")
	print(JSON.stringify({"checks": checks, "failures": failures, "cases": 36, "outcomes": 5}))
	quit(0 if failures.is_empty() else 1)
