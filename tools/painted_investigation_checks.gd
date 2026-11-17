extends "res://tools/house_investigation_checks.gd"
## Exercise the painted house through real proximity/question/item callbacks.

func run() -> void:
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	check(view.painted and view.model.data.get("mode") == "painted_investigation", "Use -- --layout=res://assets/maps/house-02.investigation.layout.json")
	if not failures.is_empty():
		print(JSON.stringify({"checks": checks, "failures": failures}))
		quit(1)
		return
	check(not view.show_preview_guests, "Only the six case suspects render, not all 55 preview examples")
	var captured_seat := false
	var captured_floor := false
	for seed_value in [2, 3]:
		view.seed_input.value = seed_value
		view.start_case()
		var session = view.investigation
		session.runtime.rules.merge({"guest_leave": 0, "activity_redraw": 0, "question_refusal": 0, "entry_death": 0, "culprit_question_death": 0}, true)
		var claims: Array = session.data.claims.duplicate(true)
		check(travel(view, session.room_ids[session.data.glass_room]), "Painted doors reach glass room")
		check(walk_to(view, session.items[int(session.data.glass_room)].position), "Painted floor reaches the glass's seeded position")
		check(view.select_nearby_item(session.data.glass_room), "Nearby chooser selects the glass")
		view.take_nearby()
		check(session.progress.glass, "Glass collected via actual nearby callback")
		for person in range(6):
			var guest: Dictionary = session.runtime.guests[person]
			check(not str(guest.slot_id).is_empty(), "Actual case suspect has an authored slot")
			check(travel(view, session.guest_screen(person)), "Walking reaches actual guest room")
			check(walk_to(view, guest.interaction_at), "Walking reaches guest beside furniture")
			check(view.nearby_guest() == person, "Reachable approach selects the intended guest")
			var before: Dictionary = guest.duplicate(true)
			if seed_value == 2 and person == 0:
				await capture(view, "painted-cast-room")
			view.ask_nearby()
			check(view.message_dialog.visible and session.progress.heard.has(str(person)), "Actual question popup records a stable account")
			var presentation: Dictionary = view.guest_presentation(person, true)
			if guest.posture == "seated":
				check(presentation.posture == "seated" and presentation.facing == guest.facing and str(presentation.pose_id).begins_with("seated_"), "Questioning never stands or reverses a seated guest")
				if not captured_seat:
					await capture(view, "painted-seated-conversation")
					captured_seat = true
			if presentation.activity == "look_down" and not captured_floor:
				await capture(view, "painted-floor-conversation")
				captured_floor = true
			check(guest.position == before.position and guest.facing == before.facing and guest.activity == before.activity, "Conversation does not mutate settled pose or position")
			view.message_dialog.hide()
			view.talking_person = -1
		var possible: Array = inspect_house_with_lens(view)
		if possible.size() != 1 or not take_deduced_item(view, possible[0]): continue
		var answer: Array = Case.candidates(6, session.progress.heard, session.progress.crime_room)
		check(answer.size() == 1, "Learned testimony and inspected crime room identify one culprit")
		check(travel(view, str(session.room_ids[session.progress.crime_room])), "Gather everyone in the room where the crime happened")
		view.assemble_case()
		check(not view.accusation_dialog.visible and view.model.transitions_locked, "Gathering locks exits without forcing accusation menu")
		check(view.investigation.runtime.guests.all(func(g): return g.screen == view.model.current_id), "All six guests gather in the player's room")
		var gathering_room: String = view.model.current_id
		var gathering_position: Vector2 = view.model.position
		for portal in view.model.screen().portals:
			view.model.position = view.Layout.point(portal.get("activation_at", portal.at))
			check(not view.model.try_door(view.Layout.point(portal.facing)), "Each gathered-room doorway rejects departure")
			check(view.model.current_id == gathering_room, "Locked doorway retains gathered room")
		check(not view.model.interact_secret(), "Gathering prevents secret exit")
		view.model.position = gathering_position
		view.model.walk(Vector2(4, 0), 0.1)
		check(view.model.position != gathering_position and view.investigation.active(), "Gathering permits walking before accusation")
		view.model.position = gathering_position
		view._physics_process(0)
		if seed_value == 2:
			await capture(view, "painted-assembly")
		view.assemble_case()
		check(view.accusation_dialog.visible, "Second action opens accusation after gathering")
		if answer.size() == 1:
			view.accusation_dialog.select(answer[0])
			view.accusation_dialog.hide()
			view.finish_accusation()
		check(session.progress.outcome == "solved", "Painted walking investigation completes using learned evidence")
		check(view.message_dialog.visible and view.guest_portrait.visible and not view.pose_window.visible, "Painted conclusion uses room dialogue and killer portrait instead of gray pose viewer")
		check(session.data.claims == claims, "Activity and conversation never change historical alibis")
		view.message_dialog.hide()
		view.pose_window.hide()
	for name in Case.POOL:
		if name not in ["Char", "Chris"]:
			check(not view.actor_art.playtest_asset(name).is_empty(), "Existing temporary art loads for " + str(name))
	view.queue_free()
	await process_frame
	paths.free()
	print(JSON.stringify({"checks": checks, "walked_cases": 2, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
