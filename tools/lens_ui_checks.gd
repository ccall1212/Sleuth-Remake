extends "res://tools/house_investigation_checks.gd"
## Actual painted UI callbacks: one item, portable evidence and final commitment.
const PreviewCases = preload("res://src/mystery/killer_preview_cases.gd")

func capture(view: Control, filename: String) -> void:
	if "--capture-ui" not in OS.get_cmdline_user_args(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/lens-ui"))
	view._physics_process(0)
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/lens-ui/" + filename + ".png")

func buttons_fit(view: Control) -> void:
	for button in view.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.get_window() == view.get_window():
			check(Rect2(Vector2.ZERO, Vector2(960, 720)).encloses(button.get_global_rect()), "Visible inventory action fits game window: " + button.text)

func select_choice(view: Control, id: int) -> void:
	view._physics_process(0)
	for index in range(view.item_choice.item_count):
		if int(view.item_choice.get_item_metadata(index)) == id:
			view.item_choice.select(index)
			view.item_choice.item_selected.emit(index)
			check(view.current_item().id == id, "Nearby chooser selects exact stable item identity")
			return
	check(false, "Expected stacked item is available in chooser")

func go_item(view: Control, id: int) -> void:
	var item: Dictionary = view.investigation.items[id]
	check(travel(view, str(item.screen)), "Painted route reaches movable item's actual screen")
	check(walk_to(view, item.position), "Walking reaches movable item's floor position")
	check(view.select_nearby_item(id), "Nearby item selected by ID")

func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(960, 720) # fixed reference window so layout checks do not depend on the headless window
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	check(view.painted, "Run painted investigation layout")
	view.seed_input.value = PreviewCases.find_seed(2, "Char", "normal")
	view.start_case()
	var session = view.investigation
	session.runtime.rules.merge({"guest_leave": 0, "activity_redraw": 0, "question_refusal": 0,
		"entry_death": 0, "culprit_question_death": 0, "stalking_isolation_chance": 0}, true)
	var original: Dictionary = session.data.duplicate(true)
	var glass: int = session.data.glass_room
	go_item(view, glass)
	view.take_nearby()
	view._physics_process(0)
	check(session.progress.glass and session.progress.carried == null and not view.item_present(), "Actual pickup takes the glass as a tool, leaves the carry slot free and removes floor sprite")
	check(not view.drop_button.visible and view.accuse_button.disabled, "Glass tool offers nothing to drop and cannot summon accusation")
	for person in range(6):
		var guest: Dictionary = session.runtime.guests[person]
		check(travel(view, str(guest.screen)) and walk_to(view, guest.get("interaction_at", guest.position)), "Walk to real suspect contact")
		view.ask_nearby()
		check(session.progress.heard.has(str(person)), "Question callback records real testimony")
		view.message_dialog.hide()
		view.talking_person = -1
	var possible: Array = inspect_house_with_lens(view)
	check(possible.size() == 1, "Public lens and wound evidence identifies one item")
	var suspects: Array = Case.candidates(6, session.progress.heard, session.progress.crime_room)
	check(suspects.size() == 1, "Collected accounts and room clue identify one suspect")
	var decoy := -1
	for key in session.progress.items_seen:
		var seen: Dictionary = session.progress.items_seen[key]
		if seen.get("stain") == "present" and seen.kind != session.progress.wound:
			decoy = int(key)
			break
	check(decoy >= 0, "Observed evidence includes a stained item excluded by wound kind")
	go_item(view, decoy)
	view.examine_nearby()
	check(session.last_message_key == "lens_stain" and view.feedback_color == Color("#FF9F40"), "Decoy stain uses authored orange lens text")
	check(session.progress.weapon == null and not view.message_text.text.to_lower().contains("murder weapon"), "Normal stain observation never identifies weapon automatically")
	check(view.message_dialog.title.contains(session.items[decoy].kind), "Item detail visibly labels kind")
	await capture(view, "stain")
	view.message_dialog.hide()
	check(travel(view, session.room_ids[session.progress.crime_room]), "Return to learned crime room")
	view.examine_floor()
	check(session.last_message_key.begins_with("wound_") and view.feedback_color == Color("#FF4D4D"), "Crime-room wound hint uses red authored style")
	check(view.message_dialog.visible and view.message_text.text.contains(session.progress.wound), "Floor discovery opens its full wound clue instead of clipping it in HUD")
	view.message_dialog.hide()
	view.show_notebook()
	check(session.notebook().contains("Wound kind:") and session.notebook().contains("stain: present") and not session.notebook().contains("Identified weapon:"), "Notebook records evidence without automatic answer")
	await capture(view, "notebook")
	view.notebook_dialog.hide()
	go_item(view, decoy)
	view.take_nearby()
	check(session.progress.carried == decoy and session.progress.glass, "Any stained decoy can be taken while holding the glass tool")
	check(travel(view, "hall_2"), "Walk to hall carrying evidence")
	var stack: Vector2 = view.Layout.point(view.model.screen().spawn)
	check(walk_to(view, stack), "Hall floor point is reachable")
	stack = view.model.position
	view.drop_nearby()
	check(session.items[decoy].screen == "hall_2" and session.items[decoy].position == stack and session.progress.glass, "Evidence stays at arbitrary hall drop point and the glass tool is kept")
	var weapon: int = possible[0]
	go_item(view, weapon)
	view.take_nearby()
	check(session.progress.carried == weapon and session.progress.glass, "True weapon can be taken while holding the glass tool")
	check(travel(view, "hall_2") and walk_to(view, stack), "Return weapon to exact decoy drop point")
	view.drop_nearby()
	view._physics_process(0)
	await process_frame
	check(view.item_choice.visible and view.item_choice.item_count == 2, "Overlapping floor items expose explicit chooser")
	check(session.all_items_in("hall_2").size() == 2, "Both stacked items retain independent floor instances")
	select_choice(view, weapon)
	view.take_nearby()
	view._physics_process(0)
	check(session.progress.carried == weapon and session.progress.glass and view.take_button.disabled, "Chooser recovers exact weapon and hands-full Take is disabled")
	check(view.select_nearby_item(decoy), "Moved decoy remains selectable while carrying the weapon")
	view.examine_nearby()
	check(session.last_message_key == "lens_stain" and session.progress.items_seen[str(decoy)].screen == "hall_2", "Stain follows the moved item and can be inspected in a hall")
	view.message_dialog.hide()
	view.drop_nearby()
	view._physics_process(0)
	await process_frame
	buttons_fit(view)
	await capture(view, "stack")
	select_choice(view, decoy)
	view.take_nearby()
	check(travel(view, str(session.room_ids[session.progress.crime_room])), "Carry decoy into the crime room for gathering")
	var room_before: String = view.model.current_id
	view.assemble_case()
	check(session.progress.assembled and view.model.current_id == room_before and view.model.transitions_locked, "Unidentified decoy gathers six guests in current room and locks exits")
	check(not view.accusation_dialog.visible, "Gathering leaves time to look around")
	view.assemble_case()
	check(view.accusation_dialog.visible, "Separate confirmation opens accusation choices")
	view.accusation_dialog.select(suspects[0])
	view.accusation_dialog.hide()
	view.drop_nearby()
	view.finish_accusation()
	check(session.active() and not view.ending_shown and session.progress.carried == null, "Empty-handed final accusation remains blocked after gathering")
	check(view.select_nearby_item(decoy), "Dropped item remains selectable in locked gathering room")
	view.take_nearby()
	view._physics_process(0)
	await process_frame
	buttons_fit(view)
	view.finish_accusation()
	check(session.progress.outcome == "wrong_weapon" and view.ending_shown and view.message_dialog.visible and view.guest_portrait.visible, "Correct public suspect/room with wrong held item triggers visible dialogue and portrait")
	check(view.message_text.text.contains(session.item_name(decoy)) and view.message_text.text.contains(session.item_name(possible[0])), "Weapon-correction dialogue distinguishes held decoy from actual weapon")
	view.reveal.finish()
	await capture(view, "wrong-weapon")
	check(session.data == original, "Inventory and dialogue UI never rewrite generated truth")
	view.queue_free()
	await process_frame
	paths.free()
	print(JSON.stringify({"checks": checks, "failures": failures, "full_flow": "glass-lens-wound-hall-stack-gather-wrong_weapon"}))
	quit(0 if failures.is_empty() else 1)
