extends RefCounted
## Approved asset metadata, lazy textures, fixed standing reference scale.
const ACTORS := {"Char": "char", "Chris": "chris"}
const Renderer = preload("res://src/characters/character_render.gd")
var catalogs: Dictionary = {}
var cache: Dictionary = {}
var reference_heights: Dictionary = {}
var adult_height := 80.0
var playtest_cast: Dictionary = {}
var playtest_cache: Dictionary = {}

func _init() -> void:
	adult_height = Renderer.height()
	for name in ACTORS:
		var path := "res://assets/characters/poses/%s/directional-index.json" % ACTORS[name]
		catalogs[name] = JSON.parse_string(FileAccess.get_file_as_string(path)).assets
	var roster_path := "res://assets/characters/playtest-cast/roster.json"
	if FileAccess.file_exists(roster_path):
		var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(roster_path))
		for entry in roster.characters:
			playtest_cast[entry.name] = entry

func playtest_asset(name: String) -> Dictionary:
	if playtest_cache.has(name):
		return playtest_cache[name]
	if not playtest_cast.has(name):
		return {}
	var record: Dictionary = playtest_cast[name]
	var path: String = record.sprite
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(record.sprite_sha256):
		push_error("Temporary cast art changed: " + name)
		return {}
	var texture: Texture2D = load(path)
	if texture == null:
		return {}
	var measured: Dictionary = Renderer.single(texture)
	var result := {"texture": texture, "bounds": measured.regions[0], "pivot": measured.pivots[0],
		"reference_height": measured.reference_height, "height_ratio": float(record.get("height_ratio", 1.0))}
	playtest_cache[name] = result
	return result

func records(name: String) -> Array:
	return catalogs.get(name, [])

func asset(name: String, pose_id: String) -> Dictionary:
	for record in records(name):
		if record.pose_id == pose_id:
			return texture_record(record)
	return {}

func texture_record(record: Dictionary) -> Dictionary:
	var path: String = "res://" + str(record.export)
	if cache.has(path):
		return cache[path]
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != record.export_sha256:
		push_error("Character art hash/path does not match approved index: " + path)
		return {}
	var texture: Texture2D = load(path)
	if texture == null:
		return {}
	var measurement: Dictionary = Renderer.single(texture)
	var result := {"texture": texture, "bounds": measurement.regions[0], "pivot": measurement.pivots[0], "record": record}
	if cache.size() >= 8:
		cache.erase(cache.keys()[0])
	cache[path] = result
	return result

func standing_height(name: String) -> float:
	if not reference_heights.has(name):
		var idle := asset(name, "standing_idle_south")
		reference_heights[name] = float(idle.bounds.size.y) if not idle.is_empty() else 1564.0
	return reference_heights[name]
