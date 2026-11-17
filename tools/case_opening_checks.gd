extends SceneTree
## Public victim briefing: presentation only, with no solution/evidence leaks.
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 25: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.gui_embed_subwindows = true
	var view = load("res://src/mystery/painted_mystery.tscn").instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	view.set_process(false)
	check(view.opening_on_start and view.random_on_start, "Painted F5 entry enables randomized case opening")
	check(view.message_dialog.visible and view.modal_open(), "A new mystery opens its blocking briefing")
	check(view.message_dialog.title == "A murder in the mansion" and view.message_dialog.ok_button_text == "Begin investigation", "Opening has clear title and continuation action")
	check(view.message_text.text.contains(str(view.investigation.data.cast[-1])), "Startup briefing names the actual generated victim")
	check(not view.guest_portrait.visible and view.talking_person == -1, "Victim portrait never makes the dead character a speaking guest")
	var template: String = view.dialogue.data.system.case_opening
	var slots := RegEx.new()
	slots.compile("\\{(\\w+)\\}")
	for matched in slots.search_all(template):
		check(matched.get_string(1) in ["victim", "victim_subject", "victim_Subject", "victim_object", "victim_possessive", "victim_reflexive"], "Opening uses public victim identity only")
	check(not template.contains("{culprit}") and not template.contains("{weapon}") and not template.contains("{room}"), "Opening template never requests hidden case solution")
	var at: Vector2 = view.model.position
	var steps: int = view.investigation.runtime.steps
	var clock: float = view.investigation.runtime.danger_clock
	var facts: Dictionary = view.investigation.progress.duplicate(true)
	for count in range(10): view._physics_process(0.1)
	check(view.model.position == at and view.investigation.runtime.steps == steps and view.investigation.runtime.danger_clock == clock, "Time spent reading the opening does not move the investigator or advance danger")
	check(view.investigation.progress == facts and facts.heard.is_empty() and facts.crime_room == null and facts.weapon == null and facts.wound == null, "Opening discovers no accounts, room, weapon or wound facts")
	check(view.reveal.is_active() and view.message_text.visible_characters >= 0 and view.message_text.visible_characters < view.message_text.get_total_character_count(), "Briefing uses gradual text reveal")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_ENTER
	view._input(key)
	check(not view.reveal.is_active() and view.message_dialog.visible, "First Enter reveals the whole opening without dismissing it")
	view.message_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(not view.message_dialog.visible and not view.modal_open(), "Continue action closes opening and enables investigation")
	var previous_seed: int = view.investigation.data.seed
	view.seed_input.value = previous_seed + 1
	view.start_case()
	check(view.message_dialog.visible and view.reveal.is_active() and view.investigation.data.seed == previous_seed + 1, "Starting another case replaces and restarts the opening")
	for actor in ["Char", "Chris", "Jessica", "John"]:
		view.investigation.data.cast[-1] = actor # Isolated public-identity fixture.
		var before: Dictionary = view.investigation.data.duplicate(true)
		view.show_case_opening()
		var subject := "She" if actor in ["Char", "Jessica"] else "He"
		check(view.message_text.text.contains(actor + " is dead. " + subject + " was killed"), "Victim name and pronoun match " + actor)
		check(not view.message_text.text.contains("{") and not view.message_text.text.contains("they was"), "Opening pronouns are completely rendered")
		check(view.item_picture.visible and view.item_picture.texture is AtlasTexture, "Opening displays existing cropped victim art for " + actor)
		var expected: Dictionary = view.actor_art.asset(actor, "standing_idle_south") if view.ActorArt.ACTORS.has(actor) else view.actor_art.playtest_asset(actor)
		if view.item_picture.texture is AtlasTexture:
			check(view.item_picture.texture.atlas == expected.texture and view.item_picture.texture.region == expected.bounds, "Approved/temporary victim portrait matches explicit metadata: " + actor)
		check(view.investigation.data == before and not view.guest_portrait.visible, "Briefing cannot mutate mystery truth or display a living-guest portrait")
	view.investigation.data.cast[-1] = "Char"
	view.show_case_opening()
	view._physics_process(0) # Refresh HUD after the isolated capture identity fixture.
	view.reveal.finish()
	if "--capture-ui" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/case-opening"))
		view.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/case-opening/game.png")
	view.queue_free()
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
