extends SceneTree
const View = preload("res://src/blockout/house_investigation.tscn")
const Paths = preload("res://tools/house_blockout_checks.gd")
const Case = preload("res://src/mystery/generated_case.gd")
var checks := 0
var failures: Array[String] = []
var paths = Paths.new()

func capture(view: Control, filename: String) -> void:
	if "--capture-ui" not in OS.get_cmdline_user_args():
		return
	view._physics_process(0)
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/house-investigation/" + filename + ".png")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and failures.size() < 20:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func walk_to(view: Control, target: Vector2) -> bool:
	var id: String = view.model.current_id
	var path: Array[Vector2] = paths.route(view.model, view.model.position, target)
	if path.is_empty() and view.model.position.distance_to(target) > 4:
		check(false, "No open-floor path in " + id + " to " + str(target))
		return false
	paths.walk_path(view.model, path, id)
	view.investigation.enter_screen(view.model.current_id)
	return true

func travel(view: Control, target: String) -> bool:
	var model = view.model
	var previous := {model.current_id: ""}
	var frontier: Array = [model.current_id]
	var cursor := 0
	var secret: Dictionary = model.data.secret
	while cursor < frontier.size() and not previous.has(target):
		var id: String = frontier[cursor]
		cursor += 1
		var neighbors: Array = model.screens[id].portals.map(func(p): return str(p.target))
		if id == secret.entrance_room:
			neighbors.append(secret.screen)
		if id == secret.screen:
			neighbors.append(secret.exit_room)
		for next in neighbors:
			if not previous.has(next):
				previous[next] = id
				frontier.append(next)
	if not previous.has(target):
		check(false, "Disconnected room: " + target)
		return false
	var route: Array = []
	var back := target
	while back != model.current_id:
		route.push_front(back)
		back = previous[back]
	for next in route:
		var id: String = model.current_id
		if id == secret.entrance_room and next == secret.screen:
			if not walk_to(view, model.secret_panel()): return false
			check(model.interact_secret(), "Walking reaches exposed secret panel")
		elif id == secret.screen:
			if not walk_to(view, model.secret_exit()): return false
			check(model.interact_secret(), "Walking reaches passage exit")
		else:
			var portal: Dictionary = model.screens[id].portals.filter(func(p): return p.target == next)[0]
			if not walk_to(view, model.point(portal.get("activation_at", portal.at))): return false
			for step in range(6):
				if model.current_id != id:
					break
				model.walk(model.point(portal.facing) * 4, 0.1)
		if model.current_id != next:
			print("INVESTIGATION_ROUTE ", id, " -> ", next, " stopped at ", model.current_id, " ", model.position)
		check(model.current_id == next, "Route crosses actual authored doorway")
		if model.current_id != next: return false
	view.investigation.enter_screen(model.current_id)
	return true

func inspect_house_with_lens(view: Control) -> Array:
	var session = view.investigation
	for room in range(session.room_ids.size()):
		if not travel(view, session.room_ids[room]): continue
		view.examine_floor()
		view.message_dialog.hide()
		if not session.items.has(room): continue # the Front Entry holds no evidence item
		check(walk_to(view, session.items[room].position), "Walking reaches the item's actual seeded floor location")
		if room != session.data.glass_room:
			check(view.select_nearby_item(room), "Initial floor item can be selected by stable identity")
			view.examine_nearby()
			view.message_dialog.hide()
	check(session.progress.crime_room != null and session.progress.wound != null, "Exploration learns murder room and wound kind")
	check(session.progress.weapon == null, "Normal lens observations never automatically identify the weapon")
	var kinds: Array = []
	kinds.resize(session.room_ids.size())
	kinds.fill("")
	var stains: Array = []
	for key in session.progress.items_seen:
		var seen: Dictionary = session.progress.items_seen[key]
		kinds[int(key)] = seen.kind
		if seen.get("stain", "") == "present": stains.append(int(key))
	check(stains.size() == 3, "Lens records three stained items, including two decoys")
	var possible: Array = Case.weapon_candidates(kinds, stains, str(session.progress.wound))
	check(possible.size() == 1, "Only public stain, item kind and wound observations identify one item")
	return possible

func take_deduced_item(view: Control, item_id: int) -> bool:
	var session = view.investigation
	var seen: Dictionary = session.progress.items_seen[str(item_id)]
	if not travel(view, str(seen.screen)): return false
	if not walk_to(view, seen.position): return false
	view.message_dialog.hide()
	check(session.progress.carried == null and session.progress.glass, "The glass is a tool: hands are free to take evidence without dropping it")
	check(session.items[session.data.glass_room].screen == "", "Taken glass has left the world")
	check(view.select_nearby_item(item_id), "Nearby chooser selects deduced item while the glass tool is held")
	view.take_nearby()
	check(session.progress.carried == item_id and session.progress.glass, "Pickup holds the deduced item and keeps the glass tool")
	return session.progress.carried == item_id

