extends ConfirmationDialog
## Pick-the-suspect accusation dialog: portrait cards, no dropdown, two-step confirmation.
const MysteryTheme = preload("res://src/blockout/mystery_theme.gd")
const CastPortrait = preload("res://src/blockout/cast_portrait.gd")
signal suspect_confirmed(index: int)
const COLUMNS := 3
var cards: Array[PanelContainer] = []
var names: Array = []
var _selected := -1
var _hover := -1
var _header: Label
var _grid: GridContainer
var _confirm: ConfirmationDialog
var _built := false

func _init() -> void:
	title = "Accuse"
	theme = MysteryTheme.create()
	size = Vector2i(760, 560)
	min_size = Vector2i(760, 560)
	ok_button_text = "Accuse"
	cancel_button_text = "Cancel"
	dialog_hide_on_ok = false
	get_ok_button().disabled = true
	confirmed.connect(request_accuse)
	window_input.connect(_on_window_input)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Final accusation"
	_confirm.ok_button_text = "Yes"
	_confirm.cancel_button_text = "No"
	_confirm.dialog_text = "Are you sure? This cannot be undone."
	_confirm.theme = theme
	_confirm.confirmed.connect(_on_confirm_yes)
	add_child(_confirm)

func setup(cast_names: Array, gathered_room_name: String) -> void:
	if _built:
		_header.get_parent().queue_free()
		cards.clear()
	_built = true
	names = cast_names.duplicate()
	_selected = -1
	_hover = -1
	get_ok_button().disabled = true
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_header = Label.new()
	_header.text = "Everyone is gathered in: %s" % gathered_room_name
	_header.add_theme_font_size_override("font_size", 17)
	_header.add_theme_color_override("font_color", Color("ead3a2"))
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_header)
	var note := Label.new()
	note.text = "Choose the person you accuse. A wrong accusation ends the investigation."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	box.add_child(_grid)
	for i in names.size(): _grid.add_child(_make_card(i))
	_refresh()
	size = Vector2i(760, 560)

func _make_card(i: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card%d" % i
	card.custom_minimum_size = Vector2(222, 196)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.add_theme_constant_override("separation", 3)
	card.add_child(inner)
	var tex_holder := Control.new()
	tex_holder.custom_minimum_size = Vector2(0, 128)
	tex_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tex_holder.clip_contents = true
	tex_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.add_child(tex_holder)
	var rect := TextureRect.new()
	rect.name = "texture_rect"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_PASS
	var tex: Texture2D = CastPortrait.bust(str(names[i]))
	rect.texture = tex
	tex_holder.add_child(rect)
	if tex == null:
		var initial := Label.new()
		initial.name = "initial"
		initial.text = str(names[i]).left(1).to_upper()
		initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial.add_theme_font_size_override("font_size", 56)
		initial.add_theme_color_override("font_color", Color("78817d"))
		initial.mouse_filter = Control.MOUSE_FILTER_PASS
		tex_holder.add_child(initial)
	var label := Label.new()
	label.name = "name_label"
	label.text = str(names[i])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.add_child(label)
	var tag := Label.new()
	tag.name = "tag"
	tag.text = "✓ ACCUSE"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Color("f0cf7a"))
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	tag.modulate.a = 0.0
	inner.add_child(tag)
	card.gui_input.connect(_on_card_input.bind(i))
	card.mouse_entered.connect(func(): _hover = i; _refresh())
	card.mouse_exited.connect(func(): if _hover == i: _hover = -1; _refresh())
	cards.append(card)
	return card

func _style_for(i: int) -> StyleBoxFlat:
	var style: StyleBoxFlat
	if i == _selected:
		style = MysteryTheme.panel("2b2a1f", "e8c566", 6, 8)
		style.set_border_width_all(3)
	elif i == _hover:
		style = MysteryTheme.panel("252d30", "c9ab70", 6, 8)
		style.set_border_width_all(2)
	else:
		style = MysteryTheme.panel("1a2327", "4b4540", 6, 8)
	return style

func _refresh() -> void:
	for i in cards.size():
		cards[i].add_theme_stylebox_override("panel", _style_for(i))
		var tag: Control = cards[i].find_child("tag", true, false)
		if tag: tag.modulate.a = 1.0 if i == _selected else 0.0
	get_ok_button().disabled = _selected < 0

func selected_index() -> int:
	return _selected

func select(index: int) -> void:
	if index < 0 or index >= cards.size(): return
	_selected = index
	cards[index].grab_focus()
	_refresh()

func _on_card_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select(i)
		cards[i].accept_event()
	elif event is InputEventKey:
		_handle_key(event, cards[i])

func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey: _handle_key(event, null)

## Arrow keys move (wrapping), Enter/Space accuse, Esc cancels.
func _handle_key(event: InputEventKey, source: Control) -> void:
	if not event.pressed or event.echo or cards.is_empty(): return
	var n := cards.size()
	var move := 0
	match event.keycode:
		KEY_RIGHT: move = 1
		KEY_LEFT: move = -1
		KEY_DOWN: move = COLUMNS
		KEY_UP: move = -COLUMNS
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _selected >= 0 and not _confirm.visible: request_accuse()
			get_viewport().set_input_as_handled()
			return
		KEY_ESCAPE:
			if not _confirm.visible: hide()
			return
		_: return
	if _selected < 0: select(0 if move > 0 else n - 1)
	else: select(posmod(_selected + move, n))
	get_viewport().set_input_as_handled()

func request_accuse() -> void:
	if _selected < 0: return
	_confirm.dialog_text = "Accuse %s? Are you sure? This cannot be undone." % str(names[_selected])
	if is_inside_tree() and DisplayServer.get_name() != "headless": _confirm.popup_centered()

func _on_confirm_yes() -> void:
	if _selected < 0: return
	hide()
	suspect_confirmed.emit(_selected)
