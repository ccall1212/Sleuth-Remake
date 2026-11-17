class_name TitleScreen
extends Control
## Title screen: main menu, new-investigation setup (difficulty + cast names) and how-to-play.
const MysteryTheme = preload("res://src/blockout/mystery_theme.gd")
const CastPortrait = preload("res://src/blockout/cast_portrait.gd")

signal start_requested(config: Dictionary)
signal quit_requested
signal setup_opened
signal cast_reroll_requested

const GOLD := Color("c9ab70")
const GOLD_LIGHT := Color("ead3a2")
const MAX_NAME := 16
const NAME_LABELS := ["Suspect 1", "Suspect 2", "Suspect 3", "Suspect 4", "Suspect 5", "Suspect 6", "The victim"]
const DIFFICULTIES := [
	["easy", "Easy", "The magnifying glass names the murder weapon outright, and the journal keeps a Facts page."],
	["normal", "Normal", "The lens only shows stains; match the wound to find the weapon. Your journal is blank."],
	["hard", "Hard", "As Normal, and the murderer can hide the secret passage clue; guests may be found studying the floor."],
]
const HOWTO_LINES := [
	"A guest has been murdered. Exactly one guest is lying. Find where it happened, with what, and who did it.",
	"Move with WASD or the arrow keys.",
	"E: talk, examine or take.",
	"Q: drop the item you are carrying.",
	"F: examine the floor with the magnifying glass.",
	"N: open your journal.",
	"Tab: open the house map.",
	"Esc: open the menu.",
	"Find the magnifying glass first. You keep it for the whole case.",
	"Guests' alibis must match. An innocent person never names the murderer and never claims the murder room.",
	"You can carry only one item at a time.",
	"When you are sure, take an item and choose Gather everyone, then accuse.",
	"Wait too long and the murderer becomes suspicious, then starts stalking you.",
	"A wrong accusation ends the case.",
]

var btn_start: Button
var btn_howto: Button
var btn_quit: Button
var diff_buttons := {}
var radio_default: CheckBox
var radio_names: CheckBox
var name_edits: Array[LineEdit] = []
var btn_begin: Button
var btn_setup_back: Button
var btn_howto_back: Button
var error_label: Label
var btn_reroll: Button
var card_portraits: Array[TextureRect] = []
var card_placeholders: Array[Label] = []
var card_name_labels: Array[Label] = []
var cast_identities: Array = []
var cast_seed := -1

var _screen := "menu"
var _difficulty := "normal"
var _bg: TextureRect
var _menu: Control
var _setup: Control
var _howto: Control
var _diff_desc: Label
var _note: Label
var _edited := false


func _init() -> void:
	theme = _make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


static func _make_theme() -> Theme:
	var t := MysteryTheme.create()
	var focus := MysteryTheme.panel("2b2f2b", "ffe3a0", 5, 7)
	focus.set_border_width_all(2)
	focus.draw_center = false
	for kind in ["Button", "CheckBox", "LineEdit"]:
		t.set_stylebox("focus", kind, focus)
	var checked := MysteryTheme.panel("4a4330", "dbc18b", 5, 7)
	t.set_stylebox("pressed", "Button", checked)
	t.set_stylebox("hover_pressed", "Button", checked)
	t.set_font_size("font_size", "Button", 18)
	t.set_font_size("font_size", "CheckBox", 16)
	t.set_font_size("font_size", "LineEdit", 16)
	t.set_color("font_pressed_color", "Button", Color("fff1ce"))
	t.set_color("font_hover_pressed_color", "Button", Color("fff1ce"))
	return t


# ---------------------------------------------------------------- public API

func set_background(texture: Texture2D) -> void:
	_bg.texture = texture
	_bg.visible = texture != null


func open() -> void:
	visible = true
	_show("menu")


func set_cast_preview(identities: Array, seed_value: int) -> void:
	cast_identities = identities.duplicate()
	cast_seed = seed_value
	for i in 7:
		var ident := str(identities[i]) if i < identities.size() else ""
		var tex: Texture2D = CastPortrait.bust(ident) if ident != "" else null
		card_portraits[i].texture = tex
		card_placeholders[i].text = ident.substr(0, 1).to_upper() if tex == null else ""
		card_name_labels[i].text = ident
		name_edits[i].placeholder_text = ident if ident != "" else "Type a name"


func current_screen() -> String:
	return _screen


