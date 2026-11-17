extends "res://tools/lens_ui_checks.gd"
## Real-game screenshots for review (run WITHOUT --headless): HUD with glass and carried item, journal, accusation, murderer zoom.
const OUT := "res://test-results/screenshots/"

func shot(view: Control, name: String, frames := 3) -> void:
	for i in range(frames): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("SHOT ", name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.gui_embed_subwindows = true
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.seed_input.value = PreviewCases.find_seed(2, "Char", "normal")
	view.start_case()
	view.message_dialog.hide()
	var session = view.investigation
	session.runtime.rules.merge({"guest_leave": 0, "activity_redraw": 0, "question_refusal": 0, "entry_death": 0, "culprit_question_death": 0, "stalking_isolation_chance": 0}, true)
	view.set_physics_process(false)
	# 1. Glass found, then an evidence item carried at the same time.
	go_item(view, session.data.glass_room)
	view.take_nearby()
	var other := -1
	for id in session.items:
		if id != session.data.glass_room and str(session.items[id].screen) != "" and id != session.data.weapon_room:
			other = id
			break
	go_item(view, other)
	view.take_nearby()
	view._physics_process(0)
	view.feedback = session.last_message
	await shot(view, "ux_1_gameplay_hud_glass_and_item")
	# 2. Question two guests so the journal has personality poses, then open it with a few of the player's own ticks.
	for person in range(2):
		var guest: Dictionary = session.runtime.guests[person]
		travel(view, str(guest.screen))
		walk_to(view, guest.get("interaction_at", guest.position))
		view.ask_nearby()
		view.message_dialog.hide()
	view.show_notebook()
	await process_frame
	var boxes: Array = view.journal.find_children("*", "CheckBox", true, false)
	boxes[0].button_pressed = true
	boxes[3].button_pressed = true
	await shot(view, "ux_2_journal_suspects")
	view.journal.tabs.current_tab = 1
	await shot(view, "ux_3_journal_evidence")
	view.notebook_dialog.hide()
	# 3. Gather everyone in the crime room and open the accusation cards.
	travel(view, str(session.room_ids[session.data.murder_room]))
	view.assemble_case()
	view.assemble_case()
	view.accusation_dialog.select(2)
	await shot(view, "ux_4_accusation_cards")
	view.accusation_dialog.hide()
	# 4. Murderer zoom at the impact moment (carrying an item, so the grab scene).
	session.progress.assembled = false
	view.ambush_pending = false
	view.ending_shown = false
	session.progress.outcome = "investigating"
	var ending: Dictionary = session.ambush()
	view.present_ending(ending, "standing_threaten_south")
	view._process(2.0)
	for i in range(50): await process_frame
	await shot(view, "ux_5_murderer_zoom", 1)
	view.zoom.skip()
	await shot(view, "ux_6_ambush_dialogue", 4)
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0)
