class_name MurdererZoom
extends Control
## Dramatic murderer portrait zoom overlay. Self-contained; add_child on top of everything.
## play(texture, overrides) runs: dim -> zoom with overshoot + flash + shake -> hold -> fade -> finished.
## Any click / Enter / Space / Esc calls skip(). Tween driven, frame-rate independent.
signal finished
const CONFIG_PATH := "res://assets/mystery/ambush_zoom.json"
const DEFAULTS := {
	"anticipation": 0.55, "dim_alpha": 0.65, "start_scale": 0.12, "final_height_fraction": 0.92,
	"zoom_duration": 0.32, "overshoot": 1.12, "settle_duration": 0.14, "flash_alpha": 0.35,
	"flash_duration": 0.08, "shake_px": 4.0, "shake_duration": 0.12, "hold": 0.8, "fade_out": 0.25,
}
var playing := false
var _cfg: Dictionary = {}
var _dim: ColorRect
var _shaker: Control
var _portrait: TextureRect
var _flash: ColorRect
var _tween: Tween
var _shake_tween: Tween
var _flash_tween: Tween
var _scale := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_dim = ColorRect.new(); _dim.color = Color(0, 0, 0, 0); _dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(_dim)
	_shaker = Control.new(); _shaker.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_shaker)
	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.visible = false
	_shaker.add_child(_portrait)
	_flash = ColorRect.new(); _flash.color = Color(1, 1, 1, 0); _flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(_flash)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	hide()

func config() -> Dictionary:
	if _cfg.is_empty(): _cfg = _merge({})
	return _cfg.duplicate()

func _merge(overrides: Dictionary) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate()
	if FileAccess.file_exists(CONFIG_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if data is Dictionary:
			for key in data:
				if out.has(key): out[key] = float(data[key])
	for key in overrides:
		if out.has(key): out[key] = float(overrides[key])
	return out

## Displayed portrait box height in pixels at the current scale.
func portrait_height() -> float:
	return _shaker.size.y * _shaker.scale.y

func _viewport_size() -> Vector2:
	return get_viewport_rect().size

func _layout() -> void:
	if _shaker == null: return
	var vs := _viewport_size()
	position = Vector2.ZERO
	if size != vs: size = vs
	_shaker.size = Vector2(vs.x, vs.y * float(config().get("final_height_fraction", 0.92)))
	_shaker.pivot_offset = _shaker.size * 0.5
	_shaker.position = (vs - _shaker.size) * 0.5
	_shaker.scale = Vector2.ONE * _scale
	_portrait.size = _shaker.size
	_portrait.position = Vector2.ZERO

func _set_scale(value: float) -> void:
	_scale = value
	_shaker.scale = Vector2.ONE * value

func _kill() -> void:
	for t in [_tween, _shake_tween, _flash_tween]:
		if t != null and t.is_valid(): t.kill()
	_tween = null; _shake_tween = null; _flash_tween = null

func play(texture: Texture2D, overrides := {}) -> void:
	_kill()
	_cfg = _merge(overrides)
	_portrait.texture = texture
	_portrait.visible = false
	_dim.color.a = 0.0
	_flash.color.a = 0.0
	modulate = Color.WHITE
	var start := float(_cfg.start_scale)
	var over := float(_cfg.overshoot)
	_scale = start
	playing = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	_layout()
	var c := _cfg
	# TRANS_BACK/EASE_OUT overshoots ~10% of travel; solve the target so the peak lands on `overshoot`.
	var target := (over + 0.1 * start) / 1.1
	_tween = create_tween()
	_tween.tween_property(_dim, "color:a", float(c.dim_alpha), maxf(float(c.anticipation), 0.0001))
	_tween.tween_callback(func(): _portrait.visible = texture != null; _set_scale(start))
	_tween.tween_method(_set_scale, start, target, maxf(float(c.zoom_duration), 0.0001)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_impact)
	_tween.tween_method(_set_scale, over, 1.0, maxf(float(c.settle_duration), 0.0001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(maxf(float(c.hold), 0.0))
	_tween.tween_property(self, "modulate:a", 0.0, maxf(float(c.fade_out), 0.0001))
	_tween.tween_callback(_end)

func _impact() -> void:
	var c := _cfg
	_flash.color.a = float(c.flash_alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, maxf(float(c.flash_duration), 0.0001))
	var home := (_viewport_size() - _shaker.size) * 0.5
	var px := float(c.shake_px)
	var dur := maxf(float(c.shake_duration), 0.0001)
	_shake_tween = create_tween()
	var steps := 4
	for i in steps:
		var amp := px * (1.0 - float(i) / steps)
		var dir := 1.0 if i % 2 == 0 else -1.0
		_shake_tween.tween_property(_shaker, "position", home + Vector2(dir * amp, -dir * amp * 0.5), dur / (steps + 1))
	_shake_tween.tween_property(_shaker, "position", home, dur / (steps + 1))

func _end() -> void:
	if not playing: return
	_kill()
	playing = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color.a = 0.0
	hide()
	finished.emit()

func skip() -> void:
	if not playing: return
	_end()

func _input(event: InputEvent) -> void:
	if not playing: return
	var hit := false
	if event is InputEventMouseButton and event.pressed: hit = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]: hit = true
	if hit:
		get_viewport().set_input_as_handled()
		skip()
