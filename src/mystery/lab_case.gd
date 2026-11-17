extends RefCounted
## Bounded case families. Validator consumes learned propositions, never truth.
const VERSION := 2
const ROOMS := ["Foyer", "Library", "Kitchen", "Study"]
const NAMES := ["Arden", "Bea", "Cora", "Dev"]
const ITEMS := ["Letter opener", "Brass weight", "Glass decanter"]
const VOICES := ["calm", "guarded", "brisk", "expressive"]
const LINKS := [[1,2], [0,3], [0,3], [1,2]]
var data: Dictionary
var progress: Dictionary
var difficulty := "introductory"
var assistance := "standard"

func _init(seed_value := 1, difficulty_value := "introductory", assistance_value := "standard") -> void:
	difficulty = difficulty_value
	assistance = assistance_value
	data = generate(seed_value, difficulty)
	progress = {"family":data.family,"attack_slot":-1,"keyholders":[],"room":0,"glass":false,"claims":{},"asked":{},"clean_rooms":[],
		"clear_items":[],"crime_room":-1,"weapon":-1,"carried":-1,
		"moves":0,"outcome":"investigating","attempts":[],"notes":[]}

static func mix(values: Array, rng: RandomNumberGenerator) -> Array:
	var result := values.duplicate()
	for i in range(result.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var temp: Variant = result[i]
		result[i] = result[j]
		result[j] = temp
	return result

static func generate(seed_value: int, difficulty_value := "introductory") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var staging_rng := RandomNumberGenerator.new()
	staging_rng.seed = seed_value ^ 0x13572468
	var voice_rng := RandomNumberGenerator.new()
	voice_rng.seed = seed_value ^ 0x24681357
	var roles := mix([0,1,2,3],rng)
	var rooms := mix([0,1,2,3],rng)
	var culprit: int = roles[0]
	var crime: int = rooms[0]
	var pair_room: int = rooms[1]
	var solo_room: int = rooms[2]
	var claims: Array = [{},{},{},{}]
	claims[roles[1]] = {"room":pair_room,"partner":roles[2]}
	claims[roles[2]] = {"room":pair_room,"partner":roles[1]}
	claims[roles[3]] = {"room":solo_room,"partner":-1}
	var variant := rng.randi_range(0,1)
	claims[culprit] = {"room":pair_room if variant == 0 else solo_room,
		"partner":roles[3] if variant == 0 else roles[1]}
	var locations := [0,0,0,0]
	for who in range(4):
		locations[who] = crime if who == culprit else claims[who].room
	var weapon := rng.randi_range(0,2)
	if difficulty_value == "standard":
		# Two guests occupy the attack room in each interval. The weapon's two
		# keyholders cross those groups, so neither time nor access alone solves it.
		var slot := rng.randi_range(0,1)
		var other_room: int = rooms[1]
		var first_group := [roles[0],roles[1]]
		var second_group := [roles[2],roles[3]]
		for who in range(4):
			claims[who] = {"room":crime if who in first_group else other_room,
				"later_room":crime if who in second_group else other_room,"partner":-1}
		var group: Array = first_group if slot == 0 else second_group
		var other_group: Array = second_group if slot == 0 else first_group
		culprit = group[rng.randi_range(0,1)]
		var holders := [culprit,other_group[rng.randi_range(0,1)]]
		holders.sort()
		for who in range(4): locations[who] = claims[who].room if slot == 0 else claims[who].later_room
		return {"version":VERSION,"seed":seed_value,"family":"timed_access","variant":slot,
			"claims":claims,"present":mix([0,1,2,3],staging_rng),"item_rooms":mix([1,2,3],staging_rng),
			"voices":mix(VOICES,voice_rng),"trace_room":crime,"marked_item":weapon,
			"attack_slot":slot,"keyholders":holders,
			"truth":{"culprit":culprit,"crime_room":crime,"locations":locations}}
	return {"version":VERSION,"seed":seed_value,"family":"conflicting_witness",
		"variant":variant,"claims":claims,"present":mix([0,1,2,3],staging_rng),
		"item_rooms":mix([1,2,3],staging_rng),"voices":mix(VOICES,voice_rng),
		"trace_room":crime,"marked_item":weapon,
		"truth":{"culprit":culprit,"crime_room":crime,"locations":locations}}

static func candidates(known: Dictionary) -> Array:
	# Public contract: one culprit may lie; all other accounts describe the whole
	# 10:00–10:10 interval accurately. The attack happened during that interval.
	var result: Array = []
	for room in range(4):
		if int(known.get("crime_room",-1)) >= 0 and room != int(known.crime_room): continue
		if room in known.get("clean_rooms",[]): continue
		for weapon in range(3):
			if int(known.get("weapon",-1)) >= 0 and weapon != int(known.weapon): continue
			if weapon in known.get("clear_items",[]): continue
			for culprit in range(4):
				if known.get("family","") == "timed_access":
					if not known.get("keyholders",[]).is_empty() and culprit not in known.keyholders: continue
					var fits := false
					for slot in range(2):
						if int(known.get("attack_slot",-1)) >= 0 and slot != int(known.attack_slot): continue
						var claim: Dictionary = known.get("claims",{}).get(str(culprit),{})
						if claim.is_empty() or int(claim.room if slot == 0 else claim.later_room) == room: fits = true
					if fits: result.append({"suspect":culprit,"room":room,"weapon":weapon})
					continue
				var placed := {}
				var alone: Array = []
				var pairs: Array = []
				var consistent := true
				for key in known.get("claims",{}):
					var who := int(key)
					if who == culprit: continue
					var claim: Dictionary = known.claims[key]
					var members := [who]
					if int(claim.partner) >= 0:
						members.append(int(claim.partner))
						pairs.append(members)
					else: alone.append(who)
					for person in members:
						if placed.has(person) and placed[person] != int(claim.room): consistent = false
						placed[person] = int(claim.room)
				for pair in pairs:
					for person in pair:
						if person in alone: consistent = false
				if placed.has(culprit) and placed[culprit] != room: consistent = false
				if consistent: result.append({"suspect":culprit,"room":room,"weapon":weapon})
	return result

static func all_clues(case_data: Dictionary) -> Dictionary:
	var claims := {}
	for who in range(4): claims[str(who)] = case_data.claims[who].duplicate(true)
	var known := {"family":case_data.family,"claims":claims,"crime_room":case_data.trace_room,"weapon":case_data.marked_item}
	if case_data.family == "timed_access":
		known.attack_slot = case_data.attack_slot
		known.keyholders = case_data.keyholders.duplicate()
	return known

static func validate(case_data: Dictionary) -> bool:
	var possible := candidates(all_clues(case_data))
	if possible.size() != 1: return false
	var answer: Dictionary = possible[0]
	if answer.suspect != case_data.truth.culprit or answer.room != case_data.truth.crime_room or answer.weapon != case_data.marked_item: return false
	if case_data.truth.locations[answer.suspect] != answer.room: return false
	if case_data.family == "timed_access":
		for who in range(4):
			var claim: Dictionary = case_data.claims[who]
			if case_data.truth.locations[who] != (claim.room if case_data.attack_slot == 0 else claim.later_room): return false
		return true
	for who in range(4):
		if who == answer.suspect: continue
		var claim: Dictionary = case_data.claims[who]
		if case_data.truth.locations[who] != claim.room: return false
		if claim.partner >= 0 and case_data.truth.locations[claim.partner] != claim.room: return false
	return true

func note(text: String) -> String:
	if assistance != "classic" and not text in progress.notes: progress.notes.append(text)
	return text

func travel(room: int) -> String:
	if progress.outcome != "investigating": return "This case is closed. Start another seed to investigate again."
	if room not in LINKS[progress.room]: return "Use a connecting doorway."
	progress.room = room
	progress.moves += 1
	return "You enter the %s. Current whereabouts are not an alibi for the earlier attack." % ROOMS[room]

func collect_glass() -> String:
	if progress.room != 0: return "The magnifying glass is on the foyer stand."
	progress.glass = true
	return note("Collected the magnifying glass from the foyer.")

func question(who: int) -> String:
	if who < 0 or who >= 4 or int(data.present[who]) != int(progress.room): return "That guest is in another room."
	if not progress.glass: return "Collect the magnifying glass in the foyer before starting the investigation."
	var key := str(who)
	var repeats := int(progress.asked.get(key,0))
	progress.asked[key] = repeats+1
	var claim: Dictionary = data.claims[who]
	progress.claims[key] = claim.duplicate(true)
	var core := "From 10:00 to 10:10, I stayed in the %s " % ROOMS[claim.room]
	core += "alone." if claim.partner < 0 else "with %s throughout." % NAMES[claim.partner]
	if data.family == "timed_access":
		core = "From 10:00 to 10:05 I was in the %s; from 10:05 to 10:10 I was in the %s." % [ROOMS[claim.room],ROOMS[claim.later_room]]
	var opening: String = {"calm":"Let me be precise. ","guarded":"Here is my account. ","brisk":"I'll keep this short. ","expressive":"I remember that interval clearly. "}[data.voices[who]]
	if repeats > 0: opening = "My account is unchanged. "
	note("%s claims: %s" % [NAMES[who],core])
	return "%s: %s%s" % [NAMES[who],opening,core]

func inspect_item(item: int) -> String:
	if item < 0 or item >= 3 or int(data.item_rooms[item]) != int(progress.room): return "That object is elsewhere."
	if not progress.glass: return "You can see the %s, but need the magnifying glass to establish a link." % ITEMS[item]
	if item == int(data.marked_item):
		progress.weapon = item
		var finding := "%s: the victim's blood is trapped in a fresh impact mark. This is the weapon." % ITEMS[item]
		if data.family == "timed_access":
			progress.keyholders = data.keyholders.duplicate()
			finding += " It came from a locked case. The intact lock and signed key register establish that only %s and %s could access it during either interval. No key was shared and it was returned after use." % [NAMES[data.keyholders[0]],NAMES[data.keyholders[1]]]
		return note(finding)
	if not item in progress.clear_items: progress.clear_items.append(item)
	return note("%s: inspection rules it out as the weapon in this case." % ITEMS[item])

func inspect_floor() -> String:
	if not progress.glass: return "Use the magnifying glass to check the room's traces."
	var room: int = progress.room
	if room == int(data.trace_room):
		progress.crime_room = room
		if data.family == "timed_access":
			progress.attack_slot = data.attack_slot
			return note("%s: blood beneath a wiped surface establishes the attack site. A recording captured the victim speaking here at %s and the fatal impact immediately afterwards. The recording was authenticated; the victim did not leave this room between those sounds." % [ROOMS[room],"10:02" if data.attack_slot == 0 else "10:07"])
		return note("%s: blood beneath a wiped surface establishes the attack site. The attack occurred between 10:00 and 10:10." % ROOMS[room])
	if not room in progress.clean_rooms: progress.clean_rooms.append(room)
	return note("%s: the trace survey rules out this room as the attack site." % ROOMS[room])

func collect_weapon() -> String:
	if progress.weapon < 0 or int(data.item_rooms[progress.weapon]) != int(progress.room): return "Inspect and identify a weapon in this room first."
	if progress.crime_room < 0 or progress.claims.size() < 4: return "Leave the weapon in place while you establish the crime room and hear all four accounts."
	progress.carried = progress.weapon
	return note("Collected the identified %s after recording the crime room and all four accounts." % ITEMS[progress.weapon])

func accuse(suspect: int, weapon: int, room: int) -> Dictionary:
	if suspect < 0 or suspect >= 4 or weapon < 0 or weapon >= 3 or room < 0 or room >= 4:
		return {"result":"blocked","text":"Choose a suspect, weapon and room."}
	if progress.outcome == "solved": return {"result":"solved","text":reconstruction()}
	if not progress.glass or progress.claims.size() < 4 or progress.crime_room < 0 or progress.carried < 0:
		return {"result":"blocked","text":"Before presenting: hear all four accounts, identify the room, inspect and collect the weapon. Your notes remain available."}
	var solved: bool = suspect == data.truth.culprit and weapon == data.marked_item and room == data.trace_room
	progress.attempts.append({"suspect":suspect,"weapon":weapon,"room":room,"correct":solved})
	if solved:
		progress.outcome = "solved"
		return {"result":"solved","text":reconstruction()}
	return {"result":"wrong","text":"That reconstruction does not fit the testimony and physical evidence. Review the accounts alongside your observations. This lab permits another attempt."}

func reconstruction() -> String:
	var culprit: int = data.truth.culprit
	if data.family == "timed_access":
		var slot: int = data.attack_slot
		var field := "room" if slot == 0 else "later_room"
		var possible_names: Array[String] = []
		for who in range(4):
			if data.claims[who][field] == data.trace_room: possible_names.append(NAMES[who])
		return "CASE CLOSED\n%s attacked the victim in the %s with the %s.\n\nThe recording places the attack in %s. The accounts place %s in that room then. Only %s and %s had access to the weapon; %s is the only guest who fits both opportunity and access. All four accounts were accurate in this case.\n\nSeed %d." % [NAMES[culprit],ROOMS[data.trace_room],ITEMS[data.marked_item],"10:00–10:05" if slot == 0 else "10:05–10:10"," and ".join(possible_names),NAMES[data.keyholders[0]],NAMES[data.keyholders[1]],NAMES[culprit],data.seed]
	var false_claim: Dictionary = data.claims[culprit]
	var partner: int = false_claim.partner
	var witness: Dictionary = data.claims[partner]
	var account := "alone" if witness.partner < 0 else "with %s" % NAMES[witness.partner]
	return "CASE CLOSED\n%s attacked the victim in the %s with the %s.\n\n%s claimed to be with %s in the %s. But %s's account puts them in the %s, %s. The truthful accounts rule the other guests out; the room trace and marked object complete the reconstruction.\n\nSeed %d. This is one case family; different names alone do not prove replayability." % [NAMES[culprit],ROOMS[data.trace_room],ITEMS[data.marked_item],NAMES[culprit],NAMES[partner],ROOMS[false_claim.room],NAMES[partner],ROOMS[witness.room],account,data.seed]

func snapshot() -> Dictionary:
	return {"version":VERSION,"difficulty":difficulty,"assistance":assistance,"case":data.duplicate(true),"progress":progress.duplicate(true)}

func restore(saved: Variant) -> bool:
	if not saved is Dictionary or saved.get("version") != VERSION or not saved.get("case") is Dictionary or not saved.get("progress") is Dictionary: return false
	var c: Dictionary = saved.case
	if not c.get("seed") is float and not c.get("seed") is int: return false
	if c.seed < 0 or c.seed > 2147483647 or float(c.seed) != float(int(c.seed)): return false
	if saved.get("difficulty") not in ["introductory","standard"] or saved.get("assistance") not in ["assisted","standard","classic"]: return false
	var canonical := generate(int(c.seed),saved.difficulty)
	# JSON numbers return as floats; compare like representations, then restore
	# the generated integer types used by array indices and stable case bindings.
	if c != JSON.parse_string(JSON.stringify(canonical)): return false
	var p: Dictionary = saved.progress
	if p.get("family") != canonical.family: return false
	if p.get("attack_slot") != -1 and p.get("attack_slot") != canonical.get("attack_slot",-1): return false
	if not p.get("keyholders") is Array: return false
	if not p.keyholders.is_empty() and p.keyholders != JSON.parse_string(JSON.stringify(canonical.get("keyholders",[]))): return false
	for key in ["room","crime_room","weapon","carried","moves"]:
		if not p.get(key) is float and not p.get(key) is int: return false
		if float(p[key]) != float(int(p[key])): return false
	if p.room < 0 or p.room > 3 or p.crime_room < -1 or p.crime_room > 3 or p.weapon < -1 or p.weapon > 2 or p.carried < -1 or p.carried > 2 or p.moves < 0: return false
	if not p.get("glass") is bool or p.get("outcome") not in ["investigating","solved"]: return false
	for key in ["claims","asked"]:
		if not p.get(key) is Dictionary: return false
	for key in ["clean_rooms","clear_items","attempts","notes"]:
		if not p.get(key) is Array: return false
	for key in p.claims:
		if key not in ["0","1","2","3"] or p.claims[key] != c.claims[int(key)]: return false
	for key in p.asked:
		if key not in ["0","1","2","3"] or not (p.asked[key] is float or p.asked[key] is int) or p.asked[key] < 1: return false
	for room in p.clean_rooms:
		if not (room is float or room is int) or float(room) != float(int(room)) or int(room) not in [0,1,2,3] or room == c.trace_room: return false
	for item in p.clear_items:
		if not (item is float or item is int) or float(item) != float(int(item)) or int(item) not in [0,1,2] or item == c.marked_item: return false
	if p.crime_room >= 0 and p.crime_room != c.trace_room: return false
	if p.weapon >= 0 and p.weapon != c.marked_item: return false
	if p.carried >= 0 and (p.carried != c.marked_item or p.weapon < 0 or p.crime_room < 0 or p.claims.size() != 4): return false
	if p.outcome == "solved" and (p.carried < 0 or p.claims.size() != 4): return false
	for line in p.notes:
		if not line is String: return false
	data = canonical
	difficulty = saved.difficulty
	assistance = saved.assistance
	progress = p.duplicate(true)
	for key in ["room","crime_room","weapon","carried","moves"]: progress[key] = int(progress[key])
	for key in progress.claims:
		progress.claims[key] = canonical.claims[int(key)].duplicate(true)
	progress.attack_slot = int(progress.attack_slot)
	for i in range(progress.keyholders.size()): progress.keyholders[i] = int(progress.keyholders[i])
	for key in progress.asked: progress.asked[key] = int(progress.asked[key])
	for key in ["clean_rooms","clear_items"]:
		for i in range(progress[key].size()): progress[key][i] = int(progress[key][i])
	return true
