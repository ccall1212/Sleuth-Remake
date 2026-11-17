extends SceneTree
const View = preload("res://src/blockout/house_investigation.tscn")
const Case = preload("res://src/mystery/generated_case.gd")
const Preview = preload("res://src/mystery/killer_preview_cases.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	var voices_seen := {}
	for index in range(8):
		if index > 0:
			view.seed_input.value += 101
			view.start_case()
		var data: Dictionary = view.investigation.data
		check(data.cast[data.culprit] == ["Char", "Chris"][index % 2], "Next preview alternates requested killer")
		var voice: String = data.personalities[data.culprit]
		check(voice == Preview.VOICE_ORDER[index], "Next preview uses the next unseen killer personality")
		voices_seen[voice] = true
		check(data == Case.generate(int(view.seed_input.value), 6, "normal"), "Selected preview is a complete original generated case")
		check(view.killer_preview_remaining == 7 - index, "Preview expires after eight successfully started cases")
		var ending: Dictionary = view.investigation.ambush()
		view.present_ending(ending, "standing_threaten_south")
		view.finish_ambush()
		check(view.message_dialog.visible and view.guest_portrait.speaker_name == data.cast[data.culprit], "Ambush dialogue shows actual killer artwork")
		check(view.guest_portrait.pose_id == "standing_threaten_south", "Locked-door ambush uses approved threat pose")
		view.message_dialog.hide()
		view.ending_shown = false
		view.investigation.progress.outcome = "investigating"
		view.investigation.progress.carried = data.weapon_room
		view.investigation.progress.assembled = true
		var accused: Dictionary = view.investigation.accuse(data.culprit, data.murder_room)
		view.present_ending(accused)
		check(view.message_dialog.visible and view.guest_portrait.speaker_name == data.cast[data.culprit], "Accusation dialogue shows actual killer artwork")
		check(view.guest_portrait.visible and view.guest_portrait.pose_id == Preview.confession_pose(voice, str(data.cast[data.culprit])), "Accusation portrait matches approved killer/personality art: " + voice)
		check(accused.message_key == "confession" and "[PENDING_DIALOGUE:" not in view.message_text.text and "{" not in view.message_text.text, "Accusation shows latest complete authored confession")
	check(voices_seen.size() == Case.PERSONALITIES.size(), "Eight previews use every killer personality exactly once")
	view.random_case.button_pressed = false
	view.seed_input.value = 123
	view.start_case()
	check(view.investigation.data == Case.generate(123, 6, "normal"), "Fixed replay stays exact after preview expires")
	view.queue_free()
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
