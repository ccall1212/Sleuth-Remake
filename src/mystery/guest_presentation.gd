extends RefCounted
## Conversation-only presentation. Never writes to guest activity or case facts.
const Dialogue = preload("res://src/mystery/case_dialogue.gd")
static var narrator = Dialogue.new()
const FACINGS := ["north", "east", "south", "west"]
const FLOOR_FOCUSED := ["curious", "fragile", "nervous"]

static func talking_action(personality: String) -> String:
	return {"warm": "talk", "nervous": "fidget", "proud": "hands_hips",
		"guarded": "cross_arms", "hot_tempered": "cross_arms", "curious": "think",
		"fragile": "withdraw", "calm": "talk"}.get(personality, "talk")

static func portrait_presentation(world: Dictionary) -> Dictionary:
	var portrait := world.duplicate(true)
	if portrait.facing != "north":
		return portrait
	# A back-facing chair/body stays at its calibrated room anchor. The close
	# conversation view shows the face instead of enlarging the guest's back.
	portrait.facing = "south"
	if portrait.posture == "seated":
		portrait.activity = "idle"
	elif str(portrait.get("narration", "")).contains("inspection"):
		portrait.activity = "look_down"
	portrait.pose_id = "%s_%s_south" % [portrait.posture, portrait.activity]
	return portrait

static func conversation_portrait(world: Dictionary, personality: String) -> Dictionary:
	var portrait := portrait_presentation(world)
	# Personality changes the close view, never a chair anchor or persistent pose.
	if portrait.get("posture") != "standing" or portrait.get("activity") != "talk":
		return portrait
	var action: String = talking_action(personality)
	portrait.activity = action
	portrait.pose_id = "standing_%s_%s" % [action, portrait.facing]
	return portrait

static func presentation(guest: Dictionary, personality: String, player: Vector2, talking: bool, actor_name := "") -> Dictionary:
	var posture := str(guest.get("posture", "standing"))
	if posture not in ["standing", "seated"]:
		posture = "standing"
	var facing := str(guest.get("facing", "south"))
	if facing not in FACINGS:
		facing = "south"
	var activity := str(guest.get("activity", "idle"))
	if not guest.has("activity"):
		activity = {"browse": "read", "window": "look_up"}.get(str(guest.get("kind", "")), "idle")
	var staring := bool(guest.get("staring", false))
	var ground := staring or activity == "look_down"
	var narration := ""
	if posture == "seated":
		# The available sprites have one calibrated view per chair anchor. A
		# conversation must not swivel the entire body/chair or stand the guest up.
		if activity not in ["idle", "read", "sleep"]:
			activity = "idle"
		if activity == "sleep" and (talking or facing == "north"):
			activity = "idle" # No north-facing seated sleep artwork exists.
		if talking:
			narration = "guest_answer_seated"
			if str(guest.get("activity", "")) == "sleep":
				narration = "guest_answer_waking"
	else:
		if activity not in ["idle", "read", "look_up", "look_down"]:
			activity = "idle"
		if ground:
			activity = "look_down"
		if talking:
			if ground and (staring or personality in FLOOR_FOCUSED):
				if facing == "north":
					narration = "guest_answer_inspecting"
				elif personality == "fragile":
					narration = "guest_answer_downcast"
				elif personality == "nervous":
					narration = "guest_answer_nervous"
				else:
					narration = "guest_answer_floor"
			else:
				var at: Vector2 = guest.get("position", Vector2.ZERO)
				var delta := player - at
				var previous := facing
				if not delta.is_zero_approx():
					if absf(delta.x) > absf(delta.y):
						facing = "east" if delta.x > 0 else "west"
					else:
						facing = "south" if delta.y > 0 else "north"
				activity = "talk"
				if facing != "north": activity = talking_action(personality)
				narration = "guest_turn" if facing != previous else "guest_answer"
		if activity == "look_down" and facing == "north":
			# Preserve facing rather than inventing a missing north/down sprite.
			# Narration above deliberately does not describe a visible downward gaze.
			activity = "idle"
	if not narration.is_empty():
		narration = narrator.system_line(narration, {"speaker": actor_name if not actor_name.is_empty() else "the guest"}, {})
	return {"posture": posture, "facing": facing, "activity": activity,
		"pose_id": "%s_%s_%s" % [posture, activity, facing], "narration": narration}
