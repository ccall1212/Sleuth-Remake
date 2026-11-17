extends SceneTree
## Role-aware pronouns must follow the named person, never a nearby name.
const Pronouns = preload("res://src/mystery/character_pronouns.gd")
const Dialogue = preload("res://src/mystery/case_dialogue.gd")
const Presentation = preload("res://src/mystery/guest_presentation.gd")
const Session = preload("res://src/mystery/house_case_session.gd")
const Case = preload("res://src/mystery/generated_case.gd")
const FEMALE := ["Char", "Chloe", "Camille", "Carolyn", "Isabelle", "Sarah Jo", "Jessica"]
const MALE := ["Chris", "Justin", "Danny", "Gage", "Robbie", "Kwinn", "Matt", "John"]
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 30: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var dialogue = Dialogue.new()
	for names in [FEMALE, MALE]:
		var female: bool = names == FEMALE
		for actor in names:
			for role in ["speaker", "victim", "partner", "other", "accused", "culprit"]:
				var input := {role: actor, "room": "Study"}
				var before := input.duplicate(true)
				var slots: Dictionary = Pronouns.slots(input)
				check(slots.get(role + "_subject") == ("she" if female else "he"), actor + " subject in " + role)
				check(slots.get(role + "_Subject") == ("She" if female else "He"), actor + " capitalized subject in " + role)
				check(slots.get(role + "_object") == ("her" if female else "him"), actor + " object in " + role)
				check(slots.get(role + "_possessive") == ("her" if female else "his"), actor + " possessive in " + role)
				check(slots.get(role + "_reflexive") == ("herself" if female else "himself"), actor + " reflexive in " + role)
				check(input == before, "Enrichment preserves caller dictionary")
	var mixed := {"speaker": "Chris", "victim": "Char", "other": "John", "partner": "Chloe", "accused": "Jessica", "culprit": "Matt"}
	check(dialogue.render("{speaker_Subject} says {victim_subject} was afraid of {other_object}; {partner_subject} hid {partner_possessive} book. {accused_Subject} did not do it; {culprit_subject} did it {culprit_reflexive}.", mixed) == "He says she was afraid of him; she hid her book. She did not do it; he did it himself.", "Different roles keep independent identities and grammar")
	check(dialogue.render("The guests said they would bring their books with them.", mixed) == "The guests said they would bring their books with them.", "Genuine plural references remain unchanged")
	check(dialogue.render("{victim_subject}", {}).is_empty() and not dialogue.last_error.is_empty(), "Missing role identity fails rather than choosing another person's pronoun")
	for actor in ["Char", "Chris"]:
		var subject := "She" if actor == "Char" else "He"
		var possessive := "her" if actor == "Char" else "his"
		var standing := {"position": Vector2.ZERO, "posture": "standing", "facing": "south", "activity": "idle"}
		var before := standing.duplicate(true)
		check(Presentation.presentation(standing, "calm", Vector2.RIGHT * 40, true, actor).narration == subject + " turns to address you.", "Standing turn names " + actor + " pronoun with singular verb")
		check(Presentation.presentation(standing, "calm", Vector2.DOWN * 40, true, actor).narration == subject + " answers you.", "Already-facing response has singular verb")
		check(standing == before, "Narration leaves saved guest presentation unchanged")
		for facing in ["north", "south", "east", "west"]:
			var seated := {"position": Vector2.ZERO, "posture": "seated", "facing": facing, "activity": "sleep"}
			var seated_result: Dictionary = Presentation.presentation(seated, "warm", Vector2.RIGHT * 40, true, actor)
			check(seated_result.narration == subject + " wakes and answers from " + possessive + " seat.", "Seated wake uses correct subject/possessive")
			check(seated_result.facing == facing and seated_result.posture == "seated", "Pronouns cannot rotate or stand seated actors")
		var ground := {"position": Vector2.ZERO, "posture": "standing", "facing": "east", "activity": "look_down"}
		check(Presentation.presentation(ground, "fragile", Vector2.DOWN * 40, true, actor).narration == "Without lifting " + possessive + " downcast eyes, " + subject.to_lower() + " answers.", "Downcast response preserves gender and singular agreement")
	for victim in ["Char", "Chris"]:
		var slots := {"speaker": "Matt", "victim": victim, "partner": "Jessica", "other": "John", "accused": "Chloe", "culprit": "Matt", "room": "Study", "true_room": "Study", "chosen_room": "Kitchen", "weapon": "Kitchen knife", "held_item": "Kitchen knife", "chosen_weapon": "Kitchen knife", "alibi": "the Library with Jessica"}
		for voice in dialogue.data.personalities:
			for kind in dialogue.data.personalities[voice]:
				for template in dialogue.data.personalities[voice][kind]:
					var line: String = dialogue.render(str(template), slots)
					check(not line.is_empty() and dialogue.last_error.is_empty() and not line.contains("{"), "All authored banks resolve mixed gender roles: " + voice + "/" + kind + "/" + victim)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.layout.json"))
	for accused in ["Char", "Chris"]:
		for voice in Case.PERSONALITIES:
			var s = Session.new()
			check(s.begin(19, layout), "Case session starts for accusation pronoun check")
			s.data.culprit = 0
			s.data.cast[0] = "Matt"
			s.data.cast[1] = accused
			s.data.cast[-1] = "Jessica" if accused == "Chris" else "John"
			s.data.personalities[0] = voice
			s.progress.assembled = true
			s.progress.carried = s.data.weapon_room
			var truth_before: Dictionary = s.data.duplicate(true)
			var expected_slots: Dictionary = s.truth_slots(-1, int(s.data.murder_room))
			expected_slots.accused = accused
			var expected: String = s.dialogue.personality_line(s.data, 0, "culprit_corrects_person", expected_slots, "wrong_person")
			var result: Dictionary = s.accuse(1, int(s.data.murder_room))
			check(result.result == "wrong_person" and result.message.begins_with(expected), "Wrong-person ending genders actual accused, independently of victim: " + voice + "/" + accused)
			check(not expected.is_empty() and s.dialogue.last_error.is_empty(), "Accusation correction resolves every pronoun")
			check(s.data == truth_before, "Pronoun correction never changes case facts")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
