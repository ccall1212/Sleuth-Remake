class_name GameHud
extends Control
## In-game overlay HUD: room name, tools, murderer phase, context actions, hints.
## Translucent panels only, so it can sit over the room art. Mouse passes through
## everything except the buttons themselves.

signal action_pressed(id: String)

const MysteryTheme := preload("res://src/blockout/mystery_theme.gd")

const GOLD := Color("c9ab70")
const DIM := Color("8a8a80")
const TEXT := Color("eee5d4")
const PANEL_BG := Color(0.082, 0.125, 0.145, 0.70)
const PANEL_BORDER := Color("514936")
const MARGIN := 12

## id -> [keycap, name, long name]
const ACTIONS := [
	["interact", "E", "Interact", "Interact with what is in front of you"],
	["examine", "E", "Examine", "Examine this object closely"],
	["take", "E", "Take", "Pick this item up"],
	["drop", "Q", "Drop", "Drop the item you are holding"],
	["floor", "F", "Floor", "Look at the floor with the magnifier"],
	["notebook", "N", "Notebook", "Open your notebook"],
	["map", "Tab", "Map", "Open the house map"],
	["accuse", "A", "Accuse", "Gather everyone and make an accusation"],
	["menu", "Esc", "Menu", "Open the game menu"],
]


## Small drawn marker so phases differ by shape, not only colour.
class PhaseIcon extends Control:
	var shape := "calm"
	var color := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(14, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r: float = minf(size.x, size.y) / 2.0 - 1.0
		match shape:
			"suspicious":
				draw_colored_polygon(PackedVector2Array([
					Vector2(c.x, c.y - r), Vector2(c.x + r, c.y + r * 0.8),
					Vector2(c.x - r, c.y + r * 0.8)]), color)
			"stalking":
				draw_colored_polygon(PackedVector2Array([
					Vector2(c.x, c.y - r), Vector2(c.x + r, c.y),
					Vector2(c.x, c.y + r), Vector2(c.x - r, c.y)]), color)
			_:
				draw_circle(c, r, color)


var _room_label: Label
var _glass_label: Label
var _held_label: Label
var _phase_panel: PanelContainer
var _phase_label: Label
var _phase_icon: PhaseIcon
var _bar_panel: PanelContainer
var _bar: HBoxContainer
var _hint_panel: PanelContainer
var _hint_label: Label
var _buttons := {}
var _states := {}
var _all_enabled := true
var _hint_tween: Tween
var _pulse_tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = MysteryTheme.create()
	_build()


func _panel(pad_h := 10, pad_v := 6) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := MysteryTheme.panel("000000", "514936", 6, 0)
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text := "", size := 14, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	# Top-left: room + tools.
	var tl := _panel()
	tl.anchor_left = 0.0
	tl.anchor_right = 0.0
	tl.offset_left = MARGIN
	tl.offset_top = MARGIN
	tl.grow_horizontal = Control.GROW_DIRECTION_END
	tl.grow_vertical = Control.GROW_DIRECTION_END
	add_child(tl)
	var tl_box := VBoxContainer.new()
	tl_box.add_theme_constant_override("separation", 3)
	tl_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(tl_box)
	_room_label = _label("", 17, Color("ead3a2"))
	tl_box.add_child(_room_label)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 14)
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl_box.add_child(tools)
	_glass_label = _label("Glass: not found", 13, DIM)
	_held_label = _label("Hands free", 13, DIM)
	tools.add_child(_glass_label)
	tools.add_child(_held_label)

	# Top-right: murderer phase.
	_phase_panel = _panel()
	_phase_panel.anchor_left = 1.0
	_phase_panel.anchor_right = 1.0
	_phase_panel.offset_right = -MARGIN
	_phase_panel.offset_top = MARGIN
	_phase_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_phase_panel.grow_vertical = Control.GROW_DIRECTION_END
	add_child(_phase_panel)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 7)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_panel.add_child(ph)
	_phase_icon = PhaseIcon.new()
	_phase_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(_phase_icon)
	_phase_label = _label("Murderer: Calm", 15)
	ph.add_child(_phase_label)

	# Bottom: hint above action bar, centred.
	var col := VBoxContainer.new()
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.offset_bottom = -MARGIN
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_hint_panel = _panel(12, 4)
	_hint_panel.visible = false
	_hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_hint_panel)
	_hint_label = _label("", 14, Color("ead3a2"))
	_hint_panel.add_child(_hint_label)
	_bar_panel = _panel(8, 6)
	_bar_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_bar_panel)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 6)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_panel.add_child(_bar)
	for a in ACTIONS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 14)
		b.text = "[%s] %s" % [a[1], a[2]]
		b.tooltip_text = a[3]
		b.visible = false
		b.pressed.connect(func() -> void: action_pressed.emit(a[0]))
		_bar.add_child(b)
		_buttons[a[0]] = b
	set_phase("Calm", Color("9bb8ca"))
	set_actions({})


func set_room(room_name: String) -> void:
	_room_label.text = room_name


func set_inventory(glass_found: bool, held_name: String) -> void:
	_glass_label.text = "Glass: found" if glass_found else "Glass: not found"
	_glass_label.add_theme_color_override("font_color", GOLD if glass_found else DIM)
	if held_name.is_empty():
		_held_label.text = "Hands free"
		_held_label.add_theme_color_override("font_color", DIM)
	else:
		_held_label.text = "Holding: %s  [Q] Drop" % held_name
		_held_label.add_theme_color_override("font_color", GOLD)


func set_phase(phase: String, color: Color) -> void:
	var word := phase.capitalize()
	_phase_label.text = "Murderer: %s" % word
	_phase_label.add_theme_color_override("font_color", color)
	_phase_icon.color = color
	_phase_icon.shape = word.to_lower()
	_phase_icon.queue_redraw()
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	_phase_panel.modulate.a = 1.0
	if word.to_lower() == "stalking":
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_phase_panel, "modulate:a", 0.6, 0.8)
		_pulse_tween.tween_property(_phase_panel, "modulate:a", 1.0, 0.8)


func set_actions(states: Dictionary) -> void:
	_states = states
	_refresh_buttons()


func set_enabled_all(enabled: bool) -> void:
	_all_enabled = enabled
	_refresh_buttons()


func _refresh_buttons() -> void:
	for a in ACTIONS:
		var id: String = a[0]
		var b: Button = _buttons[id]
		var st: Dictionary = _states.get(id, {})
		b.visible = bool(st.get("visible", false))
		b.disabled = not (bool(st.get("enabled", true)) and _all_enabled)
		var lbl: String = str(st.get("label", a[2]))
		b.text = "[%s] %s" % [a[1], lbl]
	_bar_panel.visible = not visible_action_ids().is_empty()
	_bar_panel.reset_size()


func visible_action_ids() -> Array:
	var out := []
	for a in ACTIONS:
		if (_buttons[a[0]] as Button).visible:
			out.append(a[0])
	return out


func show_hint(text: String, seconds := 6.0) -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_label.text = text
	_hint_panel.reset_size()
	_hint_panel.visible = true
	_hint_panel.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_panel, "modulate:a", 1.0, 0.25)
	_hint_tween.tween_interval(maxf(seconds - 0.7, 0.0))
	_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, 0.45)
	_hint_tween.tween_callback(func() -> void: _hint_panel.visible = false)


func clear_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	_hint_panel.visible = false
	_hint_label.text = ""


func hint_visible() -> bool:
	return _hint_panel.visible
