extends SceneTree
const View = preload("res://src/blockout/house_investigation.tscn")
const Preview = preload("res://src/mystery/killer_preview_cases.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func capture(view: Control, name: String) -> void:
	if "--capture-ui" not in OS.get_cmdline_user_args(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/encounter-ui"))
	view._physics_process(0)
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/encounter-ui/" + name + ".png")

func run() -> void:
	root.gui_embed_subwindows = true
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	view.set_process(false)
	view.seed_input.value = Preview.find_seed(2, "Char")
	view.start_case()
	var s = view.investigation
	var truth: Dictionary = s.data.duplicate(true)
	view.model.inspect_screen(s.room_ids[s.data.glass_room])
	s.enter_screen(view.model.current_id)
	s.take_item(int(s.data.glass_room))
	view.model.inspect_screen(s.room_ids[s.data.murder_room])
	s.enter_screen(view.model.current_id)
	view.examine_floor()
	check(view.message_dialog.visible and s.progress.crime_room == s.data.murder_room, "Blood discovery opens readable popup and records room")
	check(view.message_dialog.title.contains("Wound kind: " + str(s.items[s.data.weapon_room].kind)), "Floor window explicitly shows actual item wound kind")
	check(view.message_text.text.contains("\n\n") and view.reveal.is_active(), "Full wound paragraph remains in rolling dialogue")
	view.reveal.finish()
	await capture(view, "floor-clue")
	view.show_notebook()
	check(view.notebook_view.current_tab == 0 and view.notebook_text.get_parsed_text().contains("Blood discovered:"), "Notebook opens evidence summary first")
	check(view.notebook_text.get_parsed_text().contains(s.room_names[s.data.murder_room]) and view.notebook_text.get_parsed_text().contains("Wound kind:"), "Recorded blood room and wound are visible in summary")
	check(view.notebook_view.get_tab_count() == 4, "Notebook separates summary, accounts, items and searches")
	await capture(view, "notebook-summary")
	view.notebook_dialog.hide()
	view.model.inspect_screen("room_4")
	view.model.position = Vector2(360, 280)
	s.enter_screen("room_4")
	s.runtime.player_screen = "room_4"
	for person in range(s.runtime.guests.size()):
		s.runtime.guests[person].screen = "library"
	var killer: int = s.data.culprit
	s.runtime.guests[killer].screen = "room_4"
	s.runtime.guests[killer].position = Vector2(80, 260)
	s.runtime.guests[killer].interaction_at = Vector2(80, 260)
	view.refresh_guests()
	check(s.runtime.can_ambush("room_4"), "Encounter fixture is alone with killer")
	var ending: Dictionary = s.ambush()
	view.present_ending(ending, "standing_threaten_south")
	check(view.ambush_pending and not view.message_dialog.visible and not view.pose_window.visible, "Ambush starts in room before dialogue, without grey pose viewer")
	var initial: Vector2 = view.ambush_position
	view._process(0.45)
	check(view.ambush_position.distance_to(view.model.position) < initial.distance_to(view.model.position), "Killer closes in on investigator")
	check(view.model.current_id == "room_4" and view.model.position == Vector2(360, 280), "Approach leaves inspector and room unchanged")
	await capture(view, "approach")
	view._process(maxf(0.9, view.door_lock_audio.stream.get_length()) - 0.45 + 0.01)
	check(view.ambush_sting_started and view.message_dialog.visible, "Dialogue begins as the sting starts")
	check(not view.ambush_pending and not view.pose_window.visible and view.sting.playing, "Sting continues underneath normal portrait dialogue")
	check(view.guest_portrait.speaker_name == "Char" and view.guest_portrait.pose_id == "standing_threaten_south", "Ambush uses approved threat portrait")
	check(view.reveal.is_active() and view.message_text.visible_characters == 0, "Speech starts hidden for typewriter")
	view._process(0.8)
	check(view.message_text.visible_characters > 0 and view.message_text.visible_characters < view.message_text.get_total_character_count(), "Speech rolls out instead of appearing all together")
	await capture(view, "ambush-dialogue")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_SPACE
	view._input(key)
	check(not view.reveal.is_active() and view.message_dialog.visible, "Space reveals remaining text without closing dialogue")
	check(view.message_text.text == ending.message and s.data == truth, "Presentation preserves complete authored dialogue and case truth")
	view.sting.stop()
	view.door_lock_audio.stop()
	view.queue_free()
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
