extends RefCounted
## Playable investigation state. The notebook contains only learned facts.
const Case = preload("res://src/mystery/generated_case.gd")
const World = preload("res://src/mystery/house_runtime.gd")
const Dialogue = preload("res://src/mystery/case_dialogue.gd")
const Assembly = preload("res://src/mystery/house_assembly.gd")
const ITEMS := ["Letter opener", "Brass candlestick", "Heavy book", "Glass decanter", "Iron poker", "Kitchen knife", "Marble ornament", "Walking cane", "Small hammer", "Old wrench"]
var data: Dictionary = {}
var progress: Dictionary = {}
var room_ids: Array = []
var room_names: Array = []
var binding: Dictionary = {}
var runtime: RefCounted
var dialogue = Dialogue.new()
var screen_names: Dictionary = {}
var last_message := ""
var last_message_key := ""
var last_message_group := ""
var assembly_text := ""
var item_names: Array = []
var refusal_counts: Dictionary = {}
var case_layout: Dictionary = {}
var items: Dictionary = {}

func message(value: String, group := "", key := "") -> String:
	last_message = value
	last_message_group = group
	last_message_key = key
	return value

func system_message(key: String, slots := {}, event := "") -> String:
	if not dialogue.data.get("system", {}).has(key):
		return message("[PENDING_DIALOGUE:%s]" % key, "system", key)
	return message(dialogue.system_line(key, slots, data, event), "system", key)

func truth_slots(person := -1, chosen_room := -1) -> Dictionary:
	return {"speaker": str(data.cast[data.culprit if person < 0 else person]),
		"culprit": str(data.cast[data.culprit]), "victim": str(data.cast[-1]),
		"weapon": item_name(data.weapon_room), "room": str(room_names[data.murder_room]),
		"true_room": str(room_names[data.murder_room]),
		"chosen_room": str(room_names[chosen_room]) if chosen_room >= 0 else "",
		"held_item": str(held_item().get("name", "")), "chosen_weapon": str(held_item().get("name", "")),
		"alibi": culprit_alibi()}

func culprit_alibi() -> String:
	var claim: Dictionary = data.claims[data.culprit]
	var place := "the " + str(room_names[int(claim.room)])
	return place + (" on my own" if claim.partner == null else " with " + str(data.cast[int(claim.partner)]))

func truth_summary() -> String:
	if not dialogue.data.get("system", {}).has("truth_summary"):
		return "[PENDING_DIALOGUE:truth_summary]"
	return dialogue.system_line("truth_summary", truth_slots(), data, "truth")

func begin(seed_value: int, layout: Dictionary, difficulty := "normal") -> bool:
	runtime = null
	case_layout = layout
	refusal_counts.clear()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mystery/house_item_catalog.json"))
	item_names.clear()
	items.clear()
	room_ids.clear()
	room_names.clear()
	binding.clear()
	screen_names.clear()
	message("")
	assembly_text = ""
	for screen in layout.get("screens", []):
		screen_names[screen.id] = str(screen.name)
		if screen.get("role") == "room":
			room_ids.append(screen.id)
			room_names.append(screen.name)
	for screen in layout.get("screens", []):
		if screen.get("role") == "secret":
			room_ids.append(screen.id)
			room_names.append(screen.name)
	# Rooms without an item_slot (the Front Entry) can never hold evidence; the generator is told so.
	var no_item_rooms: Array = []
	for index in range(room_ids.size()):
		if not has_item_slot(str(room_ids[index])): no_item_rooms.append(index)
	data = Case.generate(seed_value, 6, difficulty, Case.POOL, [], no_item_rooms)
	if data.is_empty() or room_ids.size() != data.rooms.size():
		return false
	for index in range(room_ids.size()):
		binding[room_ids[index]] = index
	progress = {"room": -1, "glass": false, "heard": {}, "clean_floors": [], "clear_items": [],
		"crime_room": null, "weapon": null, "wound": null, "carried": null, "assembled": false, "outcome": "investigating", "items_seen": {}, "inventory_schema_version": 2}
	if not prepare_items(catalog):
		return false
	enter_screen(str(layout.start))
	return true

