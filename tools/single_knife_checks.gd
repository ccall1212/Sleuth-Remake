extends SceneTree
const Session = preload("res://src/mystery/house_case_session.gd")
const Case = preload("res://src/mystery/generated_case.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 20: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mystery/house_item_catalog.json"))
	check(catalog.items.size() == 10, "The catalog contains ten distinct approved types")
	check(catalog.items.filter(func(item): return item.kind == "sharp").size() == 1, "Kitchen knife is the only sharp catalog type")
	var seen_types := {}
	for item in catalog.items: seen_types[item.name] = item.kind
	for difficulty in ["easy", "normal", "hard"]:
		for seed_value in range(90):
			var s = Session.new()
			check(s.begin(seed_value, layout, difficulty), "Catalog deal can host every case")
			var no_item_rooms: Array = []
			for index in range(s.room_ids.size()):
				if not s.has_item_slot(str(s.room_ids[index])): no_item_rooms.append(index)
			check(no_item_rooms == [s.room_ids.find("room_6")], "Only the Front Entry lacks an item slot")
			check(s.data == Case.generate(seed_value, 6, difficulty, Case.POOL, [], no_item_rooms), "Reference generator facts and lens fixture data remain untouched")
			var names := {}
			var sharp := 0
			var stains: Array = []
			for item in s.items.values():
				names[item.name] = true
				if item.is_glass: continue
				check(seen_types.get(item.name) == item.kind, "Runtime kind matches actual named object")
				if item.kind == "sharp":
					sharp += 1
					check(item.name == "Kitchen knife", "No alternate knife names enter a case")
				if item.stained: stains.append(item.id)
			check(names.size() == s.room_ids.size() - 1 and names.size() == s.items.size() and sharp <= 1, "Every case has unique types and at most one knife")
			check(stains.size() == (1 if difficulty == "easy" else 3), "Easy has one stain; Normal and Hard retain two decoys")
			var wound: String = s.items[s.data.weapon_room].kind
			check(stains.filter(func(id): return s.items[id].kind == wound) == [s.data.weapon_room], "Actual wound kind singles out exactly the true weapon")
			for id in stains:
				if id != s.data.weapon_room:
					check(id != s.data.glass_room and id != s.room_ids.size() - 1, "Decoys remain ordinary non-glass items")
			var repeat = Session.new()
			repeat.begin(seed_value, layout, difficulty)
			check(repeat.items == s.items, "Catalog deal and repaired stains replay deterministically")
	print(JSON.stringify({"checks": checks, "cases": 270, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
