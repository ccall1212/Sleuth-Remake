extends SceneTree
## Native player-facing controls, item presentation and read-only house map.
const View = preload("res://src/blockout/house_investigation.tscn")
const Session = preload("res://src/mystery/house_case_session.gd")
const Case = preload("res://src/mystery/generated_case.gd")
var checks := 0
var failures: Array[String] = []
var capture_ui := false
var output := "res://test-results/play-ui"
var physical_input_observed := false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 25:
		failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func capture(view: Control, name: String) -> void:
	if not capture_ui:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(name + ".png")
	check(view.get_viewport().get_texture().get_image().save_png(path) == OK, "Native capture saved: " + name)

func input_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func within_window(control: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(960, 720)).encloses(control.get_global_rect())

func guest_state(world: RefCounted) -> String:
	return JSON.stringify(world.guests.map(func(g): return [g.screen, g.position, g.facing, g.get("activity", ""), g.staring]))

func run() -> void:
	capture_ui = "--capture-ui" in OS.get_cmdline_user_args()
	if capture_ui:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.gui_embed_subwindows = true
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	check(view.painted and view.model.data.get("mode") == "painted_investigation", "Player scene runs on current painted investigation layout")
	if not view.painted or view.investigation.data.is_empty():
		check(false, "Run this check with -- --layout=res://assets/maps/house-02.investigation.layout.json")
		view.queue_free()
		print(JSON.stringify({"checks": checks, "failures": failures}))
		quit(1)
		return
	view.investigation.runtime.rules.merge({"guest_leave": 0, "activity_redraw": 0, "entry_death": 0, "culprit_question_death": 0, "stalking_isolation_chance": 0}, true)
	check(not view.diagnostics and not view.show_navigation_markers and not view.show_player_marker, "Clean play hides debug markers and diagnostics")
	check(not view.show_guest_spots and not view.show_item_slots and not view.show_preview_guests, "Clean play has no authoring slot overlays")
	check(not view.sidebar.is_visible_in_tree() and not view.developer_tools.is_visible_in_tree(), "Inspection picker and developer actions stay hidden")
	check(view.random_case.button_pressed and not view.seed_input.is_visible_in_tree(), "Seed number is hidden for random mysteries")
	check(view.investigator.texture != null and view.investigator.error.is_empty(), "Existing investigator art is available")
	check(not view.investigator.frame_data().is_empty() and view.investigator.frame_rect(view.model.position).has_area(), "Investigator has drawable frame at player contact")
	check("seed" not in view.status_label.text.to_lower() and "steps" not in view.status_label.text.to_lower(), "Case panel omits developer seed and step labels")
	for button in view.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			check(within_window(button), "Visible player action fits window: " + button.text)
	var source_data: Dictionary = view.investigation.data.duplicate(true)
	view.model.inspect_screen("library")
	view.sync_world()
	view.investigator.reset(view.model.position)
	await process_frame
	await capture(view, "game")
	# House map reads real connectivity and never changes the player's room.
	var room_before: String = view.model.current_id
	var position_before: Vector2 = view.model.position
	var steps_before: int = view.model.steps
	var guests_before := guest_state(view.investigation.runtime)
	view.show_house_map()
	await process_frame
	check(view.map_menu.visible and view.modal_open(), "Map opens as a modal")
	var map: Dictionary = view.map_panel.model()
	check(map.current_id == room_before, "Map highlights current room")
	check(map.nodes.any(func(n): return n.id == "kitchen" and n.label == "Study"), "Map uses authored room names")
	check(not map.nodes.any(func(n): return n.id == "secret_passage"), "Unvisited secret passage is hidden")
	check(map.nodes.size() == 10, "Map shows ten ordinary rooms and hall before passage discovery")
	var graph := {}
	for screen in view.model.data.screens:
		for portal in screen.portals:
			var pair := [str(screen.id), str(portal.target)]
			pair.sort()
			graph["|".join(pair)] = true
	check(map.edges.size() == graph.size(), "Map draws every real doorway connection once")
	for edge in map.edges:
		var pair := [str(edge.a), str(edge.b)]
		pair.sort()
		check(graph.has("|".join(pair)) and not edge.secret, "Map never invents ordinary connections")
	check(view.map_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.map_panel.find_children("*", "Button", true, false).is_empty(), "House map is read-only rather than teleport controls")
	await capture(view, "map")
	view.map_menu.hide()
	check(view.model.current_id == room_before and view.model.position == position_before and view.model.steps == steps_before, "Map leaves player room, position and clock unchanged")
	# Modal physics callbacks must freeze position and clock. Headless display
	# backends cannot observe physical key state; report that limit separately.
	view.show_pause_menu()
	await process_frame
	check(view.pause_menu.visible and view.modal_open(), "Escape menu pauses the investigation")
	input_key(KEY_D, true)
	physical_input_observed = Input.is_physical_key_pressed(KEY_D)
	for unused in range(12):
		view._physics_process(0.1)
	input_key(KEY_D, false)
	check(view.model.steps == steps_before and view.model.position == position_before, "Paused physics callbacks never advance player or step count")
	check(guest_state(view.investigation.runtime) == guests_before, "Pause and map do not relocate guests or change poses")
	view.pause_menu.hide()
	# New-case menu uses the same controls read by start_case; no replacement widgets.
	var seed_control: SpinBox = view.seed_input
	var difficulty_control: OptionButton = view.difficulty_input
	view.case_menu.popup_centered()
	await process_frame
	check(view.case_menu.visible and view.modal_open(), "New-case menu is modal")
	view.random_case.button_pressed = false
	await process_frame
	check(view.seed_input.visible and view.seed_input == seed_control and view.difficulty_input == difficulty_control, "Deterministic case option reveals the existing seed control")
	view.seed_input.value = 2
	view.difficulty_input.select(0)
	view.random_case.button_pressed = true
	await process_frame
	check(not view.seed_input.visible and view.random_case.button_pressed, "Random mystery hides explicit case number again")
	check(view.case_menu.size.x <= 960 and view.case_menu.size.y <= 720, "New-case options fit the player window")
	await capture(view, "new-case")
	view.case_menu.hide()
	check(view.investigation.data == source_data, "Opening options does not silently replace the active case")
	view.case_menu.popup_centered()
	view.case_menu.confirmed.emit()
	check(view.investigation.data.seed == int(view.seed_input.value) and view.investigation.data.seed >= 0 and view.investigation.data.seed <= 999999999, "Random confirmation starts the case selected by the menu's seed control")
	check(not view.case_menu.visible and not view.pause_menu.visible, "Beginning a mystery closes setup and pause modals")
	view.case_menu.popup_centered()
	view.random_case.button_pressed = false
	view.seed_input.value = 2
	view.difficulty_input.select(0)
	view.case_menu.confirmed.emit()
	await process_frame
	check(view.investigation.data == source_data and view.investigation.progress.heard.is_empty(), "Fixed case confirmation faithfully replays the chosen seed with fresh progress")
	view.investigation.runtime.rules.merge({"guest_leave": 0, "activity_redraw": 0, "entry_death": 0, "culprit_question_death": 0, "stalking_isolation_chance": 0}, true)
	# Native item detail and primary E context use the same live session callbacks.
	var glass_room: String = view.investigation.room_ids[view.investigation.data.glass_room]
	view.model.inspect_screen(glass_room)
	view.model.position = view.investigation.items[int(view.investigation.data.glass_room)].position
	view.sync_world()
	await process_frame
	check(view.item_present() and view.near_item(), "Glass is visibly present at its actual item contact")
	check(view.item_art.detail(view.current_item_name()) != null and not view.item_art.asset(view.current_item_name()).is_empty(), "Glass world and detail art are actual mapped textures")
	view.examine_nearby()
	await process_frame
	check(view.message_dialog.visible and view.item_picture.visible and view.item_picture.texture != null, "Examine callback opens item artwork with detail text")
	check(view.message_dialog.title == "Magnifying glass" and not view.message_text.text.is_empty(), "Detail identifies actual nearby glass, with authored text or marked pending line")
	await capture(view, "item-detail")
	view.message_dialog.hide()
	view.primary_button.pressed.emit()
	await process_frame
	check(view.investigation.progress.glass and not view.item_present(), "Primary interaction takes glass and removes its world image")
	check(not view.model.screen().get("item_slot", []).is_empty(), "Pickup preserves authored placement geometry")
	check(view.investigation.data == source_data, "Inspecting and taking art does not alter generated truth")
	# Cosmetic evidence assignment varies by case while every generated fact stays exact.
	var permutations := {}
	var locations := {}
	var baseline: Array = []
	for seed_value in range(24):
		var s = Session.new()
		check(s.begin(seed_value, view.model.data), "Case presentation binds ten item slots")
		var no_item_rooms: Array = []
		for index in range(s.room_ids.size()):
			if not s.has_item_slot(str(s.room_ids[index])): no_item_rooms.append(index)
		check(s.data == Case.generate(seed_value, 6, "normal", Case.POOL, [], no_item_rooms), "Item selection changes no culprit, claims or clue-room facts")
		check(s.item_names.size() == s.room_ids.size() - 1, "Each case assigns an evidence item name to every room except the Front Entry")
		var seen := {}
		for room in range(s.room_ids.size()):
			if not s.items.has(room): continue # the Front Entry holds no evidence item
			var item: String = s.item_name(room)
			seen[item] = true
			check(not view.item_art.asset(item).is_empty() and view.item_art.detail(item) != null, "Assigned item has matching world and closeup art")
		check(seen.size() == s.room_ids.size() - 1, "No duplicated evidence item assignment")
		permutations[JSON.stringify(s.item_names)] = true
		locations[JSON.stringify([s.data.glass_room, s.data.weapon_room])] = true
		if seed_value == 2:
			baseline = s.item_names.duplicate()
	var repeat = Session.new()
	repeat.begin(2, view.model.data)
	check(repeat.item_names == baseline, "Same seed repeats evidence art assignment")
	check(permutations.size() > 1 and locations.size() > 1, "Different mysteries vary both item assignments and clue locations")
	view.queue_free()
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "item_permutations": permutations.size(), "capture_ui": capture_ui, "physical_input_observed": physical_input_observed}))
	quit(0 if failures.is_empty() else 1)
