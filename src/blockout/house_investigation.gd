extends "res://src/blockout/house_blockout.gd"
## Investigation on the same collision/traversal model as the approved blockout.
const Session = preload("res://src/mystery/house_case_session.gd")
const ActorArt = preload("res://src/mystery/case_actor_art.gd")
const Presentation = preload("res://src/mystery/guest_presentation.gd")
const Dialogue = preload("res://src/mystery/case_dialogue.gd")
const MysteryTheme = preload("res://src/blockout/mystery_theme.gd")
const Investigator = preload("res://src/blockout/investigator_presentation.gd")
const WindowPresentation = preload("res://src/presentation.gd")
const ItemArt = preload("res://src/mystery/house_item_art.gd")
const HouseMap = preload("res://src/blockout/house_map_panel.gd")
const GameHud = preload("res://src/blockout/game_hud.gd")
const AccusationCards = preload("res://src/blockout/accusation_cards.gd")
const CastPortrait = preload("res://src/blockout/cast_portrait.gd")
const MurdererZoom = preload("res://src/blockout/murderer_zoom.gd")
const JournalState = preload("res://src/mystery/journal_state.gd")
const JournalNotebook = preload("res://src/blockout/journal_notebook.gd")
@export var random_on_start := false
@export var opening_on_start := false
var investigation = Session.new()
var actor_art = ActorArt.new()
var seed_input: SpinBox
var difficulty_input: OptionButton
var status_label: Label
var message_dialog: AcceptDialog
var message_text: RichTextLabel
var feedback_text: RichTextLabel
var warning_text: RichTextLabel
var feedback_color := Color("dbe6ec")
var dialogue = Dialogue.new()
var notebook_dialog: AcceptDialog
var journal_state := JournalState.new() # the player's own notes; never read by the case logic
var journal: Control
var accusation_dialog: ConfirmationDialog
var feedback := "Find the magnifying glass, examine the house and compare accounts."
var guest_positions: Dictionary = {}
var guest_facings: Dictionary = {}
var talking_person := -1
var pose_window: Window
var art_actor: OptionButton
var art_pose: OptionButton
var art_preview: TextureRect
var art_note: Label
var pose_controls: HBoxContainer
var pose_close_button: Button
var ending_new_case_button: Button
var ending_shown := false
var investigator = Investigator.new()
var investigator_room := ""
var item_art = ItemArt.new()
var item_picture: TextureRect
var guest_portrait: TextureRect
var diagnostics := false
var case_menu: AcceptDialog
var pause_menu: AcceptDialog
var map_menu: AcceptDialog
var random_case: CheckButton
var primary_button: Button
var item_button: Button
var take_button: Button
var drop_button: Button
var item_choice: OptionButton
var selected_item_id := -1
var item_choice_ids: Array = []
var reveal = preload("res://src/blockout/dialogue_reveal.gd").new()
var ambush_pending := false
var ambush_elapsed := 0.0
var ambush_route: Array[Vector2] = []
var ambush_position := Vector2.ZERO
var ambush_start := Vector2.ZERO
var ambush_ending: Dictionary = {}
var ambush_pose := "standing_threaten_south"
var ambush_sting_started := false
var sting: AudioStreamPlayer
var door_lock_audio: AudioStreamPlayer
var win_audio: AudioStreamPlayer
var dialogue_new_case_button: Button
var accuse_button: Button
var context_label: Label
var victim_label: Label
var map_panel: Control
var developer_tools: VBoxContainer
var killer_preview_remaining := 0
var hud: Control
var zoom: Control
var ambush_zoom_enabled := DisplayServer.get_name() != "headless" # headless checks keep the instant dialogue unless a test turns the zoom on
var ambush_zoom_overrides := {}
var hud_hint_shown := {}
var killer_preview_index := 0