func run() -> void:
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	check(not view.modal_open(), "Investigation starts without an unsolicited popup")
	var stationary: Dictionary = view.guest_positions.duplicate(true)
	view.investigation.runtime.rules.guest_leave = 1
	view.investigation.runtime.rules.activity_redraw = 1
	view.model.steps = 100
	view._physics_process(0)
	check(view.guest_positions == stationary, "Walking inside the visible room never changes guest positions")
	check(view.investigation.runtime.guest_snapshots == 0, "In-room physics updates never resample guests")
	view.start_case()
	check(view.investigation.data.seed == 2 and "Char" in view.investigation.data.cast and "Chris" in view.investigation.data.cast, "Demo seed includes both approved characters")
	check(view.actor_art.records("Char").size() == 81 and view.actor_art.records("Chris").size() == 81, "All 162 approved poses available in Godot viewer")
	for name in ["Char", "Chris"]:
		for direction in ["north", "east", "south", "west"]:
			check(not view.actor_art.asset(name, "standing_idle_" + direction).is_empty(), "Approved directional sprite loads and hash matches")
	view.show_pose_viewer()
	view.art_actor.select(1)
	view.populate_poses("standing_idle_south")
	await capture(view, "chris-pose-viewer")
	view.pose_window.hide()
	for seed_value in [2, 3]:
		view.seed_input.value = seed_value
		view.start_case()
		# Keep the original inventory/accusation route regression deterministic.
		# The separate runtime suite exercises the real movement/refusal/risk rules.
		view.investigation.runtime.rules.merge({"guest_leave": 0, "activity_redraw": 0, "question_refusal": 0, "entry_death": 0, "culprit_question_death": 0}, true)
		var session = view.investigation
		for person in view.guest_positions:
			var id: String = session.room_ids[session.data.guest_start[person]]
			check(view.model.is_open(id, view.guest_positions[person]), "Guest marker placed on open authored floor")
			var screen: Dictionary = view.model.screens[id]
			for index in range(screen.guest_spots.size()):
				if view.model.point(screen.guest_spots[index]).is_equal_approx(view.guest_positions[person]):
					var allowed: Variant = screen.guest_spot_facing[index]
					check(allowed == "any" or (allowed is Array and view.guest_facings[person] in allowed) or allowed == view.guest_facings[person], "Actor follows the spot's allowed facing")
		check(travel(view, session.room_ids[session.data.glass_room]), "Can physically reach glass room")
		check(walk_to(view, session.items[int(session.data.glass_room)].position), "Can walk to the glass's seeded position")
		check(view.select_nearby_item(session.data.glass_room), "Nearby chooser selects the glass")
		view.take_nearby()
		check(session.progress.glass, "Actual nearby-item callback collects glass")
		for person in range(6):
			if not travel(view, session.room_ids[session.data.guest_start[person]]): continue
			walk_to(view, view.guest_positions[person])
			check(view.nearby_guest() == person, "Proximity chooses the intended guest")
			view.ask_nearby()
			check(session.progress.heard.has(str(person)), "Question callback records the account")
			if seed_value == 2 and person == 0:
				await capture(view, "question-dialog")
			view.message_dialog.hide()
			view.talking_person = -1
		var possible: Array = inspect_house_with_lens(view)
		if possible.size() != 1 or not take_deduced_item(view, possible[0]): continue
		var answer: Array = Case.candidates(6, session.progress.heard, session.progress.crime_room)
		check(answer.size() == 1, "Public notebook evidence identifies a unique answer")
		view.assemble_case()
		check(not view.accusation_dialog.visible and view.model.transitions_locked, "Assembly gathers first with exits locked")
		view.assemble_case()
		check(view.accusation_dialog.visible, "Assembly opens actual accusation UI")
		if seed_value == 2:
			await capture(view, "accusation-dialog")
		view.suspect_choice.select(answer[0])
		view.room_choice.select(session.progress.crime_room)
		view.accusation_dialog.hide()
		view.finish_accusation()
		check(session.progress.outcome == "solved", "Complete walking and interaction loop wins from learned evidence")
		check(view.message_dialog.visible and view.guest_portrait.visible and not view.pose_window.visible, "Conclusion remains over the room with an enlarged killer portrait")
		view.message_dialog.hide()
		view.pose_window.hide()
	check(view.model.steps > 0 and view.model.room_entries > 0, "Playable investigation accumulated walking and entries")
	view.difficulty_input.select(2)
	view.start_case()
	check(view.investigation.data.difficulty == "hard", "Hard difficulty is enabled in the playable scene")
	view.investigation.runtime.rules.entry_death = 0
	view.model.steps = view.investigation.runtime.warning_at
	view._physics_process(0)
	check(view.investigation.runtime.phase() == "suspicious" and "suspicious" in view.warning_text.text.to_lower(), "Walking counter drives visible warning phase")
	await capture(view, "danger-warning")
	view.model.steps = view.investigation.runtime.stalking_at
	view._physics_process(0)
	check(view.investigation.runtime.phase() == "stalking", "Walking counter drives visible stalking phase")
	await capture(view, "danger-stalking")
	for person in view.guest_positions:
		check(view.guest_positions[person] == view.investigation.runtime.guests[person].position, "Guest rendering follows the live runtime position")
	view.queue_free()
	await process_frame
	paths.free()
	print(JSON.stringify({"checks": checks, "walked_cases": 2, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
