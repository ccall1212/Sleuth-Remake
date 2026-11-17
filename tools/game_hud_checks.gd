extends SceneTree

const Hud := preload("res://src/blockout/game_hud.gd")

var checks := 0
var failures: Array = []
var last_pressed := ""


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func _initialize() -> void:
	_run.call_deferred()


func _make(size: Vector2i) -> Array:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var hud := Hud.new()
	vp.add_child(hud)
	return [vp, hud]


func _labels(n: Node, out: Array) -> Array:
	if n is Label:
		out.append(n)
	for c in n.get_children():
		_labels(c, out)
	return out


func _buttons(n: Node, out: Array) -> Array:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)
	return out


func _find_label(hud: Node, prefix: String) -> Label:
	for l in _labels(hud, []):
		if (l as Label).text.begins_with(prefix):
			return l
	return null


func _run() -> void:
	var pair := _make(Vector2i(960, 720))
	var hud = pair[1]
	await process_frame
	ok(hud != null, "builds")
	ok(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "root mouse_filter IGNORE")
	hud.action_pressed.connect(func(id: String) -> void: last_pressed = id)

	hud.set_room("Library")
	ok(_find_label(hud, "Library") != null, "room name shown")

	for p in [["Calm", Color("9bb8ca")], ["Suspicious", Color("FFD84A")], ["Stalking", Color("FF9F40")]]:
		hud.set_phase(p[0], p[1])
		var l := _find_label(hud, "Murderer:")
		ok(l != null and l.text == "Murderer: " + p[0], "phase text " + p[0])
		ok(l != null and l.get_theme_color("font_color") == p[1], "phase colour " + p[0])

	hud.set_inventory(true, "Brass candlestick")
	ok(_find_label(hud, "Glass: found") != null, "glass found text")
	ok(_find_label(hud, "Holding: Brass candlestick") != null, "held text")
	hud.set_inventory(false, "")
	ok(_find_label(hud, "Glass: not found") != null, "glass not found text")
	ok(_find_label(hud, "Hands free") != null, "hands free text")

	hud.set_actions({
		"interact": {"visible": true, "enabled": true},
		"floor": {"visible": true, "enabled": false},
		"accuse": {"visible": true, "enabled": true, "label": "Gather everyone"},
		"menu": {"visible": true, "enabled": true},
	})
	await process_frame
	ok(hud.visible_action_ids() == ["interact", "floor", "accuse", "menu"], "visible ids: %s" % [hud.visible_action_ids()])
	var by_id := {}
	for b in _buttons(hud, []):
		for a in Hud.ACTIONS:
			if (b as Button).tooltip_text == a[3]:
				by_id[a[0]] = b
	ok(by_id["floor"].disabled and not by_id["interact"].disabled, "disabled per state")
	ok(by_id["accuse"].text.contains("Gather everyone"), "label override")
	ok(not by_id["take"].visible, "hidden action not shown")
	ok(by_id["interact"].focus_mode == Control.FOCUS_NONE, "focus none")
	by_id["menu"].pressed.emit()
	ok(last_pressed == "menu", "pressed emits id")

	hud.set_enabled_all(false)
	var all_dis := true
	for id in hud.visible_action_ids():
		all_dis = all_dis and by_id[id].disabled
	ok(all_dis, "set_enabled_all(false) disables")
	hud.set_enabled_all(true)
	ok(not by_id["interact"].disabled, "set_enabled_all(true) restores")

	hud.show_hint("Try the desk.", 3.0)
	ok(hud.hint_visible(), "hint shown")
	hud.clear_hint()
	ok(not hud.hint_visible(), "hint cleared")
	pair[0].queue_free()
	await process_frame

	for size in [Vector2i(960, 720), Vector2i(1920, 1080)]:
		var pr := _make(size)
		var h = pr[1]
		h.set_room("Library")
		h.set_inventory(true, "Brass candlestick")
		h.set_phase("Stalking", Color("FF9F40"))
		h.set_actions({"interact": {"visible": true, "enabled": true}, "notebook": {"visible": true, "enabled": true},
			"map": {"visible": true, "enabled": true}, "accuse": {"visible": true, "enabled": true, "label": "Gather everyone"},
			"menu": {"visible": true, "enabled": true}})
		h.show_hint("Something glints under the desk.")
		await process_frame
		await process_frame
		var view := Rect2(Vector2.ZERO, Vector2(size))
		for panel in h.find_children("*", "PanelContainer", true, false):
			var pc := panel as PanelContainer
			if pc.visible:
				ok(view.encloses(pc.get_global_rect()), "panel inside %s: %s" % [size, pc.get_global_rect()])
		var bar: PanelContainer = null
		for panel in h.find_children("*", "PanelContainer", true, false):
			if (panel as Control).get_child(0) is HBoxContainer and (panel as Control).get_child(0).get_child_count() == Hud.ACTIONS.size():
				bar = panel
		ok(bar != null, "bar found")
		if bar:
			var cx := bar.get_global_rect().get_center().x
			ok(absf(cx - size.x / 2.0) <= 2.0, "bar centred at %s (cx=%s)" % [size, cx])
		pr[0].queue_free()
		await process_frame

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
