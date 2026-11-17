extends SceneTree
## Painted furniture contacts are stationary, capacity-aware authored slots.
const Session = preload("res://src/mystery/house_case_session.gd")
const World = preload("res://src/mystery/house_runtime.gd")
const Layout = preload("res://src/blockout/house_layout.gd")
const PATH := "res://assets/maps/house-02.investigation.layout.json"
var checks := 0
var failures: Array[String] = []
var layout: Dictionary
var seat_seen := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and failures.size() < 25:
		failures.append(message)

func session(seed_value: int, difficulty: String) -> RefCounted:
	var s = Session.new()
	check(s.begin(seed_value, layout, difficulty), "Case binds painted room names")
	s.enable_runtime(layout, {"guest_leave": 1, "activity_redraw": 1, "entry_death": 0, "culprit_question_death": 0})
	return s

func signature(world: RefCounted) -> String:
	return JSON.stringify(world.guests.map(func(g): return [g.screen, g.slot_id, g.position, g.interaction_at, g.posture, g.facing, g.activity, g.staring]))

func validate_guests(s: RefCounted) -> void:
	var world: RefCounted = s.runtime
	for person in range(world.guests.size()):
		var g: Dictionary = world.guests[person]
		var matches: Array = world.geometry.screens[g.screen].guest_slots.filter(func(slot): return slot.id == g.slot_id)
		check(matches.size() == 1, "Exactly one authored slot per guest")
		if matches.size() != 1:
			continue
		var slot: Dictionary = matches[0]
		check(g.position == Layout.point(slot.at), "Saved contact is preserved exactly")
		check(g.interaction_at == Layout.point(slot.interaction_at), "Reachable interaction contact is preserved")
		check(world.geometry.is_open(g.screen, g.interaction_at), "Guest can be questioned from open floor")
		check(g.facing == slot.facing and g.posture == slot.posture, "Facing and posture belong to slot")
		check(g.activity in slot.activities, "Activity remains compatible with authored posture/facing")
		check(g.posture != "seated" or s.data.cast[person] in ["Char", "Chris"], "Standing-only temporary cast does not sit")
		if g.posture == "seated":
			seat_seen = true
		if s.data.difficulty == "hard" and g.screen == s.room_ids[s.data.murder_room]:
			check(g.staring, "Hard murder-room occupants retain real clue state")
		for other in range(person):
			var h: Dictionary = world.guests[other]
			if h.screen == g.screen:
				check(h.slot_id != g.slot_id, "Guests never share a furniture slot")
				check(h.position.distance_to(g.position) >= 28, "Nearby alternative slots cannot overlap occupants")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var geometry = Layout.new()
	check(geometry.load_layout(PATH), "Painted investigation layout validates: " + geometry.error)
	if not failures.is_empty():
		print(JSON.stringify({"checks": checks, "failures": failures}))
		quit(1)
		return
	layout = geometry.data
	for difficulty in ["easy", "normal", "hard"]:
		for seed_value in range(25):
			var s := session(seed_value, difficulty)
			var truth: Dictionary = s.data.duplicate(true)
			validate_guests(s)
			for visit in range(5):
				var world: RefCounted = s.runtime
				var before := signature(world)
				world.advance_to(world.steps + 24)
				check(signature(world) == before, "Forced relocation cannot occur while viewing current room")
				world.enter_player_screen(s.room_ids[visit % s.room_ids.size()])
				validate_guests(s)
			check(s.data == truth, "Staging and activities do not edit alibis or case truth")
	check(seat_seen, "Real Char/Chris seated contacts were exercised")
	var a := session(29, "hard")
	var b := session(29, "hard")
	a.runtime.advance_to(100)
	for step in range(1, 101):
		b.runtime.advance_to(step)
	a.runtime.enter_player_screen(a.room_ids[0])
	b.runtime.enter_player_screen(b.room_ids[0])
	check(signature(a.runtime) == signature(b.runtime), "Seeded snapshots do not depend on frame batching")
	# Force all initial requests into the one-slot secret room. Other occupants
	# must find different compatible authored contacts instead of sharing a spawn.
	var packed: Dictionary = a.data.duplicate(true)
	packed.guest_start = [9, 9, 9, 9, 9, 9]
	var capacity = World.new(packed, a.room_ids, layout, {"entry_death": 0})
	a.runtime = capacity
	validate_guests(a)
	check(capacity.guests.filter(func(g): return g.screen == a.room_ids[9]).size() <= 1, "Single-slot room capacity survives overloaded initial staging")
	print(JSON.stringify({"checks": checks, "cases": 75, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
