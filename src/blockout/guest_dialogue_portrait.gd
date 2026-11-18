extends TextureRect
## Enlarges existing speaker art above the dialogue without changing the actor.
var speaker_name := ""
var pose_id := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 10
	hide()

func show_asset(actor_name: String, pose: String, asset: Dictionary, reference_height: float, facing: String, boost := 1.0) -> void:
	if asset.is_empty() or reference_height <= 0:
		hide()
		return
	var bounds: Rect2 = asset.bounds
	var factor := minf(240.0 * boost / reference_height, minf(260.0 * boost / bounds.size.x, 300.0 * boost / bounds.size.y))
	var atlas := AtlasTexture.new()
	atlas.atlas = asset.texture
	atlas.region = bounds
	texture = atlas
	size = bounds.size * factor
	# Placed against the 960x720 reference frame, centred in the real viewport so it stays beside the centred dialogue.
	var shift := (get_viewport_rect().size - Vector2(960.0, 720.0)) * 0.5
	position = Vector2(690.0 - size.x if facing == "west" else 36.0, 430.0 - size.y) + shift.max(Vector2.ZERO)
	speaker_name = actor_name
	pose_id = pose
	show()
