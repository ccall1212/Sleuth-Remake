extends RefCounted
## Shared, restrained game menus; no changes to room artwork.
static func panel(fill: String, border := "4b4540", radius := 5, padding := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func create() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	for kind in ["Button", "OptionButton", "MenuButton"]:
		result.set_stylebox("normal", kind, panel("20272b", "655944", 5, 7))
		result.set_stylebox("hover", kind, panel("303431", "c9ab70", 5, 7))
		result.set_stylebox("pressed", kind, panel("424034", "dbc18b", 5, 7))
		result.set_stylebox("disabled", kind, panel("171f23", "343a39", 5, 7))
		result.set_color("font_color", kind, Color("eee5d4"))
		result.set_color("font_disabled_color", kind, Color("78817d"))
		result.set_color("font_hover_color", kind, Color("fff1ce"))
	result.set_stylebox("panel", "PopupMenu", panel("172126", "9d8152"))
	result.set_stylebox("panel", "AcceptDialog", panel("172126", "9d8152", 7, 16))
	result.set_stylebox("embedded_border", "Window", panel("172126", "9d8152", 7, 8))
	result.set_color("title_color", "Window", Color("ead3a2"))
	result.set_color("font_color", "Label", Color("e8e0d2"))
	result.set_color("default_color", "RichTextLabel", Color("e8e0d2"))
	result.set_stylebox("normal", "LineEdit", panel("111a20", "655944", 4, 8))
	result.set_color("font_color", "LineEdit", Color("eee5d4"))
	return result