func has_item_slot(screen_id: String) -> bool:
	for screen in case_layout.get("screens", []):
		if str(screen.id) == screen_id: return screen.has("item_slot")
	return false

func drop_allowed(screen_id: String) -> bool:
	# Halls take dropped items; a room without an item_slot (the Front Entry) never does.
	for screen in case_layout.get("screens", []):
		if str(screen.id) == screen_id:
			return screen.has("item_slot") or str(screen.get("role", "")) == "hall"
	return false

func enter_screen(id: String) -> void:
	if progress.get("assembled", false) and id != progress.get("assembly_room", id):
		return
	progress.room = int(binding.get(id, -1))
	progress.screen = id

func enable_runtime(layout: Dictionary, overrides := {}) -> void:
	runtime = World.new(data, room_ids, layout, overrides)
	sync_carried_state()

func guest_screen(person: int) -> String:
	return str(runtime.guests[person].screen) if runtime != null else str(room_ids[data.guest_start[person]])

func observe_world(total_steps: int, id: String) -> Dictionary:
	enter_screen(id)
	if progress.get("assembled", false):
		return {}
	if runtime == null or not active():
		return {}
	runtime.advance_to(total_steps)
	if runtime.enter_player_screen(id):
		return ambush()
	return {}

func ambush_slots() -> Dictionary:
	var slots := truth_slots()
	if progress.carried != null:
		slots.weapon = str(held_item().get("name", slots.weapon)) # a grab takes whatever is held
	return slots

func ambush() -> Dictionary:
	progress.outcome = "ambushed"
	var key := "ambush_grab" if progress.carried != null else "ambush_locked"
	var scene: String = dialogue.personality_line(data, data.culprit, key, ambush_slots(), "ambush")
	var closure: String = dialogue.system_line("investigation_ended", {}, data, "end") if dialogue.data.system.has("investigation_ended") else "[PENDING_DIALOGUE:investigation_ended]"
	var text := message(scene + "\n\n" + truth_summary() + "\n\n" + closure, "personality_lines", key)
	return {"result": "ambushed", "message": text, "message_key": key, "message_group": last_message_group}

func active() -> bool:
	return progress.get("outcome", "") == "investigating"

func prepare_items(catalog: Dictionary) -> bool:
	var art_rng = Case.stream(int(data.seed), "item_art")
	var pool: Array = art_rng.shuffle(catalog.get("items", []))
	if pool.size() < room_ids.size() - 1 - data.get("no_item_rooms", []).size():
		message("[PENDING_DIALOGUE:item_catalog_capacity]")
		return false
	var dealt := {}
	var cursor := 0
	for id in range(room_ids.size()):
		if id == int(data.glass_room) or id in data.get("no_item_rooms", []): continue
		dealt[id] = pool[cursor]
		cursor += 1
	var unused: Array = pool.slice(cursor)
	var weapon: int = data.weapon_room
	var wound: String = dealt[weapon].kind
	var ordinary: Array = range(room_ids.size() - 1).filter(func(id): return id != weapon and id != int(data.glass_room) and id not in data.get("no_item_rooms", []))
	# Unique real item types replace the reference's unconstrained kind pool.
	# Ensure two ordinary decoys still differ from the actual weapon kind,
	# swapping an unused/hidden type rather than relabelling any object's kind.
	if not bool(data.get("weapon_certain", true)):
		var compatible: Array = ordinary.filter(func(id): return dealt[id].kind != wound)
		while compatible.size() < 2:
			var targets: Array = ordinary.filter(func(id): return dealt[id].kind == wound)
			if targets.is_empty(): return false
			var target: int = targets[0]
			var donor := -1
			for index in range(unused.size()):
				if str(unused[index].kind) != wound:
					donor = index
					break
			if donor >= 0:
				var previous: Dictionary = dealt[target]
				dealt[target] = unused[donor]
				unused[donor] = previous
			else:
				var hidden := room_ids.size() - 1
				if hidden == weapon or not dealt.has(hidden) or str(dealt[hidden].kind) == wound:
					message("[PENDING_DIALOGUE:item_catalog_capacity]")
					return false
				var previous: Dictionary = dealt[target]
				dealt[target] = dealt[hidden]
				dealt[hidden] = previous
			compatible = ordinary.filter(func(id): return dealt[id].kind != wound)
	var decoys: Array = []
	if not bool(data.get("weapon_certain", true)):
		for id in data.get("decoy_rooms", []):
			if id in ordinary and str(dealt[id].kind) != wound: decoys.append(id)
		var remaining: Array = ordinary.filter(func(id): return id not in decoys and str(dealt[id].kind) != wound)
		remaining = Case.stream(int(data.seed), "runtime_item_stains").shuffle(remaining)
		while decoys.size() < 2: decoys.append(remaining.pop_front())
	for id in range(room_ids.size()):
		if id in data.get("no_item_rooms", []): continue
		var glass: bool = id == int(data.glass_room)
		var kind := "" if glass else str(dealt[id].kind)
		var name: String = str(catalog.get("magnifier", {}).get("name", "Magnifying glass")) if glass else str(dealt[id].name)
		item_names.append(name)
		var at: Vector2 = preload("res://src/mystery/house_item_placement.gd").choose(case_layout, str(room_ids[id]), int(data.seed))
		if not at.is_finite(): return false
		items[id] = {"id": id, "name": name, "kind": kind, "is_glass": glass,
			"screen": str(room_ids[id]), "position": at,
			"stained": not glass and (id == weapon or id in decoys)}
	return true

