extends Control
## An isolated, art-independent lab. Does not read/write the mansion save.
const Case = preload("res://src/mystery/lab_case.gd")
const SAVE := "user://case-lab-v2.json"
var model = Case.new(1)
var seed_box: SpinBox
var room_buttons: Array[Button] = []
var actions: VBoxContainer
var notebook: RichTextLabel
var message: RichTextLabel
var status: Label
var choices: Array[OptionButton] = []
var dev_session := ""
var ticker := 0.0
var setup: Panel
var difficulty_choice: OptionButton
var assistance_choice: OptionButton
var setup_description: Label
var pending_seed := 1
var subtitle: Label

func label_at(text: String, at: Vector2, extent: Vector2, size_value := 16) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.size = extent
	node.add_theme_font_size_override("font_size",size_value)
	add_child(node)
	return node

func panel_at(at: Vector2, extent: Vector2) -> Panel:
	var node := Panel.new()
	node.position = at
	node.size = extent
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1b2a38")
	style.border_color = Color("#385365")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	node.add_theme_stylebox_override("panel",style)
	add_child(node)
	return node

func rich(parent: Control, at: Vector2, extent: Vector2) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.position = at
	node.size = extent
	node.add_theme_font_size_override("normal_font_size",15)
	node.selection_enabled = true
	parent.add_child(node)
	return node

func make_button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 31
	node.add_theme_font_size_override("font_size",15)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#101b25"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case-seed="):
			var value := arg.trim_prefix("--case-seed=")
			if value.is_valid_int(): model = Case.new(clampi(int(value),0,2147483647))
		if arg.begins_with("--dev-session=res://test-results/"): dev_session = arg.trim_prefix("--dev-session=")
	label_at("MANSION MYSTERY / CASE LAB",Vector2(22,14),Vector2(650,32),24)
	subtitle = label_at("Choose your mystery and notebook assistance.",Vector2(22,48),Vector2(916,25),16)
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(22,82)
	toolbar.size = Vector2(916,34)
	toolbar.add_theme_constant_override("separation",10)
	add_child(toolbar)
	var seed_label := Label.new()
	seed_label.text = "CASE SEED"
	toolbar.add_child(seed_label)
	seed_box = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 2147483647
	seed_box.value = model.data.seed
	seed_box.custom_minimum_size.x = 150
	toolbar.add_child(seed_box)
	make_button(toolbar,"New mystery",func(): open_setup(int(seed_box.value)))
	make_button(toolbar,"Next seed",func(): open_setup((int(model.data.seed)+1)%2147483648))
	make_button(toolbar,"Save lab",save_lab)
	make_button(toolbar,"Load lab",load_lab)
	status = label_at("",Vector2(22,120),Vector2(916,25),14)
	panel_at(Vector2(22,152),Vector2(420,272))
	label_at("ROOMS   /   Click a connected room",Vector2(36,160),Vector2(395,24),15)
	for i in range(4):
		var button := make_button(self,"",func(): show_result(model.travel(i)))
		button.position = Vector2(36+(i%2)*201,194+(i/2)*110)
		button.size = Vector2(190,100)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		room_buttons.append(button)
	panel_at(Vector2(460,152),Vector2(478,272))
	actions = VBoxContainer.new()
	actions.position = Vector2(474,164)
	actions.size = Vector2(450,248)
	actions.add_theme_constant_override("separation",7)
	add_child(actions)
	var msg_panel := panel_at(Vector2(22,438),Vector2(420,258))
	message = rich(msg_panel,Vector2(14,12),Vector2(392,234))
	var note_panel := panel_at(Vector2(460,438),Vector2(478,258))
	notebook = rich(note_panel,Vector2(14,12),Vector2(450,154))
	var row := HBoxContainer.new()
	row.position = Vector2(14,175)
	row.size = Vector2(450,32)
	note_panel.add_child(row)
	for options in [Case.NAMES,Case.ITEMS,Case.ROOMS]:
		var choice := OptionButton.new()
		choice.custom_minimum_size = Vector2(145,32)
		choice.add_theme_font_size_override("font_size",14)
		for option in options: choice.add_item(option)
		row.add_child(choice)
		choices.append(choice)
	var present := make_button(note_panel,"Present reconstruction",present_case)
	present.position = Vector2(14,214)
	present.size = Vector2(450,31)
	refresh()
	briefing()
	build_setup()
	open_setup(int(model.data.seed))
	write_dev_state()

