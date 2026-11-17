extends "res://tools/house_investigation_checks.gd"
## Focused dialogue UI regression on the imported painted investigation.

func capture(view: Control, filename: String) -> void:
	if "--capture-ui" not in OS.get_cmdline_user_args():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/dialogue-ui"))
	view._physics_process(0)
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/dialogue-ui/" + filename + ".png")

func freeze(view: Control) -> void:
	view.investigation.runtime.rules.merge({"guest_leave": 0, "activity_redraw": 0,
		"question_refusal": 0, "entry_death": 0, "culprit_question_death": 0}, true)

func close_question(view: Control) -> void:
	view.message_dialog.hide()
	view.talking_person = -1
	check(not view.guest_portrait.visible, "Closing dialogue hides enlarged speaker")

func check_portrait(view: Control, person: int, presented: Dictionary) -> void:
	presented = view.Presentation.portrait_presentation(presented)
	var portrait: TextureRect = view.guest_portrait
	check(portrait.visible and portrait.texture is AtlasTexture, "Question displays cropped existing speaker artwork")
	check(portrait.speaker_name == view.investigation.data.cast[person] and portrait.pose_id == presented.pose_id, "Portrait identifies actual speaker and current conversation pose")
	check(portrait.get_rect().end.y <= float(view.message_dialog.position.y) and Rect2(0, 0, 960, 720).encloses(portrait.get_rect()), "Speaker fits above dialogue without clipping or covering text")

func approach(view: Control, person: int) -> bool:
	var guest: Dictionary = view.investigation.runtime.guests[person]
	if not travel(view, str(guest.screen)):
		return false
	if not walk_to(view, guest.interaction_at):
		return false
	check(view.nearby_guest() == person, "Authored reachable approach selects intended speaker")
	return view.nearby_guest() == person