func item_name(id: int) -> String:
	return str(items[id].name) if items.has(id) else ""

func held_item() -> Dictionary:
	return items.get(progress.get("carried"), {})

func all_items_in(screen_id: String) -> Array:
	var result: Array = []
	for item in items.values():
		if item.screen == screen_id and progress.carried != item.id:
			result.append(item)
	return result

func observe_item(id: int) -> void:
	if not items.has(id): return
	var item: Dictionary = items[id]
	if item.screen != progress.screen and progress.carried != id: return
	var seen: Dictionary = progress.items_seen.get(str(id), {})
	seen.merge({"name": item.name, "kind": item.kind, "is_glass": item.is_glass,
		"screen": str(progress.screen) if progress.carried == id else item.screen,
		"position": item.position, "held": progress.carried == id}, true)
	progress.items_seen[str(id)] = seen

func sync_carried_state() -> void:
	# The magnifying glass is a permanent tool (progress.glass), not the carried item.
	if runtime != null and runtime.has_method("set_weapon_carried"):
		runtime.set_weapon_carried(progress.carried == data.weapon_room)

func available_item(id: int) -> Dictionary:
	if id < 0:
		id = int(progress.room)
	if not items.has(id): return {}
	var item: Dictionary = items[id]
	if item.screen != progress.screen or progress.carried == id: return {}
	return item

func question(person: int) -> String:
	if not active():
		return message("This investigation has ended. Start a new case to continue.")
	if person < 0 or person >= data.claims.size() or guest_screen(person) != progress.screen:
		return message("That guest is not in this room.")
	if runtime != null:
		var response: String = runtime.question(person, str(progress.screen))
		if response == "ambush":
			return str(ambush().message)
		if response == "refused":
			var refusal: int = int(refusal_counts.get(person, 0))
			refusal_counts[person] = refusal + 1
			return message(dialogue.personality_line(data, person, "refusal", {"speaker": str(data.cast[person])}, "question_refused_%d" % refusal), "personality_lines", "refusal")
	var claim: Dictionary = data.claims[person]
	var repeated: bool = progress.heard.has(str(person))
	progress.heard[str(person)] = claim.duplicate(true)
	return message(dialogue.compose_reply(data, person, repeated, room_names), "personality_lines", "repeat_lead" if repeated else "opening")

