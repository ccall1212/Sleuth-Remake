extends SceneTree

const Title := preload("res://src/blockout/title_screen.gd")

var checks := 0
var failures: Array = []
var emitted: Array = []
var quit_count := 0
const CAST := ["Char", "Chris", "Justin", "Danny", "Gage", "Robbie", "Kwinn"]
var setup_count := 0
var reroll_count := 0


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func _initialize() -> void:
	_run.call_deferred()


func _fresh() -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var t = Title.new()
	vp.add_child(t)
	emitted.clear()
	t.start_requested.connect(func(c: Dictionary) -> void: emitted.append(c))
	t.quit_requested.connect(func() -> void: quit_count += 1)
	t.setup_opened.connect(func() -> void: setup_count += 1)
	t.cast_reroll_requested.connect(func() -> void: reroll_count += 1)
	t.open()
	t.set_cast_preview(CAST, 4242)
	return [vp, t]


func _fill(t, names: Array) -> void:
	for i in 7:
		t.name_edits[i].text = names[i]
	t.name_edits[0].text_changed.emit(t.name_edits[0].text)


func _run() -> void:
	var pair := _fresh()
	var t = pair[1]
	await process_frame
	ok(t != null, "builds")
	ok(t.mouse_filter == Control.MOUSE_FILTER_STOP, "mouse filter stop")
	ok(t.current_screen() == "menu", "open shows menu")
	t.btn_start.pressed.emit()
	ok(setup_count == 1, "setup_opened")
	ok(t.card_portraits.size() == 7, "7 cards")
	ok(t.card_portraits[0].texture != null and t.card_portraits[2].texture != null, "portraits Char and Justin")
	ok(t.card_name_labels[2].text == "Justin" and t.card_name_labels[2].is_visible_in_tree() and not t.name_edits[2].visible, "default shows read-only names")
	t.btn_reroll.pressed.emit()
	ok(reroll_count == 1, "reroll emitted")
	ok(t.current_screen() == "setup", "start -> setup")
	ok(t.btn_begin.disabled == false, "begin enabled in default mode")
	t.btn_begin.pressed.emit()
	ok(emitted.size() == 1 and emitted[0]["difficulty"] == "normal" and emitted[0]["custom_names"] == [], "default config: %s" % [emitted])
	ok(emitted[0]["seed"] == 4242, "seed in config")

	# difficulty
	emitted.clear()
	t.diff_buttons["easy"].button_pressed = true
	t.btn_begin.pressed.emit()
	ok(emitted.size() == 1 and emitted[0]["difficulty"] == "easy", "easy emitted")
	emitted.clear()
	t.diff_buttons["hard"].button_pressed = true
	t.btn_begin.pressed.emit()
	ok(emitted.size() == 1 and emitted[0]["difficulty"] == "hard", "hard emitted")

	# personalized
	emitted.clear()
	t.radio_names.button_pressed = true
	await process_frame
	ok(t.name_edits.size() == 7, "7 line edits")
	ok(t.name_edits[0].is_visible_in_tree(), "edits visible in personalized mode")
	ok(t.btn_begin.disabled, "begin disabled until valid")
	ok(t.error_label.text == "", "no error before edit")
	for i in 7:
		ok(t.name_edits[i].placeholder_text == CAST[i], "placeholder %d" % i)
		ok(t.name_edits[i].is_visible_in_tree() and not t.card_name_labels[i].visible, "edit mode %d" % i)
	t.name_edits[1].text = "x{"
	t.name_edits[1].text_changed.emit("x{")
	ok(t.error_label.text != "", "error shown after edit")
	t.name_edits[1].text = ""
	var names := [" Ann ", "Bob", "Cy", "Di", "Ed", "Flo", "Gus"]
	_fill(t, names)
	ok(not t.btn_begin.disabled, "begin enabled when valid")
	t.btn_begin.pressed.emit()
	ok(emitted.size() == 1 and emitted[0]["custom_names"] == ["Ann", "Bob", "Cy", "Di", "Ed", "Flo", "Gus"], "names emitted trimmed: %s" % [emitted])
	_fill(t, ["Ann", "ann", "Cy", "Di", "Ed", "Flo", "Gus"])
	ok(t.btn_begin.disabled, "begin disabled with duplicates")

	# validate_names
	ok(t.validate_names(["a", "b"]) != "", "wrong count")
	ok(t.validate_names(["", "b", "c", "d", "e", "f", "g"]) != "", "empty")
	ok(t.validate_names(["   ", "b", "c", "d", "e", "f", "g"]) != "", "blank")
	ok(t.validate_names(["a".repeat(17), "b", "c", "d", "e", "f", "g"]) != "", "17 chars")
	ok(t.validate_names(["Ann", "ann", "c", "d", "e", "f", "g"]) == "Names must be different.", "dupes")
	ok(t.validate_names(["A{b", "b", "c", "d", "e", "f", "g"]) == "Use letters, numbers, spaces, apostrophes or hyphens.", "bad chars")
	ok(t.validate_names(["Mary-Jane O'Nl.", "b", "c", "d", "e", "f", "g"]) == "", "mary-jane ok")
	ok(t.validate_names(["Zoë", "Łukasz", "Renée 2", "d", "e", "f", "g"]) == "", "unicode ok")
	ok(t.validate_names(["a".repeat(16), "b", "c", "d", "e", "f", "g"]) == "", "16 chars ok")

	# names survive a reroll preview refresh
	_fill(t, ["Ann", "Bob", "Cy", "Di", "Ed", "Flo", "Gus"])
	t.set_cast_preview(CAST, 77)
	ok(t.name_edits[0].text == "Ann" and t.name_edits[6].text == "Gus", "names kept after reroll")
	emitted.clear()
	t.btn_begin.pressed.emit()
	ok(emitted[0]["seed"] == 77, "new seed")

	# back from setup
	emitted.clear()
	t.btn_setup_back.pressed.emit()
	ok(t.current_screen() == "menu" and emitted.is_empty(), "back from setup")

	# howto
	t.btn_howto.pressed.emit()
	ok(t.current_screen() == "howto", "howto opens")
	t.btn_howto_back.pressed.emit()
	ok(t.current_screen() == "menu", "howto back")

	# quit
	t.btn_quit.pressed.emit()
	ok(quit_count == 1, "quit emitted")

	# background API tolerates null
	t.set_background(null)
	t.set_background(ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8)))
	ok(true, "set_background")
	pair[0].queue_free()
	await process_frame

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
