extends "res://tools/lens_ui_checks.gd"
## Screenshot of the solved conclusion: everyone gathered, the killer portrait enlarged, other guests startled (run without --headless).
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/screenshots"))
	root.gui_embed_subwindows = true
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.seed_input.value = PreviewCases.find_seed(2, "Char", "normal")
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
	root.get_texture().get_image().save_png("res://test-results/screenshots/ux_8_reveal_shock.png")
	print("SHOT reveal ", session.progress.outcome)
	quit(0)
