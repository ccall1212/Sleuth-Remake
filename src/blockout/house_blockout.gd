extends Control
## Standalone map review. The mansion and mystery lab are not modified.

const Layout = preload("res://src/blockout/house_layout.gd")
const RoomTexture = preload("res://src/blockout/approved_room_texture.gd")
const GuestPreview = preload("res://src/blockout/house_guest_preview.gd")
const ORIGIN := Vector2(20, 120)
const MAP_SCALE := 1.45
const SPEED := 100.0
const FLOOR_COLOR := Color("263c48")
const DOOR_COLOR := Color("57d5e0")
const GUEST_COLOR := Color("ce9df2")
const ITEM_COLOR := Color("f0c267")
@export var layout_path := Layout.DEFAULT_PATH
var model = Layout.new()
var font: Font
var picker: OptionButton
var details: Label
var labels := true
var capture_path := ""
var review_screen := ""
var sidebar: VBoxContainer
var show_guest_spots := true
var show_item_slots := true
var painted := false
var collision_overlay := false
var background_cache: Dictionary = {}
var guest_preview = GuestPreview.new()
var show_preview_guests := true
var show_navigation_markers := true
var show_player_marker := true

func _ready() -> void:
	font = ThemeDB.fallback_font
	var path := layout_path
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--layout="):
			path = arg.trim_prefix("--layout=")
		if arg.begins_with("--blockout-capture="):
			capture_path = arg.trim_prefix("--blockout-capture=")
		if arg.begins_with("--blockout-screen="):
			review_screen = arg.trim_prefix("--blockout-screen=")
	if not model.load_layout(path):
		push_error(model.error)
		set_physics_process(false)
		return
	if model.screens.has(review_screen):
		model.inspect_screen(review_screen)
	painted = model.data.get("presentation", "") == "approved_painted_walkthrough"
	if painted:
		labels = false
		show_guest_spots = false
		show_item_slots = false
		DisplayServer.window_set_title("House 02 — Painted walkthrough")
		if not guest_preview.load_placements(model.data):
			push_error(guest_preview.error)
	sidebar = VBoxContainer.new()
	sidebar.position = Vector2(742, 122)
	sidebar.size = Vector2(198, 540)
	sidebar.add_theme_constant_override("separation", 8 if painted else 14)
	add_child(sidebar)
	var heading := Label.new()
	heading.text = "INSPECT A SCREEN"
	heading.add_theme_color_override("font_color", Color("92b6c9"))
	sidebar.add_child(heading)
	picker = OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	for id in model.screens:
		picker.add_item(str(model.screens[id].name))
		picker.set_item_metadata(picker.item_count - 1, id)
	picker.item_selected.connect(func(index: int): model.inspect_screen(str(picker.get_item_metadata(index))))
	sidebar.add_child(picker)
	var jump_note := Label.new()
	jump_note.text = "Inspection jumps reset\nsteps and entry counts."
	jump_note.add_theme_font_size_override("font_size", 13)
	sidebar.add_child(jump_note)
	jump_note.visible = not painted
	var reset_button := Button.new()
	reset_button.text = "Restart at Front Entry   R"
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(model.reset)
	sidebar.add_child(reset_button)
	reset_button.visible = not painted
	var toggle := CheckButton.new()
	toggle.text = "Show labels"
	toggle.button_pressed = labels
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(value: bool): labels = value)
	sidebar.add_child(toggle)
	if painted:
		var collision_toggle := CheckButton.new()
		collision_toggle.text = "Show collision"
		collision_toggle.focus_mode = Control.FOCUS_NONE
		collision_toggle.toggled.connect(func(value: bool): collision_overlay = value)
		sidebar.add_child(collision_toggle)
		build_guest_controls()
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(198, 140 if painted else 260)
	details.add_theme_font_size_override("font_size", 14)
	sidebar.add_child(details)
	if not capture_path.is_empty():
		call_deferred("capture_review")

func _physics_process(delta: float) -> void:
	if model.current_id.is_empty():
		return
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	model.walk(direction.normalized() * SPEED * minf(delta, 0.1), delta)
	for index in range(picker.item_count):
		if picker.get_item_metadata(index) == model.current_id:
			picker.select(index)
	details.text = "LEGEND\nWhite  You\nCyan  Doorway\nGold  Item slot\nPurple  Guest spot\nBrown  Furniture\n\nRole: %s\nVisited: %d / %d\nLast screen leg: %d steps\n\nWalk into cyan doors.\nE: secret panel / exit\n\nNo danger clock yet." % [str(model.screen().role), model.visited.size(), model.screens.size(), model.last_trip_steps]
	if painted:
		details.text = "%d saved spots / %d masks\nin this room.\n\nWhite: your feet\nCyan: doorway\nE: hidden panel / exit\n\nPreview choices do not\nchange your saved spots.\nClues are not placed yet." % [guest_preview.spots(model.current_id).size(), guest_preview.masks(model.current_id).size()]
		if not guest_preview.error.is_empty():
			details.text = guest_preview.error
	queue_redraw()

