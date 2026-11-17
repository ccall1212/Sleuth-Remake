extends SceneTree
const Case = preload("res://src/mystery/generated_case.gd")
const Stream = preload("res://src/mystery/seed_stream.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and failures.size() < 20:
		failures.append(message)

func normalize(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Array:
		return value.map(normalize)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = normalize(value[key])
		return result
	return value

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixtures: Dictionary = normalize(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/case_design_v2.json")))
	for row in fixtures.rng:
		var rng = Stream.new(2, row.seed, row.stream)
		for index in range(row.bounds.size()):
			check(rng.below(row.bounds[index]) == row.expected[index], "Unsigned SHA stream mismatch: %s/%s/%d" % [row.seed, row.stream, index])
	for row in fixtures.records:
		var expected: Dictionary = row.case
		var data: Dictionary = Case.generate(expected.seed, expected.claims.size(), expected.difficulty)
		var label := "%s/%s/%s" % [expected.seed, expected.claims.size(), expected.difficulty]
		# The original solver fixtures predate the three additive lens fields.
		var legacy: Dictionary = data.duplicate(true)
		for key in ["item_kinds", "decoy_rooms", "weapon_certain"]:
			if not expected.has(key): legacy.erase(key)
		check(legacy == expected, "Existing generator fields differ from Python: " + label)
		if data.is_empty():
			continue
		var heard := {}
		check(Case.candidates(data.claims.size(), heard).size() == data.claims.size(), "No evidence leaves every suspect possible")
		for speaker in range(data.claims.size()):
			heard[str(speaker)] = data.claims[speaker]
			var possible: Array = Case.candidates(data.claims.size(), heard)
			check(possible == row.partial_candidates[speaker], "Partial solver differs from Python: " + label)
			check(data.culprit in possible, "Honest evidence cannot eliminate the culprit")
		check(Case.candidates(data.claims.size(), heard, data.murder_room) == row.complete_candidates, "Complete solver differs from Python: " + label)
		check(row.complete_candidates == [data.culprit], "Every fixture has one discoverable solution")
		check(data.murder_room != data.rooms.size() - 1, "Secret room never hosts murder")
		check(data.glass_room != data.weapon_room, "Glass and weapon use independent item slots")
	# Cosmetic overrides must not change the crime or alibis.
	var original: Dictionary = Case.generate(42)
	var changed: Dictionary = Case.generate(42, 6, "normal", Case.POOL, ["calm", "calm", "calm", "calm", "calm", "calm"])
	for field in ["culprit", "murder_room", "weapon_room", "glass_room", "claims", "guest_start", "item_kinds", "decoy_rooms", "weapon_certain"]:
		check(original[field] == changed[field], "Personality cannot alter " + field)
	check(Case.generate(1, 3).is_empty() and Case.generate(1, 9).is_empty(), "Reject unsupported suspect counts")
	check(Case.generate(1, 6, "unknown").is_empty(), "Reject unknown difficulty")
	print(JSON.stringify({"checks": checks, "fixture_cases": fixtures.records.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
