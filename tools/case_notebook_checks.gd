extends SceneTree
const Notebook = preload("res://src/blockout/case_notebook.gd")
const Session = preload("res://src/mystery/house_case_session.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	var session = Session.new()
	session.begin(2, layout)
	var notebook = Notebook.new()
	root.add_child(notebook)
	await process_frame
	notebook.populate(session)
	check(notebook.get_tab_count() == 4, "Notebook separates Summary, Accounts, Items and Searches")
	check(notebook.summary.get_parsed_text().contains("Blood discovered: Not recorded"), "Unseen crime room is not revealed")
	check(notebook.summary.get_parsed_text().contains("Wound kind: Not recorded"), "Unseen wound is not revealed")
	check(notebook.item_table.get_root().get_child_count() == 0, "Unseen item registry is not exposed")
	var room: int = session.data.murder_room
	var weapon: int = session.data.weapon_room
	session.progress.crime_room = room
	session.progress.wound = session.items[weapon].kind
	session.progress.clean_floors = [(room + 1) % session.room_ids.size()]
	session.progress.heard["0"] = session.data.claims[0]
	session.enter_screen(session.items[weapon].screen)
	session.observe_item(weapon)
	session.progress.items_seen[str(weapon)].stain = "present"
	var state := JSON.stringify(session.progress)
	notebook.current_tab = 2
	notebook.populate(session)
	check(notebook.current_tab == 0, "Opening notebook always starts at Summary")
	var text: String = notebook.summary.get_parsed_text()
	check(text.find("Blood discovered:") < text.find("Victim:"), "Crime-room discovery is prominent above general notes")
	check(text.contains(session.room_names[room]) and text.contains(str(session.progress.wound).capitalize()), "Summary shows recorded blood room and actual wound kind")
	check(not text.contains("Identified weapon:"), "Normal notebook does not solve the weapon automatically")
	check(notebook.item_table.get_root().get_child_count() == 1, "Only observed item becomes a table row")
	var row: TreeItem = notebook.item_table.get_root().get_first_child()
	check(row.get_text(0) == session.item_name(weapon) and row.get_text(2) == "Stained", "Item row retains observed name and stain")
	check(row.get_text(3) == session.screen_names[session.items[weapon].screen], "Item location is recorded by room")
	check(notebook.accounts.get_parsed_text().contains(session.data.cast[0]) and notebook.accounts.get_parsed_text().contains("Not questioned"), "Accounts distinguish heard and unheard guests")
	check(notebook.searches.get_parsed_text().contains("Blood discovered:") and notebook.searches.get_parsed_text().contains(session.room_names[session.progress.clean_floors[0]]), "Search page preserves positive and negative floor observations")
	check(JSON.stringify(session.progress) == state, "Notebook presentation changes no learned facts")
	session.data.cast[-1] = "[b]Victim[/b]"
	notebook.populate(session)
	check(notebook.summary.get_parsed_text().contains("[b]Victim[/b]"), "User names are displayed literally instead of as markup")
	notebook.queue_free()
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
