extends SceneTree
const Case = preload("res://src/mystery/lab_case.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func visit(model: RefCounted, room: int) -> void:
	# The lab's square graph has a route of at most two edges.
	if int(model.progress.room) == room: return
	if room in Case.LINKS[model.progress.room]: model.travel(room)
	else:
		model.travel(Case.LINKS[model.progress.room][0])
		model.travel(room)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var signatures := {}
	var culprits := {}
	var crime_rooms := {}
	var variants := {}
	var colocated := false
	for seed_value in range(100):
		var model = Case.new(seed_value)
		var data: Dictionary = model.data
		check(Case.validate(data),"Unique clue-supported answer: seed "+str(seed_value))
		check(data == Case.generate(seed_value),"Deterministic seed "+str(seed_value))
		signatures[JSON.stringify([data.claims,data.trace_room,data.marked_item])] = true
		culprits[data.truth.culprit] = true
		crime_rooms[data.trace_room] = true
		variants[data.variant] = true
		colocated = colocated or data.item_rooms[data.marked_item] == data.trace_room
		var known := Case.all_clues(data)
		var expected: Array = Case.candidates(known)
		var changed: Dictionary = data.duplicate(true)
		changed.truth.culprit = (data.truth.culprit+1)%4
		changed.truth.locations = [3,3,3,3]
		changed.voices.reverse()
		check(Case.candidates(Case.all_clues(changed)) == expected,"Deduction ignores secret answer and voice")
		check(not Case.validate(changed),"Reject hidden solution inconsistent with clues")
		check(Case.candidates({}).size() == 48,"Unknown evidence leaves alternatives")
		var broken := known.duplicate(true)
		broken.clear_items = [data.marked_item]
		check(Case.candidates(broken).is_empty(),"Contradictory physical evidence rejected")
		# Both glass and collection gates are exercised through the gameplay API.
		check(not model.progress.glass,"Fresh case has no lens")
		check(model.accuse(0,0,0).result == "blocked","Early accusation blocked")
		model.collect_glass()
		for room in range(4):
			visit(model,room)
			check(int(model.progress.room) == room,"Connected route reaches every room")
			var who: int = data.present.find(room)
			model.question(who)
			var first: Dictionary = model.progress.claims[str(who)].duplicate(true)
			model.question(who)
			check(model.progress.claims[str(who)] == first,"Recap preserves learned claim")
			model.inspect_floor()
			var item: int = data.item_rooms.find(room)
			if item >= 0: model.inspect_item(item)
		check(model.progress.carried == -1,"Inspection never auto-collects weapon")
		var visible_answer: Dictionary = Case.candidates(model.progress)[0]
		check(Case.candidates(model.progress).size() == 1,"Playable evidence leaves one reconstruction")
		visit(model,data.item_rooms[model.progress.weapon])
		model.collect_weapon()
		check(model.progress.carried == visible_answer.weapon,"Late weapon collection succeeds")
		check(model.accuse((visible_answer.suspect+1)%4,visible_answer.weapon,visible_answer.room).result == "wrong","Wrong suspect not accepted")
		check(model.accuse(visible_answer.suspect,(visible_answer.weapon+1)%3,visible_answer.room).result == "wrong","Wrong weapon not accepted")
		check(model.accuse(visible_answer.suspect,visible_answer.weapon,(visible_answer.room+1)%4).result == "wrong","Wrong room not accepted")
		var saved: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
		var restored = Case.new(999)
		check(restored.restore(saved) and restored.progress.claims == model.progress.claims,"JSON save round trip preserves case and memory")
		var corrupt: Dictionary = saved.duplicate(true)
		corrupt.progress.claims["0"].room = (int(corrupt.progress.claims["0"].room)+1)%4
		check(not restored.restore(corrupt),"Reject altered saved testimony")
		check(restored.accuse(visible_answer.suspect,visible_answer.weapon,visible_answer.room).result == "solved","Clue-derived reconstruction reaches ending")
	check(signatures.size() > 90,"Seeds vary evidence and claim bindings")
	check(culprits.size() == 4 and crime_rooms.size() == 4 and variants.size() == 2,"All roles rooms and contradiction variants covered")
	check(colocated,"Weapon may share crime room")
	# A different reasoning structure: time and access each leave two suspects.
	var slots := {}
	for seed_value in range(100):
		var model = Case.new(seed_value,"standard",["assisted","standard","classic"][seed_value%3])
		var data: Dictionary = model.data
		check(Case.validate(data),"Timed access has unique supported answer")
		check(data == Case.generate(seed_value,"standard"),"Timed access deterministic")
		slots[data.attack_slot] = true
		var known := Case.all_clues(data)
		var without_time: Dictionary = known.duplicate(true)
		without_time.attack_slot = -1
		check(Case.candidates(without_time).size() == 2,"Access without time leaves two suspects")
		var without_access: Dictionary = known.duplicate(true)
		without_access.keyholders = []
		check(Case.candidates(without_access).size() == 2,"Time without access leaves two suspects")
		var accounts_only := {"family":data.family,"claims":known.claims}
		check(Case.candidates(accounts_only).size() > 2,"Accounts alone cannot solve timed case")
		var changed: Dictionary = data.duplicate(true)
		changed.truth.culprit = (data.truth.culprit+1)%4
		check(Case.candidates(Case.all_clues(changed)) == Case.candidates(known),"Timed deduction ignores hidden culprit")
		check(not Case.validate(changed),"Timed validator rejects mismatched culprit")
		model.collect_glass()
		for room in range(4):
			visit(model,room)
			var who: int = data.present.find(room)
			model.question(who)
			model.inspect_floor()
			var item: int = data.item_rooms.find(room)
			if item >= 0: model.inspect_item(item)
		check(Case.candidates(model.progress).size() == 1,"Gameplay reveals complete timed evidence")
		check(model.progress.notes.is_empty() == (model.assistance == "classic"),"Classic stores no automatic clue history")
		var restored = Case.new(999)
		check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))),"Timed case JSON round trip")
		check(restored.difficulty == "standard" and restored.assistance == model.assistance and restored.progress == model.progress,"Save preserves options and learned facts")
		visit(restored,data.item_rooms[data.marked_item])
		restored.collect_weapon()
		var answer: Dictionary = Case.candidates(restored.progress)[0]
		check(restored.accuse(answer.suspect,answer.weapon,answer.room).result == "solved","Timed case solves from obtained clues")
	check(slots.size() == 2,"Both attack windows generated")
	# UI smoke: press actual bound controls, then interact through the lab screen API.
	var lab = load("res://src/mystery/case_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	check(lab.room_buttons.size() == 4 and lab.choices.size() == 3,"Lab exposes rooms and reconstruction controls")
	check(lab.setup.visible,"New game opens options before investigation")
	lab.difficulty_choice.select(1)
	lab.assistance_choice.select(2)
	lab.begin_setup()
	check(lab.model.difficulty == "standard" and lab.model.assistance == "classic" and not lab.setup.visible,"Start applies independent options")
	lab.actions.get_child(1).pressed.emit()
	check(lab.model.progress.glass,"Collect button is connected")
	lab.room_buttons[1].pressed.emit()
	check(lab.model.progress.room == 1,"Room button moves to correct room")
	var in_room: int = lab.model.data.present.find(1)
	lab.actions.get_child(1).pressed.emit()
	check(lab.model.progress.claims.has(str(in_room)) and not lab.notebook.text.is_empty(),"Question button updates notebook")
	check(not lab.notebook.text.contains("claims:") and lab.model.progress.notes.is_empty(),"Classic UI does not show learned history")
	lab.start_seed(3,"standard","standard")
	lab.model.collect_glass()
	var local_guest: int = lab.model.data.present.find(0)
	lab.show_result(lab.model.question(local_guest))
	check(lab.notebook.text.contains("claims:") and not lab.notebook.text.contains("COMPARE:"),"Standard shows raw observations without prompts")
	lab.start_seed(3,"standard","assisted")
	lab.refresh()
	check(lab.notebook.text.contains("COMPARE:") and lab.notebook.text.contains("10:05"),"Assisted offers structured timeline comparison")
	lab.start_seed(3)
	check(not lab.model.progress.glass and lab.model.progress.claims.is_empty(),"New seed resets investigation")
	if "--capture" in OS.get_cmdline_user_args():
		lab.open_setup(3)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/case-lab-preview.png")
	lab.queue_free()
	await process_frame
	var report := {"ok":failures.is_empty(),"checks":checks,"seeds":200,"families":2,"case_signatures":signatures.size(),"failures":failures}
	var file := FileAccess.open("res://test-results/case-lab-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("CASE_LAB_CHECKS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