func validate_names(names: Array) -> String:
	if names.size() != 7:
		return "Every name needs 1-16 characters."
	var cleaned: Array[String] = []
	for n in names:
		var s := str(n).strip_edges()
		if s.length() < 1 or s.length() > MAX_NAME:
			return "Every name needs 1-16 characters."
		cleaned.append(s)
	for s in cleaned:
		for i in s.length():
			if not _char_ok(s.substr(i, 1)):
				return "Use letters, numbers, spaces, apostrophes or hyphens."
	var seen := {}
	for s in cleaned:
		var key := s.to_lower()
		if seen.has(key):
			return "Names must be different."
		seen[key] = true
	return ""


static func _char_ok(c: String) -> bool:
	if c in [" ", "'", "-", "."]:
		return true
	var code := c.unicode_at(0)
	if code >= 48 and code <= 57:
		return true
	return c.to_lower() != c.to_upper()


# ---------------------------------------------------------------- building

func _build() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.visible = false
	add_child(_bg)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_menu = _build_menu()
	_setup = _build_setup()
	_howto = _build_howto()
	var footer := Label.new()
	footer.text = "Early playable"
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color("8d8573"))
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -30
	footer.offset_bottom = -8
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)


func _screen_root() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _panel(width: float) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := MysteryTheme.panel("0f171c", "9d8152", 8, 24)
	sb.bg_color.a = 0.82
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.x = width
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	_screen_root_for(p)
	return box


func _screen_root_for(p: Control) -> void:
	var root := _screen_root()
	root.add_child(p)
	p.set_meta("screen_root", root)


func _owner_screen(box: Control) -> Control:
	return box.get_parent().get_meta("screen_root")


func _heading(text: String, size: int, color := GOLD_LIGHT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_ALL
	return b


func _build_menu() -> Control:
	var box := _panel(520)
	var title := _heading("MANSION MYSTERY", 52, GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)
	var sub := _heading("Six guests. One murderer. Find the truth.", 18, Color("cfc6b4"))
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	box.add_child(gap)
	btn_start = _button("Start Game")
	btn_howto = _button("How to Play")
	btn_quit = _button("Quit")
	for b in [btn_start, btn_howto, btn_quit]:
		box.add_child(b)
	btn_start.pressed.connect(func() -> void: _show("setup"))
	btn_howto.pressed.connect(func() -> void: _show("howto"))
	btn_quit.pressed.connect(func() -> void: quit_requested.emit())
	return _owner_screen(box)


func _build_setup() -> Control:
	var box := _panel(800)
	box.add_theme_constant_override("separation", 6)
	box.add_child(_heading("New investigation", 28, GOLD))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var group := ButtonGroup.new()
	for d in DIFFICULTIES:
		var b := _button(d[1])
		b.custom_minimum_size.y = 44
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggled.connect(_on_difficulty_toggled.bind(d[0]))
		row.add_child(b)
		diff_buttons[d[0]] = b
	diff_buttons["normal"].set_pressed_no_signal(true)
	_diff_desc = Label.new()
	_diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_desc.custom_minimum_size = Vector2(0, 40)
	_diff_desc.add_theme_font_size_override("font_size", 15)
	_diff_desc.add_theme_color_override("font_color", Color("cfc6b4"))
	box.add_child(_diff_desc)

	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 16)
	box.add_child(crow)
	var cl := Label.new()
	cl.text = "Cast"
	cl.add_theme_color_override("font_color", GOLD)
	crow.add_child(cl)
	var cgroup := ButtonGroup.new()
	radio_default = CheckBox.new()
	radio_default.text = "Default characters"
	radio_names = CheckBox.new()
	radio_names.text = "Personalized names"
	for r in [radio_default, radio_names]:
		r.button_group = cgroup
		r.focus_mode = Control.FOCUS_ALL
		r.custom_minimum_size = Vector2(0, 34)
		crow.add_child(r)
	radio_default.set_pressed_no_signal(true)
	radio_names.toggled.connect(func(_on: bool) -> void: _refresh_cast())

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for i in 7:
		grid.add_child(_make_card(i))
	var cell := CenterContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reroll = _button("Different cast")
	btn_reroll.custom_minimum_size = Vector2(150, 44)
	btn_reroll.pressed.connect(func() -> void: cast_reroll_requested.emit())
	cell.add_child(btn_reroll)
	grid.add_child(cell)

	_note = Label.new()
	_note.text = "Typed names replace the characters' names in all dialogue and notes; the art stays the same."
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color("a89f8c"))
	box.add_child(_note)

	error_label = Label.new()
	error_label.add_theme_color_override("font_color", Color("e07b6e"))
	error_label.add_theme_font_size_override("font_size", 14)
	error_label.custom_minimum_size = Vector2(0, 20)
	box.add_child(error_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	btn_setup_back = _button("Back")
	btn_setup_back.custom_minimum_size = Vector2(120, 46)
	btn_begin = _button("Begin investigation")
	btn_begin.custom_minimum_size.y = 46
	btn_begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(btn_setup_back)
	buttons.add_child(btn_begin)
	btn_setup_back.pressed.connect(func() -> void: _show("menu"))
	btn_begin.pressed.connect(_begin)
	_refresh_difficulty()
	_refresh_cast()
	return _owner_screen(box)


func _make_card(i: int) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", MysteryTheme.panel("141d23", "4b4540", 5, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 96)
	v.add_child(holder)
	var ph := Label.new()
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.add_theme_font_size_override("font_size", 40)
	ph.add_theme_color_override("font_color", Color("655944"))
	holder.add_child(ph)
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tr)
	var cap := Label.new()
	cap.text = NAME_LABELS[i]
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", GOLD)
	v.add_child(cap)
	var nl := Label.new()
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.custom_minimum_size = Vector2(0, 32)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.clip_text = true
	nl.add_theme_font_size_override("font_size", 15)
	v.add_child(nl)
	var e := LineEdit.new()
	e.max_length = MAX_NAME
	e.placeholder_text = "Type a name"
	e.custom_minimum_size = Vector2(0, 32)
	e.add_theme_font_size_override("font_size", 15)
	e.text_changed.connect(func(_t: String) -> void:
		_edited = true
		_refresh_cast())
	e.text_submitted.connect(_on_name_submitted.bind(i))
	v.add_child(e)
	name_edits.append(e)
	card_portraits.append(tr)
	card_placeholders.append(ph)
	card_name_labels.append(nl)
	return card


