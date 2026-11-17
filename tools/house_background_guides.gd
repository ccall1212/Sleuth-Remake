extends SceneTree
## Deterministic layout diagrams only; these are generation guides, not room art.
const Geometry = preload("res://src/blockout/house_layout.gd")
class Guide extends Node2D:
	var screen: Dictionary
	var geometry: RefCounted
	func _draw() -> void:
		if screen.is_empty(): return
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * 3.2)
		draw_rect(Rect2(0, 0, 480, 360), Color("25313d"))
		for rect in screen.walk_regions:
			draw_rect(Geometry.rectangle(rect), Color("91b9c7"))
		for index in range(screen.obstacles.size()):
			var rect: Rect2 = Geometry.rectangle(screen.obstacles[index])
			draw_rect(rect, Color("a57648"))
			draw_rect(rect, Color("f6d4a5"), false, 1)
			var kinds: Array = screen.get("obstacle_kinds", [])
			if index < kinds.size():
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(2, 9), str(kinds[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
		for portal in screen.portals:
			var at: Vector2 = Geometry.point(portal.at)
			var direction: Vector2 = Geometry.point(portal.facing)
			var side := direction.orthogonal()
			draw_line(at - side * 11, at + side * 11, Color.CYAN, 4)
			draw_line(at - direction * 12, at + direction * 4, Color.CYAN, 1)
		if screen.id == geometry.data.secret.entrance_room:
			draw_rect(Rect2(geometry.secret_panel() - Vector2(9, 2), Vector2(18, 5)), Color.MAGENTA)
		if screen.id == geometry.data.secret.screen:
			draw_circle(geometry.secret_exit(), 6, Color.MAGENTA, false, 2)
		draw_string(ThemeDB.fallback_font, Vector2(10, 19), str(screen.name).to_upper() + " / LOCKED FLOOR PLAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1536, 1152)
	root.content_scale_size = Vector2i(1536, 1152)
	var geometry = Geometry.new()
	assert(geometry.load_layout())
	var folder := "res://assets/rooms/house-02/guides"
	DirAccess.make_dir_recursive_absolute(folder)
	var guide := Guide.new()
	guide.geometry = geometry
	root.add_child(guide)
	for screen in geometry.data.screens:
		guide.screen = screen
		guide.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "/" + str(screen.id) + ".png")
	print("WROTE 11 HOUSE-02 LAYOUT GUIDES")
	quit()
