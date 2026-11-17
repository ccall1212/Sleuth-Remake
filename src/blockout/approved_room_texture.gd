extends RefCounted
## Room artwork is approved by the caller's metadata, never by folder presence.
## Local sources are hash checked. Exported imported textures trust the build's
## approved source/import chain because a PCK may omit original PNG bytes.

static func load_approved(path: String, expected_sha256: String) -> Texture2D:
	if not path.begins_with("res://assets/rooms/") or not path.ends_with(".png"):
		return null
	if expected_sha256.length() != 64 or not expected_sha256.is_valid_hex_number(false):
		return null
	var source_exists := FileAccess.file_exists(path)
	if source_exists:
		if FileAccess.get_sha256(path) != expected_sha256.to_lower():
			return null
	elif OS.has_feature("editor"):
		# An editor/local checkout must retain its approval-verifiable source.
		return null
	if ResourceLoader.exists(path, "Texture2D"):
		return ResourceLoader.load(path, "Texture2D") as Texture2D
	if not source_exists:
		return null
	# New local PNGs may not yet be imported. Decode their verified bytes without
	# Image.load_from_file's warning about resource loading in exported builds.
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)
