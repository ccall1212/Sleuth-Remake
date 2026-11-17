extends SceneTree
const Session = preload("res://src/mystery/house_case_session.gd")
const Assembly = preload("res://src/mystery/house_assembly.gd")
const Layout = preload("res://src/blockout/house_layout.gd")
const View = preload("res://src/blockout/house_investigation.tscn")
var checks := 0
var failures: Array[String] = []
var sample: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 25:
		failures.append(label)

func equip(s: RefCounted) -> void:
	s.enter_screen(s.room_ids[s.data.glass_room])
	s.take_item(s.data.glass_room)
	s.enter_screen(s.room_ids[s.data.weapon_room])
	s.inspect_item(s.data.weapon_room)
	s.drop_item(s.items[s.data.weapon_room].position)
	s.take_item(s.data.weapon_room)

func signature(world: RefCounted) -> String:
	return JSON.stringify(world.guests.map(func(g): return [g.screen, g.position, g.facing, g.posture, g.activity, g.staring, g.move_rng.counter, g.activity_rng.counter]))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for path in ["res://assets/maps/house-02.layout.json", "res://assets/maps/house-02.investigation.layout.json"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var original_layout := JSON.stringify(layout)
		for seed_value in range(20):
			var s = Session.new()
			check(s.begin(seed_value, layout, "hard"), "Assembly case begins")
			var original_case: Dictionary = s.data.duplicate(true)
			check(not s.assemble() and not s.progress.assembled, "No gathering with empty hands")
			equip(s)
			var current_room := "room_4" # Kitchen; the legacy id 'kitchen' is Study.
			s.enter_screen(current_room)
			check(s.progress.carried == s.data.weapon_room, "Real evidence callbacks equip true weapon")
			check(s.assemble() and s.active() and s.progress.assembled, "Gathering is a distinct active stage before accusation")
			check(s.progress.assembly_room == current_room and s.screen_names[s.progress.assembly_room] == "Kitchen", "Gathering stays in the current Kitchen")
			check(s.runtime.guests.size() == s.data.claims.size() and s.runtime.guests.size() == 6, "Exactly six living suspects gathered; victim is not an extra actor")
			check(s.progress.screen == s.progress.assembly_room and s.runtime.player_screen == s.progress.assembly_room, "Session and runtime enter the gathering room together")
			var player := Layout.point(s.progress.assembly_position)
			check(Assembly.safe_contact(s.runtime.geometry, s.progress.assembly_room, player), "Investigator gathering arrival has floor, furniture and door clearance")
			var ids := {}
			var positions := {}
			for person in range(s.runtime.guests.size()):
				var guest: Dictionary = s.runtime.guests[person]
				check(guest.screen == s.progress.assembly_room, "Every living cast member is physically in the one room")
				check(guest.posture == "standing" and guest.activity == "idle" and guest.kind == "stand", "Gathering supports all current standing artwork")
				check(Assembly.safe_contact(s.runtime.geometry, guest.screen, guest.position), "Gathered guest has real collision and door clearance")
				check(Rect2(0, 0, 480, 360).encloses(Rect2(guest.position - Vector2(32, 82), Vector2(64, 82))), "Full standing silhouette fits room viewport")
				check(guest.position.distance_to(player) >= Assembly.SEPARATION, "Guests do not cover investigator arrival")
				check(not ids.has(guest.slot_id) and not positions.has(guest.position), "Temporary gathering contacts are unique")
				check(guest.interaction_at == guest.position, "Every gathered guest can be approached on open floor")
				ids[guest.slot_id] = true
				positions[guest.position] = true
				for other in range(person):
					check(guest.position.distance_to(s.runtime.guests[other].position) >= Assembly.SEPARATION, "Gathered sprite contacts remain separated")
			var before := signature(s.runtime)
			var clock: int = s.runtime.steps
			s.observe_world(clock + 2000, s.room_ids[0])
			check(signature(s.runtime) == before and s.runtime.steps == clock and not s.runtime.dead, "Gathering freezes relocation and danger while player can look around")
			check(s.progress.screen == s.progress.assembly_room, "Session rejects a locked-room departure")
			check(s.assemble() and signature(s.runtime) == before, "Gathering is idempotent and does not rearrange the cast again")
			var speech: String = s.question(s.data.culprit)
			check(not speech.is_empty() and s.active() and signature(s.runtime) == before, "Post-gathering questions do not move or ambush guests")
			var text: String = s.assemble_message()
			check(text == s.assemble_message() and str(s.screen_names[current_room]) in text and ("lock" in text or "key" in text), "Authored gathering prose describes actual room and locking stage")
			check(s.data == original_case, "Gathering changes no culprit, claims, clue locations or personality")
			check(JSON.stringify(layout) == original_layout, "User-authored map and guest positions are not rewritten")
			if seed_value == 2 and path.contains("investigation"):
				sample = {"room": s.progress.assembly_room, "player": s.progress.assembly_position,
					"guests": s.runtime.guests.map(func(g): return [g.position.x, g.position.y])}
			var ending: Dictionary = s.accuse(s.data.culprit, s.data.murder_room)
			check(ending.result == "solved" and not s.active(), "Explicit later accusation still resolves the case")
	# Cached plans must remain bound to the requested screen, including halls.
	var painted = Layout.new()
	check(painted.load_layout("res://assets/maps/house-02.investigation.layout.json"), "Painted gathering geometry loads")
	var fitted: Array[String] = []
	for id in painted.screens:
		var plan: Dictionary = Assembly.prepare(painted, 6, str(id))
		check(plan.has("error") or plan.room == id, "A gathering plan never selects another screen: " + str(id))
		if not plan.has("error"):
			fitted.append(str(id))
			check(plan.slots.size() == 6, "Requested screen fits exactly six contacts: " + str(id))
	var kitchen_plan: Dictionary = Assembly.prepare(painted, 6, "room_4")
	check(not kitchen_plan.has("error") and kitchen_plan.room == "room_4", "Kitchen cache remains Kitchen after requesting every other screen")
	# An unusable current room fails safely rather than silently relocating.
	var tiny = Session.new()
	var tiny_layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	tiny.begin(2, tiny_layout)
	tiny.enable_runtime(tiny_layout)
	equip(tiny)
	tiny.enter_screen("room_4")
	tiny.runtime.geometry.screens.room_4.obstacles = [[0, 0, 480, 360]]
	var tiny_progress := JSON.stringify(tiny.progress)
	var tiny_guests := signature(tiny.runtime)
	check(not tiny.assemble(), "No clear room space refuses gathering without fallback")
	check(JSON.stringify(tiny.progress) == tiny_progress and signature(tiny.runtime) == tiny_guests, "Insufficient space leaves room, progress and guests unchanged")
	# Text-only refusal rotation never records an alibi or changes probability.
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.layout.json"))
	var refused = Session.new()
	refused.begin(7, layout)
	refused.enable_runtime(layout, {"culprit_question_death": 0})
	check(is_equal_approx(float(refused.runtime.rules.question_refusal), 0.10), "Runtime uses the approved ten-percent refusal rate")
	refused.runtime.rules.question_refusal = 1
	refused.enter_screen(refused.guest_screen(0))
	var texts := {}
	for count in range(3):
		texts[refused.question(0)] = true
	check(texts.size() == 3 and refused.refusal_counts[0] == 3, "Consecutive silent refusals rotate text without repeating")
	check(texts.keys().all(func(text): return not str(text).contains('"') and not str(text).to_lower().contains("ask me")), "Refusal rotation remains silent rather than requesting another question")
	check(refused.progress.heard.is_empty() and refused.runtime.rules.question_refusal == 1, "Refusal wording changes no heard facts or refusal rate")
	refused.runtime.rules.question_refusal = 0
	refused.question(0)
	check(refused.last_message_key == "opening" and refused.progress.heard["0"] == refused.data.claims[0], "First actual answer remains first after refusals")
	refused.begin(7, layout)
	check(refused.refusal_counts.is_empty(), "New case resets text-only refusal counters")
	if "--capture-ui" in OS.get_cmdline_user_args():
		root.gui_embed_subwindows = true
		var view = View.instantiate()
		root.add_child(view)
		await process_frame
		await process_frame
		equip(view.investigation)
		view.model.inspect_screen("room_4")
		view.investigation.enter_screen("room_4")
		view.assemble_case()
		view.message_dialog.hide()
		view.accusation_dialog.hide()
		view._physics_process(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/house-investigation"))
		check(view.get_viewport().get_texture().get_image().save_png("res://test-results/house-investigation/assembly-kitchen-preview.png") == OK, "Native Kitchen gathering preview captured")
		view.queue_free()
		await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "painted_sample": sample, "fitted_screens": fitted}))
	quit(0 if failures.is_empty() else 1)