func _ready() -> void:
	super()
	if model.current_id.is_empty():
		return
	sidebar.hide()
	overlay_layout = true # the room fills the window; the HUD overlays it
	theme = MysteryTheme.create()
	show_preview_guests = false
	show_guest_spots = false
	show_item_slots = false
	show_navigation_markers = false
	show_player_marker = false
	DisplayServer.window_set_title("Mansion Mystery")
	WindowPresentation.fit_window_to_screen()
	var card := Panel.new()
	card.visible = false # the permanent sidebar is replaced by the HUD overlay
	card.position = Vector2(736, 112)
	card.size = Vector2(208, 536)
	card.add_theme_stylebox_override("panel", MysteryTheme.panel("152025", "514936", 7))
	add_child(card)
	var controls := VBoxContainer.new()
	controls.visible = false # kept as hidden state holders; the HUD mirrors them
	controls.position = Vector2(748, 126)
	controls.size = Vector2(184, 510)
	controls.add_theme_constant_override("separation", 6)
	add_child(controls)
	var title := Label.new()
	title.text = "CASE FILE"
	title.add_theme_color_override("font_color", Color("c9ab70"))
	controls.add_child(title)
	victim_label = Label.new()
	victim_label.add_theme_font_size_override("font_size", 19)
	controls.add_child(victim_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("b8bdb5"))
	status_label.add_theme_font_size_override("font_size", 13)
	controls.add_child(status_label)
	controls.add_child(HSeparator.new())
	context_label = Label.new()
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_label.custom_minimum_size.y = 30
	context_label.add_theme_font_size_override("font_size", 13)
	controls.add_child(context_label)
	item_choice = OptionButton.new()
	item_choice.visible = false
	item_choice.clip_text = true
	item_choice.focus_mode = Control.FOCUS_NONE
	item_choice.item_selected.connect(func(index): selected_item_id = int(item_choice.get_item_metadata(index)))
	controls.add_child(item_choice)
	primary_button = add_action(controls, "Interact   E", interact_nearby)
	item_button = add_action(controls, "Examine item", examine_nearby)
	take_button = add_action(controls, "Take item", take_nearby)
	drop_button = add_action(controls, "Drop held item   Q", drop_nearby)
	add_action(controls, "Examine the floor", examine_floor)
	controls.add_child(HSeparator.new())
	add_action(controls, "Notebook   N", show_notebook)
	add_action(controls, "House map   Tab", show_house_map)
	accuse_button = add_action(controls, "Make an accusation", assemble_case)
	add_action(controls, "Menu   Esc", show_pause_menu)
	var keys := Label.new()
	keys.text = "WASD / arrows  ·  Move"
	keys.add_theme_font_size_override("font_size", 11)
	keys.add_theme_color_override("font_color", Color("8b9896"))
	controls.add_child(keys)
	case_menu = AcceptDialog.new()
	case_menu.title = "A new mystery"
	case_menu.ok_button_text = "Begin investigation"
	case_menu.min_size = Vector2i(450, 310)
	add_child(case_menu)
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 14)
	case_menu.add_child(options)
	var explanation := Label.new()
	explanation.text = "Start a fresh case with a new cast and new evidence.\nYour current investigation will be replaced."
	options.add_child(explanation)
	random_case = CheckButton.new()
	random_case.text = "Random mystery"
	random_case.button_pressed = true
	options.add_child(random_case)
	seed_input = SpinBox.new()
	seed_input.min_value = 0
	seed_input.max_value = 999999999
	seed_input.step = 1
	seed_input.value = 2
	seed_input.prefix = "Case number "
	seed_input.visible = false
	options.add_child(seed_input)
	random_case.toggled.connect(func(value: bool): seed_input.visible = not value)
	difficulty_input = OptionButton.new()
	difficulty_input.focus_mode = Control.FOCUS_NONE
	difficulty_input.add_item("Normal")
	difficulty_input.add_item("Easy")
	difficulty_input.add_item("Hard")
	options.add_child(difficulty_input)
	case_menu.confirmed.connect(func():
		if random_case.button_pressed:
			seed_input.value = randi_range(0, 999999999)
		start_case())
	pause_menu = AcceptDialog.new()
	pause_menu.title = "Investigation paused"
	pause_menu.ok_button_text = "Return to the house"
	pause_menu.min_size = Vector2i(400, 270)
	add_child(pause_menu)
	var menu_actions := VBoxContainer.new()
	menu_actions.add_theme_constant_override("separation", 10)
	pause_menu.add_child(menu_actions)
	add_action(menu_actions, "New mystery…", func(): pause_menu.hide(); case_menu.popup_centered())
	add_action(menu_actions, "Fullscreen / windowed", WindowPresentation.toggle_fullscreen)
	developer_tools = VBoxContainer.new()
	developer_tools.visible = false
	menu_actions.add_child(developer_tools)
	add_action(developer_tools, "Character pose viewer", func(): pause_menu.hide(); show_pose_viewer())
	message_dialog = AcceptDialog.new()
	message_dialog.title = "Investigation"
	message_dialog.min_size = Vector2i(620, 220)
	message_dialog.dialog_autowrap = true
	add_child(message_dialog)
	message_text = RichTextLabel.new()
	message_text.custom_minimum_size = Vector2(650, 145)
	message_text.bbcode_enabled = false
	message_text.selection_enabled = true
	message_text.scroll_active = true
	var message_layout := HBoxContainer.new()
	message_layout.custom_minimum_size = Vector2(650, 145)
	message_layout.add_theme_constant_override("separation", 16)
	message_dialog.add_child(message_layout)
	item_picture = TextureRect.new()
	item_picture.custom_minimum_size = Vector2(130, 145)
	item_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_picture.visible = false
	message_layout.add_child(item_picture)
	message_text.custom_minimum_size.x = 0
	message_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_layout.add_child(message_text)
	message_dialog.confirmed.connect(func(): talking_person = -1)
	message_dialog.canceled.connect(func(): talking_person = -1)
	dialogue_new_case_button = message_dialog.add_button("Start a new mystery", false, "new_case")
	dialogue_new_case_button.hide()
	dialogue_new_case_button.pressed.connect(func(): message_dialog.hide(); case_menu.popup_centered())
	message_dialog.get_ok_button().gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and reveal.is_active():
			reveal.finish()
			message_dialog.get_ok_button().accept_event())
	message_text.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed: reveal.finish())
	sting = preload("res://src/blockout/mystery_sting.gd").new()
	add_child(sting)
	door_lock_audio = AudioStreamPlayer.new()
	door_lock_audio.stream = preload("res://src/blockout/mystery_sting.gd").create_door_stream()
	add_child(door_lock_audio)
	win_audio = AudioStreamPlayer.new()
	win_audio.stream = preload("res://src/blockout/mystery_sting.gd").create_win_stream()
	add_child(win_audio)
	guest_portrait = preload("res://src/blockout/guest_dialogue_portrait.gd").new()
	add_child(guest_portrait)
	message_dialog.visibility_changed.connect(func():
		if not message_dialog.visible:
			guest_portrait.hide()
			reveal.stop())
	notebook_dialog = AcceptDialog.new()
	notebook_dialog.title = "Investigation journal"
	notebook_dialog.ok_button_text = "Close journal"
	notebook_dialog.min_size = Vector2i(900, 640)
	add_child(notebook_dialog)
	journal = JournalNotebook.new()
	notebook_dialog.add_child(journal)
	accusation_dialog = AccusationCards.new()
	add_child(accusation_dialog)
	accusation_dialog.suspect_confirmed.connect(func(_index): finish_accusation())
	feedback_text = RichTextLabel.new()
	feedback_text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	feedback_text.offset_left = 150
	feedback_text.offset_right = -150
	feedback_text.offset_top = -176
	feedback_text.offset_bottom = -124
	feedback_text.add_theme_stylebox_override("normal", MysteryTheme.panel("0a1116d8", "514936", 6))
	feedback_text.fit_content = false
	feedback_text.add_theme_font_size_override("normal_font_size", 13)
	feedback_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_text.scroll_active = false
	add_child(feedback_text)
	warning_text = RichTextLabel.new()
	warning_text.visible = false # the HUD shows the murderer's status
	warning_text.position = Vector2(22, 693)
	warning_text.size = Vector2(916, 27)
	warning_text.add_theme_font_size_override("normal_font_size", 12)
	warning_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_text.scroll_active = false
	add_child(warning_text)
	build_pose_viewer()
	hud = GameHud.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.action_pressed.connect(on_hud_action)
	add_child(hud)
	zoom = MurdererZoom.new()
	add_child(zoom) # last child: the full-screen reveal draws above the HUD
	if random_on_start: seed_input.value = randi_range(0, 999999999)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--killer-preview-count="):
			killer_preview_remaining = clampi(int(arg.trim_prefix("--killer-preview-count=")), 0, 20)
		if arg == "--random-case": seed_input.value = randi_range(0, 999999999)
		if arg.begins_with("--case-seed="): seed_input.value = int(arg.trim_prefix("--case-seed="))
	start_case()
	if model.screens.has(review_screen):
		model.inspect_screen(review_screen)
		investigation.enter_screen(model.current_id)

