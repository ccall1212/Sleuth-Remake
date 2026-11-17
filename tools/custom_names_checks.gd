extends SceneTree
## Personalized names (title screen option B): typed names replace the displayed words only.
## Identities (art, poses, pronouns, the truth of the case) are unchanged and the default cast shows the original names.
const Session = preload("res://src/mystery/house_case_session.gd")
const Dialogue = preload("res://src/mystery/case_dialogue.gd")
const Pronouns = preload("res://src/mystery/character_pronouns.gd")
const AccusationCards = preload("res://src/blockout/accusation_cards.gd")
const JournalNotebook = preload("res://src/blockout/journal_notebook.gd")
const JournalState = preload("res://src/mystery/journal_state.gd")
const CastPortrait = preload("res://src/blockout/cast_portrait.gd")
const TYPED := ["Aunt Mabel", "Uncle Ned", "Cousin Pat", "Dr. Quill", "Nurse Joy", "Old Tom", "Mr. Hollis"]
var checks := 0
var failures: Array[String] = []
var layout: Dictionary

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 30: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	for seed_value in range(8):
		var plain = Session.new()
		check(plain.begin(seed_value, layout, "normal"), "Default case starts")
		var typed = Session.new()
		check(typed.begin(seed_value, layout, "normal", TYPED), "Personalized case starts")
		check(typed.data == plain.data, "Typed names never change the generated case or its truth")
		check(typed.display(str(typed.data.cast[0])) == TYPED[0] and typed.display(str(typed.data.cast[-1])) == TYPED[6], "Suspects take the first six names and the victim the seventh")
		# Dialogue shows typed names and never the identity names.
		typed.enable_runtime(layout, {"question_refusal": 0.0, "entry_death": 0.0, "culprit_question_death": 0.0, "guest_leave": 0.0})
		for person in range(6):
			var text: String = typed.question(person)
			check(not text.is_empty() and not text.begins_with("[PENDING"), "Answer builds")
			var identity := str(typed.data.cast[person])
			check(not text.contains(identity) or TYPED.any(func(n): return n.contains(identity)), "Answer from %s never shows the identity name %s" % [TYPED[person], identity])
		check(typed.truth_summary().contains(TYPED[6]) and not typed.truth_summary().contains(str(typed.data.cast[-1])), "Truth summary names the typed victim")
		var notes: String = typed.notebook()
		check(notes.contains("Victim: " + TYPED[6]), "Notebook shows the typed victim")
		# Pronouns still follow the art identity.
		var slots: Dictionary = Pronouns.slots({"speaker": str(typed.data.cast[0])})
		var plain_slots: Dictionary = Pronouns.slots({"speaker": str(plain.data.cast[0])})
		check(slots.speaker_subject == plain_slots.speaker_subject, "Pronouns follow the character art, not the typed name")
		# A later default case clears the names.
		var again = Session.new()
		again.begin(seed_value, layout, "normal")
		check(again.display(str(again.data.cast[0])) == str(again.data.cast[0]), "A default case shows the original names again")
	# UI components display typed names but keep identity keys.
	var typed2 = Session.new()
	typed2.begin(3, layout, "normal", TYPED)
	var names: Array = []
	for person in range(6): names.append(str(typed2.data.cast[person]))
	var cards = AccusationCards.new()
	root.add_child(cards)
	cards.setup(names, "the Library")
	await process_frame
	var labels: Array = cards.find_children("name_label", "Label", true, false).map(func(l): return l.text)
	check(labels.size() == 6 and labels == TYPED.slice(0, 6), "Accusation cards show the typed names")
	check(CastPortrait.bust(names[0]) != null, "Art is still found by identity, not by the typed name")
	var journal := JournalNotebook.new()
	root.add_child(journal)
	var state := JournalState.new()
	journal.setup(state, names, false)
	await process_frame
	var journal_labels: Array = journal.find_children("*", "Label", true, false).map(func(l): return l.text)
	check(TYPED.slice(0, 6).all(func(n): return journal_labels.has(n)), "Journal cards show the typed names")
	var boxes: Array = journal.find_children("*", "CheckBox", true, false)
	boxes[0].button_pressed = true
	check(state.flags_for("suspect", names[0]).size() == 1, "Journal notes are keyed by identity, so typed names cannot collide")
	Dialogue.aliases = {}
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
