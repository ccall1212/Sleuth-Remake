extends SceneTree
const Presentation = preload("res://src/mystery/guest_presentation.gd")
const Case = preload("res://src/mystery/generated_case.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var directions := {"north": Vector2.UP, "east": Vector2.RIGHT, "south": Vector2.DOWN, "west": Vector2.LEFT}
	var action_poses := {}
	for actor in ["char", "chris"]:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/poses/%s/directional-index.json" % actor))
		var approved: Array = catalog.assets.map(func(asset): return str(asset.pose_id))
		for voice in Case.PERSONALITIES:
			for direction in directions:
				var guest := {"position": Vector2(200, 200), "posture": "standing", "facing": "south", "activity": "idle", "staring": false}
				var settled := guest.duplicate(true)
				var world: Dictionary = Presentation.presentation(guest, voice, guest.position + directions[direction] * 40, true)
				var before := world.duplicate(true)
				var close: Dictionary = Presentation.conversation_portrait(world, voice)
				check(close.pose_id in approved, "Personality close view uses approved art: " + actor + "/" + voice + "/" + direction)
				check(close.facing != "north" and close.posture == "standing", "Standing portrait exposes the speaker's face")
				check(world.pose_id in approved, "Actual speaking guest uses approved directional world artwork")
				if direction != "north":
					check(world.pose_id == close.pose_id and world.activity == close.activity, "Visible world conversation and close portrait share personality pose")
				check(guest == settled and world == before, "Personality portrait leaves world facing, posture and staging unchanged")
				if direction == "south": action_poses[close.pose_id] = true
			for facing in directions:
				var chair := {"position": Vector2(200, 200), "posture": "seated", "facing": facing, "activity": "read", "staring": false}
				var settled := chair.duplicate(true)
				var world: Dictionary = Presentation.presentation(chair, voice, Vector2(200, 240), true)
				var before := world.duplicate(true)
				var close: Dictionary = Presentation.conversation_portrait(world, voice)
				check(close.posture == "seated" and close.pose_id in approved, "Every personality stays seated with approved portrait artwork")
				check(chair == settled and world == before and world.facing == facing, "Personality never swivels or stands the world chair pose")
				var down := {"posture": "standing", "activity": "look_down", "facing": "south", "pose_id": "standing_look_down_south", "narration": ""}
				check(Presentation.conversation_portrait(down, voice) == down, "Downcast close view retains its activity for every personality")
	check(action_poses.size() >= 6, "Eight personalities use visibly varied approved conversation poses")
	print(JSON.stringify({"checks": checks, "failures": failures, "distinct_standing_poses": action_poses.size()}))
	quit(0 if failures.is_empty() else 1)
