extends SceneTree
const Art = preload("res://src/mystery/house_item_art.gd")
const Session = preload("res://src/mystery/house_case_session.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var art = Art.new()
	check(art.last_error.is_empty(), "Existing runtime evidence catalog loads")
	var mapped := 0
	var missing: Array = []
	var known: Dictionary = {}
	for item in art.item_catalog.items:
		var name: String = item.name
		check(not known.has(name), name + ": unique selectable identity")
		known[name] = true
		var entry: Dictionary = art.asset(name)
		if entry.is_empty():
			missing.append(name)
			continue
		mapped += 1
		check(entry.texture.get_size() == Vector2(160, 160), name + ": imported inspection detail reused")
		check(entry.width > 0 and entry.height > 0, name + ": visible rendering extents")
		check(entry.width <= entry.world_bounds.size.x + .001 and entry.height <= entry.world_bounds.size.y + .001,
			name + ": existing world footprint preserved")
		check(is_equal_approx(entry.width / entry.height, entry.bounds.size.x / entry.bounds.size.y), name + ": source aspect ratio preserved")
		var at := Vector2(123, 234)
		var target: Rect2 = art.destination(name, at)
		check(is_equal_approx(target.get_center().x, at.x) and is_equal_approx(target.end.y, at.y), name + ": floor anchor preserved")
		check(entry.source_sha256 == FileAccess.get_sha256(entry.source), name + ": existing source hash")
		check(art.asset(name).texture == entry.texture, name + ": cached without rewriting pixels")
		check(art.detail(name) == entry.texture, name + ": inspection detail exposes actual item texture")
		check(entry.definition == item.evidence_id and entry.condition == item.variant, name + ": exact identity/variant mapping")
	check(mapped == art.item_catalog.items.size() and mapped == 10, "Ten distinct current item types have existing artwork")
	check(missing.is_empty(), "No unsupported placeholders enter the randomized pool")
	check(not known.has("Magnifying glass"), "Magnifier is separate from potential weapon pool")
	for name in ["Letter opener", "Brass candlestick", "Marble ornament", "Walking cane", "Old wrench"]:
		check(art.asset(name).is_empty(), name + ": no incompatible art substituted")
	var magnifier: Dictionary = art.asset("Magnifying glass")
	check(not magnifier.is_empty() and magnifier.definition == "magnifier", "The glass uses actual magnifier art")
	check(art.asset("Brass magnifying glass").source == magnifier.source, "Existing full glass label supported")
	check(art.asset("Unknown object").is_empty(), "Unknown objects do not inherit weapon art")
	check(art.destination("Old wrench", Vector2(100,100)).end.y == 100, "Unmapped inspection glint retains floor position")
	for path in Art.HASHES:
		check(FileAccess.get_sha256(path) == Art.HASHES[path], "Evidence source bytes unchanged: " + path)
	art.catalog.definitions.book.conditions.whole.closeup = "res://wrong.png"
	art.cache.clear()
	check(art.asset("Heavy book").is_empty() and not art.last_error.is_empty(), "Unexpected catalog mapping fails safely")
	print(JSON.stringify({"checks":checks,"mapped_case_items":mapped,"missing_art":missing,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
