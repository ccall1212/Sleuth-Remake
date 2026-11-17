extends SceneTree
const Dialogue = preload("res://src/mystery/case_dialogue.gd")
const Case = preload("res://src/mystery/generated_case.gd")
const Stream = preload("res://src/mystery/seed_stream.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var dialogue = Dialogue.new()
	check(dialogue.last_error.is_empty(), "Authored silent refusal banks load")
	check(dialogue.refusal_variants.size() == 8, "Eight voices retained")
	var line_count := 0
	for voice in dialogue.refusal_variants:
		var case_data: Dictionary = Case.generate(2,6,"normal")
		case_data.personalities[0] = voice
		var before := JSON.stringify(case_data)
		var seen := {}
		var source_refusals: Array = dialogue.data.personalities[voice].refusal
		check(source_refusals.size() == 6, str(voice) + ": six authored silent variants")
		for template in dialogue.refusal_variants[voice]:
			line_count += 1
			var rendered: String = dialogue.render(str(template), {"speaker": "Char"})
			check(not rendered.is_empty() and dialogue.last_error.is_empty(), str(voice) + ": valid speaker-only template")
			check(rendered.begins_with("Char ") and rendered.count('"') == 0, str(voice) + ": silent physical refusal, no spoken stall")
			check(not rendered.contains("{") and not rendered.contains("}"), str(voice) + ": no unresolved slots")
			check(rendered.length() <= 190, str(voice) + ": brief refusal")
			for phrase in ["ask me again later", "come back", "try again", "ask again", "guilty", "innocent", "murderer"]:
				check(not rendered.to_lower().contains(phrase), str(voice) + ": no mechanical stall or guilt phrasing")
		for number in range(6):
			var event := "question_refused_%d" % number
			var line: String = dialogue.personality_line(case_data,0,"refusal",{"speaker":"Char"},event)
			check(line == dialogue.personality_line(case_data,0,"refusal",{"speaker":"Char"},event), str(voice) + ": exact replay")
			if number < 6:
				check(not seen.has(line), str(voice) + ": first six refusals differ")
				seen[line] = true
			if number > 0:
				var previous: String = dialogue.personality_line(case_data,0,"refusal",{"speaker":"Char"},"question_refused_%d" % (number-1))
				check(line != previous, str(voice) + ": no consecutive duplicate refusals")
		check(JSON.stringify(case_data) == before, str(voice) + ": no case mutation")
	check(line_count == 48, "Forty-eight authored silent refusals")
	var case_data: Dictionary = Case.generate(2,6,"normal")
	var baseline: String = dialogue.compose_reply(case_data,0,false)
	var rng_a = Stream.new(2,2,"runtime:refusal")
	var rng_b = Stream.new(2,2,"runtime:refusal")
	for number in range(6):
		dialogue.personality_line(case_data,0,"refusal",{"speaker":"Char"},"question_refused_%d" % number)
		check(rng_a.below(1000000) == rng_b.below(1000000), "Text rotation never consumes refusal RNG")
	check(dialogue.compose_reply(case_data,0,false) == baseline, "Refusals never change successful question text")
	print(JSON.stringify({"checks":checks,"refusal_lines":line_count,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
