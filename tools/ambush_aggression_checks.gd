extends SceneTree
## Difficulty odds are independent rolls; held weapon boosts questions only.
const Session = preload("res://src/mystery/house_case_session.gd")
var checks := 0
var failures: Array[String] = []
var layout: Dictionary

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 25: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func session(seed_value: int, held := "empty", extra := {}, difficulty := "normal") -> RefCounted:
	var s = Session.new()
	check(s.begin(seed_value, layout, difficulty), "Difficulty aggression case starts")
	var overrides := {"guest_leave": 0, "activity_redraw": 0,
		"stalking_isolation_chance": 0, "question_refusal": 0}
	overrides.merge(extra, true)
	s.enable_runtime(layout, overrides)
	var id := -1
	if held == "weapon": id = int(s.data.weapon_room)
	elif held == "glass": id = int(s.data.glass_room)
	elif held == "ordinary":
		for candidate in s.items:
			if candidate != s.data.weapon_room and candidate != s.data.glass_room:
				id = int(candidate)
				break
	if id >= 0:
		s.enter_screen(str(s.items[id].screen))
		s.take_item(id)
		check((s.progress.glass if held == "glass" else s.progress.carried == id), "Actual pickup selects requested held object")
	stage(s, s.room_ids[0])
	s.runtime.advance_to(s.runtime.stalking_at + 1)
	return s

func stage(s: RefCounted, room: String, witness := false) -> void:
	for guest in s.runtime.guests: guest.screen = s.room_ids[1]
	s.runtime.guests[s.data.culprit].screen = room
	if witness: s.runtime.guests[(s.data.culprit + 1) % 6].screen = room
	s.enter_screen(room)
	s.runtime.player_screen = room

func run() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	var stats := {}
	var long_streak_seen := false
	var odds := {"easy": 0.15, "normal": 0.20, "hard": 0.25}
	for difficulty in odds:
		stats[difficulty] = {}
		for held in ["empty", "glass", "ordinary", "weapon"]:
			var longest := 0
			var total := 0
			for seed_value in range(50):
				var s = session(seed_value, held, {}, difficulty)
				var entry_chance: float = odds[difficulty]
				var question_chance: float = 0.5 if held == "weapon" else entry_chance
				check(is_equal_approx(s.runtime.attack_chance("entry"), entry_chance), "Weapon never boosts room-entry chance")
				check(is_equal_approx(s.runtime.attack_chance("question"), question_chance), "Only true-weapon questioning uses fifty percent")
				# Compare each actual question to its exact independent RNG roll.
				var expected_rng = s.runtime.rng("question_ambush")
				var attempts := 0
				for attempt in range(1, 301):
					attempts = attempt
					var expected_hit: bool = expected_rng.chance(question_chance)
					s.question(s.data.culprit)
					check((s.progress.outcome == "ambushed") == expected_hit, "Question follows independent seeded chance without forced attack")
					if expected_hit: break
				check(not s.active() and s.runtime.question_rolls == attempts, "Only actual eligible questions count as rolls")
				long_streak_seen = long_streak_seen or attempts > 4
				longest = maxi(longest, attempts)
				total += attempts
				var entered = session(seed_value, held, {}, difficulty)
				var entered_room: String = entered.progress.screen
				var expected_entry_rng = entered.runtime.rng("entry_ambush")
				var expected_entry: bool = expected_entry_rng.chance(entry_chance)
				entered.observe_world(entered.runtime.steps, entered.runtime.halls[0])
				entered.observe_world(entered.runtime.steps, entered_room)
				check((entered.progress.outcome == "ambushed") == expected_entry and entered.runtime.entry_rolls == 1, "Actual entry uses difficulty odds regardless of held item")
			stats[difficulty][held] = {"cases": 50, "longest": longest, "mean": float(total) / 50.0}
	check(long_streak_seen, "Independent rolls allow more than four attempts; old forced limits are gone")
	var safe = session(7, "weapon")
	var room: String = safe.progress.screen
	var steps_before: int = safe.runtime.steps
	for index in range(20): safe.observe_world(steps_before, room)
	safe.observe_world(steps_before + 20, room)
	check(safe.active() and safe.runtime.entry_rolls == 0 and safe.runtime.question_rolls == 0, "Same-room waiting and walking create no attack rolls")
	stage(safe, room, true)
	for index in range(12): safe.question(safe.data.culprit)
	check(safe.active() and safe.runtime.question_rolls == 0, "Witnesses suppress every weapon-enhanced attack")
	var hall: String = safe.runtime.halls[0]
	stage(safe, hall)
	for index in range(12): safe.question(safe.data.culprit)
	check(safe.active() and safe.runtime.question_rolls == 0, "Hall remains safe with true weapon held")
	var calm = session(3, "weapon")
	calm.runtime.danger_clock = 0.0
	for index in range(12): calm.question(calm.data.culprit)
	check(calm.active() and calm.runtime.question_rolls == 0, "Calm phase never attacks regardless of held weapon")
	var disabled = session(9, "weapon", {"entry_death": 0.0, "culprit_question_death": 0.0})
	check(disabled.runtime.attack_chance("entry") == 0 and disabled.runtime.attack_chance("question") == 0, "Explicit zero overrides keep controlled playtests safe")
	for index in range(12): disabled.question(disabled.data.culprit)
	check(disabled.active(), "No forced attack overrides disabled chances")
	var guaranteed = session(9, "weapon", {"entry_death": 1.0, "culprit_question_death": 1.0})
	check(guaranteed.runtime.attack_chance("entry") == 1 and guaranteed.runtime.attack_chance("question") == 1, "Explicit one overrides preserve guaranteed attack fixtures")
	var frozen = session(11, "weapon")
	frozen.runtime.finished = true
	check(frozen.runtime.question(frozen.data.culprit, frozen.progress.screen) == "ended" and frozen.runtime.question_rolls == 0, "Finished/gathering runtime cannot attack")
	print(JSON.stringify({"checks": checks, "failures": failures, "question_pacing": stats}))
	quit(0 if failures.is_empty() else 1)
