extends SceneTree
## Renders journal screenshots. Run WITHOUT --headless.
const StateScript = preload("res://src/mystery/journal_state.gd")
const NotebookScript = preload("res://src/blockout/journal_notebook.gd")
const JournalTheme = preload("res://src/blockout/mystery_theme.gd")

func shot(name: String) -> void:
	for i in 4: await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/screenshots"))
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://test-results/screenshots/" + name))

func _initialize() -> void:
	root.size = Vector2i(960, 720)
	root.content_scale_size = Vector2i(960, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.theme = JournalTheme.create()
	var bg := ColorRect.new()
	bg.color = Color("0d1216")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var holder := Control.new()
	holder.position = Vector2(50, 60)
	holder.size = Vector2(860, 600)
	root.add_child(holder)
	var state: RefCounted = StateScript.new()
	var nb: Control = NotebookScript.new()
	holder.add_child(nb)
	nb.setup(state, ["Char", "Chris", "Justin", "Danny", "Gage", "Robbie"], true)
	nb.refresh_evidence([
		{"key": "knife", "name": "Kitchen knife", "kind": "sharp", "location": "Kitchen"},
		{"key": "ledger", "name": "Bound estate ledger", "kind": "heavy", "location": "Study"},
		{"key": "decanter", "name": "Cut-glass decanter", "kind": "blunt", "location": "Carried"}])
	nb.set_facts("Char said she was in the library.")
	await process_frame
	var suspect_cards: Array = nb.suspect_box.get_children()
	for card in suspect_cards.slice(0, 2): pass
	var box_list: Array = []
	_collect(suspect_cards[0], box_list)
	box_list[0].button_pressed = true
	box_list[3].button_pressed = true
	_collect(suspect_cards[1], box_list)
	for c in suspect_cards[0].find_children("*", "LineEdit", true, false): c.text = "Seemed nervous about the study."; c.text_changed.emit(c.text)
	await shot("journal_suspects.png")
	nb.tabs.current_tab = 1
	var ev: Array = nb.evidence_box.get_children()
	var evboxes: Array = []
	_collect(ev[0], evboxes)
	evboxes[0].button_pressed = true
	evboxes[5].button_pressed = true
	for c in ev[0].find_children("*", "LineEdit", true, false): c.text = "Missing from the block?"; c.text_changed.emit(c.text)
	await shot("journal_evidence.png")
	quit()

func _collect(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is CheckBox: out.append(child)
		_collect(child, out)
