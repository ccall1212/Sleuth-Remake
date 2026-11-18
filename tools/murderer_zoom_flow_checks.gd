extends "res://tools/lens_ui_checks.gd"
## The murderer portrait zoom inside the real ambush flow, for both ambush types, including skipping it.

func ambush_run(view: Control, carrying: bool, skip_midway: bool) -> void:
	var session = view.investigation
	view.message_dialog.hide()
	view.ending_shown = false
	view.ambush_pending = false
	session.progress.outcome = "investigating"
	session.progress.carried = null
	if carrying:
		for id in session.items:
			if id != session.data.glass_room and str(session.items[id].screen) != "":
				session.progress.carried = id
				break
	var key := "ambush_grab" if carrying else "ambush_locked"
	var ending: Dictionary = session.ambush()
	check(ending.message_key == key, "Ambush type %s selected (carrying=%s)" % [key, str(carrying)])
	view.ambush_sting_started = false
	view.present_ending(ending, "standing_threaten_south")
	check(view.ambush_pending and not view.message_dialog.visible, "Approach starts first; dialogue waits")
	view._process(2.0)  # the approach is over: the zoom begins
	check(view.zoom.playing and view.ambush_pending and not view.message_dialog.visible, "Zoom plays before any dialogue (%s)" % key)
	check(view.zoom.get_parent() == view and view.zoom.get_index() > view.hud.get_index(), "Zoom is a separate full-screen layer above the HUD")
	var before: Vector2 = view.guest_portrait.size
	if skip_midway:
		view.zoom.skip()
	else:
		var waited := 0.0
		while view.zoom.playing and waited < 5.0:
			await process_frame
			waited += 0.016
	check(not view.zoom.playing and not view.zoom.visible, "Zoom ends hidden (%s)" % key)
	check(not view.ambush_pending and view.message_dialog.visible, "Dialogue follows the zoom (%s)" % key)
	check(view.message_text.text.contains("\n\n") or view.message_text.text.length() > 20, "Ambush dialogue is readable after the zoom")
	check(view.guest_portrait.visible and view.guest_portrait.size.y <= 310.0 * view.REVEAL_PORTRAIT_BOOST and view.guest_portrait.size.y > 0.0, "The conclusion portrait stays within the enlarged reveal size after the zoom")
	check(session.progress.outcome == "ambushed", "Outcome remains ambushed")
	view.message_dialog.hide()

func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(960, 720)
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	view.seed_input.value = PreviewCases.find_seed(2, "Char", "normal")
	view.start_case()
	view.message_dialog.hide()
	view.ambush_zoom_enabled = true
	view.ambush_zoom_overrides = {"anticipation": 0.02, "zoom_duration": 0.03, "settle_duration": 0.02, "hold": 0.02, "fade_out": 0.02, "flash_duration": 0.01, "shake_duration": 0.01}
	await ambush_run(view, false, false)
	await ambush_run(view, true, false)
	view.ambush_zoom_overrides = {}  # default timings, interrupted by the player
	await ambush_run(view, false, true)
	await ambush_run(view, true, true)
	view.ambush_zoom_enabled = false
	view.message_dialog.hide()
	view.ending_shown = false
	view.ambush_pending = false
	view.investigation.progress.outcome = "investigating"
	var ending: Dictionary = view.investigation.ambush()
	view.present_ending(ending, "standing_threaten_south")
	view._process(2.0)
	check(not view.zoom.playing and view.message_dialog.visible, "With the zoom disabled the old immediate dialogue still works")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
