extends SceneTree
## Murderer zoom overlay checks. Prints {"checks":N,"failures":[...]}.
const Zoom = preload("res://src/blockout/murderer_zoom.gd")
var checks := 0
var failures: Array[String] = []
var count := 0
const TINY := {"anticipation": 0.02, "zoom_duration": 0.02, "settle_duration": 0.02, "hold": 0.02, "fade_out": 0.02, "flash_duration": 0.02, "shake_duration": 0.02}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 30: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func tex() -> Texture2D:
	var img := Image.create(40, 80, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	return ImageTexture.create_from_image(img)

func make(host: Node) -> Control:
	var z: Control = Zoom.new()
	host.add_child(z)
	count = 0
	z.finished.connect(func(): count += 1)
	return z

func wait(sec: float) -> void:
	await create_timer(sec).timeout

func run() -> void:
	var z := make(root)
	var c: Dictionary = z.config()
	for key in ["anticipation", "start_scale", "final_height_fraction", "zoom_duration", "overshoot", "settle_duration", "hold", "fade_out", "flash_alpha", "flash_duration", "shake_px", "shake_duration", "dim_alpha"]:
		check(c.has(key), "config key " + key)
	var file: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mystery/ambush_zoom.json"))
	check(file is Dictionary and float(file.anticipation) == 0.55 and float(file.final_height_fraction) == 0.92 and float(file.overshoot) == 1.12, "json defaults")
	check(not z.playing and not z.visible, "hidden initially")
	z.skip(); check(count == 0 and not z.playing, "skip when idle no-op")
	z.play(tex(), {"hold": 0.5})
	check(z.playing and z.visible and z.config().hold == 0.5 and z.config().zoom_duration == 0.32, "play sets playing, overrides merged")
	check(z.mouse_filter == Control.MOUSE_FILTER_STOP, "mouse stop while playing")
	z.skip()
	check(count == 1 and not z.playing and not z.visible, "skip during anticipation ends immediately")
	z.skip(); await wait(0.1); check(count == 1, "finished exactly once")
	check(z.mouse_filter == Control.MOUSE_FILTER_IGNORE, "mouse ignore when done")
	z.play(tex(), TINY)
	await wait(0.5)
	check(count == 2 and not z.visible and not z.playing, "full tiny run finishes once, hidden")
	z.play(tex(), TINY); z.play(tex(), TINY)
	await wait(0.5)
	check(count == 3, "double play emits one finished")
	z.play(null, TINY)
	await wait(0.5)
	check(count == 4 and not z.visible, "null texture finishes")
	for vs in [Vector2i(960, 720), Vector2i(1600, 900)]:
		var sv := SubViewport.new()
		sv.size = vs
		root.add_child(sv)
		var zz := make(sv)
		zz.play(tex(), {"anticipation": 0.02, "zoom_duration": 0.02, "settle_duration": 0.02, "hold": 5.0})
		var pr: TextureRect = zz._portrait
		check(pr.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "keep aspect centered")
		await wait(0.5)
		var h: float = zz.portrait_height()
		check(absf(h - vs.y * 0.92) < 2.0 and h < vs.y, "settle height %s at %s" % [h, vs])
		var center: Vector2 = zz._shaker.position + zz._shaker.size * 0.5
		check(center.distance_to(Vector2(vs) * 0.5) < 6.0, "centered at %s" % vs)
		zz.skip()
		check(count == 1, "skip finishes at %s" % vs)
		sv.queue_free()
	check(load("res://src/blockout/guest_dialogue_portrait.gd") != null, "guest portrait loads")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
