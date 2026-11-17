extends SceneTree
const Preview = preload("res://src/mystery/killer_preview_cases.gd")
const Case = preload("res://src/mystery/generated_case.gd")
const Session = preload("res://src/mystery/house_case_session.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	var baseline: Dictionary = Case.generate(27, 6, "normal")
	var wrapped := false
	for target in ["Char", "Chris"]:
		for difficulty in ["easy", "normal", "hard"]:
			for first in [0, 47, 999999999]:
				var selected: int = Preview.find_seed(first, target, difficulty)
				check(selected >= 0 and selected < Preview.SEED_LIMIT, "Preview seed is in supported replay range")
				if selected < 0:
					continue
				var truth: Dictionary = Case.generate(selected, 6, difficulty)
				check(truth.cast[truth.culprit] == target, "Naturally generated culprit matches requested preview identity")
				check(selected == Preview.find_seed(first, target, difficulty), "Same preview request repeats the same complete case seed")
				var distance := posmod(selected - first, Preview.SEED_LIMIT)
				check(distance < Preview.SEARCH_LIMIT, "Search respects bounded candidate limit")
				var no_match_skipped := true
				for offset in range(distance):
					var earlier: Dictionary = Case.generate(posmod(first + offset, Preview.SEED_LIMIT), 6, difficulty)
					if earlier.cast[earlier.culprit] == target:
						no_match_skipped = false
				check(no_match_skipped, "Search chooses first matching case in sequential wrapped order")
				var session := Session.new()
				check(session.begin(selected, layout, difficulty) and session.data == truth, "Full replay truth binds unchanged to actual mystery session")
				if first == 999999999 and selected < first:
					wrapped = true
	check(wrapped, "Boundary fixtures exercise wrap from final seed to zero")
	var confession_samples := {}
	var approved_poses := {}
	for target in ["Char", "Chris"]:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/poses/%s/directional-index.json" % target.to_lower()))
		approved_poses[target] = catalog.assets.map(func(asset): return str(asset.pose_id))
	for voice in Case.PERSONALITIES:
		for target in ["Char", "Chris"]:
			for difficulty in ["easy", "normal", "hard"]:
				var seed_value: int = Preview.find_seed(0, target, difficulty, voice)
				check(seed_value >= 0, "Requested killer personality is reachable: " + target + "/" + voice)
				if seed_value < 0: continue
				var truth: Dictionary = Case.generate(seed_value, 6, difficulty)
				check(truth.cast[truth.culprit] == target and truth.personalities[truth.culprit] == voice, "Preview matches identity and personality without edits")
				check(Preview.confession_pose(voice, target) in approved_poses[target], "Personality reveal has approved artwork for " + target + "/" + voice)
				check(Preview.find_seed(0, target, difficulty, voice) == seed_value, "Personality preview seed replays exactly")
				var session := Session.new()
				check(session.begin(seed_value, layout, difficulty) and session.data == truth, "Personality preview preserves complete generated case")
				if target != "Char" or difficulty != "normal": continue
				var slots: Dictionary = session.truth_slots()
				for template in session.dialogue.data.personalities[voice].confession:
					var line: String = session.dialogue.render(template, slots)
					check(not line.is_empty() and session.dialogue.last_error.is_empty() and "[PENDING_DIALOGUE:" not in line and "{" not in line, "Latest authored confession renders every slot: " + voice)
				session.progress.carried = truth.weapon_room
				session.progress.assembled = true
				var ending: Dictionary = session.accuse(truth.culprit, truth.murder_room)
				check(ending.result == "solved" and ending.message_key == "confession", "Correct accusation uses new personality confession bank")
				check(not ending.message.is_empty() and "[PENDING_DIALOGUE:" not in ending.message and "{" not in ending.message, "Actual conclusion has complete authored confession")
				confession_samples[ending.message] = true
	check(confession_samples.size() == Case.PERSONALITIES.size(), "All eight personality conclusions differ")
	check(Preview.find_seed(0, "Unknown guest") == -1, "Unknown target is rejected")
	check(Preview.find_seed(0, "Char", "invalid") == -1, "Unknown difficulty is rejected")
	check(Preview.find_seed(0, "Char", "normal", "invalid") == -1, "Unknown personality is rejected")
	check(Case.generate(27, 6, "normal") == baseline, "Preview searches change no ordinary generator state or facts")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
