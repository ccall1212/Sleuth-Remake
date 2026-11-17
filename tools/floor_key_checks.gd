extends "res://tools/lens_ui_checks.gd"
## F examines the floor exactly like the Floor button, and is ignored while any modal window is open.

func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	event.keycode = code
	return event

func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(960, 720) # fixed reference window so layout checks do not depend on the headless window
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	view.seed_input.value = PreviewCases.find_seed(2, "Char", "normal")
	view.start_case()
	view.message_dialog.hide()
	var session = view.investigation
	session.runtime.rules.merge({"guest_leave": 0, "activity_redraw": 0, "question_refusal": 0,
		"entry_death": 0, "culprit_question_death": 0, "stalking_isolation_chance": 0}, true)
	# Before the glass is found the HUD does not offer the floor action.
	view._physics_process(0)
	check(not view.hud.visible_action_ids().has("floor"), "Floor action hidden until the magnifying glass is found")
	var glass: int = session.data.glass_room
	go_item(view, glass)
	view.take_nearby()
	view._physics_process(0)
	check(session.progress.glass and view.hud.visible_action_ids().has("floor"), "Floor action appears once the glass is found")
	check(view.hud.visible_action_ids().has("floor") and not view.hud.visible_action_ids().has("drop"), "Glass is a tool: nothing to drop")
	# Button path.
	var steps_before: int = view.model.steps
	var button_text := ""
	view.on_hud_action("floor")
	button_text = view.investigation.last_message
	var steps_button: int = view.model.steps - steps_before
	var floors_after_button: int = session.progress.clean_floors.size() + (1 if session.progress.crime_room != null else 0)
	# Key path (same room, same state): must produce the same message and charge no extra steps.
	view.message_dialog.hide()
	steps_before = view.model.steps
	view._unhandled_key_input(key_event(KEY_F))
	check(view.investigation.last_message == button_text, "F produces the same floor result as the Floor button")
	check(view.model.steps - steps_before == steps_button, "F advances the walking clock no more than the button")
	var floors_after_key: int = session.progress.clean_floors.size() + (1 if session.progress.crime_room != null else 0)
	check(floors_after_key == floors_after_button, "F records the same floor evidence as the button")
	# Modal windows swallow the key.
	var marker := "unchanged"
	session.last_message = marker
	view.message_dialog.show()
	view._unhandled_key_input(key_event(KEY_F))
	check(session.last_message == marker, "F ignored while a message dialog is open")
	view.message_dialog.hide()
	view.notebook_dialog.show()
	view._unhandled_key_input(key_event(KEY_F))
	check(session.last_message == marker, "F ignored while the notebook is open")
	view.notebook_dialog.hide()
	view.accusation_dialog.show()
	view._unhandled_key_input(key_event(KEY_F))
	check(session.last_message == marker, "F ignored while the accusation screen is open")
	view.accusation_dialog.hide()
	view.seed_input.get_line_edit().grab_focus()
	view._unhandled_key_input(key_event(KEY_F))
	check(session.last_message == marker, "F ignored while a text field has focus")
	view.seed_input.get_line_edit().release_focus()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
