extends SceneTree
## Full lens reference parity, not a projection onto the previous schema.
const Case = preload("res://src/mystery/generated_case.gd")
const FIXTURES := "res://tests/fixtures/lens_cases_v2.json"
var checks := 0
var failures: Array[String] = []
var cases := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 25:
		failures.append(label)

func normalize(value: Variant) -> Variant:
	if value is float: return int(value)
	if value is Array: return value.map(normalize)
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = normalize(value[key])
		return result
	return value

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixture: Dictionary = normalize(JSON.parse_string(FileAccess.get_file_as_string(FIXTURES)))
	check(fixture.cases.size() == 900, "All 900 reference cases loaded")
	for expected in fixture.cases:
		var generated: Dictionary = Case.generate(expected.seed, expected.claims.size(), expected.difficulty)
		var label := "%s/%s/%s" % [expected.seed, expected.claims.size(), expected.difficulty]
		cases += 1
		check(generated == expected, "All case fields match reference: " + label)
		check(generated == Case.generate(expected.seed, expected.claims.size(), expected.difficulty), "Exact replay: " + label)
		check(generated.item_kinds.size() == generated.rooms.size(), "One kind per initial room slot: " + label)
		check(generated.item_kinds.all(func(kind): return kind in Case.ITEM_KINDS), "Known item kinds: " + label)
		check(generated.weapon_certain == (generated.difficulty == "easy"), "Only Easy identifies weapon directly: " + label)
		check(generated.decoy_rooms.size() == (0 if generated.weapon_certain else 2), "Correct number of stained decoys: " + label)
		var sorted: Array = generated.decoy_rooms.duplicate()
		sorted.sort()
		check(sorted == generated.decoy_rooms, "Decoys sorted before kind repairs: " + label)
		var wound: String = generated.item_kinds[generated.weapon_room]
		for room in generated.decoy_rooms:
			check(room != generated.weapon_room and room != generated.glass_room and room < generated.rooms.size() - 1, "Decoy excludes weapon/glass/hidden: " + label)
			check(generated.item_kinds[room] != wound, "Decoy kind differs from wound: " + label)
		var observed_stains: Array = generated.decoy_rooms.duplicate()
		observed_stains.append(generated.weapon_room)
		check(Case.weapon_candidates(generated.item_kinds, observed_stains, wound) == [generated.weapon_room], "Observed stain/kind/wound evidence singles out weapon: " + label)
		check(Case.candidates(generated.claims.size(), Case.all_claims(generated), generated.murder_room) == [generated.culprit], "Lens additions preserve unique culprit: " + label)
	# Helper deliberately receives public evidence only; unknown or invalid items
	# cannot leak a hidden weapon identity through an indexing exception.
	check(Case.weapon_candidates(["sharp", "blunt", "sharp"], [2, 0], "sharp") == [0, 2], "Public weapon candidates are sorted")
	check(Case.weapon_candidates(["sharp"], [-1, 3], "sharp").is_empty(), "Out-of-range observation is safely ignored")
	print(JSON.stringify({"checks": checks, "fixture_cases": cases, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
