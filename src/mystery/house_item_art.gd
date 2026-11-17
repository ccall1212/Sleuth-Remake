extends RefCounted
## Reuse existing runtime evidence artwork; never infer guilt from the art.
## Unmapped item types get a small neutral inspection glint, not a wrong object.
const MANIFEST := "res://assets/objects/object-manifest.json"
const ITEM_CATALOG := "res://assets/mystery/house_item_catalog.json"
const ITEMS := {
	"Heavy book": ["book", "whole", "book-whole"],
	"Glass decanter": ["decanter", "stoppered", "decanter-stoppered"],
	"Iron poker": ["poker", "straight", "poker-straight"],
	"Kitchen knife": ["knife", "ordinary", "knife-ordinary"],
	"Small hammer": ["hammer", "ordinary", "hammer-ordinary"],
	"Magnifying glass": ["magnifier", "ordinary", "magnifier-ordinary"],
	"Brass magnifying glass": ["magnifier", "ordinary", "magnifier-ordinary"],
}
const HASHES := {
	"res://assets/objects/object-book-whole.png": "69ab5ea17963d79f072c3f4d54cb31b4499751767ac50ba317ab449524587c4d",
	"res://assets/objects/closeups/object-book-whole.png": "cb58075b9a5ff8a5ac454c4befcd70da2f1fb12af4a8bad5ed5c6e5a7fadfe57",
	"res://assets/objects/object-knife-ordinary.png": "876e94aad148491b9fcd520d0d166573cddbd1ee994878e27e8bbf6d78ac46e5",
	"res://assets/objects/closeups/object-knife-ordinary.png": "5a8c0adc3f18e3eaf4be0f9c93f3e3b17aa5ce6276891603d71e44eeb8206541",
	"res://assets/objects/object-poker-straight.png": "7a49e138e7085b995aae13724afedee4b5a7e885fed53f2784fe0357d687eafd",
	"res://assets/objects/closeups/object-poker-straight.png": "543e85c3957d698f34015a1b45aa745aaa5df8cd4bfdbd8e7d71512d9e460a9e",
	"res://assets/objects/object-hammer-ordinary.png": "556d7113c7f379fcbbea7d8d895eba4c45b95fa559f66590fbeefaddbd1665cf",
	"res://assets/objects/closeups/object-hammer-ordinary.png": "0c09b4a6ee652dbd555b561d905bed0885f56cddfaf542a273baa64e20948078",
	"res://assets/objects/object-decanter-stoppered.png": "e0d08f19f154a1b76cb846a09b91112f1c2cacf0f98b012c9cb80560f4047b54",
	"res://assets/objects/closeups/object-decanter-stoppered.png": "9ad6fe6624c487bd0f7d684641d1acc357e43d789e1fbbaeaa972e355d0e904a",
	"res://assets/objects/object-magnifier-ordinary.png": "bfcfe8ae8d534baf2f3ac87d334f4481c7ad3e991e26cc8768b9deaa71f6c1bb",
	"res://assets/objects/closeups/object-magnifier-ordinary.png": "91010d79989fe19c5b838e0e1b1c22e5ee3fe9d0095d05889b64db85828a633a",
	"res://assets/objects/object-bust-intact.png": "e9a1431ea3627831bd24388e18f2f893373dc1b2e9ae062dbe670322e03f4b5a",
	"res://assets/objects/closeups/object-bust-intact.png": "3109383a0cae39e239d0241619c0cfa0a37d4ce526ff3644062650c175912762",
	"res://assets/objects/object-bottle-sealed.png": "5778be64eabc0266c3f4acb12223f86fd7d4aaaf6bb5986f548db8134a55ba39",
	"res://assets/objects/closeups/object-bottle-sealed.png": "f43bf22c29d451d005814f0ebedc299ee8326b46af59dbf41d9c38c40713f8e3",
	"res://assets/objects/object-stool-upright.png": "92636cc2c7fca12a4808ab81d3f2ff1c5720f4a639afe00dff9c50f1df794998",
	"res://assets/objects/closeups/object-stool-upright.png": "cb1a74b42cea6752f5b0793dce654d7cf10f80d60fc17e8ad8e877911e19cd25",
	"res://assets/objects/object-mirror-intact.png": "65fc88c97c36dc274b55640ba724be1e2c520b2e2b55964394304eb656fa9297",
	"res://assets/objects/closeups/object-mirror-intact.png": "e03adfcd5ab2cecfde5cff0afce3994b8279bf2bbab89ed8d5568a9b8b7b7db1",
	"res://assets/objects/object-mallet-sound.png": "ffa8a8688e26e0ec26246f066bce4518c18df3154cfe0e4165723d8a413d4f92",
	"res://assets/objects/closeups/object-mallet-sound.png": "706a72ce1e38f4e69723dbbeb14dd0fb7b537e20d83b45edf739432f70fa8108",
}
var catalog: Dictionary = {}
var item_catalog: Dictionary = {}
var mappings: Dictionary = ITEMS.duplicate(true)
var cache: Dictionary = {}
var last_error := ""

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if parsed is Dictionary:
		catalog = parsed
	else:
		last_error = "Could not read existing evidence catalog"
	var selected: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEM_CATALOG))
	if not selected is Dictionary:
		last_error = "Could not read the house item catalog"
		return
	item_catalog = selected
	var entries: Array = item_catalog.get("items", []).duplicate()
	entries.append(item_catalog.get("magnifier", {}))
	for entry in entries:
		var evidence_id := str(entry.get("evidence_id", ""))
		var variant := str(entry.get("variant", ""))
		if not evidence_id.is_empty() and not variant.is_empty():
			mappings[str(entry.get("name", ""))] = [evidence_id, variant, evidence_id + "-" + variant]

