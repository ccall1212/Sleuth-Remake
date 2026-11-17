extends Control
## Read-only House 02 connectivity. Screen artwork coordinates are not map scale.
const MysteryTheme = preload("res://src/blockout/mystery_theme.gd")
const MAP_SIZE := Vector2(680, 400)
const BOXES := {
	"library": Rect2(270, 16, 140, 44),
	"hall_2": Rect2(305, 76, 70, 252),
	"room_6": Rect2(270, 344, 140, 44),
	"room_2": Rect2(75, 90, 150, 46),
	"room": Rect2(75, 171, 150, 46),
	"kitchen": Rect2(75, 252, 150, 46),
	"room_3": Rect2(455, 90, 150, 46),
	"room_4": Rect2(455, 171, 150, 46),
	"room_5": Rect2(455, 252, 150, 46),
	"room_7": Rect2(455, 16, 150, 44),
	"secret_passage": Rect2(20, 344, 170, 44),
}
var map_nodes: Array = []
var map_edges: Array = []
var current_id := ""

func _init() -> void:
	custom_minimum_size = MAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

func setup(layout: Dictionary, current: String, visited: Dictionary) -> void:
	current_id = current
	map_nodes.clear()
	map_edges.clear()
	var shown := {}
	var secret: Dictionary = layout.get("secret", {})
	var secret_id := str(secret.get("screen", ""))
	for screen in layout.get("screens", []):
		var id := str(screen.id)
		if (id == secret_id or screen.get("role") == "secret") and not visited.has(id) and id != current:
			continue
		if not BOXES.has(id):
			continue # This is the House 02 plan, not a general graph-layout editor.
		var node := {"id": id, "label": str(screen.name), "rect": BOXES[id],
			"current": id == current, "visited": visited.has(id), "secret": id == secret_id}
		map_nodes.append(node)
		shown[id] = node
	var seen := {}
	for screen in layout.get("screens", []):
		if not shown.has(str(screen.id)):
			continue
		for portal in screen.get("portals", []):
			add_edge(str(screen.id), str(portal.target), false, shown, seen)
	if shown.has(secret_id):
		add_edge(str(secret.get("entrance_room", "")), secret_id, true, shown, seen)
		add_edge(secret_id, str(secret.get("exit_room", "")), true, shown, seen)
	queue_redraw()

func add_edge(a: String, b: String, hidden_route: bool, shown: Dictionary, seen: Dictionary) -> void:
	if not shown.has(a) or not shown.has(b) or a == b:
		return
	var pair := [a, b]
	pair.sort()
	var key := "|".join(pair)
	if seen.has(key):
		return
	seen[key] = true
	var from: Rect2 = shown[a].rect
	var to: Rect2 = shown[b].rect
	var points := PackedVector2Array()
	if hidden_route:
		# Route discovered passages outside ordinary room boxes. These are
		# dashed schematic links, not a claim of exact architectural distance.
		var other_id := b if a == "secret_passage" else a
		var other: Rect2 = shown[other_id].rect
		var passage: Rect2 = shown["secret_passage"].rect
		if other_id == "library":
			points = PackedVector2Array([Vector2(other.position.x, other.get_center().y), Vector2(30, other.get_center().y), Vector2(30, passage.position.y)])
		else:
			points = PackedVector2Array([Vector2(other.get_center().x, other.end.y), Vector2(other.get_center().x, passage.position.y)])
	elif a == "hall_2" or b == "hall_2":
		var room: Rect2 = to if a == "hall_2" else from
		var hall: Rect2 = shown["hall_2"].rect
		if room.end.y < hall.position.y:
			points = PackedVector2Array([Vector2(room.get_center().x, room.end.y), Vector2(hall.get_center().x, hall.position.y)])
		elif room.position.y > hall.end.y:
			points = PackedVector2Array([Vector2(hall.get_center().x, hall.end.y), Vector2(room.get_center().x, room.position.y)])
		elif room.get_center().x < hall.get_center().x:
			points = PackedVector2Array([Vector2(room.end.x, room.get_center().y), Vector2(hall.position.x, room.get_center().y)])
		else:
			points = PackedVector2Array([Vector2(hall.end.x, room.get_center().y), Vector2(room.position.x, room.get_center().y)])
	else:
		var delta := to.get_center() - from.get_center()
		if absf(delta.x) > absf(delta.y):
			points = PackedVector2Array([Vector2(from.end.x if delta.x > 0 else from.position.x, from.get_center().y), Vector2(to.position.x if delta.x > 0 else to.end.x, to.get_center().y)])
		else:
			points = PackedVector2Array([Vector2(from.get_center().x, from.end.y if delta.y > 0 else from.position.y), Vector2(to.get_center().x, to.position.y if delta.y > 0 else to.end.y)])
	map_edges.append({"a": a, "b": b, "secret": hidden_route, "points": points})

func model() -> Dictionary:
	return {"nodes": map_nodes.duplicate(true), "edges": map_edges.duplicate(true), "current_id": current_id}

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for edge in map_edges:
		var points: PackedVector2Array = edge.points
		for index in range(1, points.size()):
			if edge.secret:
				draw_dashed_line(points[index - 1], points[index], Color("9d8152"), 1.5, 6.0)
			else:
				draw_line(points[index - 1], points[index], Color("78817d"), 2.0, true)
	for node in map_nodes:
		var box: Rect2 = node.rect
		var fill := "424034" if node.current else ("263f42" if node.visited else "172126")
		var border := "dbc18b" if node.current else ("78817d" if node.visited else "3c4547")
		var style := MysteryTheme.panel(fill, border, 5, 0)
		if node.current:
			style.set_border_width_all(2)
		draw_style_box(style, box)
		var color := Color("fff1ce") if node.current else (Color("e8e0d2") if node.visited else Color("83908e"))
		var baseline: float = box.get_center().y + (0.0 if node.current else 5.0)
		draw_string(font, Vector2(box.position.x + 7, baseline), node.label, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 14, 13, color)
		if node.current:
			draw_string(font, Vector2(box.position.x + 7, baseline + 14), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 14, 9, Color("dbc18b"))
	draw_rect(Rect2(455, 349, 10, 10), Color("dbc18b"))
	draw_string(font, Vector2(471, 359), "Here", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e8e0d2"))
	draw_rect(Rect2(528, 349, 10, 10), Color("375d60"))
	draw_string(font, Vector2(544, 359), "Visited", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e8e0d2"))
	draw_string(font, Vector2(455, 380), "Dim rooms: not yet visited", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("83908e"))
