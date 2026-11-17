extends RefCounted
## Walking advances danger only. Guest snapshots update on room entry, never visibly.
const Stream = preload("res://src/mystery/seed_stream.gd")
const Layout = preload("res://src/blockout/house_layout.gd")
const Dialogue = preload("res://src/mystery/case_dialogue.gd")
const MAX_ROOM_GUESTS := 2
const RULES_PATH := "res://assets/mystery/house_runtime_rules.json"
var rules: Dictionary
var data: Dictionary
var room_ids: Array
var geometry = Layout.new()
var guests: Array = []
var halls: Array = []
var steps := 0
var danger_clock := 0.0
var weapon_carried := false
var warning_at := 0
var stalking_at := 0
var player_screen := ""
var dead := false
var finished := false
var entry_rolls := 0
var question_rolls := 0
var phase_history: Array = ["calm"]
var entry_rng: RefCounted
var question_rng: RefCounted
var refusal_rng: RefCounted
var isolation_rng: RefCounted
var last_guest_snapshot_step := 0
var guest_snapshots := 0
var authored_slots := false
var dialogue = Dialogue.new()
var warning_lines: Dictionary = {}

func _init(case_data: Dictionary, ids: Array, layout: Dictionary, overrides := {}) -> void:
	data = case_data
	room_ids = ids
	rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	var base_chance := float(rules.get("ambush_chance_by_difficulty", {}).get(str(data.difficulty), 0.20))
	rules.entry_death = base_chance
	rules.culprit_question_death = base_chance
	rules.merge(overrides, true)
	geometry.data = layout
	authored_slots = layout.screens.any(func(s): return s.has("guest_slots"))
	for screen in layout.screens:
		geometry.screens[screen.id] = screen
		if screen.has("walk_polygons"):
			var polygons: Array[PackedVector2Array] = []
			for raw in screen.walk_polygons:
				var polygon := PackedVector2Array()
				for vertex in raw:
					polygon.append(geometry.point(vertex))
				polygons.append(polygon)
			geometry.floor_polygons[screen.id] = polygons
	player_screen = str(layout.start)
	for screen in layout.screens:
		if screen.role == "hall":
			halls.append(str(screen.id))
	var clock := rng("clock")
	warning_at = int(rules.warning_min) + clock.below(int(rules.warning_max) - int(rules.warning_min) + 1)
	stalking_at = warning_at + int(rules.stalking_gap_min) + clock.below(int(rules.stalking_gap_max) - int(rules.stalking_gap_min) + 1)
	entry_rng = rng("entry_ambush")
	question_rng = rng("question_ambush")
	refusal_rng = rng("refusal")
	isolation_rng = rng("stalking_isolation")
	for person in range(data.claims.size()):
		var screen: String = room_ids[data.guest_start[person]]
		var guest := {"screen": screen, "position": Vector2.ZERO, "facing": "south", "kind": "stand", "staring": false,
			"move_rng": rng("move_%d" % person), "activity_rng": rng("activity_%d" % person)}
		guests.append(guest)
		guest.screen = initial_destination(person, screen)
		choose_spot(person)
		roll_activity(person)

func room_occupancy(id: String, except_person := -1) -> int:
	var count := 0
	for person in range(guests.size()):
		if person != except_person and guests[person].screen == id:
			count += 1
	return count

func claimed_partner_present(person: int, id: String) -> bool:
	# Includes a culprit's false partner and either direction of a claimed pair.
	# Present-day staging never edits the historical claims or reveals their truth.
	for other in range(guests.size()):
		if other == person or guests[other].screen != id: continue
		if data.claims[person].partner == other or data.claims[other].partner == person:
			return true
	return false

func initial_destination(person: int, requested: String) -> String:
	if has_placement_space(person, requested) and not claimed_partner_present(person, requested):
		return requested
	var candidates: Array = []
	var fallback: Array = []
	for id in room_ids + halls:
		if id in fallback or not has_placement_space(person, str(id)): continue
		fallback.append(id)
		if not claimed_partner_present(person, str(id)): candidates.append(id)
	# A cramped custom map may force an initial pair together, but never a crowd.
	var choices := candidates if not candidates.is_empty() else fallback
	if choices.is_empty():
		push_error("No room has space for guest " + str(data.cast[person]))
		return requested
	return str(rng("initial_staging_%d" % person).choice(choices))