func inspect_item(id := -1) -> String:
	if not active(): return system_message("investigation_ended")
	var item := available_item(id)
	if item.is_empty(): return system_message("no_item")
	id = int(item.id)
	observe_item(id)
	if item.is_glass:
		return system_message("inspect_glass", {"item": item.name})
	if not progress.glass:
		return system_message("item_needs_glass", {"item": item.name})
	progress.items_seen[str(id)].stain = "present" if item.stained else "absent"
	if item.stained:
		if bool(data.get("weapon_certain", true)):
			progress.weapon = id
			return system_message("weapon_blood", {"weapon": item.name}, "item_%d" % id)
		return system_message("lens_stain", {"item": item.name}, "item_%d" % id)
	if id not in progress.clear_items: progress.clear_items.append(id)
	return system_message("lens_clean", {"item": item.name}, "item_%d" % id)

func inspect_floor(staring_guest := false) -> String:
	if not active(): return system_message("investigation_ended")
	if progress.room < 0: return system_message("no_floor")
	if not progress.glass: return system_message("floor_needs_glass")
	if runtime != null: staring_guest = runtime.staring_in(str(progress.screen))
	if data.trace_mode == "staring" and not staring_guest:
		return system_message("floor_inconclusive")
	if progress.room == data.murder_room:
		progress.crime_room = progress.room
		var floor_text := system_message("floor_blood", {"room": str(room_names[progress.room])}, "floor_%d" % progress.room)
		if items.has(int(data.weapon_room)):
			progress.wound = str(items[int(data.weapon_room)].kind)
			var wound_text := system_message("wound_" + str(progress.wound), {}, "wound")
			return message(floor_text + "\n\n" + wound_text, "system", "wound_" + str(progress.wound))
		return floor_text
	if progress.room not in progress.clean_floors: progress.clean_floors.append(progress.room)
	var watched: bool = runtime != null and runtime.guests.any(func(g): return g.screen == progress.screen)
	return system_message("floor_nothing" if watched else "floor_nothing_unwatched", {}, "floor_%d" % progress.room)

func take_item(id := -1) -> String:
	if not active(): return system_message("investigation_ended")
	var item := available_item(id)
	if item.is_empty(): return system_message("no_item")
	observe_item(int(item.id))
	if item.is_glass:
		progress.glass = true # a permanent tool: it never occupies the carried-item slot
		item.screen = ""
		observe_item(int(item.id))
		return system_message("take_glass", {"item": item.name})
	if progress.carried != null:
		return system_message("hands_full", {"item": held_item().name})
	progress.carried = int(item.id)
	item.screen = ""
	sync_carried_state()
	observe_item(int(item.id))
	return system_message("take_item", {"item": item.name})

func drop_item(at: Vector2) -> String:
	if not active(): return system_message("investigation_ended")
	if progress.carried == null: return system_message("no_held_item")
	if not drop_allowed(str(progress.screen)) or not at.is_finite() or (runtime != null and not runtime.geometry.is_open(str(progress.screen), at)):
		return system_message("drop_blocked")
	var item := held_item()
	item.screen = str(progress.screen)
	item.position = at
	progress.carried = null
	sync_carried_state()
	observe_item(int(item.id))
	return system_message("drop_item", {"item": item.name})

func assembly_hint() -> String:
	return system_message("assemble_need_item")

func assemble_message() -> String:
	if not progress.assembled:
		return assembly_hint()
	return message(assembly_text, "system", "assemble_ok")

func assemble() -> bool:
	if not active() or progress.carried == null:
		assembly_hint()
		return false
	if progress.assembled:
		return true
	if runtime == null:
		enable_runtime(case_layout)
	var stage: Dictionary = Assembly.prepare(runtime.geometry, data.claims.size(), str(progress.screen))
	if stage.has("error"):
		message(str(stage.error))
		return false
	for person in range(data.claims.size()):
		var slot: Dictionary = stage.slots[person]
		var guest: Dictionary = runtime.guests[person]
		guest.screen = str(stage.room)
		guest.position = World.Layout.point(slot.at)
		guest.interaction_at = World.Layout.point(slot.interaction_at)
		guest.slot_id = str(slot.id)
		guest.posture = "standing"
		guest.activity = "idle"
		guest.activities = ["idle"]
		guest.kind = "stand"
		guest.facing = str(slot.facing)
		guest.staring = false
	progress.assembly_room = str(stage.room)
	progress.assembly_position = stage.player_at.duplicate()
	progress.assembled = true
	enter_screen(str(stage.room))
	runtime.player_screen = str(stage.room)
	runtime.finished = true # Freeze danger and relocation, not the accusation UI.
	assembly_text = system_message("assemble_ok", {"room": str(screen_names[stage.room])}, "assembly")
	return true

