extends SceneTree

const Hud := preload("res://src/blockout/game_hud.gd")
## Renders the HUD over a stand-in room image into test-results/screenshots/.

const OUT := "res://test-results/screenshots/"


func _initialize() -> void:
	_run.call_deferred()


func _find_png() -> String:
	var dir := "res://assets/rooms/house-02/furnishing-review/"
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			return dir + f
	return ""


func _shot(img: Image, size: Vector2i, name: String, phase: String, col: Color, held: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var fill := ColorRect.new()
	fill.color = Color("0b0d10")
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(fill)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(tr)
	var hud := Hud.new()
	vp.add_child(hud)
	hud.set_room("Library")
	hud.set_inventory(true, held)
	hud.set_phase(phase, col)
	hud.set_actions({
		"interact": {"visible": true, "enabled": true},
		"examine": {"visible": true, "enabled": true},
		"take": {"visible": false, "enabled": true},
		"drop": {"visible": not held.is_empty(), "enabled": true},
		"floor": {"visible": true, "enabled": true},
		"notebook": {"visible": true, "enabled": true},
		"map": {"visible": true, "enabled": true},
		"accuse": {"visible": true, "enabled": true, "label": "Gather everyone"},
		"menu": {"visible": true, "enabled": true},
	})
	hud.show_hint("Something glints beneath the desk.", 60.0)
	for i in 12:
		await process_frame
	var out := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	out.save_png(ProjectSettings.globalize_path(OUT + name))
	vp.queue_free()
	await process_frame


func _run() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(_find_png()))
	var stalk := Color("FF9F40")
	await _shot(img, Vector2i(960, 720), "hud_960x720.png", "Stalking", stalk, "Brass candlestick")
	await _shot(img, Vector2i(1280, 720), "hud_1280x720.png", "Stalking", stalk, "Brass candlestick")
	await _shot(img, Vector2i(1920, 1080), "hud_1920x1080.png", "Stalking", stalk, "Brass candlestick")
	await _shot(img, Vector2i(1280, 720), "hud_calm.png", "Calm", Color("9bb8ca"), "")
	await _shot(img, Vector2i(1280, 720), "hud_suspicious.png", "Suspicious", Color("FFD84A"), "")
	print("preview saved")
	quit()
