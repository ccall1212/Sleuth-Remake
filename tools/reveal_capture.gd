extends "res://tools/lens_ui_checks.gd"
## Screenshot of the solved conclusion: everyone gathered, the killer portrait enlarged, other guests startled (run without --headless).
func both_seed(killer: String) -> int:
	# A case where Char and Chris are both guests and the killer is the named one, so the other one can look shocked.
	var blocked: Array = []
	var layout_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	blocked = preload("res://src/mystery/house_case_session.gd").blocked_rooms(layout_data)
	for candidate in range(0, 5000):
		var data: Dictionary = preload("res://src/mystery/generated_case.gd").generate(candidate, 6, "normal", preload("res://src/mystery/generated_case.gd").POOL, [], blocked)
		var guests: Array = data.cast.slice(0, 6)
		if "Char" in guests and "Chris" in guests and str(data.cast[data.culprit]) == killer:
			return candidate
	return -1

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/screenshots"))
	root.gui_embed_subwindows = true
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	var killer := "Char"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--killer="): killer = arg.trim_prefix("--killer=")
	view.seed_input.value = both_seed(killer)
	view.start_case()
	view.message_dialog.hide()
	var session = view.investigation
	session.runtime.rules.merge({"guest_leave": 0, "activity_redraw": 0, "entry_death": 0, "culprit_question_death": 0}, true)
	view.set_physics_process(false)
	go_item(view, session.data.weapon_room)
	view.take_nearby()
	travel(view, str(session.room_ids[session.data.murder_room]))
	view.assemble_case()
	view.assemble_case()
	view.accusation_dialog.select(session.data.culprit)
	view.finish_accusation()
	view.reveal.finish()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/screenshots/ux_8_reveal_shock_killer_%s.png" % killer.to_lower())
	for person in range(6):
		var shown: Dictionary = view.reveal_presentation(person, view.guest_presentation(person, false))
		print("GUEST ", session.data.cast[person], " ", shown.pose_id, " at ", session.runtime.guests[person].position, " killer=", person == session.data.culprit)
	view.message_dialog.hide()
	view.guest_portrait.hide()
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/screenshots/ux_8_reveal_shock_killer_%s_group.png" % killer.to_lower())
	print("SHOT reveal ", session.progress.outcome)
	quit(0)
