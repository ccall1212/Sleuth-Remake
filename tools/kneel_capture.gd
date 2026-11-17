extends "res://tools/lens_ui_checks.gd"
## Screenshot: Char kneeling to study the floor beside the player (run without --headless).
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
	var who: int = session.data.cast.find("Char")
	var guest: Dictionary = session.runtime.guests[who]
	guest.screen = view.model.current_id
	guest.position = view.model.position + Vector2(-70, -20)
	guest.interaction_at = guest.position
	guest.staring = true
	guest.activity = "look_down"
	guest.posture = "standing"
	guest.facing = "south"
	view.refresh_guests()
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/screenshots/ux_7_kneeling_char.png")
	print("SHOT kneel ", view.guest_presentation(who, false).pose_id)
	quit(0)
