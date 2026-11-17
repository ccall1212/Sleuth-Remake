extends RefCounted
## User-authored placement review, separate from case casting and guest simulation.
const PATH := "res://assets/maps/house-02.guest-positions.json"
const ART_PATH := "res://assets/rooms/house-02/furnishing-review/guest-preview-data.json"
var rooms: Dictionary = {}
var catalog: Dictionary = {}
var textures: Dictionary = {}
var mask_textures: Dictionary = {}
var mask_room := ""
var adult_height := 80.0
var error := ""
var actor_override := ""
var activity_override := ""
var show_masks := true
var show_anchors := false

func load_placements(layout: Dictionary, path := PATH) -> bool:
	rooms.clear()
	textures.clear()
	mask_textures.clear()
	mask_room = ""
	error = ""
	if not FileAccess.file_exists(path):
		return true # A plain painted walkthrough can be used before any placement.
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary or raw.get("schema") != "house02-guest-placement-v1":
		error = "Guest placement file has an unsupported format."
		return false
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART_PATH))
	catalog = art.actors
	adult_height = float(art.adult_height)
	var screens := {}
	for screen in layout.screens:
		screens[screen.id] = screen
	for room in raw.rooms:
		if not screens.has(room.id) or room.image_sha256 != screens[room.id].get("background_sha256", ""):
			error = "Guest placements do not match the room artwork: " + str(room.id)
			rooms.clear()
			return false
		rooms[room.id] = room
	return true

func spots(room_id: String) -> Array:
	return rooms.get(room_id, {}).get("guest_spots", [])

func masks(room_id: String) -> Array:
	return rooms.get(room_id, {}).get("foreground_masks", [])

func render_pose(spot: Dictionary) -> Dictionary:
	var actor := actor_override if not actor_override.is_empty() else str(spot.preview_actor)
	var activity := activity_override if not activity_override.is_empty() else str(spot.activity)
	for pose in catalog.get(actor, []):
		if pose.posture == spot.posture and pose.facing == spot.facing and pose.activity == activity:
			return pose
	# An incompatible activity leaves this slot in its saved pose/posture/facing.
	for pose in catalog.get(actor, []):
		if pose.posture == spot.posture and pose.facing == spot.facing and pose.activity == spot.activity:
			return pose
	return {}

func render_rect(spot: Dictionary, pose: Dictionary) -> Rect2:
	var scale := adult_height / float(pose.standing_reference)
	var at := Vector2(float(spot.at[0]), float(spot.at[1]))
	var contact := Vector2(float(pose.contact[0]), float(pose.contact[1]))
	return Rect2(at - contact * scale, Vector2(float(pose.size[0]), float(pose.size[1])) * scale)

func texture(pose: Dictionary) -> Texture2D:
	var path := "res://" + str(pose.source)
	if textures.has(path):
		return textures[path]
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != str(pose.sha256):
		push_error("Guest preview source changed: " + path)
		return null
	var loaded: Texture2D = load(path)
	if loaded != null:
		if textures.size() >= 24:
			textures.clear()
		textures[path] = loaded
	return loaded

func commands(room_id: String) -> Array:
	var result: Array = []
	for spot in spots(room_id):
		# The seat, rather than extended feet, determines seated occlusion.
		result.append({"type": "guest", "depth": float(spot.at[1]), "value": spot})
	if show_masks:
		for mask in masks(room_id):
			result.append({"type": "mask", "depth": float(mask.depth_y), "value": mask})
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		return a.depth < b.depth or (a.depth == b.depth and a.type == "guest" and b.type == "mask"))
	return result

func draw_on(canvas: CanvasItem, room_id: String, background: Texture2D) -> void:
	if mask_room != room_id:
		mask_textures.clear()
		mask_room = room_id
	for command in commands(room_id):
		if command.type == "guest":
			var pose := render_pose(command.value)
			if pose.is_empty():
				continue
			var image := texture(pose)
			if image != null:
				canvas.draw_texture_rect(image, render_rect(command.value, pose), false)
		elif background != null:
			var foreground := mask_texture(command.value, background)
			if foreground != null:
				canvas.draw_texture_rect(foreground, Rect2(0, 0, 480, 360), false)
	if show_anchors:
		for spot in spots(room_id):
			canvas.draw_circle(Vector2(float(spot.at[0]), float(spot.at[1])), 3, Color("fff085"))

func mask_texture(mask: Dictionary, background: Texture2D) -> Texture2D:
	var id := str(mask.id)
	if mask_textures.has(id):
		return mask_textures[id]
	# SVG fill matches the browser, including concave/self-crossing user polygons.
	# Direct draw_polygon triangulation cannot represent all those shapes.
	var source := background.get_image()
	if source.is_compressed():
		source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var points := PackedStringArray()
	for p in mask.polygon:
		points.append("%s,%s" % [str(p[0]), str(p[1])])
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 480 360" preserveAspectRatio="none"><polygon points="%s" fill="white"/></svg>' % [source.get_width(), source.get_height(), " ".join(points)]
	var alpha := Image.new()
	if alpha.load_svg_from_string(svg) != OK:
		push_error("Could not draw furniture mask: " + id)
		return null
	alpha.convert(Image.FORMAT_RGBA8)
	var result := Image.create_empty(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	result.blend_rect_mask(source, alpha, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i.ZERO)
	var image := ImageTexture.create_from_image(result)
	mask_textures[id] = image
	return image
