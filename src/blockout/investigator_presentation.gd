extends RefCounted
## Reuse the investigator already displayed by the older mansion.
## Drawing uses the caller's existing world transform and never changes it.
const Appearance = preload("res://src/characters/character_render.gd")
const HorizontalAnimation = preload("res://src/characters/detective_animation.gd")
const SHEET := "res://assets/foyer/investigator-sheet.png"
const SHEET_SHA256 := "69c4a13cf6063b7bad6c2de71b23803333782a343983dee6b3a21d0d5fd68bde"
const HORIZONTAL_SHEET := "res://assets/characters/detective-walk-v1/horizontal-sheet.png"
const HORIZONTAL_SHA256 := "7c388b6563ececda58af38829c4b3197da5582b3854a37ba9853ac71faaef58c"
var texture: Texture2D
var appearance: Dictionary = {}
var horizontal: RefCounted
var facing := Vector2.DOWN
var is_walking := false
var walk_time := 0.0
var current_frame := 1
var distance_walked := 0.0
var previous_position := Vector2.ZERO
var positioned := false
var error := ""

func _init() -> void:
	for source in [[SHEET, SHEET_SHA256], [HORIZONTAL_SHEET, HORIZONTAL_SHA256]]:
		if FileAccess.file_exists(source[0]) and FileAccess.get_sha256(source[0]) != source[1]:
			error = "Existing investigator artwork changed: " + str(source[0])
			return
	texture = load(SHEET) as Texture2D
	if texture == null:
		error = "Existing investigator sheet could not be loaded."
		return
	appearance = Appearance.sheet(texture, 4, 4)
	horizontal = HorizontalAnimation.new()
	if horizontal.texture == null:
		error = "Existing investigator horizontal cycle could not be loaded."
	current_frame = int(Appearance.settings().movement.idle_frame)

func reset(position: Vector2) -> void:
	previous_position = position
	positioned = true
	is_walking = false
	walk_time = 0.0
	current_frame = int(Appearance.settings().movement.idle_frame)

func update(position: Vector2, delta: float) -> void:
	if not positioned:
		reset(position)
		return
	var movement := position - previous_position
	var travelled := movement.length()
	# Normal native movement is capped to 0.1 seconds. Large discontinuities
	# are arrivals/inspection jumps, not a sprint across the old room.
	var jump_limit := maxf(32.0, float(Appearance.settings().movement.speed) * minf(delta, 0.1) * 2.0)
	if delta <= 0 or travelled > jump_limit:
		reset(position)
		return
	previous_position = position
	is_walking = travelled > 0.01
	if not is_walking:
		walk_time = 0.0
		current_frame = int(Appearance.settings().movement.idle_frame)
		return
	if absf(movement.x) > absf(movement.y):
		facing = Vector2(signf(movement.x), 0)
	elif absf(movement.y) > absf(movement.x):
		facing = Vector2(0, signf(movement.y))
	elif facing.dot(movement) <= 0:
		facing = Vector2(0, signf(movement.y))
	distance_walked += travelled
	walk_time = fmod(walk_time + travelled / float(Appearance.settings().movement.stride_distance), 1.0)
	var order: Array = Appearance.settings().movement.walk_order
	current_frame = int(order[int(walk_time * order.size()) % order.size()])

func frame_data() -> Dictionary:
	if not error.is_empty() or texture == null:
		return {}
	if horizontal != null and is_walking and absf(facing.x) > 0.4:
		var row := 0 if facing.x < 0 else 1
		var index := row * 4 + current_frame
		return {"texture": horizontal.texture, "region": horizontal.appearance.regions[index],
			"pivot": horizontal.appearance.pivots[index],
			"factor": Appearance.height(float(horizontal.definition.standing_height_ratio)) / float(horizontal.appearance.reference_height),
			"source": HORIZONTAL_SHEET, "frame": index}
	var row := 0
	if facing.y < -0.4:
		row = 3
	elif absf(facing.x) > 0.4:
		row = 2 if facing.x > 0 else 1
	var index := row * 4 + current_frame
	return {"texture": texture, "region": appearance.regions[index], "pivot": appearance.pivots[index],
		"factor": Appearance.height() / float(appearance.reference_height), "source": SHEET, "frame": index}

func frame_rect(position: Vector2) -> Rect2:
	var data := frame_data()
	if data.is_empty():
		return Rect2()
	return Rect2(position + (data.region.position - data.pivot) * data.factor, data.region.size * data.factor)

func draw_on(canvas: CanvasItem, position: Vector2) -> void:
	var data := frame_data()
	if not data.is_empty():
		canvas.draw_texture_rect_region(data.texture, frame_rect(position), data.region)
