class_name JournalNotebook
extends Control

const CaseDialogue = preload("res://src/mystery/case_dialogue.gd")
## Player-owned investigation journal UI. Writes only to JournalState; never reads case truth.
const StateScript = preload("res://src/mystery/journal_state.gd")
const JournalTheme = preload("res://src/blockout/mystery_theme.gd")
const Portrait = preload("res://src/blockout/cast_portrait.gd")
const ItemArtScript = preload("res://src/mystery/house_item_art.gd")

signal changed

const SUSPECT_LABELS := {"suspect": "Suspect", "cleared": "Cleared", "alibi_checked": "Alibi checked",
	"needs_questioning": "Needs questioning", "important": "Important"}
const EVIDENCE_LABELS := {"interesting": "Interesting", "connected": "Connected", "ruled_out": "Ruled out",
	"investigate": "Investigate", "room_searched": "Room searched", "contradiction": "Contradiction"}
const EMPTY_TEXT := "Nothing recorded yet. Examine objects to list them here."
const INK := Color("2b2116")
const PAPER := "d8c7a0"
const PAPER_EDGE := "8a7448"

var state: RefCounted
var suspect_names: Array = []
var easy_facts := false
var tabs: TabContainer
var suspect_box: VBoxContainer
var evidence_box: VBoxContainer
var evidence_scroll: ScrollContainer
var suspect_scroll: ScrollContainer
var empty_label: Label
var general_edit: TextEdit
var facts_label: RichTextLabel
var facts_page: Control
var item_art: RefCounted = ItemArtScript.new()
var _items: Array = []
var _built := false

func _init() -> void:
	custom_minimum_size = Vector2(820, 540)
	set_anchors_preset(Control.PRESET_FULL_RECT)

func setup(journal_state: RefCounted, names: Array, easy: bool) -> void:
	state = journal_state
	suspect_names = names.duplicate()
	easy_facts = easy
	_build()

## Rebuild every card from the current state (e.g. after JournalState.reset()).
func rebuild() -> void:
	if not _built: return
	_build_suspects()
	_rebuild_evidence()
	general_edit.text = state.get_note("general", "")
	var facts_index := tabs.get_tab_idx_from_control(facts_page)
	tabs.set_tab_hidden(facts_index, not easy_facts)

func set_facts(text: String) -> void:
	if facts_label != null:
		facts_label.text = text

func refresh_evidence(items: Array) -> void:
	if not _built: return
	if _signature(items) == _signature(_items) and evidence_box.get_child_count() > 0: return
	_items = items.duplicate(true)
	_rebuild_evidence()

func _signature(items: Array) -> String:
	var parts: Array[String] = []
	for item in items:
		parts.append("%s|%s|%s|%s" % [item.get("key", ""), item.get("name", ""), item.get("kind", ""), item.get("location", "")])
	return "\n".join(parts)

# ---------- construction ----------
func _label(text: String, size := 14, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _page_scroll(title: String) -> Array:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	tabs.add_child(scroll)
	return [scroll, box]

func _build() -> void:
	if _built:
		for child in get_children(): child.queue_free()
	_built = true
	tabs = TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 16)
	tabs.add_theme_stylebox_override("panel", JournalTheme.panel("2b2217", "6b5a3a", 5, 0))
	tabs.add_theme_stylebox_override("tab_selected", JournalTheme.panel(PAPER, "a18a56", 4, 12))
	tabs.add_theme_stylebox_override("tab_unselected", JournalTheme.panel("4a3a26", "6b5a3a", 4, 12))
	tabs.add_theme_stylebox_override("tab_hovered", JournalTheme.panel("5c4a30", "a18a56", 4, 12))
	tabs.add_theme_color_override("font_selected_color", INK)
	tabs.add_theme_color_override("font_unselected_color", Color("e0cfa6"))
	tabs.add_theme_color_override("font_hovered_color", Color("fff1ce"))
	add_child(tabs)

	var page: Array = _page_scroll("Suspects")
	suspect_scroll = page[0]
	suspect_box = page[1]
	page = _page_scroll("Evidence")
	evidence_scroll = page[0]
	evidence_box = page[1]
	_build_notes_tab()
	_build_facts_tab()
	_build_suspects()
	_rebuild_evidence()
	tabs.set_tab_hidden(tabs.get_tab_idx_from_control(facts_page), not easy_facts)
	tabs.current_tab = 0

func _build_notes_tab() -> void:
	var margin := MarginContainer.new()
	margin.name = "Notes"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(_label("Your own notes. Nothing here is filled in for you.", 15, Color("e0cfa6")))
	general_edit = TextEdit.new()
	general_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	general_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	general_edit.placeholder_text = "Theories, timelines, questions to ask..."
	_style_edit(general_edit, 16)
	general_edit.text = state.get_note("general", "")
	general_edit.text_changed.connect(_on_general_changed)
	box.add_child(general_edit)
	tabs.add_child(margin)