func accuse(person: int, room: int) -> Dictionary:
	if not active() or not progress.assembled:
		return {"result": "blocked", "message": system_message("accuse_need_assembly"), "message_key": last_message_key, "message_group": last_message_group}
	if progress.carried == null:
		return {"result": "blocked", "message": assembly_hint(), "message_key": last_message_key, "message_group": last_message_group}
	if person < 0 or person >= data.claims.size() or room < 0 or room >= room_names.size():
		return {"result": "blocked", "message": message("Choose a suspect and a room."), "message_key": last_message_key, "message_group": last_message_group}
	var right_person: bool = person == data.culprit
	var right_room: bool = room == data.murder_room
	var result := ("solved" if progress.carried == data.weapon_room else "wrong_weapon") if right_person and right_room else ("wrong_room" if right_person else ("wrong_person" if right_room else "both_wrong"))
	progress.outcome = result
	if runtime != null:
		runtime.finished = true
	var key: String = {"solved": "confession", "wrong_room": "culprit_corrects_room", "wrong_person": "culprit_corrects_person", "both_wrong": "accuse_wrong_both", "wrong_weapon": "culprit_corrects_weapon"}[result]
	var group := "system" if result == "both_wrong" else "personality_lines"
	var slots := truth_slots(-1, room)
	slots.accused = str(data.cast[person])
	var ending: String
	if group == "system":
		ending = system_message(key, slots, result)
	elif dialogue.data.personalities.get(str(data.personalities[data.culprit]), {}).has(key):
		ending = dialogue.personality_line(data, data.culprit, key, slots, result)
	else:
		ending = "[PENDING_DIALOGUE:%s]" % key
	var closure := system_message("case_closed" if result == "solved" else "case_ended")
	var text := message(ending + "\n\n" + closure + "\n\n" + truth_summary(), group, key)
	return {"result": result, "message": text, "message_key": key, "message_group": group}

func notebook() -> String:
	var lines: Array[String] = ["Victim: " + str(data.cast[-1]), "Carrying: " + str(held_item().get("name", "nothing")), "", "ACCOUNTS HEARD"]
	for person in range(data.claims.size()):
		var key := str(person)
		if not progress.heard.has(key): continue
		var claim: Dictionary = progress.heard[key]
		var company := "alone" if claim.partner == null else "with " + str(data.cast[int(claim.partner)])
		lines.append("%s: %s, %s" % [data.cast[person], room_names[int(claim.room)], company])
	if progress.heard.is_empty(): lines.append("No accounts recorded yet.")
	lines.append("\nPHYSICAL OBSERVATIONS")
	if progress.crime_room != null: lines.append("Crime traces: " + str(room_names[progress.crime_room]))
	if progress.wound != null: lines.append("Wound kind: " + str(progress.wound))
	if progress.weapon != null: lines.append("Identified weapon: " + item_name(progress.weapon))
	for room in progress.clean_floors: lines.append("Floor checked, no crime traces: " + str(room_names[room]))
	lines.append("\nITEMS / LAST KNOWN LOCATIONS")
	for key in progress.items_seen:
		var seen: Dictionary = progress.items_seen[key]
		var location := "carried" if seen.held or (seen.is_glass and progress.glass) else str(screen_names.get(seen.screen, seen.screen))
		var detail := "" if seen.is_glass else "; kind: " + str(seen.kind)
		if seen.has("stain"): detail += "; stain: " + str(seen.stain)
		lines.append("%s — %s%s" % [seen.name, location, detail])
	return "\n".join(lines)
