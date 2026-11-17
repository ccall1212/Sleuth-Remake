extends RefCounted
## Version-2 reference port. Generated truth and learned evidence stay separate.
const Stream = preload("res://src/mystery/seed_stream.gd")
const VERSION := 2
const PERSONALITIES := ["warm", "nervous", "proud", "guarded", "hot_tempered", "curious", "fragile", "calm"]
const POOL := ["Char", "Justin", "Danny", "Gage", "Robbie", "Chris", "Kwinn", "Chloe", "Matt", "Camille", "Carolyn", "Isabelle", "Sarah Jo", "Jessica", "John"]
const ROOM_POOL := ["Library", "Kitchen", "Study", "Parlor", "Dining room", "Ballroom", "Conservatory", "Sewing room", "Bedroom", "Gallery", "Pantry", "Bathroom"]
const ROOM_COUNT := {4: 7, 5: 8, 6: 10, 7: 11, 8: 12}
const ITEM_KINDS := ["blunt", "sharp", "heavy"]
const SETTINGS := {
	"easy": {"decoy": 0.0, "hidden_ok": false, "trace": "lens", "stained_decoys": 0, "certain": true},
	"normal": {"decoy": 0.5, "hidden_ok": false, "trace": "lens", "stained_decoys": 2, "certain": false},
	"hard": {"decoy": 1.0, "hidden_ok": true, "trace": "staring", "stained_decoys": 2, "certain": false},
}

static func stream(seed_value: int, name: String) -> RefCounted:
	return Stream.new(VERSION, seed_value, name)