func _build_facts_tab() -> void:
	var margin := MarginContainer.new()
	margin.name = "Facts"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	facts_label = RichTextLabel.new()
	facts_label.bbcode_enabled = true
	facts_label.scroll_active = true
	facts_label.selection_enabled = true
	facts_label.add_theme_font_size_override("normal_font_size", 15)
	facts_label.add_theme_color_override("default_color", Color("e8e0d2"))
	margin.add_child(facts_label)
	facts_page = margin
	tabs.add_child(margin)

func _style_edit(edit: Control, size := 14) -> void:
	var box := JournalTheme.panel("efe3c4", "8a7448", 4, 8)
	for state_name in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(state_name, box)
	edit.add_theme_color_override("font_color", INK)
	edit.add_theme_color_override("font_placeholder_color", Color("7a6c50"))
	edit.add_theme_color_override("caret_color", INK)
	edit.add_theme_font_size_override("font_size", size)

func _card(portrait: Texture2D, show_frame: bool) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", JournalTheme.panel(PAPER, PAPER_EDGE, 6, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	if show_frame:
		var picture := TextureRect.new()
		picture.custom_minimum_size = Vector2(96, 96)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.texture = portrait
		picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(picture)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)
	return [panel, column]

func _checkbox(kind: String, key: String, flag: String, text: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.custom_minimum_size = Vector2(0, 32)
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_size_override("font_size", 14)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		box.add_theme_color_override(color_name, INK)
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var plain := StyleBoxFlat.new()
		plain.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		plain.content_margin_left = 4
		plain.content_margin_right = 6
		if style_name == "hover" or style_name == "hover_pressed": plain.bg_color = Color(0.45, 0.35, 0.15, 0.18)
		box.add_theme_stylebox_override(style_name, plain)
	box.button_pressed = state.has_flag(kind, key, flag)
	box.set_meta("kind", kind)
	box.set_meta("key", key)
	box.set_meta("flag", flag)
	box.toggled.connect(_on_flag_toggled.bind(kind, key, flag))
	return box

func _flag_grid(kind: String, key: String, labels: Dictionary, columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	for flag in labels:
		grid.add_child(_checkbox(kind, key, flag, labels[flag]))
	return grid

func _note_edit(kind: String, key: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.max_length = 400
	edit.placeholder_text = "Your note..."
	edit.custom_minimum_size = Vector2(0, 34)
	_style_edit(edit)
	edit.text = state.get_note(kind, key)
	edit.text_changed.connect(_on_note_changed.bind(kind, key))
	return edit

func _clear(box: Control) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _build_suspects() -> void:
	_clear(suspect_box)
	for suspect in suspect_names:
		var name_text := str(suspect)
		var parts: Array = _card(Portrait.bust(name_text), true)
		var column: VBoxContainer = parts[1]
		column.add_child(_label(CaseDialogue.shown(name_text), 18))
		column.add_child(_flag_grid("suspect", name_text, SUSPECT_LABELS, 3))
		column.add_child(_note_edit("suspect", name_text))
		suspect_box.add_child(parts[0])

func _rebuild_evidence() -> void:
	var keep: float = evidence_scroll.scroll_vertical if evidence_scroll != null else 0.0
	_clear(evidence_box)
	if _items.is_empty():
		empty_label = _label(EMPTY_TEXT, 16, Color("e0cfa6"))
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		evidence_box.add_child(empty_label)
		return
	empty_label = null
	for item in _items:
		var key := str(item.get("key", item.get("name", "")))
		var picture: Texture2D = item_art.detail(str(item.get("name", "")))
		var parts: Array = _card(picture, true)
		var column: VBoxContainer = parts[1]
		column.add_child(_label(str(item.get("name", key)), 18))
		var detail_bits: Array[String] = []
		if str(item.get("kind", "")) != "": detail_bits.append("Kind: " + str(item.kind).capitalize())
		if str(item.get("location", "")) != "": detail_bits.append("Location: " + str(item.location))
		if not detail_bits.is_empty():
			column.add_child(_label("   ".join(detail_bits), 14, Color("4a3b27")))
		column.add_child(_flag_grid("evidence", key, EVIDENCE_LABELS, 3))
		column.add_child(_note_edit("evidence", key))
		evidence_box.add_child(parts[0])
	_restore_scroll.call_deferred(keep)

func _restore_scroll(value: float) -> void:
	if is_instance_valid(evidence_scroll): evidence_scroll.scroll_vertical = int(value)

# ---------- writes ----------
func _on_flag_toggled(pressed: bool, kind: String, key: String, flag: String) -> void:
	if state.set_flag(kind, key, flag, pressed): changed.emit()

func _on_note_changed(text: String, kind: String, key: String) -> void:
	state.set_note(kind, key, text)
	changed.emit()

func _on_general_changed() -> void:
	if general_edit.text.length() > 400:
		general_edit.text = general_edit.text.substr(0, 400)
		general_edit.set_caret_column(400)
	state.set_note("general", "", general_edit.text)
	changed.emit()