func build_setup() -> void:
	setup = panel_at(Vector2.ZERO,Vector2(960,720))
	var heading := rich(setup,Vector2(120,82),Vector2(720,80))
	heading.text = "NEW MYSTERY\nChoose the case complexity and how much the notebook records."
	difficulty_choice = OptionButton.new()
	difficulty_choice.position = Vector2(120,188)
	difficulty_choice.size = Vector2(720,44)
	difficulty_choice.add_item("Mystery difficulty: Introductory — witness conflict")
	difficulty_choice.add_item("Mystery difficulty: Standard — time and weapon access")
	setup.add_child(difficulty_choice)
	assistance_choice = OptionButton.new()
	assistance_choice.position = Vector2(120,260)
	assistance_choice.size = Vector2(720,44)
	for option in ["Notebook: Assisted — organized comparison and prompts","Notebook: Standard — records statements and findings","Notebook: Classic — keep your own notes"]:
		assistance_choice.add_item(option)
	assistance_choice.select(1)
	setup.add_child(assistance_choice)
	setup_description = Label.new()
	setup_description.position = Vector2(120,334)
	setup_description.size = Vector2(720,200)
	setup_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup.add_child(setup_description)
	difficulty_choice.item_selected.connect(func(_i): update_setup())
	assistance_choice.item_selected.connect(func(_i): update_setup())
	var start := make_button(setup,"Start mystery",begin_setup)
	start.position = Vector2(120,562)
	start.size = Vector2(350,44)
	var cancel := make_button(setup,"Back to current case",func(): setup.hide())
	cancel.position = Vector2(490,562)
	cancel.size = Vector2(350,44)
	var load_button := make_button(setup,"Load saved lab",load_lab)
	load_button.position = Vector2(120,626)
	load_button.size = Vector2(720,34)

func open_setup(seed_value: int) -> void:
	pending_seed = seed_value
	setup.show()
	update_setup()

func update_setup() -> void:
	var difficulty_text := "Compare conflicting accounts from one interval." if difficulty_choice.selected == 0 else "Combine two time windows, room evidence and restricted weapon access. Accounts alone leave several suspects."
	var notebook_text: String = ["Organizes learned facts by guest and adds comparison questions, without selecting the murderer.","Keeps a chronological record of exactly what you learned. You interpret it.","No automatic clue history or comparison table. You can question and inspect again; only the latest response stays on screen."][assistance_choice.selected]
	setup_description.text = "Seed %d\n\n%s\n\n%s\n\nThese choices are independent. This lab has no danger timer." % [pending_seed,difficulty_text,notebook_text]

func begin_setup() -> void:
	start_seed(pending_seed,["introductory","standard"][difficulty_choice.selected],["assisted","standard","classic"][assistance_choice.selected])
	setup.hide()

func briefing() -> void:
	message.text = "A guest was killed between 10:00 and 10:10. Everyone's account refers to that entire interval.\n\nThe culprit may lie. The other three guests are truthful; a shared account means they stayed together throughout.\n\nStart with the magnifying glass in the foyer. Inspect objects and room traces, hear every account, then collect the identified weapon and present your reconstruction.\n\nThis first lab has no danger timer. Judge the deduction, not the graphics."
	if model.data.family == "timed_access":
		message.text = "A guest was killed between 10:00 and 10:10. Reconstruct two intervals: 10:00–10:05 and 10:05–10:10.\n\nAll four whereabouts accounts are independently verified and accurate, including the culprit's. Several guests had opportunity. Physical evidence can establish the attack time and who could access the weapon. Keys were never shared and the weapon was never passed to another person.\n\nCollect the glass, hear all four accounts, inspect room traces and objects. Combine time, place and access before collecting the weapon and presenting your case. No danger timer."

func start_seed(seed_value: int, difficulty_value := "", assistance_value := "") -> void:
	model = Case.new(seed_value,model.difficulty if difficulty_value.is_empty() else difficulty_value,model.assistance if assistance_value.is_empty() else assistance_value)
	assert(Case.validate(model.data),"Generated case failed the independent fairness check")
	seed_box.value = seed_value
	for choice in choices: choice.select(0)
	refresh()
	briefing()

func show_result(text: String) -> void:
	message.text = text
	refresh()

