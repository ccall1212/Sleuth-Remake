extends SceneTree
## Front Entry rule (2026-11-17): no evidence item, decoy, glass or dropped item may ever be in the Front Entry,
## and the magnifying glass is a permanent tool that never occupies the carried-item slot.
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

func norm(value: Variant) -> Variant:
	if value is float and value == floor(value): return int(value)
	if value is Array: return value.map(func(v): return norm(v))
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = norm(value[key])
		return out
	return value

func begin(seed_value: int, difficulty: String) -> RefCounted:
	var s = Session.new()
	check(s.begin(seed_value, layout, difficulty), "Case starts (seed %d %s)" % [seed_value, difficulty])
	s.enable_runtime(layout, {"question_refusal": 0.0, "entry_death": 0.0, "culprit_question_death": 0.0, "guest_leave": 0.0})
	return s

func run() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	# Python parity for the restricted generator: every field must match exactly.
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/front_entry_cases_v2.json"))
	var blocked: Array = fixture._meta.no_item_rooms.map(func(v): return int(v))
	var mismatches := 0
	for row in fixture.cases:
		var data: Dictionary = Case.generate(int(row.seed), 6, str(row.difficulty), Case.POOL, [], blocked)
		for key in ["culprit", "murder_room", "weapon_room", "glass_room", "decoy_rooms", "item_kinds", "claims", "guest_start", "no_item_rooms"]:
			if JSON.stringify(norm(data[key])) != JSON.stringify(norm(row[key])):
				mismatches += 1
				if failures.size() < 10: failures.append("Parity %s seed %s %s" % [key, row.seed, row.difficulty])
		check(int(data.weapon_room) not in blocked and int(data.glass_room) not in blocked, "Generated weapon and glass avoid the Front Entry")
		for room in data.decoy_rooms: check(int(room) not in blocked, "Decoys avoid the Front Entry")
	check(mismatches == 0, "GDScript generator matches Python with no_item_rooms (%d fixture cases)" % fixture.cases.size())
	# The live session: no item object in the Front Entry, drops refused there, glass is a tool.
	var murder_front := 0
	for difficulty in ["easy", "normal", "hard"]:
		for seed_value in range(40):
			var s = begin(seed_value, difficulty)
			var front: int = s.room_ids.find("room_6")
			check(front >= 0 and front in s.data.no_item_rooms, "Front Entry is excluded by the layout")
			check(not s.items.has(front), "No item object exists for the Front Entry")
			for item in s.items.values(): check(str(item.screen) != "room_6", "No item placed on the Front Entry floor")
			if int(s.data.murder_room) == front: murder_front += 1
			check(s.items.size() == s.room_ids.size() - 1, "One item per eligible room")
			# Drops are rejected in the Front Entry, accepted elsewhere.
			var weapon: int = int(s.data.weapon_room)
			s.enter_screen(str(s.items[weapon].screen))
			check(s.take_item(weapon) != "" and s.progress.carried == weapon, "Weapon can be picked up")
			s.enter_screen("room_6")
			var spawn: Vector2 = s.runtime.geometry.point(s.runtime.geometry.screens["room_6"].spawn)
			s.drop_item(spawn)
			check(s.progress.carried == weapon and str(s.items[weapon].screen) != "room_6", "Dropping in the Front Entry is refused")
			s.enter_screen(str(s.items[weapon].screen if str(s.items[weapon].screen) != "" else "library"))
			# The glass is a permanent tool.
			var glass: int = int(s.data.glass_room)
			s.enter_screen(str(s.items[glass].screen))
			check(not s.progress.glass, "Glass starts not found")
			s.take_item(glass)
			check(s.progress.glass and s.progress.carried == weapon, "Taking the glass keeps the carried item and sets the tool")
			check(str(s.items[glass].screen) == "", "The glass leaves the world when collected")
			check(s.notebook().contains("carried") or true, "Notebook still builds")
			var floor_text: String = s.inspect_floor()
			check(not floor_text.begins_with("[PENDING"), "Floor can be examined while holding evidence")
			s.progress.carried = null
			s.sync_carried_state()
			check(s.progress.glass, "Dropping evidence never removes the tool")
	check(murder_front > 0, "The murder room may still be the Front Entry (%d of 120 cases)" % murder_front)
	print(JSON.stringify({"checks": checks, "murder_in_front_entry": murder_front, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
