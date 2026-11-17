extends "res://tools/lens_ui_checks.gd"
## The title screen inside the real game: backdrop, difficulty, default and personalized cast.
const Dialogue = preload("res://src/mystery/case_dialogue.gd")
const TYPED := ["Aunt Mabel", "Uncle Ned", "Cousin Pat", "Dr. Quill", "Nurse Joy", "Old Tom", "Mr. Hollis"]

func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(960, 720)
	var view = View.instantiate()
	view.title_on_start = true
	view.opening_on_start = true
	view.random_on_start = true
	root.add_child(view)
	await process_frame
	check(view.title_menu.visible and view.title_menu.current_screen() == "menu" and view.title_open, "The title screen opens first")
	check(view.modal_open() and not view.message_dialog.visible, "The game is blocked and no briefing shows behind the title")
	check(not view.hud.visible, "The HUD is hidden behind the title")
	# Opening the setup screen shows the exact cast of the upcoming case; Begin uses that same seed.
	view.title_menu.btn_start.pressed.emit()
	await process_frame
	check(view.title_menu.current_screen() == "setup" and view.title_menu.name_edits.size() == 7, "Setup shows seven cast cards")
	var seed_shown: int = view.title_menu.cast_seed
	check(seed_shown >= 0, "Opening setup previews a cast from a seed")
	var shown_cast: Array = view.Session.Case.generate(seed_shown, 6, "normal", view.Session.Case.POOL, [], view.Session.blocked_rooms(view.model.data)).cast
	var portraits_ok := true
	for edit in view.title_menu.name_edits: portraits_ok = portraits_ok and edit.placeholder_text in shown_cast
	check(portraits_ok, "Each field's placeholder is the real name of a character in the previewed cast")
	view.title_menu.btn_reroll.pressed.emit()
	check(view.title_menu.cast_seed >= 0, "Different cast keeps a valid previewed seed")
	# Default characters, Hard, using the previewed seed.
	view.title_menu.start_requested.emit({"difficulty": "hard", "custom_names": [], "seed": 4242})
	await process_frame
	check(view.investigation.data.seed == 4242, "Begin starts exactly the seed whose cast the player saw")
	check(not view.title_menu.visible and not view.title_open and view.hud.visible, "Beginning hides the title and shows the HUD")
	check(view.investigation.data.difficulty == "hard", "Chosen difficulty starts the case")
	check(view.message_dialog.visible and view.message_dialog.title == "A murder in the mansion", "The briefing opens after the title")
	check(Dialogue.aliases.is_empty(), "Default characters keep their own names")
	view.message_dialog.hide()
	# Personalized, Easy.
	view.open_title()
	check(view.title_open and view.modal_open(), "The title can be reopened from the pause menu")
	view.title_menu.start_requested.emit({"difficulty": "easy", "custom_names": TYPED})
	await process_frame
	var session = view.investigation
	check(session.data.difficulty == "easy" and not Dialogue.aliases.is_empty(), "Personalized easy case starts with aliases")
	check(session.display(str(session.data.cast[0])) == TYPED[0], "Typed names reach the case")
	check(view.message_text.text.contains(TYPED[6]), "The briefing uses the typed victim name")
	view.message_dialog.hide()
	view.start_case()
	check(not Dialogue.aliases.is_empty(), "A new mystery from the pause menu keeps the personalized names")
	view.open_title()
	view.title_menu.start_requested.emit({"difficulty": "normal", "custom_names": []})
	await process_frame
	check(Dialogue.aliases.is_empty(), "Choosing default characters clears the names")
	Dialogue.aliases = {}
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
