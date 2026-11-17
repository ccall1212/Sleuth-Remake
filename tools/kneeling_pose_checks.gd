extends SceneTree
## Approved kneeling_reach poses appear when Char or Chris study the floor; other actors and directions keep their standing poses.
const Presentation = preload("res://src/mystery/guest_presentation.gd")
const ActorArt = preload("res://src/mystery/case_actor_art.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 30: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var art = ActorArt.new()
	for actor in ["Char", "Chris"]:
		for facing in ["east", "south", "west"]:
			var guest := {"posture": "standing", "facing": facing, "activity": "look_down", "staring": true, "position": Vector2.ZERO}
			var p: Dictionary = Presentation.presentation(guest, "calm", Vector2.ZERO, false, actor)
			check(p.pose_id == "kneeling_reach_" + facing, "%s studying the floor kneels (%s)" % [actor, facing])
			check(not art.asset(actor, p.pose_id).is_empty(), "Approved art loads for " + p.pose_id + " / " + actor)
			var talking: Dictionary = Presentation.presentation(guest, "fragile", Vector2.DOWN * 30, true, actor)
			check(talking.pose_id == "kneeling_reach_" + facing, "Talking does not make a floor-studying guest stand (%s)" % actor)
			var portrait: Dictionary = Presentation.conversation_portrait(talking, "fragile")
			check(portrait.pose_id == "standing_look_down_" + facing and not art.asset(actor, portrait.pose_id).is_empty(), "Close view uses the approved standing look-down portrait")
		var north := {"posture": "standing", "facing": "north", "activity": "look_down", "staring": true, "position": Vector2.ZERO}
		check(Presentation.presentation(north, "calm", Vector2.ZERO, false, actor).pose_id == "standing_idle_north", "No north kneeling art: north keeps the standing idle")
		var idle := {"posture": "standing", "facing": "south", "activity": "idle", "staring": false, "position": Vector2.ZERO}
		check(Presentation.presentation(idle, "calm", Vector2.ZERO, false, actor).pose_id == "standing_idle_south", "Ordinary guests are not forced to kneel")
		var seated := {"posture": "seated", "facing": "south", "activity": "idle", "staring": true, "position": Vector2.ZERO}
		check(Presentation.presentation(seated, "calm", Vector2.ZERO, false, actor).posture == "seated", "A seated guest is never moved to the floor")
	var other := {"posture": "standing", "facing": "south", "activity": "look_down", "staring": true, "position": Vector2.ZERO}
	check(Presentation.presentation(other, "calm", Vector2.ZERO, false, "Justin").pose_id == "standing_look_down_south", "Cast without kneeling art keeps the standing look-down")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