func build_guest_controls() -> void:
	for setting in [["Show guest previews", "guests"], ["Furniture masks", "masks"], ["Show guest anchors", "anchors"]]:
		var toggle := CheckButton.new()
		toggle.text = setting[0]
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.button_pressed = setting[1] != "anchors"
		var key: String = setting[1]
		toggle.toggled.connect(func(value: bool):
			match key:
				"guests": show_preview_guests = value
				"masks": guest_preview.show_masks = value
				"anchors": guest_preview.show_anchors = value
		)
		sidebar.add_child(toggle)
	var actors := OptionButton.new()
	actors.focus_mode = Control.FOCUS_NONE
	for title in ["Saved characters", "Char", "Chris"]:
		actors.add_item(title)
	actors.item_selected.connect(func(index: int): guest_preview.actor_override = "" if index == 0 else actors.get_item_text(index))
	sidebar.add_child(actors)
	var activities := OptionButton.new()
	activities.focus_mode = Control.FOCUS_NONE
	for activity in ["", "idle", "read", "look_up", "look_down", "sleep"]:
		activities.add_item("Saved activities" if activity.is_empty() else activity.replace("_", " ").capitalize())
		activities.set_item_metadata(activities.item_count - 1, activity)
	activities.item_selected.connect(func(index: int): guest_preview.activity_override = str(activities.get_item_metadata(index)))
	sidebar.add_child(activities)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			model.reset()
		elif event.physical_keycode == KEY_E:
			model.interact_secret()

func text(at: Vector2, value: String, color := Color("e4edf2"), font_size := 15) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func marker(at: Vector2, value: String, color: Color) -> void:
	draw_circle(at, 5, color)
	if labels:
		text(at + Vector2(8, 3), value, color, 9)

func room_background(screen: Dictionary) -> Texture2D:
	var path := str(screen.get("background", ""))
	if path.is_empty():
		return null
	if background_cache.has(path):
		return background_cache[path]
	var texture: Texture2D = RoomTexture.load_approved(path, str(screen.get("background_sha256", "")))
	if texture == null:
		push_error("Could not load approved room background: " + path)
		return null
	if background_cache.size() >= 2:
		background_cache.clear()
	background_cache[path] = texture
	return texture

