extends SceneTree
const Investigator = preload("res://src/blockout/investigator_presentation.gd")
const Appearance = preload("res://src/characters/character_render.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := Investigator.new()
	check(player.error.is_empty(), "Existing investigator sheets load: " + player.error)
	check(FileAccess.get_sha256(Investigator.SHEET) == Investigator.SHEET_SHA256, "Original 16-frame artwork is unchanged")
	check(FileAccess.get_sha256(Investigator.HORIZONTAL_SHEET) == Investigator.HORIZONTAL_SHA256, "Existing corrected horizontal artwork is unchanged")
	check(Appearance.height() == 80, "Shared adult stature remains 80 logical units")
	check(player.appearance.regions.size() == 16 and player.horizontal.appearance.regions.size() == 8, "Original cardinal frames and established horizontal cycle retained")
	var at := Vector2(200, 220)
	player.update(at, 0.016)
	check(not player.is_walking and player.current_frame == 1, "First sample establishes planted idle")
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		player.reset(at)
		var seen := {}
		for step in range(28):
			at += direction * 2
			player.update(at, 0.02)
			seen[player.current_frame] = true
		check(player.is_walking and player.facing == direction, "Actual displacement selects facing " + str(direction))
		check(seen.size() == 4, "Real travel visits all four gait frames")
		var data := player.frame_data()
		check(data.source == (Investigator.HORIZONTAL_SHEET if direction.x != 0 else Investigator.SHEET), "Walking selects existing source for this direction")
		var rect := player.frame_rect(at)
		check(absf(rect.end.y - at.y) < 0.001, "Visible feet retain exact floor contact")
		check(rect.size.y <= Appearance.height() + 0.001 and rect.size.y > Appearance.height() * 0.85, "Source proportions retain original standing-scale range")
		var walked := player.distance_walked
		for frame in range(6):
			player.update(at, 0.2)
		check(not player.is_walking and player.current_frame == 1 and player.distance_walked == walked, "Idle/blocked movement advances no gait or walking distance")
		check(player.frame_data().source == Investigator.SHEET, "All planted idles use the original investigator sheet")
		check(player.facing == direction, "Stopping retains facing")
	var before := player.distance_walked
	player.update(Vector2(20, 20), 0.016)
	check(not player.is_walking and player.distance_walked == before, "Large arrival teleport does not animate as movement")
	player.update(Vector2(22, 20), 0)
	check(not player.is_walking and player.distance_walked == before, "Paused/zero-time reposition adds no gait")
	player.reset(Vector2(100, 100))
	player.update(Vector2(102, 100), 0.02)
	var phase := player.walk_time
	player.update(Vector2(100, 100), 0.02)
	check(player.facing == Vector2.LEFT and player.walk_time > phase, "Direction reversal retains travel-driven phase")
	print(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