func texture(path: String) -> Texture2D:
	if not HASHES.has(path): return null
	if FileAccess.file_exists(path):
		if FileAccess.get_sha256(path) != HASHES[path]:
			last_error = "Existing item art changed: " + path
			return null
	elif OS.has_feature("editor"):
		return null
	if ResourceLoader.exists(path, "Texture2D"):
		return ResourceLoader.load(path, "Texture2D") as Texture2D
	if not FileAccess.file_exists(path): return null
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: return null
	return ImageTexture.create_from_image(image)

func asset(item_name: String) -> Dictionary:
	last_error = ""
	if cache.has(item_name): return cache[item_name]
	if not mappings.has(item_name): return {}
	var mapping: Array = mappings[item_name]
	var definition: Dictionary = catalog.get("definitions", {}).get(mapping[0], {})
	var condition: Dictionary = definition.get("conditions", {}).get(mapping[1], {})
	var world_path := "res://assets/objects/object-%s.png" % mapping[2]
	var detail_path := "res://assets/objects/closeups/object-%s.png" % mapping[2]
	if condition.get("asset", "") != world_path or condition.get("closeup", "") != detail_path:
		last_error = "Existing evidence mapping changed: " + item_name
		return {}
	var world := texture(world_path)
	var detail := texture(detail_path)
	if world == null or detail == null: return {}
	var world_bounds := Rect2(world.get_image().get_used_rect())
	var bounds := Rect2(detail.get_image().get_used_rect())
	if not bounds.has_area() or not world_bounds.has_area(): return {}
	var scale := minf(world_bounds.size.x / bounds.size.x, world_bounds.size.y / bounds.size.y)
	var occupied := bounds.size * scale
	var result := {"texture": detail, "bounds": bounds, "pivot": Vector2(bounds.get_center().x, bounds.end.y),
		"width": occupied.x, "height": occupied.y, "size": occupied, "world_bounds": world_bounds,
		"definition": str(mapping[0]), "condition": str(mapping[1]),
		"source": detail_path, "source_sha256": HASHES[detail_path]}
	cache[item_name] = result
	return result

func detail(item_name: String) -> Texture2D:
	var entry := asset(item_name)
	return null if entry.is_empty() else entry.texture as Texture2D

func destination(item_name: String, at: Vector2) -> Rect2:
	var entry := asset(item_name)
	if entry.is_empty(): return Rect2(at - Vector2(3, 6), Vector2(6, 6))
	return Rect2(at - Vector2(entry.width * 0.5, entry.height), entry.size)

func draw_on(canvas: CanvasItem, item_name: String, at: Vector2) -> bool:
	var entry := asset(item_name)
	if entry.is_empty():
		# A neutral glint says something can be inspected; the nearby prompt names
		# the actual item. No incompatible artwork is substituted.
		var center := at - Vector2(0, 3)
		canvas.draw_line(center - Vector2(3, 0), center + Vector2(3, 0), Color("dcc997"), 1)
		canvas.draw_line(center - Vector2(0, 3), center + Vector2(0, 3), Color("dcc997"), 1)
		return false
	canvas.draw_texture_rect_region(entry.texture, Rect2(at - Vector2(entry.width * 0.5, entry.height), entry.size), entry.bounds)
	return true