func rng(name: String) -> RefCounted:
	return Stream.new(int(data.version), int(data.seed), "runtime:" + name)

func phase() -> String:
	if dead:
		return "ambush"
	if danger_clock >= stalking_at:
		return "stalking"
	if danger_clock >= warning_at:
		return "suspicious"
	return "calm"

func warning() -> String:
	var state := phase()
	if state in ["suspicious", "stalking"]:
		if not warning_lines.has(state):
			warning_lines[state] = dialogue.system_line("warning_" + state, {}, data)
		return str(warning_lines[state])
	match state:
		"ambush": return "The murderer has ambushed you. This case has ended."
	return "Calm. Walking advances the clock; reading and inspecting do not."

func advance_to(total_steps: int) -> void:
	if finished:
		return
	while steps < total_steps:
		steps += 1
		danger_clock += float(rules.get("weapon_clock_multiplier", 2.0)) if weapon_carried else 1.0
		var current := phase()
		if current != phase_history[-1]:
			phase_history.append(current)

func set_weapon_carried(value: bool) -> void:
	# Callers flush pending physical movement before changing the carried item.
	# Dropping never removes danger already accumulated.
	weapon_carried = value

func attack_chance(kind: String) -> float:
	var base := clampf(float(rules.entry_death if kind == "entry" else rules.culprit_question_death), 0.0, 1.0)
	# Explicit zero/one overrides remain useful for controlled playtests.
	if base <= 0.0 or base >= 1.0: return base
	return clampf(float(rules.get("weapon_question_death", 0.5)), 0.0, 1.0) if kind == "question" and weapon_carried else base

func roll_ambush(kind: String) -> bool:
	var chance := attack_chance(kind)
	if chance <= 0.0: return false
	var stream: RefCounted = entry_rng if kind == "entry" else question_rng
	return stream.chance(chance)

func update_guest_snapshot() -> void:
	# Apply the existing elapsed-step probability only when the room is loaded.
	# No walking, arrivals, departures or activity changes occur in the visible room.
	var elapsed := maxi(0, steps - last_guest_snapshot_step)
	last_guest_snapshot_step = steps
	guest_snapshots += 1
	if elapsed == 0:
		return
	var relocate_chance := 1.0 - pow(1.0 - float(rules.guest_leave), elapsed)
	var activity_chance := 1.0 - pow(1.0 - float(rules.activity_redraw), elapsed)
	var hunting := phase() == "stalking" and float(rules.guest_leave) > 0.0
	for person in range(guests.size()):
		var guest: Dictionary = guests[person]
		if hunting and person == int(data.culprit):
			# The stalker hunts (2026-11-17): it never lingers in a hall, moves far more often, and often turns up in the room
			# the player has just entered so the two can finally be alone together.
			var hunt_chance := 1.0 - pow(1.0 - minf(0.95, float(rules.guest_leave) * float(rules.get("stalking_leave_multiplier", 6.0))), elapsed)
			if guest.screen in halls or guest.move_rng.chance(hunt_chance):
				var hunted := choose_stalker_destination(person)
				if hunted != guest.screen:
					guest.screen = hunted
					choose_spot(person)
				roll_activity(person)
			continue
		if guest.move_rng.chance(relocate_chance):
			var target := choose_destination(person)
			if target != guest.screen:
				guest.screen = target
				choose_spot(person)
			roll_activity(person)
		elif guest.activity_rng.chance(activity_chance):
			roll_activity(person)
	if phase() == "stalking":
		isolate_culprit_room()

func choose_stalker_destination(person: int) -> String:
	var stream: RefCounted = guests[person].move_rng
	var rooms: Array = []
	for id in room_ids:
		if id not in rooms and has_placement_space(person, str(id)):
			rooms.append(id)
	if rooms.is_empty():
		return str(guests[person].screen)
	if player_screen in rooms and stream.chance(float(rules.get("stalking_follow_chance", 0.5))):
		return player_screen
	return str(stream.choice(rooms))

func can_ambush(id: String) -> bool:
	if id in halls or guests[int(data.culprit)].screen != id:
		return false
	for person in range(guests.size()):
		if person != int(data.culprit) and guests[person].screen == id:
			return false
	return true

