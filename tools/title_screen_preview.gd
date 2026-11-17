extends SceneTree

const Title := preload("res://src/blockout/title_screen.gd")
## Renders the title screen into test-results/screenshots/.

const OUT := "res://test-results/screenshots/"
const BG := "res://assets/rooms/house-02/furnishing-review/library-v1.png"


func _initialize() -> void:
	_run.call_deferred()


func _make(size: Vector2i, tex: Texture2D) -> Array:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var t = Title.new()
	vp.add_child(t)
	t.set_background(tex)
	t.open()
	t.set_cast_preview(["Char", "Chris", "Justin", "Danny", "Gage", "Robbie", "Kwinn"], 4242)
	return [vp, t]


func _save(vp: SubViewport, name: String) -> void:
	for i in 8:
		await process_frame
	var img := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + name))


func _run() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(BG))
	var tex: Texture2D = ImageTexture.create_from_image(img) if img else null
	var pair := _make(Vector2i(960, 720), tex)
	var t = pair[1]
	await _save(pair[0], "title_menu.png")
	t.btn_start.pressed.emit()
	await _save(pair[0], "title_setup.png")
	t.radio_names.button_pressed = true
	var names := ["Eleanor Vale", "Mary-Jane O'Neil", "Dr. Hargrove", "Ada", "Bertram", "Cordelia", "Mr. Finch"]
	for i in 7:
		t.name_edits[i].text = names[i]
	t.name_edits[0].text_changed.emit(names[0])
	await _save(pair[0], "title_setup_names.png")
	t.btn_setup_back.pressed.emit()
	t.btn_howto.pressed.emit()
	await _save(pair[0], "title_howto.png")
	pair[0].queue_free()
	var wide := _make(Vector2i(1600, 900), tex)
	await _save(wide[0], "title_menu_wide.png")
	print("preview saved")
	quit()