func add_action(parent: VBoxContainer, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func start_case() -> void:
	hud_hint_shown.clear()
	for window in [case_menu, pause_menu, message_dialog, notebook_dialog, accusation_dialog, pose_window, map_menu]:
		if is_instance_valid(window): window.hide()
	if painted and (model.data.get("mode", "") != "painted_investigation" or not guest_preview.error.is_empty() or FileAccess.get_sha256(GuestPreview.PATH) != str(model.data.get("source_guest_positions_sha256", ""))):
		investigation.data.clear()
		feedback = "Rebuild the painted investigation after importing guest positions."
		status_label.text = feedback
		queue_redraw()
		return
	var difficulty: String = ["normal", "easy", "hard"][difficulty_input.selected]
	var preview_case := killer_preview_remaining > 0 and random_case.button_pressed
	if preview_case:
		var target: String = ["Char", "Chris"][killer_preview_index % 2]
		var preview = preload("res://src/mystery/killer_preview_cases.gd")
		var voice: String = preview.VOICE_ORDER[killer_preview_index % preview.VOICE_ORDER.size()]
		var matching_seed: int = preview.find_seed(int(seed_input.value), target, difficulty, voice, Session.blocked_rooms(model.data))
		if matching_seed < 0:
			feedback = "Could not prepare the requested killer playtest case."
			return
		seed_input.value = matching_seed
	if not investigation.begin(int(seed_input.value), model.data, difficulty):
		feedback = "This layout cannot host a six-suspect case."
		return
	journal_state.reset() # player notes belong to one case
	CastPortrait.expressions.clear()
	var suspect_names: Array = []
	for person in range(6):
		suspect_names.append(str(investigation.data.cast[person]))
	journal.setup(journal_state, suspect_names, str(investigation.data.difficulty) == "easy")
	if preview_case:
		killer_preview_remaining -= 1
		killer_preview_index += 1
	model.reset()
	ambush_pending = false
	ambush_ending.clear()
	reveal.stop()
	if is_instance_valid(zoom) and zoom.playing:
		if zoom.finished.is_connected(finish_ambush): zoom.finished.disconnect(finish_ambush)
		zoom.skip()
	sting.stop()
	door_lock_audio.stop()
	win_audio.stop()
	selected_item_id = -1
	item_choice_ids.clear()
	investigation.enable_runtime(model.data)
	ending_shown = false
	talking_person = -1
	refresh_guests()
	investigator.reset(model.position)
	investigator_room = model.current_id
	feedback = "Find the glass, inspect objects and floors, and question guests."
	feedback_color = Color("dbe6ec")
	seed_input.get_line_edit().release_focus()
	queue_redraw()
	if opening_on_start: show_case_opening()

func show_case_opening() -> void:
	# The briefing receives only public victim identity, never the solution.
	var victim := str(investigation.data.cast[-1])
	var text := dialogue.system_line("case_opening", {"victim": victim}, investigation.data)
	say(text, true)
	message_dialog.title = "A murder in the mansion"
	message_dialog.ok_button_text = "Begin investigation"
	var asset: Dictionary = actor_art.asset(victim, "standing_idle_south") if ActorArt.ACTORS.has(victim) else actor_art.playtest_asset(victim)
	if not asset.is_empty():
		var portrait := AtlasTexture.new()
		portrait.atlas = asset.texture
		portrait.region = asset.bounds
		item_picture.texture = portrait
		item_picture.show()
	message_dialog.popup_centered(Vector2i(700, 330))

func modal_open() -> bool:
	return ambush_pending or (is_instance_valid(message_dialog) and (message_dialog.visible or notebook_dialog.visible or accusation_dialog.visible or pose_window.visible or case_menu.visible or pause_menu.visible or (is_instance_valid(map_menu) and map_menu.visible) or (is_instance_valid(item_choice) and item_choice.get_popup().visible)))

func _process(delta: float) -> void:
	reveal.advance(delta)
	if not ambush_pending: return
	ambush_elapsed += delta
	if not ambush_route.is_empty():
		var total := 0.0
		for index in range(1, ambush_route.size()): total += ambush_route[index - 1].distance_to(ambush_route[index])
		var distance := minf(1.0, ambush_elapsed / 0.9) * total
		ambush_position = ambush_route[0]
		for index in range(1, ambush_route.size()):
			var length := ambush_route[index - 1].distance_to(ambush_route[index])
			if distance <= length:
				ambush_position = ambush_route[index - 1].lerp(ambush_route[index], distance / maxf(length, 0.001))
				break
			distance -= length
			ambush_position = ambush_route[index]
	var sting_delay := maxf(0.9, door_lock_audio.stream.get_length())
	if ambush_elapsed >= sting_delay and not ambush_sting_started:
		ambush_sting_started = true
		if ambush_zoom_enabled and ambush_zoom_texture() != null:
			start_ambush_zoom()
		else:
			sting.play_sting()
			finish_ambush()
	queue_redraw()

func _exit_tree() -> void:
	for player in [sting, door_lock_audio, win_audio]:
		if is_instance_valid(player): player.stop()

func _input(event: InputEvent) -> void:
	if not reveal.is_active() or not message_dialog.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
		reveal.finish()
		get_viewport().set_input_as_handled()

func refresh_guests() -> void:
	guest_positions.clear()
	guest_facings.clear()
	for person in range(investigation.runtime.guests.size()):
		var guest: Dictionary = investigation.runtime.guests[person]
		guest_positions[person] = guest.position
		guest_facings[person] = guest.facing

func sync_world() -> void:
	var ending: Dictionary = investigation.observe_world(model.steps, model.current_id)
	refresh_guests()
	if not ending.is_empty():
		present_ending(ending, "standing_threaten_south")

func _physics_process(delta: float) -> void:
	if investigation.data.is_empty():
		return
	if investigation.active() and not modal_open() and not seed_input.get_line_edit().has_focus():
		super(delta)
	else:
		queue_redraw()
	sync_world()
	if investigator_room != model.current_id:
		investigator.reset(model.position)
		investigator_room = model.current_id
	else:
		investigator.update(model.position, delta if not modal_open() else 0.0)
	victim_label.text = "Victim: " + str(investigation.data.cast[-1])
	var held: Dictionary = investigation.held_item()
	status_label.text = "Magnifying glass: %s\nHolding: %s\nAccounts: %d / 6" % ["found" if investigation.progress.glass else "not found", str(held.name) if not held.is_empty() else "nothing", investigation.progress.heard.size()]
	refresh_item_choice()
	var near_person := nearby_guest()
	var near_object := near_item()
	context_label.text = "Explore the room."
	if model.transitions_locked:
		context_label.text = "Everyone is gathered. Look around, then make your accusation. Exits are locked."
	primary_button.text = "Interact   E"
	if near_person >= 0:
		var guest_name: String = investigation.data.cast[near_person]
		context_label.text = guest_name + (" is studying the floor." if investigation.runtime.guests[near_person].staring else " is nearby.")
		primary_button.text = "Speak   E"
	elif near_object:
		var item: Dictionary = current_item()
		context_label.text = current_item_name() + (" · " + str(item.kind) if not item.is_glass else "")
		primary_button.text = "Examine   E"
		if held.is_empty() or bool(item.is_glass):
			primary_button.text = "Take   E"
	var secret: Dictionary = model.data.secret
	if model.current_id == str(secret.entrance_room) and model.position.distance_to(model.secret_panel()) <= 26:
		context_label.text = "A seam in the panelling catches your eye."
		primary_button.text = "Examine wall   E"
	elif model.current_id == str(secret.screen) and (model.position.distance_to(model.secret_exit()) <= 24 or (secret.has("return_at") and model.position.distance_to(Layout.point(secret.return_at)) <= 24)):
		context_label.text = "An opening leads out of the passage."
		primary_button.text = "Use passage   E"
	if locked_exit_near():
		context_label.text = "The doors are locked until you make your accusation."
		primary_button.text = "Check door   E"
	item_button.disabled = not near_object or not investigation.active()
	take_button.disabled = not near_object or (not held.is_empty() and not bool(current_item().get("is_glass", false))) or not investigation.active()
	item_button.visible = near_object and primary_button.text != "Examine   E"
	take_button.visible = near_object and primary_button.text != "Take   E"
	drop_button.visible = not held.is_empty()
	drop_button.disabled = not investigation.active()
	accuse_button.disabled = held.is_empty() or not investigation.active()
	accuse_button.text = "Make an accusation" if investigation.progress.get("assembled", false) else "Gather everyone"
	primary_button.disabled = not investigation.active()
	feedback_text.text = feedback
	feedback_text.add_theme_color_override("default_color", feedback_color)
	warning_text.text = investigation.runtime.warning() if investigation.runtime.phase() != "calm" else "E Interact  ·  N Notebook  ·  Tab House map  ·  Esc Menu"
	warning_text.add_theme_color_override("default_color", phase_color())
	update_hud(near_person, near_object, held)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F11:
		WindowPresentation.toggle_fullscreen()
		return
	if event.physical_keycode == KEY_F3:
		diagnostics = not diagnostics
		show_navigation_markers = diagnostics
		developer_tools.visible = diagnostics
		return
	if modal_open(): return
	if seed_input.get_line_edit().has_focus():
		return
	if event.physical_keycode == KEY_N:
		show_notebook()
	elif event.physical_keycode == KEY_TAB:
		show_house_map()
	elif event.physical_keycode == KEY_ESCAPE:
		show_pause_menu()
	elif event.physical_keycode == KEY_E:
		interact_nearby()
	elif event.physical_keycode == KEY_Q:
		drop_nearby()
	elif event.physical_keycode == KEY_F:
		examine_floor() # identical to the Floor button

func interact_nearby() -> void:
	sync_world()
	if not investigation.active(): return
	if locked_exit_near():
		say("The doors are locked. Everyone will remain here until you make your accusation.")
		return
	var before_screen: String = model.current_id
	if model.interact_secret():
		sync_world()
		if before_screen == str(model.data.secret.entrance_room) and model.current_id == str(model.data.secret.screen):
			say(dialogue.system_line("secret_panel", {}, investigation.data, before_screen))
		return
	var person := nearby_guest()
	if person >= 0:
		ask_nearby()
	elif near_item():
		if investigation.held_item().is_empty() or bool(current_item().get("is_glass", false)):
			take_nearby()
		else:
			examine_nearby()
	else:
		examine_floor()

func locked_exit_near() -> bool:
	if not model.transitions_locked:
		return false
	for portal in model.screen().get("portals", []):
		if model.position.distance_to(Layout.point(portal.get("activation_at", portal.at))) <= 32:
			return true
	return false

func show_pause_menu() -> void:
	pause_menu.popup_centered()

func show_house_map() -> void:
	if not is_instance_valid(map_menu):
		map_menu = AcceptDialog.new()
		map_menu.title = "The house"
		map_menu.ok_button_text = "Return to investigation"
		add_child(map_menu)
		map_panel = HouseMap.new()
		map_menu.add_child(map_panel)
	map_panel.setup(model.data, model.current_id, model.visited)
	map_menu.popup_centered()

func current_item_name() -> String:
	var item := current_item()
	return str(item.get("name", ""))

func nearby_items() -> Array:
	var nearby: Array = investigation.all_items_in(model.current_id).filter(func(item): return model.position.distance_to(item.position) <= 40)
	nearby.sort_custom(func(a, b):
		var first: float = model.position.distance_squared_to(a.position)
		var second: float = model.position.distance_squared_to(b.position)
		return first < second or (is_equal_approx(first, second) and int(a.id) < int(b.id)))
	return nearby

func current_item() -> Dictionary:
	var nearby := nearby_items()
	for item in nearby:
		if int(item.id) == selected_item_id: return item
	return nearby[0] if not nearby.is_empty() else {}

func select_nearby_item(id: int) -> bool:
	for item in nearby_items():
		if int(item.id) == id:
			selected_item_id = id
			return true
	return false

func refresh_item_choice() -> void:
	var nearby := nearby_items()
	var ids: Array = nearby.map(func(item): return int(item.id))
	if ids != item_choice_ids:
		item_choice.clear()
		for item in nearby:
			item_choice.add_item(str(item.name))
			item_choice.set_item_metadata(item_choice.item_count - 1, int(item.id))
		item_choice_ids = ids
	item_choice.visible = nearby.size() > 1
	var item := current_item()
	if not item.is_empty():
		selected_item_id = int(item.id)
		item_choice.select(ids.find(selected_item_id))
	for candidate in nearby:
		investigation.observe_item(int(candidate.id))

func near_item() -> bool:
	sync_world()
	return not current_item().is_empty()

func nearby_guest() -> int:
	sync_world()
	var nearest := -1
	var distance := 44.0
	for person in guest_positions:
		if investigation.guest_screen(person) != model.current_id:
			continue
		var away: float = model.position.distance_to(guest_positions[person])
		if painted:
			var contact: Vector2 = investigation.runtime.guests[person].get("interaction_at", guest_positions[person])
			away = minf(away, model.position.distance_to(contact))
		if away < distance:
			nearest = int(person)
			distance = away
	return nearest

func phase_color() -> Color:
	var phase: String = investigation.runtime.phase()
	if phase == "ambush":
		return dialogue.color("runtime_text", "ambush_result", Color("e87970"))
	return dialogue.color("system", "warning_" + phase, Color("9bb8ca"))

func say_case(value: String, popup := false) -> void:
	say(value, popup, dialogue.color(investigation.last_message_group, investigation.last_message_key, Color("dbe6ec")))

func say(value: String, popup := false, color := Color("dbe6ec")) -> void:
	feedback = value
	feedback_color = color
	if popup:
		guest_portrait.hide()
		dialogue_new_case_button.hide()
		message_dialog.ok_button_text = "OK"
		message_dialog.title = "Investigation"
		item_picture.visible = false
		message_text.text = value
		message_text.add_theme_color_override("default_color", color)
		message_text.scroll_to_line(0)
		if painted:
			message_dialog.popup(Rect2i(20, 450, 690, 230))
		else:
			message_dialog.popup_centered()
		reveal.start(message_text)

func ask_nearby() -> void:
	var person := nearby_guest()
	if person < 0:
		var distant := -1
		var closest := INF
		for candidate in guest_positions:
			if investigation.guest_screen(candidate) == model.current_id:
				var away: float = model.position.distance_to(guest_positions[candidate])
				if away < closest:
					closest = away
					distant = int(candidate)
		if distant >= 0:
			say(dialogue.system_line("too_far_to_hear", {"speaker": str(investigation.data.cast[distant])}, investigation.data, "far_%d" % distant))
		else:
			say("There is nobody nearby to question.")
	else:
		talking_person = person
		var response: String = investigation.question(person)
		if investigation.active():
			var presentation := guest_presentation(person, true)
			# No stage-direction narration before answers (user, 2026-11-17): the voice tag in the dialogue is enough.
			say_case(response, true)
			message_dialog.title = "Questioning " + str(investigation.data.cast[person])
			show_guest_portrait(person, presentation)
		else:
			present_ending({"message": response}, "standing_threaten_south")

func show_guest_portrait(person: int, presentation: Dictionary) -> void:
	presentation = Presentation.conversation_portrait(presentation, str(investigation.data.personalities[person])) if investigation.active() else Presentation.portrait_presentation(presentation)
	var actor_name: String = investigation.data.cast[person]
	var pose: String = presentation.pose_id
	var asset: Dictionary = actor_art.asset(actor_name, pose) if ActorArt.ACTORS.has(actor_name) else actor_art.playtest_asset(actor_name)
	if asset.is_empty():
		guest_portrait.hide()
		return
	var reference: float = actor_art.standing_height(actor_name) if ActorArt.ACTORS.has(actor_name) else float(asset.reference_height) / float(asset.height_ratio)
	guest_portrait.show_asset(actor_name, pose, asset, reference, str(presentation.facing))

func examine_nearby() -> void:
	if near_item():
		var item := current_item()
		say_case(investigation.inspect_item(int(item.id)), true)
		item_picture.texture = item_art.detail(str(item.name))
		item_picture.visible = item_picture.texture != null
		message_dialog.title = str(item.name) + (" · " + str(item.kind) if not item.is_glass else "")
	else:
		say("Walk closer to the object to inspect it.")

func take_nearby() -> void:
	sync_world() # Charge prior walking under the previous held item.
	if near_item():
		say_case(investigation.take_item(int(current_item().id)))
		refresh_item_choice()
	else:
		say("Walk closer to the object to pick it up.")

func drop_nearby() -> void:
	sync_world()
	if not investigation.active(): return
	say_case(investigation.drop_item(model.position))
	refresh_item_choice()
	queue_redraw()

func examine_floor() -> void:
	sync_world()
	var result: String = investigation.inspect_floor()
	say_case(result, true)
	message_dialog.title = "Floor inspection"
	if investigation.progress.crime_room == investigation.progress.room and investigation.progress.wound != null:
		message_dialog.title += " · Wound kind: " + str(investigation.progress.wound)

func show_notebook() -> void:
	message_dialog.hide()
	sync_cast_expressions()
	var evidence: Array = []
	for key in investigation.progress.items_seen:
		var seen: Dictionary = investigation.progress.items_seen[key]
		if bool(seen.is_glass): continue
		var where := "carried" if bool(seen.held) else str(investigation.screen_names.get(seen.screen, seen.screen))
		evidence.append({"key": str(key), "name": str(seen.name), "kind": str(seen.kind), "location": where})
	journal.refresh_evidence(evidence)
	if str(investigation.data.difficulty) == "easy":
		journal.set_facts(investigation.notebook()) # Easy only: what the game itself recorded
	journal.rebuild()
	notebook_dialog.popup_centered()

func assemble_case() -> void:
	investigation.enter_screen(model.current_id)
	var already_assembled: bool = investigation.progress.get("assembled", false)
	if not investigation.assemble():
		say_case(investigation.last_message)
		return
	talking_person = -1
	if not already_assembled:
		model.position = Layout.point(investigation.progress.assembly_position)
		model.transitions_locked = true
		door_lock_audio.play()
		investigator.reset(model.position)
		investigator_room = model.current_id
		refresh_guests()
		say_case(investigation.assemble_message())
		queue_redraw()
		return
	message_dialog.hide()
	sync_cast_expressions()
	var names: Array = []
	for person in range(6):
		names.append(str(investigation.data.cast[person]))
	var gathered := str(investigation.screen_names.get(investigation.progress.get("assembly_room", model.current_id), model.screen().name))
	accusation_dialog.setup(names, gathered)
	accusation_dialog.popup_centered()

func sync_cast_expressions() -> void:
	# Portraits in the cards and the journal show a personality pose only for guests the player has already questioned.
	CastPortrait.expressions.clear()
	for key in investigation.progress.heard:
		var person := int(key)
		CastPortrait.expressions[str(investigation.data.cast[person])] = str(investigation.data.personalities[person])

func finish_accusation() -> void:
	var ending: Dictionary = investigation.accuse(accusation_dialog.selected_index())
	if ending.get("result") == "blocked":
		say(str(ending.message))
		return
	present_ending(ending)

func present_ending(ending: Dictionary, pose := "") -> void:
	if ending_shown or ambush_pending:
		return
	if pose.is_empty():
		pose = preload("res://src/mystery/killer_preview_cases.gd").confession_pose(str(investigation.data.personalities[investigation.data.culprit]), str(investigation.data.cast[investigation.data.culprit]))
	if ending.get("result", "") == "ambushed" and not ending.get("ambush_staged", false):
		begin_ambush(ending, pose)
		return
	ending_shown = true
	if ending.get("result", "") == "solved": win_audio.play()
	for window in [message_dialog, notebook_dialog, accusation_dialog, case_menu, pause_menu, map_menu, pose_window]:
		if is_instance_valid(window): window.hide()
	talking_person = -1
	var culprit_name: String = investigation.data.cast[investigation.data.culprit]
	say_case(str(ending.message), true)
	message_dialog.title = "Case conclusion · " + culprit_name
	message_dialog.ok_button_text = "Return to house"
	dialogue_new_case_button.show()
	if ActorArt.ACTORS.has(culprit_name):
		show_guest_portrait(int(investigation.data.culprit), {"pose_id": pose, "posture": "standing", "activity": "talk", "facing": "south"})
	else:
		show_guest_portrait(int(investigation.data.culprit), {"pose_id": "standing_idle_south", "posture": "standing", "activity": "idle", "facing": "south"})
	queue_redraw()

func begin_ambush(ending: Dictionary, pose: String) -> void:
	for window in [message_dialog, notebook_dialog, accusation_dialog, case_menu, pause_menu, map_menu, pose_window]:
		if is_instance_valid(window): window.hide()
	ambush_pending = true
	ambush_elapsed = 0.0
	ambush_sting_started = false
	door_lock_audio.play()
	ambush_ending = ending.duplicate(true)
	ambush_pose = pose
	var guest: Dictionary = investigation.runtime.guests[int(investigation.data.culprit)]
	ambush_start = guest.get("interaction_at", guest.position)
	ambush_position = ambush_start
	ambush_route = preload("res://src/blockout/ambush_approach.gd").route(model, model.current_id, ambush_start, model.position)
	if not ambush_route.is_empty(): ambush_position = ambush_route[0]
	queue_redraw()

func ambush_zoom_texture() -> Texture2D:
	# The murderer's own approved art: the reveal/threat pose when one exists, otherwise the best available portrait.
	var culprit := int(investigation.data.culprit)
	var actor_name := str(investigation.data.cast[culprit])
	var record: Dictionary = actor_art.asset(actor_name, ambush_pose) if ActorArt.ACTORS.has(actor_name) else actor_art.playtest_asset(actor_name)
	if record.is_empty() and ActorArt.ACTORS.has(actor_name):
		record = actor_art.asset(actor_name, "standing_idle_south")
	if record.is_empty() or not record.has("texture") or not record.has("bounds"): return null
	var bounds: Rect2 = record.bounds
	var crop := AtlasTexture.new() # head and torso only, so the zoom is a face, not a full-length figure
	crop.atlas = record.texture
	crop.region = Rect2(bounds.position, Vector2(bounds.size.x, bounds.size.y * 0.55))
	return crop

func start_ambush_zoom() -> void:
	var texture := ambush_zoom_texture()
	var overrides := ambush_zoom_overrides.duplicate()
	zoom.finished.connect(finish_ambush, CONNECT_ONE_SHOT)
	zoom.play(texture, overrides)
	var config: Dictionary = zoom.config()
	# The sting lands as the face hits the screen.
	get_tree().create_timer(float(config.anticipation) + float(config.zoom_duration) * 0.8).timeout.connect(func():
		if is_instance_valid(sting) and ambush_pending: sting.play_sting())

func finish_ambush() -> void:
	if not ambush_pending: return
	ambush_pending = false
	var ending := ambush_ending.duplicate(true)
	ending.ambush_staged = true
	if not ambush_route.is_empty(): ambush_position = ambush_route[-1]
	present_ending(ending, ambush_pose)

func guest_draw_position(person: int) -> Vector2:
	if (ambush_pending or (ending_shown and investigation.progress.outcome == "ambushed")) and person == int(investigation.data.culprit):
		return ambush_position
	return investigation.runtime.guests[person].position

func build_pose_viewer() -> void:
	pose_window = Window.new()
	pose_window.title = "Approved Char and Chris poses"
	pose_window.size = Vector2i(780, 640)
	pose_window.transient = true
	pose_window.exclusive = true
	pose_window.hide()
	pose_window.close_requested.connect(pose_window.hide)
	add_child(pose_window)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_constant_override("separation", 8)
	pose_window.add_child(panel)
	var row := HBoxContainer.new()
	pose_controls = row
	panel.add_child(row)
	art_actor = OptionButton.new()
	art_actor.add_item("Char")
	art_actor.add_item("Chris")
	art_actor.custom_minimum_size.x = 140
	art_actor.item_selected.connect(func(unused): populate_poses())
	row.add_child(art_actor)
	art_pose = OptionButton.new()
	art_pose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_pose.item_selected.connect(func(unused): update_pose_preview())
	row.add_child(art_pose)
	art_preview = TextureRect.new()
	art_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(art_preview)
	art_note = Label.new()
	art_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	art_note.add_theme_font_size_override("font_size", 13)
	panel.add_child(art_note)
	var close_button := Button.new()
	pose_close_button = close_button
	close_button.text = "Return to investigation"
	close_button.pressed.connect(pose_window.hide)
	panel.add_child(close_button)
	ending_new_case_button = Button.new()
	ending_new_case_button.text = "Start a new mystery"
	ending_new_case_button.visible = false
	ending_new_case_button.pressed.connect(func(): pose_window.hide(); case_menu.popup_centered())
	panel.add_child(ending_new_case_button)
	populate_poses()

func show_pose_viewer() -> void:
	pose_window.title = "Char / Chris pose viewer"
	pose_controls.show()
	ending_new_case_button.hide()
	pose_close_button.text = "Return to investigation"
	pose_window.popup_centered()

func populate_poses(preferred := "standing_idle_south") -> void:
	art_pose.clear()
	for record in actor_art.records(art_actor.get_item_text(art_actor.selected)):
		art_pose.add_item(str(record.pose_id) + " / " + str(record.variant_id))
		art_pose.set_item_metadata(art_pose.item_count - 1, record)
		if record.pose_id == preferred:
			art_pose.select(art_pose.item_count - 1)
	update_pose_preview()

func update_pose_preview() -> void:
	var asset: Dictionary = actor_art.texture_record(art_pose.get_item_metadata(art_pose.selected))
	if asset.is_empty():
		return
	art_preview.texture = asset.texture
	art_note.add_theme_color_override("font_color", Color("dbe6ec"))
	art_note.text = "%s — 81 approved poses. Original PNG; preview only. Furniture contact and runtime fit remain pending.\n%s" % [art_actor.get_item_text(art_actor.selected), asset.record.export]

func guest_presentation(person: int, talking := false) -> Dictionary:
	return Presentation.presentation(investigation.runtime.guests[person], str(investigation.data.personalities[person]), model.position, talking, str(investigation.data.cast[person]))

func draw_case_guest(person: int) -> void:
	var guest: Dictionary = investigation.runtime.guests[person]
	var at: Vector2 = guest_draw_position(person)
	var name: String = investigation.data.cast[person]
	var presentation := guest_presentation(person, person == talking_person)
	if (ambush_pending or (ending_shown and investigation.progress.outcome == "ambushed")) and person == int(investigation.data.culprit):
		presentation = {"pose_id": "standing_threaten_south", "posture": "standing", "facing": "south"}
	if ActorArt.ACTORS.has(name):
		if painted and presentation.posture == "seated":
			# Use the same measured seat contact and source scale as the editor.
			for pose in guest_preview.catalog.get(name, []):
				if pose.pose_id == presentation.pose_id:
					var texture: Texture2D = guest_preview.texture(pose)
					if texture != null:
						draw_texture_rect(texture, guest_preview.render_rect({"at": [at.x, at.y]}, pose), false)
					return
		var asset: Dictionary = actor_art.asset(name, str(presentation.pose_id))
		if not asset.is_empty():
			var factor: float = actor_art.adult_height / actor_art.standing_height(name)
			var bounds: Rect2 = asset.bounds
			draw_texture_rect_region(asset.texture, Rect2(at + (bounds.position - asset.pivot) * factor, bounds.size * factor), bounds)
			return
	var temporary: Dictionary = actor_art.playtest_asset(name)
	if not temporary.is_empty():
		var factor: float = actor_art.adult_height * temporary.height_ratio / temporary.reference_height
		var bounds: Rect2 = temporary.bounds
		draw_texture_rect_region(temporary.texture, Rect2(at + (bounds.position - temporary.pivot) * factor, bounds.size * factor), bounds)
	else:
		draw_circle(at, 7, GUEST_COLOR)
		draw_circle(at, 9, GUEST_COLOR, false, 1)

func draw_case_population() -> void:
	var commands: Array = []
	commands.append({"type": "investigator", "depth": model.position.y})
	for item in investigation.all_items_in(model.current_id):
		commands.append({"type": "item", "depth": item.position.y, "item": item})
	for person in guest_positions:
		if investigation.guest_screen(person) == model.current_id:
			commands.append({"type": "guest", "depth": guest_draw_position(int(person)).y, "person": person})
	if painted:
		if guest_preview.mask_room != model.current_id:
			guest_preview.mask_textures.clear()
			guest_preview.mask_room = model.current_id
		for mask in guest_preview.masks(model.current_id):
			commands.append({"type": "mask", "depth": float(mask.depth_y), "mask": mask})
	commands.sort_custom(func(a, b): return a.depth < b.depth or (a.depth == b.depth and a.type != "mask" and b.type == "mask"))
	for command in commands:
		if command.type == "guest":
			draw_case_guest(int(command.person))
		elif command.type == "investigator":
			investigator.draw_on(self, model.position)
		elif command.type == "item":
			item_art.draw_on(self, str(command.item.name), command.item.position)
		else:
			var background := room_background(model.screen())
			if background != null:
				var texture: Texture2D = guest_preview.mask_texture(command.mask, background)
				if texture != null:
					draw_texture_rect(texture, Rect2(0, 0, 480, 360), false)
	for person in guest_positions:
		if investigation.guest_screen(person) != model.current_id:
			continue
		var guest: Dictionary = investigation.runtime.guests[person]
		var at: Vector2 = guest.position
		if diagnostics and guest.staring:
			var floor_at: Vector2 = guest.get("interaction_at", at)
			draw_circle(floor_at + Vector2(0, 6), 3, ITEM_COLOR, false, 1)
		if diagnostics or guest.staring or model.position.distance_to(at) < 50:
			var caption := str(investigation.data.cast[person]) + (" · studying the floor" if guest.staring else "")
			var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			var caption_at := at + Vector2(10, 12)
			if caption_at.x + width > 476: caption_at.x = maxf(4, at.x - width - 10)
			text(caption_at, caption, Color("d9d1bb"), 9)

func item_present() -> bool:
	return not investigation.all_items_in(model.current_id).is_empty()

func _draw() -> void:
	super()
	if investigation.data.is_empty() or font == null:
		return
	if diagnostics:
		text(Vector2(size.x - 260, 76), "Case %s / %d steps" % [investigation.data.seed, model.steps], ITEM_COLOR, 12)
	draw_set_transform(room_origin, 0, Vector2.ONE * room_scale)
	draw_case_population()
	if diagnostics:
		for item in investigation.all_items_in(model.current_id):
			text(item.position + Vector2(8, -7), str(item.name), ITEM_COLOR, 9)
	draw_set_transform(Vector2.ZERO)

func on_hud_action(id: String) -> void:
	match id:
		"interact": interact_nearby()
		"examine": examine_nearby()
		"take": take_nearby()
		"drop": drop_nearby()
		"floor": examine_floor()
		"notebook": show_notebook()
		"map": show_house_map()
		"accuse": assemble_case()
		"menu": show_pause_menu()

func hud_label(button: Button) -> String:
	return button.text.split("   ")[0].strip_edges()

func update_hud(near_person: int, near_object: bool, held: Dictionary) -> void:
	if not is_instance_valid(hud) or investigation.data.is_empty(): return
	var live: bool = investigation.active() and not modal_open() and not ambush_pending
	hud.set_room(str(model.screen().name))
	hud.set_inventory(bool(investigation.progress.glass), str(held.get("name", "")))
	var phase: String = investigation.runtime.phase()
	hud.set_phase(phase if phase in ["calm", "suspicious", "stalking"] else "stalking", phase_color())
	var assembled: bool = bool(investigation.progress.get("assembled", false))
	hud.set_actions({
		"interact": {"visible": true, "enabled": live, "label": hud_label(primary_button)},
		"examine": {"visible": item_button.visible, "enabled": live and not item_button.disabled, "label": "Examine"},
		"take": {"visible": take_button.visible, "enabled": live and not take_button.disabled, "label": "Take"},
		"drop": {"visible": not held.is_empty(), "enabled": live, "label": "Drop"},
		"floor": {"visible": bool(investigation.progress.glass), "enabled": live, "label": "Floor"},
		"notebook": {"visible": true, "enabled": not ambush_pending, "label": "Notebook"},
		"map": {"visible": true, "enabled": not ambush_pending, "label": "Map"},
		"accuse": {"visible": not held.is_empty() or assembled, "enabled": live and not accuse_button.disabled, "label": "Accuse" if assembled else "Gather everyone"},
		"menu": {"visible": true, "enabled": true, "label": "Menu"},
	})
	hint_for_state(near_object)

func hint_once(key: String, text: String) -> void:
	if hud_hint_shown.has(key): return
	hud_hint_shown[key] = true
	hud.show_hint(text)

func hint_for_state(near_object: bool) -> void:
	# Short, one-time onboarding hints; they never block input and reset with each new case.
	if modal_open() or ambush_pending or not investigation.active(): return
	if bool(investigation.progress.glass) and not hud_hint_shown.has("glass_cleared"):
		hud_hint_shown["glass_cleared"] = true
		hud.clear_hint() # the find-the-glass hint is over once the glass is in hand
	if not bool(investigation.progress.glass):
		if near_object and bool(current_item().get("is_glass", false)): hint_once("glass", "A magnifying glass. Take it: you keep it for the whole case.")
		else: hint_once("find_glass", "Look for the magnifying glass. Questioning guests costs nothing.")
	elif near_object and investigation.progress.items_seen.size() == 0: hint_once("inspect", "Examine objects and floors with the glass. Stains and wounds are clues, not proof.")
	elif investigation.progress.heard.size() >= 2: hint_once("notebook", "Record what you learn in the notebook (N).")
	elif bool(investigation.progress.get("assembled", false)): hint_once("accuse", "Everyone is gathered. Choose who you accuse.")