func _build_howto() -> Control:
	var box := _panel(660)
	box.add_child(_heading("How to play", 30, GOLD))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 5)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	for t in HOWTO_LINES:
		var l := Label.new()
		l.text = t
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 16)
		lines.add_child(l)
	btn_howto_back = _button("Back")
	box.add_child(btn_howto_back)
	btn_howto_back.pressed.connect(func() -> void: _show("menu"))
	return _owner_screen(box)


# ---------------------------------------------------------------- behaviour

func _show(which: String) -> void:
	_screen = which
	_menu.visible = which == "menu"
	_setup.visible = which == "setup"
	_howto.visible = which == "howto"
	if not is_inside_tree():
		return
	if which == "setup":
		setup_opened.emit()
	match which:
		"menu":
			btn_start.grab_focus()
		"setup":
			diff_buttons[_difficulty].grab_focus()
		"howto":
			btn_howto_back.grab_focus()


func _on_difficulty_toggled(on: bool, id: String) -> void:
	if on:
		_difficulty = id
		_refresh_difficulty()


func _refresh_difficulty() -> void:
	for d in DIFFICULTIES:
		if d[0] == _difficulty:
			_diff_desc.text = d[2]


func _current_names() -> Array:
	var out: Array = []
	for e in name_edits:
		out.append(e.text.strip_edges())
	return out


func _refresh_cast() -> void:
	var custom := radio_names.button_pressed
	_note.visible = custom
	for i in 7:
		name_edits[i].visible = custom
		card_name_labels[i].visible = not custom
	var err := validate_names(_current_names()) if custom else ""
	error_label.text = err if _edited else ""
	btn_begin.disabled = err != ""


func _on_name_submitted(_t: String, i: int) -> void:
	if i < name_edits.size() - 1:
		name_edits[i + 1].grab_focus()
	elif not btn_begin.disabled:
		_begin()


func _begin() -> void:
	if btn_begin.disabled:
		return
	var custom: Array = _current_names() if radio_names.button_pressed else []
	start_requested.emit({"difficulty": _difficulty, "custom_names": custom, "seed": cast_seed})


func _input(event: InputEvent) -> void:
	if not visible or _screen == "menu":
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show("menu")
