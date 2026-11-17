extends RefCounted
## Original authored dialogue, with independent replayable text-only RNG streams.
## This module never reads or advances guest, refusal, danger or generator RNGs.
const Pronouns = preload("res://src/mystery/character_pronouns.gd")
const Stream = preload("res://src/mystery/seed_stream.gd")
const BASE := "res://assets/dialogue/"
var data: Dictionary = {}
var refusal_variants: Dictionary = {}
var last_error := ""
var slot_pattern := RegEx.new()
var first_person := RegEx.new()

func _init() -> void:
	slot_pattern.compile("\\{(\\w+)\\}")
	first_person.compile("^I\\b")
	for key in ["personalities", "system", "styles"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASE + key + ".json"))
		if not parsed is Dictionary:
			last_error = "Could not read dialogue " + key
			data[key] = {}
		else:
			data[key] = parsed
	# The latest authored six-line banks supersede the temporary refusal override.
	for voice in data.personalities:
		refusal_variants[voice] = data.personalities[voice].get("refusal", []).duplicate()

func fail(message: String) -> String:
	last_error = message
	return ""

func render(template: String, slots: Dictionary) -> String:
	slots = Pronouns.slots(slots)
	last_error = ""
	var unmatched := slot_pattern.sub(template, "", true)
	if unmatched.contains("{") or unmatched.contains("}"):
		return fail("Stray brace in dialogue template")
	var result := ""
	var cursor := 0
	for matched in slot_pattern.search_all(template):
		var name: String = matched.get_string(1)
		if not slots.has(name):
			return fail("Missing dialogue slot: " + name)
		result += template.substr(cursor, matched.get_start() - cursor) + str(slots[name])
		cursor = matched.get_end()
	return result + template.substr(cursor)

func choose(lines: Dictionary, kind: String, rng: RefCounted) -> String:
	var options: Variant = lines.get(kind)
	if not options is Array or options.is_empty():
		return fail("Missing dialogue variants: " + kind)
	var selected: Variant = options[rng.below(options.size())]
	if not selected is String:
		return fail("Dialogue variant is not text: " + kind)
	return selected

func rendered_choice(lines: Dictionary, kind: String, slots: Dictionary, rng: RefCounted) -> String:
	var template := choose(lines, kind, rng)
	if not last_error.is_empty():
		return ""
	return render(template, slots)

func valid_person(case_data: Dictionary, person: int) -> bool:
	for key in ["cast", "personalities", "claims"]:
		if not case_data.get(key) is Array or person < 0 or person >= case_data[key].size():
			fail("Invalid dialogue speaker")
			return false
	return true

func stream(case_data: Dictionary, name: String) -> RefCounted:
	return Stream.new(int(case_data.get("version", 2)), int(case_data.get("seed", 0)), name)

func after_lead(core: String, template: String) -> String:
	if core.is_empty() or template.begins_with("{") or first_person.search(template) != null:
		return core
	return core.substr(0, 1).to_lower() + core.substr(1)

func compose_reply(case_data: Dictionary, person: int, repeat: bool, rooms: Array = []) -> String:
	last_error = ""
	if not valid_person(case_data, person):
		return ""
	var names: Array = rooms if not rooms.is_empty() else case_data.get("rooms", [])
	var claim: Dictionary = case_data.claims[person]
	var room_index := int(claim.get("room", -1))
	if room_index < 0 or room_index >= names.size():
		return fail("Invalid dialogue claim room")
	var cast: Array = case_data.cast
	var slots := {"speaker": cast[person], "room": names[room_index], "victim": cast[-1],
		"other": cast[(person + 1) % case_data.claims.size()]}
	var kind := "solo"
	if claim.get("partner") != null:
		var partner := int(claim.partner)
		if partner < 0 or partner >= case_data.claims.size():
			return fail("Invalid dialogue partner")
		slots.partner = cast[partner]
		kind = "pair"
	var voice := str(case_data.personalities[person])
	var lines: Dictionary = data.personalities.get(voice, {})
	var rng := stream(case_data, "dialogue/%d/%d" % [person, 1 if repeat else 0])
	var claim_template := choose(lines, "claim_" + kind, rng)
	if not last_error.is_empty(): return ""
	var core := render(claim_template, slots)
	if not last_error.is_empty(): return ""
	if repeat:
		var lead := rendered_choice(lines, "repeat_lead", slots, rng)
		if not last_error.is_empty(): return ""
		var close := rendered_choice(lines, "repeat_close", slots, rng)
		if not last_error.is_empty(): return ""
		return '"%s %s %s"' % [lead, after_lead(core, claim_template), close]
	var opening := rendered_choice(lines, "opening", slots, rng)
	if not last_error.is_empty(): return ""
	var kinds: Array = []
	if slots.has("victim"): kinds.append("commentary_victim")
	if slots.has("other") and slots.has("victim"): kinds.append("commentary_suspect")
	kinds.append("commentary_self")
	var commentary := rendered_choice(lines, str(kinds[rng.below(kinds.size())]), slots, rng)
	if not last_error.is_empty(): return ""
	return '%s "%s %s"' % [opening, core, commentary]

func system_line(key: String, slots: Dictionary, case_data: Dictionary, event := "") -> String:
	last_error = ""
	var value: Variant = data.system.get(key)
	if value is String:
		return render(value, slots)
	if not value is Array:
		return fail("Missing system dialogue key: " + key)
	return rendered_choice(data.system, key, slots, stream(case_data, "dialogue/system/" + key + "/" + event))

func personality_line(case_data: Dictionary, person: int, kind: String, slots: Dictionary, event := "") -> String:
	last_error = ""
	if not valid_person(case_data, person): return ""
	var voice := str(case_data.personalities[person])
	if kind == "refusal" and refusal_variants.has(voice):
		var variants: Array = refusal_variants[voice]
		var sequence := 0
		if event.begins_with("question_refused_"):
			var suffix: String = event.trim_prefix("question_refused_")
			if suffix.is_valid_int(): sequence = int(suffix)
		# Refusal mechanics decide whether this line is shown. This independent
		# text-only stream picks an offset; successive refusals rotate variants.
		var offset: int = stream(case_data, "dialogue/%d/refusal/silent" % person).below(variants.size())
		return render(str(variants[posmod(offset + sequence, variants.size())]), slots)
	var lines: Dictionary = data.personalities.get(voice, {})
	return rendered_choice(lines, kind, slots,
		stream(case_data, "dialogue/%d/%s/%s" % [person, kind, event]))

func color(group: String, key: String, fallback: Color) -> Color:
	var styles: Dictionary = data.get("styles", {})
	var mapped: Dictionary = styles.get(group, {})
	var values: Dictionary = styles.get("colors", {})
	return Color.from_string(str(values.get(mapped.get(key, ""), "")), fallback)
