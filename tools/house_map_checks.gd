extends SceneTree
const MapPanel = preload("res://src/blockout/house_map_panel.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.investigation.layout.json"))
	var before := layout.duplicate(true)
	var visited := {"room_6": true, "hall_2": true}
	var visited_before := visited.duplicate(true)
	var panel := MapPanel.new()
	panel.setup(layout, "hall_2", visited)
	var data := panel.model()
	check(data.nodes.size() == 10, "All ten ordinary mansion screens are present")
	check(data.edges.size() == 12, "24 reciprocal doorway links collapse to twelve routes")
	check(not data.nodes.any(func(n): return n.id == "secret_passage"), "Unvisited secret passage is concealed")
	check(not data.edges.any(func(e): return e.secret), "Undiscovered passage routes are concealed")
	check(data.nodes.filter(func(n): return n.current).size() == 1 and data.nodes.filter(func(n): return n.current)[0].id == "hall_2", "Current room has the only gold highlight")
	check(data.nodes.filter(func(n): return n.visited).size() == 2, "Visited state follows player's actual visited set")
	check(data.nodes.filter(func(n): return n.id == "kitchen")[0].label == "Study", "Legacy kitchen ID displays actual Study name")
	check(data.nodes.filter(func(n): return n.id == "room_4")[0].label == "Kitchen", "Actual Kitchen displays correctly")
	check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and panel.focus_mode == Control.FOCUS_NONE, "Map has no clickable teleport or keyboard movement behavior")
	check(panel.custom_minimum_size == Vector2(680, 400), "Map provides a readable native layout size")
	for node in data.nodes:
		check(Rect2(Vector2.ZERO, panel.custom_minimum_size).encloses(node.rect), "Room box stays inside map bounds")
		for other in data.nodes:
			if node.id < other.id:
				check(not node.rect.intersects(other.rect), "Room boxes do not overlap")
	visited.secret_passage = true
	panel.setup(layout, "secret_passage", visited)
	data = panel.model()
	check(data.nodes.size() == 11 and data.edges.size() == 14, "Visited passage reveals eleven screens and two hidden connections")
	check(data.nodes.filter(func(n): return n.current)[0].label == "Secret passage", "Discovered passage can be highlighted normally")
	check(data.edges.filter(func(e): return e.secret).size() == 2, "Only the two actual secret routes use dashed lines")
	check(layout == before and visited_before == {"room_6": true, "hall_2": true}, "Map construction never changes layout or supplied previous visit data")
	var alternate := layout.duplicate(true)
	alternate.screens.reverse()
	panel.setup(alternate, "room_4", {})
	check(panel.model().nodes.filter(func(n): return n.id == "room_4")[0].rect == MapPanel.BOXES.room_4, "Room positions are stable under screen reordering")
	panel.setup(layout, "secret_passage", {})
	check(panel.model().nodes.any(func(n): return n.id == "secret_passage"), "Entering passage reveals it even before visit collection updates")
	panel.free()
	print(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
