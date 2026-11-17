extends "res://tools/lens_ui_checks.gd"
## Screenshot at a wide window: a questioning dialogue and the HUD must stay anchored to the 4:3 play frame (run without --headless).
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/screenshots"))
	root.gui_embed_subwindows = true
	var view = View.instantiate()
	root.add_child(view)
	for i in range(3): await process_frame
	DisplayServer.window_set_size(Vector2i(1900, 860)) # after the game fits itself to the screen
	for i in range(6): await process_frame
	view.seed_input.value = PreviewCases.find_seed(2, "Char", "normal")
	view.start_case()
	view.message_dialog.hide()
	var session = view.investigation
	session.runtime.rules.merge({"guest_leave": 0, "activity_redraw": 0, "question_refusal": 0}, true)
	view.set_physics_process(false)
	var guest: Dictionary = session.runtime.guests[0]
	travel(view, str(guest.screen))
	walk_to(view, guest.get("interaction_at", guest.position))
	view.ask_nearby()
	view._physics_process(0)
	view.reveal.finish()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/screenshots/wide_dialogue.png")
	print("SHOT wide ", root.size, " ", view.size, " origin ", view.room_origin, " portrait ", view.guest_portrait.visible, view.guest_portrait.position, view.guest_portrait.size, view.guest_portrait.texture)
	quit(0)
