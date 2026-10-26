extends SceneTree
## Renders contact sheets of the approved Chris and Char pose exports with Godot, plus a side-by-side comparison of
## matching poses. Reads the PNGs straight from exports/ (no import needed). Output: test-results/pose-library/.
##
##   Godot --path . --rendering-method gl_compatibility --script tools/pose_library_preview.gd
##
## Two kinds of sheet: "fit" (each pose scaled to its own box, to see the art) and "true scale" (every pose drawn at
## the same factor TRUE_K of its native pixels, feet on a common ground line, with height guides, to compare real sizes).
##
## Technical preview only: it shows pixels as exported (native canvases, no alignment or furniture fit) on a dark
## background so transparency and edges are visible. It does not approve or integrate anything.

const CHARACTERS := {"chris": "Chris", "char": "Char"}
const SECTIONS := ["north", "east", "south", "west", "lying", "murderer-reveal"]
const CELL := Vector2(124, 188)
const THUMB := Vector2(116, 150)
const COLUMNS := 14
const OUT_DIR := "res://test-results/pose-library/"
const BG := Color("#2b3036")
const TRUE_K := 0.12            # true-scale factor: native pixels * 0.12 (a 1650 px figure is 198 px)
const TRUE_BOX := Vector2(192, 204)
const STAND_HEIGHT := {"chris": 1564, "char": 1673}   # occupied standing heights from the manifests (native px)

var font: Font = ThemeDB.fallback_font


func _initialize() -> void:
	_run.call_deferred()


func _folder(character: String, section: String) -> String:
	return "res://assets/characters/poses/%s/exports/%s/" % [character, section]


func _pngs(path: String) -> Array:
	var names: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return names
	for file in dir.get_files():
		if file.ends_with(".png"):
			names.append(file)
	names.sort()
	return names


func _texture(path: String) -> ImageTexture:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _cell(parent: Node2D, at: Vector2, path: String, label: String, box: Vector2, fixed := 0.0) -> void:
	var texture := _texture(path)
	if texture != null:
		var size := texture.get_size()
		var scale := fixed if fixed > 0.0 else minf(box.x / size.x, box.y / size.y)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.scale = Vector2(scale, scale)
		sprite.position = at + Vector2((box.x - size.x * scale) / 2.0, box.y - size.y * scale)
		parent.add_child(sprite)
	var text := Label.new()
	text.text = label.replace("_", " ")
	text.add_theme_font_size_override("font_size", 9)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(box.x, 30)
	text.size = Vector2(box.x, 30)
	text.position = at + Vector2(0, box.y + 2)
	parent.add_child(text)


func _header(parent: Node2D, at: Vector2, value: String) -> void:
	var text := Label.new()
	text.text = value
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", Color("#efd29a"))
	text.position = at
	parent.add_child(text)


func _render(size: Vector2i, build: Callable, out_path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var canvas := Node2D.new()
	viewport.add_child(canvas)
	var background := ColorRect.new()
	background.color = BG
	background.size = Vector2(size)
	canvas.add_child(background)
	build.call(canvas)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(out_path))
	print("%s -> %s (%d)" % [out_path, size, error])
	viewport.queue_free()


func _guide(parent: Node2D, at: Vector2, box: Vector2, character: String, color: Color) -> void:
	var line := Line2D.new()
	var y: float = at.y + box.y - float(STAND_HEIGHT[character]) * TRUE_K
	line.points = PackedVector2Array([Vector2(at.x, y), Vector2(at.x + box.x, y)])
	line.width = 1.0
	line.default_color = color
	parent.add_child(line)


func _sheet(character: String, true_scale := false) -> void:
	var thumb := TRUE_BOX if true_scale else THUMB
	var cell := thumb + Vector2(8, 38)
	var columns := 8 if true_scale else COLUMNS
	var fixed := TRUE_K if true_scale else 0.0
	var rows := 0
	var plan: Array = []
	for section in SECTIONS:
		var files := _pngs(_folder(character, section))
		if files.is_empty():
			continue
		plan.append([section, files])
		rows += int(ceil(files.size() / float(columns)))
	var height := 24 + plan.size() * 30 + rows * int(cell.y) + 20
	var width := int(columns * cell.x + 24)
	var build := func(canvas: Node2D) -> void:
		var y := 12.0
		var total := 0
		for entry in plan:
			total += entry[1].size()
		var mode: String = "TRUE SCALE x%.2f (red line = standing height)" % TRUE_K if true_scale else "fit to box, not to scale"
		_header(canvas, Vector2(12, y), "%s: %d approved exports, %s" % [CHARACTERS[character], total, mode])
		y += 30
		for entry in plan:
			_header(canvas, Vector2(12, y), "%s (%d)" % [entry[0], entry[1].size()])
			y += 26
			var index := 0
			for file in entry[1]:
				var at := Vector2(12 + (index % columns) * cell.x, y + (index / columns) * cell.y)
				if true_scale:
					_guide(canvas, at, thumb, character, Color(1, 0.3, 0.3, 0.55))
				_cell(canvas, at, _folder(character, entry[0]) + file, file.trim_prefix(character + "_").trim_suffix(".png"), thumb, fixed)
				index += 1
			y += int(ceil(entry[1].size() / float(columns))) * cell.y + 4
	var suffix := "-true-scale" if true_scale else ""
	await _render(Vector2i(width, height), build, OUT_DIR + character + suffix + ".png")


func _compare(true_scale := false) -> void:
	var pairs: Array = []
	for section in ["south", "east", "west", "north", "murderer-reveal"]:
		var chris := _pngs(_folder("chris", section))
		var char_files := _pngs(_folder("char", section))
		for file in chris:
			var tail: String = file.trim_prefix("chris_")
			if char_files.has("char_" + tail):
				pairs.append([section, tail, _folder("chris", section) + file, _folder("char", section) + "char_" + tail])
	var thumb := TRUE_BOX if true_scale else THUMB
	var fixed := TRUE_K if true_scale else 0.0
	var cols := 4 if true_scale else 6
	var cell := Vector2(2 * thumb.x + 24, thumb.y + 40)
	var rows := int(ceil(pairs.size() / float(cols)))
	var size := Vector2i(int(cols * cell.x + 24), int(rows * (cell.y + 10) + 60))
	var build := func(canvas: Node2D) -> void:
		var mode: String = "TRUE SCALE x%.2f, feet on one line; lines: red = Chris standing height, blue = Char's" % TRUE_K if true_scale else "fit to box, not to scale"
		_header(canvas, Vector2(12, 10), "Chris (left) vs Char (right): %d matching poses, %s" % [pairs.size(), mode])
		for i in pairs.size():
			var at := Vector2(12 + (i % cols) * cell.x, 44 + (i / cols) * (cell.y + 10))
			var right := at + Vector2(thumb.x + 8, 0)
			if true_scale:
				_guide(canvas, at, thumb, "chris", Color(1, 0.3, 0.3, 0.6))
				_guide(canvas, right, thumb, "char", Color(0.4, 0.6, 1, 0.7))
			_cell(canvas, at, pairs[i][2], pairs[i][1].trim_suffix(".png") + " (Chris)", thumb, fixed)
			_cell(canvas, right, pairs[i][3], "(Char)", thumb, fixed)
	var name := "chris-vs-char-true-scale" if true_scale else "chris-vs-char"
	await _render(size, build, OUT_DIR + name + ".png")


func _run() -> void:
	for character in CHARACTERS:
		await _sheet(character)
		await _sheet(character, true)
	await _compare()
	await _compare(true)
	quit()
