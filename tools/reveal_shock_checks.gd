extends "res://tools/lens_ui_checks.gd"
## At the case conclusion every other guest with an approved startle pose looks shocked; the killer portrait is larger.
const ActorArtScript = preload("res://src/mystery/case_actor_art.gd")

func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(960, 720)
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	view.seed_input.value = PreviewCases.find_seed(2, "Char", "normal")
	view.start_case()
	view.message_dialog.hide()
	var session = view.investigation
	var culprit: int = int(session.data.culprit)
	var art = ActorArtScript.new()
	var standing := {"pose_id": "standing_idle_south", "posture": "standing", "activity": "idle", "facing": "south"}
	for person in range(6):
		check(view.reveal_presentation(person, standing) == standing, "Before the reveal nobody looks shocked")
	session.progress.outcome = "solved"
	view.ending_shown = true
	var shocked := 0
	for person in range(6):
		var shown: Dictionary = view.reveal_presentation(person, standing)
		var name := str(session.data.cast[person])
		if person == culprit:
			check(shown == standing, "The killer keeps their own pose")
		elif ActorArtScript.ACTORS.has(name):
			shocked += 1
			check(shown.pose_id == "standing_startle_south" and not art.asset(name, shown.pose_id).is_empty(), name + " shows the approved startle pose")
		else:
			check(shown == standing, name + " has no startle art and keeps the standing image")
	var west := standing.duplicate()
	west.facing = "west"
	west.pose_id = "standing_idle_west"
	var north := standing.duplicate()
	north.facing = "north"
	var seated := standing.duplicate()
	seated.posture = "seated"
	for person in range(6):
		if person != culprit and ActorArtScript.ACTORS.has(str(session.data.cast[person])):
			check(view.reveal_presentation(person, west).pose_id == "standing_startle_west", "Startle follows the guest's facing")
			check(view.reveal_presentation(person, north) == north, "No north startle art: north keeps the standing pose")
			check(view.reveal_presentation(person, seated) == seated, "A seated guest stays seated")
			break
	session.progress.outcome = "both_wrong"
	for person in range(6):
		check(view.reveal_presentation(person, standing) == standing, "A wrong accusation that exposes nobody shocks nobody")
	session.progress.outcome = "ambushed"
	for person in range(6):
		check(view.reveal_presentation(person, standing) == standing, "The ambush is not the reveal scene")
	# The killer conclusion portrait is bigger than a conversation portrait.
	session.progress.outcome = "solved"
	view.ending_shown = false
	var ending := {"result": "solved", "message": "It was me.", "message_key": "confession", "message_group": "personality_lines"}
	view.present_ending(ending, "standing_laugh_south")
	var big: float = view.guest_portrait.size.y
	view.message_dialog.hide()
	view.ending_shown = false
	var person_view: Dictionary = view.guest_presentation(culprit, true)
	view.show_guest_portrait(culprit, person_view)
	var normal: float = view.guest_portrait.size.y
	check(big > normal * 1.2, "The killer conclusion portrait is larger than a conversation portrait (%.0f vs %.0f)" % [big, normal])
	check(view.guest_portrait.position.y >= -30.0, "The enlarged portrait stays on screen")
	print(JSON.stringify({"checks": checks, "failures": failures, "shocked_guests": shocked}))
	quit(0 if failures.is_empty() else 1)
