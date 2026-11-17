extends SceneTree
const Dialogue = preload("res://src/mystery/case_dialogue.gd")
const Case = preload("res://src/mystery/generated_case.gd")
const Stream = preload("res://src/mystery/seed_stream.gd")
const SNAPSHOT_HASHES := {
	"res://assets/dialogue/personalities.json": "1389e03b2d8d0612495c400b00a9cb92b49c8a18cb525f969c45bdc0be3614fa",
	"res://assets/dialogue/system.json": "6e585247aeb6f8b57e9ab25b9d9ead1b39e9c492392581d6052c0363976c05e6",
	"res://assets/dialogue/styles.json": "f9b8e9ff6c2173d37af55d2003d7c0feaadcb6bb49bda4cc251c040f35eb27a6",
	"res://tests/fixtures/dialogue_v2.json": "7762ba66e3a2348d70184205d5ea2745bfc9cff4fcb6a4c3f2b295c30939222e",
}
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and failures.size() < 30: failures.append(message)

func lf_sha256(path: String) -> String:
	# Line endings differ between Windows checkouts and the repository (eol=lf), so hash the LF form.
	return FileAccess.get_file_as_string(path).replace("
", "
").sha256_text()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var dialogue = Dialogue.new()
	check(dialogue.last_error.is_empty(), "Authored dialogue loads")
	for path in SNAPSHOT_HASHES:
		check(lf_sha256(path) == SNAPSHOT_HASHES[path], "Reviewed authored snapshot " + path)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dialogue_v2.json"))
	var strings := 0
	for row in fixture.cases:
		var current: Dictionary = Case.generate(int(row.seed), int(row.suspects), str(row.difficulty))
		var before := JSON.stringify(current)
		for ask in row.asks:
			var person := int(ask.suspect)
			for repeat in [false, true]:
				var actual: String = dialogue.compose_reply(current, person, repeat)
				check(actual == str(ask.repeat if repeat else ask.first), "Exact Python dialogue seed=%s difficulty=%s speaker=%d repeat=%s" % [row.seed, row.difficulty, person, repeat])
				check(dialogue.last_error.is_empty(), "No template failure for fixture")
				strings += 1
		check(JSON.stringify(current) == before, "Dialogue never changes case facts")
	check(strings == 432, "All216first/repeatpairs compared")
	check(dialogue.render("Hello {speaker}, {speaker}.", {"speaker": "Char", "unused": "ignored"}) == "Hello Char, Char.", "Repeated slots and unused slots")
	check(dialogue.render("{room}", {}) == "" and not dialogue.last_error.is_empty(), "Missing slots fail safely")
	for malformed in ["Hello {speaker", "Hello speaker}", "{{speaker}}", "{not-a-slot}", "{}"]:
		check(dialogue.render(malformed, {"speaker": "Char"}) == "" and not dialogue.last_error.is_empty(), "Stray braces rejected: " + malformed)
	check(dialogue.render("{speaker}", {"speaker": "Name {with braces}"}) == "Name {with braces}", "Inserted slot values are not parsed as templates")
	check(dialogue.after_lead("Alone in Study.", "Alone in {room}.") == "alone in Study.", "Repeat lowercases normal initial")
	check(dialogue.after_lead("I was in Study.", "I was in {room}.") == "I was in Study.", "Repeat preserves I")
	check(dialogue.after_lead("I'll tell you.", "I'll tell you.") == "I'll tell you.", "Repeat preserves I-word boundary")
	check(dialogue.after_lead("Char and I stayed.", "{partner} and I stayed.") == "Char and I stayed.", "Repeat preserves leading slot")
	var case_data: Dictionary = Case.generate(2,6,"normal")
	var first: String = dialogue.compose_reply(case_data,0,false)
	var repeated: String = dialogue.compose_reply(case_data,0,true)
	var runtime_a = Stream.new(2,2,"runtime:refusal")
	var runtime_b = Stream.new(2,2,"runtime:refusal")
	check(runtime_a.below(1000000) == runtime_b.below(1000000), "Runtime stream baseline")
	for key in ["warning_suspicious", "warning_stalking", "floor_blood", "weapon_blood", "item_flavor_generic", "secret_panel"]:
		var slots := {"room": "Study", "weapon": "Heavy book"}
		var line: String = dialogue.system_line(key,slots,case_data,"event")
		check(not line.is_empty() and not line.contains("{"), "System line rendered " + key)
		check(line == dialogue.system_line(key,slots,case_data,"event"), "System replay " + key)
	check(runtime_a.below(1000000) == runtime_b.below(1000000), "Dialogue never consumes runtime RNG")
	check(dialogue.compose_reply(case_data,0,false) == first and dialogue.compose_reply(case_data,0,true) == repeated, "Other text requests never change question variants")
	var mapped_rooms: Array = case_data.rooms.duplicate()
	mapped_rooms[int(case_data.claims[0].room)] = "ACTUAL PAINTED ROOM"
	check(dialogue.compose_reply(case_data,0,false,mapped_rooms).contains("ACTUAL PAINTED ROOM"), "Game supplies real room labels")
	var slots := {"speaker": case_data.cast[0], "victim": case_data.cast[-1], "room": "Study", "weapon": "Heavy book", "alibi": "the Pantry with Justin", "held_item": "Magnifying glass", "chosen_room": "Library", "accused": "Chris"}
	var roles := {"speaker": "Char", "victim": "John", "room": "Master-Bedroom", "weapon": "Bound estate ledger", "chosen_room": "Kitchen", "alibi": "the Pantry on my own"}
	for template in [dialogue.data.personalities.warm.confession[4]]:
		var corrected: String = dialogue.render(template, roles)
		check(corrected.contains("John") and not corrected.contains("John was"), "Confession names speaker and victim")
	for kind in ["refusal", "ambush_locked", "ambush_grab", "confession", "culprit_corrects_room", "culprit_corrects_person"]:
		var line: String = dialogue.personality_line(case_data,0,kind,slots,"event")
		check(not line.is_empty() and not line.contains("{"), "Personality line " + kind)
		check(line == dialogue.personality_line(case_data,0,kind,slots,"event"), "Personality replay " + kind)
	check(dialogue.system_line("unknown",{},case_data).is_empty() and not dialogue.last_error.is_empty(), "Unknown system key safe")
	check(dialogue.personality_line(case_data,0,"unknown",{},"").is_empty() and not dialogue.last_error.is_empty(), "Unknown personality key safe")
	check(dialogue.compose_reply(case_data,-1,false).is_empty() and not dialogue.last_error.is_empty(), "Invalid speaker safe")
	check(dialogue.color("system","warning_suspicious",Color.WHITE) == Color("#FFD84A"), "Yellow suspicious style")
	check(dialogue.color("system","warning_stalking",Color.WHITE) == Color("#FF9F40"), "Orange stalking style")
	check(dialogue.color("system","floor_blood",Color.WHITE) == Color("#FF4D4D"), "Red floor evidence style")
	check(dialogue.color("runtime_text","ambush_result",Color.WHITE) == Color("#FF4D4D"), "Red full ambush style")
	check(dialogue.color("missing","key",Color.WHITE) == Color.WHITE, "Unknown style fallback")
	print(JSON.stringify({"checks":checks,"fixture_strings":strings,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
