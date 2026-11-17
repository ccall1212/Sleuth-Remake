extends SceneTree
const RoomTexture = preload("res://src/blockout/approved_room_texture.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.painted.layout.json"))
	for screen in layout.screens:
		var texture: Texture2D = RoomTexture.load_approved(screen.background, screen.background_sha256)
		check(texture != null, str(screen.id) + ": approved background loads")
		if texture != null:
			check(texture.get_width() > 0 and texture.get_height() > 0, str(screen.id) + ": nonempty imported texture")
	var foyer: Dictionary = layout.screens.filter(func(s): return s.id == "room_6")[0]
	check(RoomTexture.load_approved(foyer.background, "0".repeat(64)) == null, "Changed source cannot reuse an imported texture")
	check(RoomTexture.load_approved(foyer.background, "not a hash") == null, "Malformed approval hash rejected")
	check(RoomTexture.load_approved("res://assets/characters/unknown.png", "0".repeat(64)) == null, "Non-room paths rejected")
	check(RoomTexture.load_approved("res://assets/rooms/missing.png", "0".repeat(64)) == null, "Missing local source rejected")
	print(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