func free_contact(person: int, id: String, at: Vector2, clearance: float) -> bool:
	for other in range(guests.size()):
		if other != person and guests[other].screen == id and guests[other].position.distance_to(at) < clearance:
			return false
	return true

func has_placement_space(person: int, id: String) -> bool:
	if room_occupancy(id, person) >= MAX_ROOM_GUESTS: return false
	if authored_slots:
		return not available_slots(person, id).is_empty()
	var screen: Dictionary = geometry.screens[id]
	for raw in screen.get("guest_spots", []) + [screen.spawn]:
		var at := geometry.point(raw)
		if geometry.is_open(id, at) and free_contact(person, id, at, 18):
			return true
	for y in range(32, 336, 12):
		for x in range(24, 456, 12):
			var at := Vector2(x, y)
			if geometry.is_open(id, at) and free_contact(person, id, at, 18):
				return true
	return false

func isolate_culprit_room() -> void:
	var culprit_room := str(guests[int(data.culprit)].screen)
	if culprit_room in halls or not isolation_rng.chance(float(rules.stalking_isolation_chance)):
		return
	# This runs only while loading a new room snapshot, before it is shown.
	# Failure to find room elsewhere leaves a bystander in place, keeping safety.
	for person in range(guests.size()):
		if person == int(data.culprit) or guests[person].screen != culprit_room:
			continue
		var destinations: Array = []
		for id in room_ids + halls:
			if id != culprit_room and id not in destinations and has_placement_space(person, str(id)):
				destinations.append(id)
		if destinations.is_empty():
			continue
		guests[person].screen = str(isolation_rng.choice(destinations))
		choose_spot(person, isolation_rng)
		roll_activity(person, isolation_rng)

func enter_player_screen(id: String) -> bool:
	if id == player_screen or finished:
		return false
	player_screen = id
	if id not in halls:
		update_guest_snapshot()
	if phase() != "stalking" or not can_ambush(id):
		return false
	entry_rolls += 1
	if roll_ambush("entry"):
		dead = true
		finished = true
		phase_history.append("ambush")
	return dead

func question(person: int, current_screen := "") -> String:
	if finished:
		return "ended"
	var location := player_screen if current_screen.is_empty() else current_screen
	if person == int(data.culprit) and phase() in ["suspicious", "stalking"] and can_ambush(location):
		question_rolls += 1
		if roll_ambush("question"):
			dead = true
			finished = true
			phase_history.append("ambush")
			return "ambush"
	return "refused" if refusal_rng.chance(float(rules.question_refusal)) else "answer"

func choose_destination(person: int) -> String:
	var stream: RefCounted = guests[person].move_rng
	if authored_slots:
		var available: Array = []
		for id in room_ids + halls:
			if id not in available and has_placement_space(person, str(id)):
				available.append(id)
		if available.is_empty():
			return str(guests[person].screen)
		var crime: String = room_ids[data.murder_room]
		if data.difficulty == "hard" and stream.chance(float(rules.hard_murder_pull)) and crime in available:
			return crime
		var free_halls: Array = halls.filter(func(id): return id in available)
		if not free_halls.is_empty() and stream.chance(float(rules.hall_share)):
			return str(stream.choice(free_halls))
		return str(stream.choice(available))
	var available: Array = []
	for id in room_ids + halls:
		if id not in available and has_placement_space(person, str(id)):
			available.append(id)
	if available.is_empty(): return str(guests[person].screen)
	# The hard murder-room preference is constrained by the same two-guest cap.
	var crime: String = room_ids[data.murder_room]
	if data.difficulty == "hard" and stream.chance(float(rules.hard_murder_pull)) and crime in available:
		return crime
	var free_halls: Array = halls.filter(func(id): return id in available)
	if not free_halls.is_empty() and stream.chance(float(rules.hall_share)):
		return str(stream.choice(free_halls))
	var free_rooms: Array = room_ids.filter(func(id): return id in available)
	return str(stream.choice(free_rooms if not free_rooms.is_empty() else available))