func _draw() -> void:
	if font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("101b26"))
	text(Vector2(22, 31), "HOUSE 02 / PAINTED WALKTHROUGH" if painted else "HOUSE 02 / WALKABLE BLOCKOUT", Color("9bb8ca"), 16)
	if model.current_id.is_empty():
		text(Vector2(22, 80), model.error, Color.SALMON, 16)
		return
	text(Vector2(22, 65), str(model.screen().name), Color.WHITE, 27)
	text(Vector2(22, 94), "WASD / arrows to walk  ·  E interact  ·  R restart", Color("9bb8ca"), 14)
	text(Vector2(498, 48), "%d STEPS" % model.steps, ITEM_COLOR, 27)
	text(Vector2(498, 73), "%d room entries  ·  %.0f px walked" % [model.room_entries, model.walked_pixels], Color("b9cbd6"), 13)
	text(Vector2(498, 95), "%d logical px = 1 walking step" % int(model.data.px_per_step), Color("9bb8ca"), 13)
	draw_set_transform(ORIGIN, 0, Vector2.ONE * MAP_SCALE)
	draw_rect(Rect2(0, 0, 480, 360), Color("172630"))
	var screen: Dictionary = model.screen()
	var background: Texture2D = room_background(screen)
	if background != null:
		draw_texture_rect(background, Rect2(0, 0, 480, 360), false)
		if painted and show_preview_guests:
			guest_preview.draw_on(self, model.current_id, background)
	if painted and collision_overlay:
		for polygon in model.floor_polygons.get(model.current_id, []):
			draw_colored_polygon(polygon, Color(0.2, 0.8, 0.9, 0.18))
		for raw in screen.get("door_access_regions", []):
			draw_rect(Layout.rectangle(raw), Color(0.2, 0.8, 0.9, 0.18))
		for raw in screen.get("obstacles", []):
			draw_rect(Layout.rectangle(raw), Color(1, 0.25, 0.15, 0.4))
	if background == null:
		for raw in screen.get("walk_regions", []):
			draw_rect(Layout.rectangle(raw), FLOOR_COLOR)
			draw_rect(Layout.rectangle(raw), Color("506878"), false, 1)
		for x in range(0, 481, int(model.data.px_per_step)):
			draw_line(Vector2(x, 0), Vector2(x, 360), Color(0.4, 0.6, 0.7, 0.08))
		for y in range(0, 361, int(model.data.px_per_step)):
			draw_line(Vector2(0, y), Vector2(480, y), Color(0.4, 0.6, 0.7, 0.08))
		var kinds: Array = screen.get("obstacle_kinds", [])
		for index in range(screen.get("obstacles", []).size()):
			var r: Rect2 = Layout.rectangle(screen.obstacles[index])
			draw_rect(r, Color("765c48"))
			draw_rect(r, Color("b3916b"), false, 0.8)
			if labels and index < kinds.size() and r.size.x >= 36:
				text(r.position + Vector2(3, 11), str(kinds[index]), Color("f6dfc6"), 8)
	var spots: Array = screen.get("guest_spots", []) if show_guest_spots else []
	var spot_kinds: Array = screen.get("guest_spot_kinds", [])
	var facings: Array = screen.get("guest_spot_facing", [])
	for index in range(spots.size()):
		var at: Vector2 = Layout.point(spots[index])
		marker(at, str(spot_kinds[index]) if index < spot_kinds.size() else "guest", GUEST_COLOR)
		if index < facings.size():
			var allowed: Array = facings[index] if facings[index] is Array else (["north", "east", "south", "west"] if facings[index] == "any" else [facings[index]])
			for facing in allowed:
				var vector: Vector2 = {"north": Vector2.UP, "east": Vector2.RIGHT, "south": Vector2.DOWN, "west": Vector2.LEFT}.get(facing, Vector2.ZERO)
				draw_line(at + vector * 6, at + vector * 11, GUEST_COLOR, 1)
	if screen.has("item_slot") and show_item_slots:
		var at: Vector2 = Layout.point(screen.item_slot)
		draw_rect(Rect2(at - Vector2.ONE * 4, Vector2.ONE * 8), ITEM_COLOR)
		if labels:
			text(at + Vector2(7, -4), "item", ITEM_COLOR, 9)
	for portal in screen.get("portals", []):
		if not show_navigation_markers:
			continue
		var at: Vector2 = Layout.point(portal.at)
		var facing: Vector2 = Layout.point(portal.facing)
		var tangent := facing.orthogonal()
		draw_line(at - tangent * 11, at + tangent * 11, DOOR_COLOR, 4)
		draw_line(at - facing * 12, at + facing * 5, DOOR_COLOR, 1)
		if labels:
			var title := str(model.screens[portal.target].name)
			var label_at := at + Vector2(8, -8)
			if at.x > 300:
				label_at.x = at.x - font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x - 8
			if at.y < 35:
				label_at.y = at.y + 18
			text(label_at, title, DOOR_COLOR, 9)
	var secret: Dictionary = model.data.get("secret", {})
	if show_navigation_markers and model.current_id == secret.get("entrance_room"):
		var panel: Vector2 = model.secret_panel()
		draw_rect(Rect2(panel - Vector2(9, 2), Vector2(18, 5)), GUEST_COLOR)
		text(panel + Vector2(-34, -9), "Secret panel · E", GUEST_COLOR, 9)
	if show_navigation_markers and model.current_id == secret.get("screen"):
		marker(model.secret_exit(), "Exit · E", DOOR_COLOR)
	var player: Vector2 = model.position
	if show_player_marker:
		draw_circle(player + Vector2(0, 2), 8, Color("101b26"))
		draw_circle(player, 6, Color("f6f5e9"))
		draw_circle(player, 8, Color("efffff"), false, 1)
	draw_set_transform(Vector2.ZERO)
	text(Vector2(22, 675), model.notice, Color("c9dbe4"), 14)
	text(Vector2(22, 703), "PLACEMENT PREVIEW / Saved guest spots and furniture masks / Case casting and clues come next." if painted else "BLOCKOUT ONLY  /  Door positions and floor geometry come from the layout file; no painted room art.", Color("7996a9"), 12)

func capture_review() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	print("BLOCKOUT_CAPTURE " + capture_path)
	get_tree().quit()