static func generate(seed_value: int, suspects := 6, difficulty := "normal", pool: Array = POOL, voice_override: Array = [], no_item_rooms: Array = []) -> Dictionary:
	if not SETTINGS.has(difficulty) or not ROOM_COUNT.has(suspects) or pool.size() < suspects + 1:
		return {}
	if not voice_override.is_empty() and voice_override.size() != suspects:
		return {}
	var cfg: Dictionary = SETTINGS[difficulty]
	var total: int = ROOM_COUNT[suspects]
	var hidden := total - 1
	var ordinary: Array = range(hidden)
	var anywhere: Array = range(total) if cfg.hidden_ok else ordinary.duplicate()
	var cast: Array = stream(seed_value, "cast").shuffle(pool).slice(0, suspects + 1)
	var culprit: int = stream(seed_value, "culprit").below(suspects)
	var murder_room: int = stream(seed_value, "crime_room").choice(ordinary)
	# Rooms that cannot hold an evidence item (the Front Entry). Murder rooms are independent of this.
	var item_rooms: Array = anywhere.filter(func(r): return r not in no_item_rooms)
	var weapon_room: int = stream(seed_value, "weapon").choice(item_rooms)
	var glass_choices: Array = item_rooms.filter(func(r): return r != weapon_room)
	var glass_room: int = stream(seed_value, "glass").choice(glass_choices)
	# Kind draws include the glass and hidden slots. Keep names/art on a
	# different stream so presentation cannot change the lens evidence.
	var items = stream(seed_value, "items")
	var item_kinds: Array = []
	for unused in range(total):
		item_kinds.append(items.choice(ITEM_KINDS))
	var wound: String = item_kinds[weapon_room]
	var stains = stream(seed_value, "stains")
	var decoy_pool: Array = ordinary.filter(func(r): return r != weapon_room and r != glass_room and r not in no_item_rooms)
	# Python shuffles even on Easy, sorts the selected rooms, then repairs
	# matching kinds in that sorted order using the same stains stream.
	var decoy_rooms: Array = stains.shuffle(decoy_pool).slice(0, int(cfg.stained_decoys))
	decoy_rooms.sort()
	for room in decoy_rooms:
		if item_kinds[room] == wound:
			item_kinds[room] = stains.choice(ITEM_KINDS.filter(func(kind): return kind != wound))
	var rng = stream(seed_value, "alibis")
	var innocent_ids: Array = range(suspects).filter(func(s): return s != culprit)
	var innocents: Array = rng.shuffle(innocent_ids)
	var options: Array = [0, 1, 2].filter(func(s): return (innocents.size() - s) % 2 == 0 and (innocents.size() - s) / 2 >= 1)
	var solos: int = options[0] if options.size() == 1 or rng.chance(0.6) else options[1]
	var pairs := int((innocents.size() - solos) / 2)
	var claimable: Array = rng.shuffle(ordinary.filter(func(r): return r != murder_room))
	var claims: Array = []
	claims.resize(suspects)
	var pair_rooms := {}
	var solo_rooms := {}
	var members: Array = []
	var solo_members: Array = []
	var cursor := 0
	for index in range(pairs):
		var a: int = innocents[index * 2]
		var b: int = innocents[index * 2 + 1]
		var room: int = claimable[cursor]
		cursor += 1
		claims[a] = {"room": room, "partner": b}
		claims[b] = {"room": room, "partner": a}
		pair_rooms[a] = room
		pair_rooms[b] = room
		members.append_array([a, b])
	for index in range(solos):
		var person: int = innocents[pairs * 2 + index]
		var room: int = claimable[cursor]
		cursor += 1
		claims[person] = {"room": room, "partner": null}
		solo_rooms[person] = room
		solo_members.append(person)
	var target: int
	var claimed_room: int
	if rng.chance(float(cfg.decoy)):
		target = rng.choice(members)
		claimed_room = rng.choice(ordinary.filter(func(r): return r != murder_room and r != pair_rooms[target]))
	elif not solo_members.is_empty():
		target = rng.choice(solo_members)
		claimed_room = solo_rooms[target]
	else:
		target = rng.choice(members)
		claimed_room = pair_rooms[target]
	claims[culprit] = {"room": claimed_room, "partner": target}
	var staging = stream(seed_value, "staging")
	var rooms: Array = staging.shuffle(ROOM_POOL).slice(0, hidden)
	rooms.append("Secret passage")
	var guest_start: Array = []
	for unused in range(suspects):
		guest_start.append(staging.choice(range(total)))
	var personalities := voice_override.duplicate()
	if personalities.is_empty():
		var voice = stream(seed_value, "voice")
		while personalities.size() < suspects:
			var personality: String = voice.choice(PERSONALITIES)
			if personalities.count(personality) < 2:
				personalities.append(personality)
	var result := {"version": VERSION, "seed": seed_value, "difficulty": difficulty, "cast": cast,
		"personalities": personalities, "rooms": rooms, "claims": claims, "culprit": culprit,
		"murder_room": murder_room, "weapon_room": weapon_room, "glass_room": glass_room,
		"trace_mode": cfg.trace, "guest_start": guest_start,
		"item_kinds": item_kinds, "decoy_rooms": decoy_rooms, "weapon_certain": cfg.certain}
	if not no_item_rooms.is_empty(): result["no_item_rooms"] = no_item_rooms.duplicate()
	return result

static func weapon_candidates(item_kinds: Array, stained_items: Array, wound: String) -> Array:
	# Public observations only: do not accept the generated truth object.
	var ordered := stained_items.duplicate()
	ordered.sort()
	return ordered.filter(func(item): return item is int and item >= 0 and item < item_kinds.size() and item_kinds[item] == wound)

static func candidates(suspects: int, heard: Dictionary, murder_room: Variant = null) -> Array:
	# Deliberately accepts only public facts, not a generated case or truth object.
	var result: Array = []
	for culprit in range(suspects):
		var valid := true
		for key in heard:
			var speaker := int(key)
			var claim: Dictionary = heard[key]
			if speaker == culprit:
				continue
			if murder_room != null and int(claim.room) == int(murder_room):
				valid = false
				break
			if claim.partner == null:
				continue
			var partner := int(claim.partner)
			if partner == culprit:
				valid = false
				break
			var back: Variant = heard.get(str(partner), heard.get(partner))
			if back != null and (back.partner != speaker or back.room != claim.room):
				valid = false
				break
		if valid:
			result.append(culprit)
	return result

static func all_claims(data: Dictionary) -> Dictionary:
	var heard := {}
	for index in range(data.claims.size()):
		heard[str(index)] = data.claims[index].duplicate(true)
	return heard