func available_slots(person: int, id: String) -> Array:
	var result: Array = []
	if room_occupancy(id, person) >= MAX_ROOM_GUESTS: return result
	var slots: Array = geometry.screens[id].get("guest_slots", [])
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		# The other cast members currently have standing test art only.
		if slot.posture == "seated" and str(data.cast[person]) not in ["Char", "Chris"]:
			continue
		var at: Vector2 = geometry.point(slot.at)
		var free := true
		for other in range(guests.size()):
			if other == person or guests[other].screen != id:
				continue
			if guests[other].get("slot_id", "") == slot.id or guests[other].position.distance_to(at) < 28:
				free = false
				break
		if free:
			result.append(index)
	return result

func choose_spot(person: int, placement_rng: RefCounted = null) -> bool:
	var guest: Dictionary = guests[person]
	if room_occupancy(str(guest.screen), person) >= MAX_ROOM_GUESTS:
		var destination := ""
		for id in room_ids + halls:
			if has_placement_space(person, str(id)):
				destination = str(id)
				break
		if destination.is_empty():
			push_error("No room has space for guest " + str(data.cast[person]))
			return false
		guest.screen = destination
	if authored_slots:
		var available := available_slots(person, str(guest.screen))
		if available.is_empty():
			# Initial case staging can request a full room. Use another authored
			# contact rather than piling guests onto a spawn or inventing a spot.
			for id in room_ids + halls:
				available = available_slots(person, str(id))
				if not available.is_empty():
					guest.screen = str(id)
					break
		if available.is_empty():
			push_error("No compatible authored guest slot for " + str(data.cast[person]))
			return false
		var slot_stream: RefCounted = guest.move_rng if placement_rng == null else placement_rng
		var selected_slot: int = slot_stream.choice(available)
		var slot: Dictionary = geometry.screens[guest.screen].guest_slots[selected_slot]
		guest.slot_id = str(slot.id)
		guest.position = geometry.point(slot.at)
		guest.interaction_at = geometry.point(slot.interaction_at)
		guest.posture = str(slot.posture)
		guest.facing = str(slot.facing)
		guest.activities = slot.activities.duplicate()
		guest.activity = str(slot.activity)
		guest.kind = "seat" if guest.posture == "seated" else "stand"
		return true
	var screen: Dictionary = geometry.screens[guest.screen]
	var spots: Array = screen.get("guest_spots", [])
	var selected := -1
	for index in range(spots.size()):
		var p: Vector2 = geometry.point(spots[index])
		var free := true
		for other in range(guests.size()):
			if other != person and guests[other].screen == guest.screen and guests[other].position.distance_to(p) < 18:
				free = false
		if free:
			selected = index
			break
	if selected >= 0:
		guest.position = geometry.point(spots[selected])
		guest.kind = str(screen.get("guest_spot_kinds", [])[selected]) if selected < screen.get("guest_spot_kinds", []).size() else "stand"
		var allowed: Variant = screen.get("guest_spot_facing", [])[selected] if selected < screen.get("guest_spot_facing", []).size() else "any"
		guest.facing = str(allowed[0]) if allowed is Array else ("south" if allowed == "any" else str(allowed))
	else:
		guest.position = geometry.point(screen.spawn)
		for y in range(32, 336, 12):
			var found := false
			for x in range(24, 456, 12):
				var p := Vector2(x, y)
				if not geometry.is_open(guest.screen, p): continue
				var free := true
				for other in range(guests.size()):
					if other != person and guests[other].screen == guest.screen and guests[other].position.distance_to(p) < 18:
						free = false
				if free:
					guest.position = p
					found = true
					break
			if found: break
		guest.kind = "stand"
		guest.facing = "south"
	return true

func roll_activity(person: int, activity_override: RefCounted = null) -> void:
	var guest: Dictionary = guests[person]
	var activity_stream: RefCounted = guest.activity_rng if activity_override == null else activity_override
	guest.staring = guest.screen == room_ids[data.murder_room] and data.difficulty == "hard" or activity_stream.chance(float(rules.stare_share))
	if authored_slots:
		var activities: Array = guest.activities
		guest.activity = "look_down" if guest.staring and guest.posture == "standing" and "look_down" in activities else str(activity_stream.choice(activities))
		guest.kind = "seat" if guest.posture == "seated" else ("browse" if guest.activity == "read" else ("window" if guest.activity == "look_up" else "stand"))

func staring_in(id: String) -> bool:
	return guests.any(func(g): return g.screen == id and g.staring)
