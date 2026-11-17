extends SceneTree
const View = preload("res://src/blockout/house_investigation.tscn")
const Cue = preload("res://src/blockout/mystery_sting.gd")
const Preview = preload("res://src/mystery/killer_preview_cases.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var clip := Cue.create_win_stream()
	check(FileAccess.get_sha256(Cue.WIN_PATH) == "3c6105d2e50bbe4595cde18a79c1ce33cd906a22db94689fcc70742fc12d91e9", "Win sound exactly matches supplied MP3")
	check(clip.get_length() > 0 and not clip.loop, "Win MP3 decodes and plays once")
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	for correct in [false, true]:
		view.seed_input.value = Preview.find_seed(2, "Char")
		view.start_case()
		var s = view.investigation
		var held: int = s.data.weapon_room
		if not correct:
			for id in s.items:
				if id != s.data.weapon_room and not s.items[id].is_glass:
					held = id
					break
		s.enter_screen(str(s.items[held].screen))
		s.take_item(held)
		s.progress.assembled = true
		var result: Dictionary = s.accuse(s.data.culprit, s.data.murder_room)
		view.present_ending(result)
		check(view.win_audio.playing == correct, "Victory audio plays only for solved accusation")
		check(view.message_dialog.visible, "Conclusion text does not wait for win sound")
	view.start_case()
	check(not view.win_audio.playing, "New case stops previous victory audio")
	view.queue_free()
	await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures,"win_seconds":clip.get_length()}))
	quit(0 if failures.is_empty() else 1)