func refresh() -> void:
	var p: Dictionary = model.progress
	subtitle.text = "Mystery: %s   |   Notebook: %s" % [model.difficulty.capitalize(),model.assistance.capitalize()]
	status.text = "Seed %d  |  %d room moves  |  Glass: %s  |  Accounts: %d/4  |  %s" % [model.data.seed,p.moves,"collected" if p.glass else "in foyer",p.claims.size(),"CASE CLOSED" if p.outcome == "solved" else "INVESTIGATING"]
	for room in range(4):
		var button := room_buttons[room]
		var who: int = model.data.present.find(room)
		button.text = "  %s\n  %s\n  %s" % [Case.ROOMS[room].to_upper(),"YOU ARE HERE" if room == int(p.room) else ("Connected doorway" if room in Case.LINKS[p.room] else "Via another room"),"Guest token: "+Case.NAMES[who]]
		button.disabled = room not in Case.LINKS[p.room] or p.outcome == "solved"
		button.modulate = Color("#b8edce") if room == int(p.room) else Color.WHITE
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = "IN THE "+Case.ROOMS[p.room].to_upper()
	heading.add_theme_font_size_override("font_size",18)
	actions.add_child(heading)
	if p.outcome == "solved":
		make_button(actions,"Read reconstruction",func(): show_result(model.reconstruction()))
	else:
		if p.room == 0 and not p.glass:
			make_button(actions,"Collect magnifying glass",func(): show_result(model.collect_glass()))
		var who: int = model.data.present.find(int(p.room))
		var question := make_button(actions,"Question "+Case.NAMES[who],func(): show_result(model.question(who)))
		question.disabled = not p.glass
		question.tooltip_text = "Collect the glass in the foyer first." if not p.glass else "Ask about whereabouts during the attack window."
		var item: int = model.data.item_rooms.find(int(p.room))
		if item >= 0:
			make_button(actions,"Inspect "+Case.ITEMS[item],func(): show_result(model.inspect_item(item)))
		make_button(actions,"Inspect room traces",func(): show_result(model.inspect_floor()))
		if p.weapon >= 0 and int(model.data.item_rooms[p.weapon]) == int(p.room) and p.carried < 0:
			make_button(actions,"Collect identified weapon",func(): show_result(model.collect_weapon()))
	var lines: Array[String] = ["CLAIMED WHEREABOUTS / 10:00–10:10"]
	for who in range(4):
		var key := str(who)
		if not p.claims.has(key):
			lines.append(Case.NAMES[who]+": account not heard")
		else:
			var claim: Dictionary = p.claims[key]
			if model.data.family == "timed_access":
				lines.append("%s: %s / %s" % [Case.NAMES[who],Case.ROOMS[claim.room],Case.ROOMS[claim.later_room]])
			else:
				lines.append("%s: %s, %s" % [Case.NAMES[who],Case.ROOMS[claim.room],"alone" if claim.partner < 0 else "with "+Case.NAMES[claim.partner]])
	if model.data.family == "timed_access":
		lines[0] = "WHEREABOUTS: 10:00–10:05 / 10:05–10:10"
		lines.append("ATTACK TIME: "+("unconfirmed" if p.attack_slot < 0 else ("10:02" if p.attack_slot == 0 else "10:07")))
		lines.append("KEY ACCESS: "+("unconfirmed" if p.keyholders.is_empty() else "%s, %s" % [Case.NAMES[p.keyholders[0]],Case.NAMES[p.keyholders[1]]]))
	lines.append("ATTACK SITE: "+("unconfirmed" if p.crime_room < 0 else Case.ROOMS[p.crime_room]))
	lines.append("WEAPON: "+("unconfirmed" if p.weapon < 0 else Case.ITEMS[p.weapon]+(" (carried)" if p.carried >= 0 else " (in place)")))
	if model.assistance == "assisted":
		lines.append("COMPARE: who fits the time, place AND access?" if model.data.family == "timed_access" else "COMPARE: do the named witnesses agree about room and company?")
		lines.append("\nFULL OBSERVATIONS\n"+"\n\n".join(p.notes))
		notebook.text = "\n".join(lines)
	elif model.assistance == "standard":
		notebook.text = "NOTEBOOK / OBSERVATIONS\n\n"+("\n\n".join(p.notes) if not p.notes.is_empty() else "No findings recorded yet.")
	else:
		notebook.text = "CLASSIC / NO AUTOMATIC NOTEBOOK\n\nKeep your own notes. Guests and evidence can be revisited. The latest response appears on the left."
	write_dev_state()

func present_case() -> void:
	var result: Dictionary = model.accuse(choices[0].selected,choices[1].selected,choices[2].selected)
	show_result(result.text)

func save_lab() -> void:
	var file := FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if file == null:
		show_result("Could not open the lab save.")
		return
	file.store_string(JSON.stringify(model.snapshot()))
	file.close()
	var ok := DirAccess.rename_absolute(SAVE+".tmp",SAVE) == OK
	show_result("Saved this seed and investigation to the separate case-lab slot." if ok else "Could not finish saving the lab.")

func load_lab() -> void:
	if not FileAccess.file_exists(SAVE):
		show_result("No case-lab save yet.")
		return
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not model.restore(saved):
		show_result("The case-lab save is invalid or uses another generator version.")
		return
	seed_box.value = model.data.seed
	if setup != null:
		difficulty_choice.select(0 if model.difficulty == "introductory" else 1)
		assistance_choice.select(["assisted","standard","classic"].find(model.assistance))
		setup.hide()
	show_result("Restored the same case, learned evidence and conversation history.")

func _process(delta: float) -> void:
	if dev_session.is_empty(): return
	ticker += delta
	if ticker < 0.1: return
	ticker = 0
	if FileAccess.file_exists(dev_session+"/capture.request"):
		DirAccess.remove_absolute(dev_session+"/capture.request")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dev_session+"/capture.png")

func write_dev_state() -> void:
	if dev_session.is_empty(): return
	var path := dev_session+"/state.json"
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return
	# No hidden solution is exported in the normal developer status snapshot.
	file.store_string(JSON.stringify({"scene":"case_lab","ready":true,"seed":model.data.seed,
		"room":model.progress.room,"glass":model.progress.glass,
		"accounts":model.progress.claims.size(),"outcome":model.progress.outcome}))
	file.close()
	DirAccess.rename_absolute(path+".tmp",path)
