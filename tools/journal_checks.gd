extends SceneTree
## Journal checks. Run: godot --headless --path . --script tools/journal_checks.gd
const StateScript = preload("res://src/mystery/journal_state.gd")
const NotebookScript = preload("res://src/blockout/journal_notebook.gd")
const NAMES := ["Char", "Chris", "Justin", "Danny", "Gage", "Robbie"]
var checks := 0
var failures: Array = []
var fired := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func boxes(node: Node, out: Array = []) -> Array:
	for child in node.get_children():
		if child is CheckBox: out.append(child)
		boxes(child, out)
	return out

func cards(box: Control) -> Array:
	return box.get_children().filter(func(c): return c is PanelContainer)

func make(state: RefCounted, easy: bool) -> Control:
	var nb: Control = NotebookScript.new()
	root.add_child(nb)
	nb.setup(state, NAMES, easy)
	nb.changed.connect(func(): fired += 1)
	return nb

func _initialize() -> void:
	# --- state ---
	var s: RefCounted = StateScript.new()
	check(s.set_flag("suspect", "Char", "cleared", true), "set valid flag")
	check(s.has_flag("suspect", "Char", "cleared"), "has flag")
	check(not s.set_flag("suspect", "Char", "guilty", true), "unknown suspect flag rejected")
	check(not s.has_flag("suspect", "Char", "guilty"), "unknown flag not stored")
	check(not s.set_flag("evidence", "Knife", "cleared", true), "suspect flag rejected on evidence")
	check(not s.set_flag("room", "x", "interesting", true), "unknown kind rejected")
	check(s.flags_for("suspect", "Char") == ["cleared"], "flags_for")
	s.set_flag("suspect", "Char", "cleared", false)
	check(s.flags_for("suspect", "Char").is_empty(), "flag clears")
	s.set_note("general", "", "x".repeat(500))
	check(s.get_note("general", "").length() == 400, "note limit 400")
	s.set_note("evidence", "Knife", "odd")
	s.set_flag("evidence", "Knife", "interesting", true)
	var copy: RefCounted = StateScript.new()
	copy.from_dict(s.to_dict())
	check(copy.get_note("evidence", "Knife") == "odd" and copy.has_flag("evidence", "Knife", "interesting"), "dict round trip")
	s.reset()
	check(s.get_note("evidence", "Knife") == "" and not s.has_flag("evidence", "Knife", "interesting"), "reset clears")

	# --- UI ---
	var state: RefCounted = StateScript.new()
	var nb: Control = make(state, false)
	await process_frame
	var suspect_cards := cards(nb.suspect_box)
	check(suspect_cards.size() == 6, "6 suspect cards")
	var all_ok := true
	for card in suspect_cards:
		if boxes(card).size() != 5: all_ok = false
	check(all_ok, "5 checkboxes per suspect")
	check(NotebookScript.Portrait.bust("Char") != null, "Char portrait non-null")
	for box in boxes(nb):
		check(not box.button_pressed, "starts unchecked")
	check(nb.empty_label != null and nb.empty_label.text.begins_with("Nothing recorded yet"), "evidence empty state")

	var first: CheckBox = boxes(suspect_cards[0])[0]
	var before := fired
	first.button_pressed = true
	check(state.has_flag("suspect", "Char", "suspect") and fired == before + 1, "toggle on writes state + emits")
	first.button_pressed = false
	check(not state.has_flag("suspect", "Char", "suspect") and fired == before + 2, "toggle off clears")

	# evidence
	nb.refresh_evidence([
		{"key": "knife", "name": "Kitchen knife", "kind": "sharp", "location": "Kitchen"},
		{"key": "ledger", "name": "Bound estate ledger", "kind": "", "location": "Study"}])
	await process_frame
	var ev := cards(nb.evidence_box)
	check(ev.size() == 2 and nb.empty_label == null, "2 evidence cards")
	var six := true
	for card in ev:
		if boxes(card).size() != 6: six = false
	check(six, "6 checkboxes per evidence card")
	for box in boxes(nb.evidence_box):
		check(not box.button_pressed, "evidence starts unchecked")
	boxes(ev[1])[3].button_pressed = true
	nb.refresh_evidence([
		{"key": "knife", "name": "Kitchen knife", "kind": "sharp", "location": "Hall"},
		{"key": "ledger", "name": "Bound estate ledger", "kind": "", "location": "Study"}])
	await process_frame
	check(boxes(cards(nb.evidence_box)[1])[3].button_pressed, "refresh keeps checked state")
	check(state.has_flag("evidence", "ledger", "investigate"), "state kept after refresh")

	# facts
	var facts_idx: int = nb.tabs.get_tab_idx_from_control(nb.facts_page)
	check(nb.tabs.is_tab_hidden(facts_idx), "facts hidden when not easy")
	var easy: Control = make(StateScript.new(), true)
	await process_frame
	easy.set_facts("Heard: Char was in the hall")
	check(not easy.tabs.is_tab_hidden(easy.tabs.get_tab_idx_from_control(easy.facts_page)), "facts shown when easy")
	check(easy.facts_label.get_parsed_text().contains("Char was in the hall"), "facts text shown")

	# reset
	state.reset()
	nb.rebuild()
	await process_frame
	var any_checked := false
	for box in boxes(nb): if box.button_pressed: any_checked = true
	check(not any_checked, "reset unchecks everything on rebuild")

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
