extends SceneTree
const Presentation = preload("res://src/mystery/guest_presentation.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var directions := {"north": Vector2.UP, "east": Vector2.RIGHT, "south": Vector2.DOWN, "west": Vector2.LEFT}
	var catalogs := []
	for actor in ["char", "chris"]:
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/poses/%s/directional-index.json" % actor))
		catalogs.append(index.assets.map(func(a): return a.pose_id))
	for facing in directions:
		for direction in directions:
			for activity in ["idle", "read", "sleep"]:
				var guest := {"position": Vector2(100, 100), "posture": "seated", "facing": facing, "activity": activity, "staring": false}
				var before := guest.duplicate(true)
				var p := Presentation.presentation(guest, "warm", guest.position + directions[direction] * 30, true)
				check(p.posture == "seated" and p.facing == facing and p.pose_id.begins_with("seated_"), "Seated conversation retains chair orientation in every quadrant")
				check(p.activity != "sleep", "Talking seated guest is awake")
				check(not p.narration.contains("turn"), "Seated narration does not invent a head turn")
				check(guest == before, "Seated conversation does not mutate stored staging")
				for catalog in catalogs:
					check(p.pose_id in catalog, "Seated conversation uses existing Char/Chris art")
		var ground := {"position": Vector2(100, 100), "posture": "standing", "facing": facing, "activity": "look_down", "staring": false}
		for personality in ["curious", "fragile", "nervous"]:
			var before := ground.duplicate(true)
			var p := Presentation.presentation(ground, personality, Vector2(150, 150), true)
			check(p.facing == facing, "Floor-focused conversation keeps original facing")
			check(p.activity == ("idle" if facing == "north" else "look_down"), "Downward presentation uses safe north fallback")
			check(ground == before, "Floor-focused conversation preserves persistent guest")
			check(p.narration.contains("inspection") if facing == "north" else p.narration.contains("eyes"), "Floor-focused narration matches available artwork")
			for catalog in catalogs:
				check(p.pose_id in catalog, "Floor-focused pose exists for both actors")
		ground.staring = true
		var staring_before := ground.duplicate(true)
		var focused := Presentation.presentation(ground, "warm", Vector2(150, 150), true)
		check(focused.facing == facing and ground == staring_before, "Real staring remains grounded without changing clue state")
	for direction in directions:
		var guest := {"position": Vector2(100, 100), "posture": "standing", "facing": "south", "activity": "idle"}
		var before := guest.duplicate(true)
		var p := Presentation.presentation(guest, "calm", guest.position + directions[direction] * 40, true)
		check(p.facing == direction and p.pose_id == "standing_talk_" + direction, "Standing conversation addresses actual player quadrant")
		check(guest == before, "Standing conversation does not overwrite saved facing")
		for catalog in catalogs:
			check(p.pose_id in catalog, "Standing talk pose exists for both actors")
	var warm_ground := {"position": Vector2.ZERO, "posture": "standing", "facing": "east", "activity": "look_down", "staring": false}
	check(Presentation.presentation(warm_ground, "warm", Vector2.LEFT * 20, true).pose_id == "standing_talk_west", "Ordinary inspection can pause to address player")
	var reading := {"position": Vector2.ZERO, "posture": "standing", "facing": "west", "activity": "read"}
	var resting := Presentation.presentation(reading, "warm", Vector2.DOWN, false)
	check(resting.pose_id == "standing_read_west" and resting.narration.is_empty(), "Non-conversation preserves saved reading")
	# North-facing room poses may stay fixed only when the conversation portrait
	# offers a readable face; it must never swivel a calibrated chair or guest.
	var north_talk := Presentation.presentation({"position": Vector2.ZERO, "posture": "standing", "facing": "south", "activity": "idle"}, "calm", Vector2.UP * 40, true)
	var north_before: Dictionary = north_talk.duplicate(true)
	var talk_portrait := Presentation.portrait_presentation(north_talk)
	check(talk_portrait.pose_id == "standing_talk_south" and talk_portrait.facing == "south", "Northward conversation uses a face-visible talking portrait")
	check(north_talk == north_before, "Portrait direction never mutates world conversation presentation")
	for activity in ["idle", "read", "sleep"]:
		var guest := {"position": Vector2.ZERO, "posture": "seated", "facing": "north", "activity": activity}
		var before := guest.duplicate(true)
		var world := Presentation.presentation(guest, "warm", Vector2.DOWN * 40, true)
		var world_before: Dictionary = world.duplicate(true)
		var portrait := Presentation.portrait_presentation(world)
		check(world.facing == "north" and world.posture == "seated" and guest == before, "North-facing chair stays fixed during conversation")
		check(portrait.pose_id == "seated_idle_south" and portrait.posture == "seated", "North-facing seated guest has face-visible seated portrait")
		check(world == world_before, "Seated portrait leaves world pose unchanged")
		for catalog in catalogs:
			check(portrait.pose_id in catalog, "Face-visible seated portrait exists for both actors")
	var north_ground := Presentation.presentation({"position": Vector2.ZERO, "posture": "standing", "facing": "north", "activity": "look_down", "staring": true}, "fragile", Vector2.DOWN * 40, true)
	var ground_portrait := Presentation.portrait_presentation(north_ground)
	check(north_ground.facing == "north" and ground_portrait.pose_id == "standing_look_down_south", "North-facing inspection portrait preserves downcast mood without a back view")
	var idle_portrait := Presentation.portrait_presentation({"posture": "standing", "facing": "north", "activity": "idle", "pose_id": "standing_idle_north", "narration": ""})
	check(idle_portrait.pose_id == "standing_idle_south", "North-facing standing idle portrait has a face-visible fallback")
	for catalog in catalogs:
		check(talk_portrait.pose_id in catalog and ground_portrait.pose_id in catalog and idle_portrait.pose_id in catalog, "All north-view portrait fallbacks use existing approved actor poses")
	for direction in ["east", "south", "west"]:
		var world := Presentation.presentation({"position": Vector2.ZERO, "posture": "standing", "facing": direction, "activity": "idle"}, "calm", directions[direction] * 40, true)
		check(Presentation.portrait_presentation(world) == world, "Existing face-visible conversation portrait direction remains unchanged")
	print(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
