extends SceneTree
const Cards = preload("res://src/blockout/accusation_cards.gd")
var checks := 0
var failures: Array[String] = []
var fired: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 30: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func count_selected(d) -> int:
	var n := 0
	for i in d.cards.size():
		if d.selected_index() == i: n += 1
	return n

func has_type(node: Node, type_name: String) -> bool:
	if node.is_class(type_name): return true
	for c in node.get_children():
		if has_type(c, type_name): return true
	return false

func run() -> void:
	var d = Cards.new()
	root.add_child(d)
	d.setup(["Char", "Chris", "Justin", "Danny", "Gage", "Robbie"], "the Library")
	d.suspect_confirmed.connect(func(i): fired.append(i))
	check(d.cards.size() == 6, "6 cards")
	check(d.selected_index() == -1, "none selected at start")
	check(d.get_ok_button().disabled, "Accuse disabled at start")
	d.select(2)
	check(d.selected_index() == 2 and count_selected(d) == 1, "select highlights exactly one")
	check(not d.get_ok_button().disabled, "Accuse enabled after select")
	var tags := 0
	for c in d.cards:
		if c.find_child("tag", true, false).modulate.a > 0.5: tags += 1
	check(tags == 1, "exactly one ACCUSE tag visible")
	d._handle_key(key(KEY_RIGHT), null)
	check(d.selected_index() == 3, "right moves")
	d.select(5)
	d._handle_key(key(KEY_RIGHT), null)
	check(d.selected_index() == 0, "right wraps")
	d._handle_key(key(KEY_LEFT), null)
	check(d.selected_index() == 5, "left wraps")
	d.select(0)
	d._handle_key(key(KEY_DOWN), null)
	check(d.selected_index() == 3, "down moves a row")
	d._handle_key(key(KEY_UP), null)
	d._handle_key(key(KEY_UP), null)
	check(d.selected_index() == 3, "up wraps")
	check(not has_type(d, "OptionButton") and not has_type(d, "LineEdit"), "no OptionButton or LineEdit")
	check(Cards.CastPortrait.bust("Char") != null, "Char portrait non-null")
	check(Cards.CastPortrait.bust("Justin") != null, "Justin portrait non-null")
	var rect: TextureRect = d.cards[0].find_child("texture_rect", true, false)
	check(rect != null and rect.stretch_mode in [TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, TextureRect.STRETCH_KEEP_ASPECT_COVERED], "aspect preserved")
	check(rect != null and rect.texture != null, "Char card has texture")
	# Confirmation gating.
	d.select(1)
	d.get_ok_button().pressed.emit()
	check(fired.is_empty(), "no signal before confirm step")
	d._handle_key(key(KEY_ENTER), null)
	check(fired.is_empty(), "Enter alone does not emit")
	d._confirm.confirmed.emit()
	check(fired == [1], "signal only after Yes")
	# Cancel emits nothing.
	fired.clear()
	var d2 = Cards.new()
	root.add_child(d2)
	d2.setup(["Char", "Chris", "Justin", "Danny", "Gage", "Robbie"], "the Hall")
	d2.suspect_confirmed.connect(func(i): fired.append(i))
	d2.select(4)
	d2.get_cancel_button().pressed.emit()
	check(fired.is_empty(), "cancel emits nothing")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