func run() -> void:
	root.size = Vector2i(960, 720) # fixed reference window so layout checks do not depend on the headless window
	var view = View.instantiate()
	root.add_child(view)
	await process_frame
	view.set_physics_process(false)
	check(view.painted and view.model.data.get("mode") == "painted_investigation", "Run with -- --layout=res://assets/maps/house-02.investigation.layout.json")
	if not failures.is_empty():
		view.queue_free()
		paths.free()
		print(JSON.stringify({"checks": checks, "failures": failures}))
		quit(1)
		return
	view.seed_input.value = 3
	view.start_case()
	freeze(view)
	var session = view.investigation
	check(travel(view, session.room_ids[session.data.glass_room]), "Reach glass before lens dialogue checks")
	walk_to(view, session.items[int(session.data.glass_room)].position)
	view.select_nearby_item(int(session.data.glass_room))
	view.take_nearby()
	var seated := -1
	for person in range(session.runtime.guests.size()):
		if session.runtime.guests[person].posture == "seated":
			seated = person
			break
	check(seated >= 0, "Controlled seed includes a seated speaker")
	if seated >= 0 and approach(view, seated):
		var guest: Dictionary = session.runtime.guests[seated]
		var settled: Dictionary = guest.duplicate(true)
		var claims: Array = session.data.claims.duplicate(true)
		view.ask_nearby()
		var raw: String = session.last_message
		var speech := raw.substr(raw.find('"'))
		var presented: Dictionary = view.guest_presentation(seated, true)
		check_portrait(view, seated, presented)
		check(view.message_dialog.visible and view.message_text.text == presented.narration + "\n\n" + speech, "Seated popup preserves complete speech with only matching physical preface")
		check(not view.message_text.bbcode_enabled and view.message_text.scroll_active, "Full question body is plain, scrollable text")
		check(view.message_dialog.title == "Questioning " + str(session.data.cast[seated]), "Question window identifies its speaker")
		check(guest.position == settled.position and guest.posture == settled.posture and guest.facing == settled.facing and guest.activity == settled.activity, "Question leaves saved seating and activity unchanged")
		check(session.data.claims == claims and session.progress.heard[str(seated)] == claims[seated], "Question records facts without rewriting truth")
		close_question(view)
		session.progress.heard.erase(str(seated))
		session.runtime.rules.question_refusal = 1
		view.ask_nearby()
		check(session.last_message_key == "refusal" and not session.progress.heard.has(str(seated)), "Forced refusal records no alibi")
		check_portrait(view, seated, view.guest_presentation(seated, true))
		check(view.message_text.text == session.last_message, "Silent refusal keeps complete authored action without invented speech")
		check(not view.message_text.text.begins_with("They answer"), "Refusal does not claim a successful answer")
		close_question(view)
		session.runtime.rules.question_refusal = 0
		view.ask_nearby()
		check(session.last_message_key == "opening", "First successful answer after refusal remains a first answer")
		close_question(view)
		view.ask_nearby()
		check(session.last_message_key == "repeat_lead", "Next successful answer uses repeat text")
		close_question(view)
	# Exercise authored warm text in a standing presentation using a real slot.
	var standing := -1
	for person in range(session.runtime.guests.size()):
		if session.runtime.guests[person].posture == "standing":
			standing = person
			break
	if standing >= 0 and approach(view, standing):
		var guest: Dictionary = session.runtime.guests[standing]
		session.data.personalities[standing] = "warm" # Controlled cosmetic fixture.
		guest.staring = false
		guest.activity = "idle"
		session.progress.heard.erase(str(standing))
		view.ask_nearby()
		var first: String = view.message_text.text
		check_portrait(view, standing, view.guest_presentation(standing, true))
		check(first.ends_with(session.last_message), "Standing first popup retains full authored account")
		await capture(view, "warm-first")
		close_question(view)
		view.ask_nearby()
		check(session.last_message_key == "repeat_lead" and view.message_text.text != first, "Warm repeated question visibly uses its concise repeat")
		await capture(view, "warm-repeat")
		close_question(view)
	# Blood clues and phase warnings use styles, never wording guesses.
	if travel(view, session.room_ids[session.data.murder_room]):
		view.examine_floor()
		check(session.last_message_key.begins_with("wound_") and view.feedback_color == view.dialogue.color("system", session.last_message_key, Color.MAGENTA), "Crime-room discovery includes a red wound hint")
		await capture(view, "floor-blood")
	if travel(view, session.room_ids[session.data.weapon_room]):
		walk_to(view, session.items[int(session.data.weapon_room)].position)
		view.examine_nearby()
		check(not view.guest_portrait.visible, "Object inspection never retains an unrelated guest portrait")
		check(session.last_message_key == "lens_stain" and view.feedback_color == view.dialogue.color("system", "lens_stain", Color.MAGENTA), "Normal lens shows an orange stain without naming the weapon")
	check(not view.feedback_text.bbcode_enabled and not view.warning_text.bbcode_enabled, "HUD feedback and warnings are plain text")
	# Every case identity resolves existing approved or temporary speaker art.
	var saved_name: String = session.data.cast[0]
	for actor in Case.POOL:
		session.data.cast[0] = actor
		view.show_guest_portrait(0, {"pose_id": "standing_idle_south", "facing": "south"})
		var expected: Dictionary = view.actor_art.asset(actor, "standing_idle_south") if view.ActorArt.ACTORS.has(actor) else view.actor_art.playtest_asset(actor)
		check(view.guest_portrait.visible and view.guest_portrait.speaker_name == actor and view.guest_portrait.texture.atlas == expected.texture and view.guest_portrait.texture.region == expected.bounds, "Correct original artwork resolves for portrait: " + str(actor))
	for actor in ["Char", "Chris"]:
		session.data.cast[0] = actor
		var saved_guest: Dictionary = session.runtime.guests[0].duplicate(true)
		view.say("They answer you.", true)
		view.message_dialog.title = "Questioning " + actor
		view.show_guest_portrait(0, {"posture": "standing", "activity": "talk", "pose_id": "standing_talk_north", "facing": "north"})
		check(view.guest_portrait.pose_id == "standing_talk_south" and session.runtime.guests[0] == saved_guest, "North conversation shows face in portrait without moving guest: " + actor)
		if actor == "Char": await capture(view, "north-face-portrait")
	session.data.cast[0] = saved_name
	view.say("A room observation.", true)
	check(not view.guest_portrait.visible, "System observation clears any previous speaker art")
	view.message_dialog.hide()
	session.runtime.steps = session.runtime.warning_at
	session.runtime.danger_clock = session.runtime.warning_at
	view._physics_process(0)
	check(view.warning_text.text.contains("The murderer is suspicious of you"), "Suspicion warning explicitly names murderer state")
	check(view.warning_text.get_theme_color("default_color") == view.dialogue.color("system", "warning_suspicious", Color.MAGENTA), "Suspicion warning uses yellow style")
	await capture(view, "warning-yellow")
	session.runtime.steps = session.runtime.stalking_at
	session.runtime.danger_clock = session.runtime.stalking_at
	view._physics_process(0)
	check(view.warning_text.text.contains("The murderer is stalking you"), "Stalking warning explicitly names murderer state")
	check(view.warning_text.get_theme_color("default_color") == view.dialogue.color("system", "warning_stalking", Color.MAGENTA), "Stalking warning uses orange style")
	# Both approved reveal actors must get red text in the HUD and conclusion.
	for actor in ["Char", "Chris"]:
		view.pose_window.hide()
		view.ending_shown = false
		session.data.cast[session.data.culprit] = actor # Controlled ending fixture.
		session.progress.outcome = "investigating"
		session.progress.carried = null
		var ending: Dictionary = session.ambush()
		view.present_ending(ending, "standing_threaten_south")
		view.finish_ambush()
		var red: Color = view.dialogue.color("personality_lines", "ambush_locked", Color.MAGENTA)
		check(view.message_dialog.visible and view.message_text.text == ending.message and view.guest_portrait.speaker_name == actor, actor + ": ordinary dialogue shows complete ambush text and killer portrait")
		check(view.feedback_color == red and view.message_text.get_theme_color("default_color") == red, actor + ": whole ambush is red in HUD and dialogue")
		view.message_dialog.hide()
	view.queue_free()
	await process_frame
	paths.free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
