extends TabContainer
## Read-only presentation of learned case facts, grouped for quick reference.
const NotebookTheme = preload("res://src/blockout/mystery_theme.gd")
var summary: RichTextLabel
var accounts: RichTextLabel
var item_table: Tree
var searches: RichTextLabel

static func escaped(value: Variant) -> String:
	return str(value).replace("[", "[lb]")

func _ready() -> void:
	build()

func page(title: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	return margin

func text_page(title: String) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = true
	text.selection_enabled = true
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_color_override("default_color", Color("e8e0d2"))
	page(title).add_child(text)
	return text

func build() -> void:
	if is_instance_valid(summary): return
	custom_minimum_size = Vector2(660, 400)
	add_theme_stylebox_override("panel", NotebookTheme.panel("111c23", "514936", 5, 0))
	add_theme_stylebox_override("tab_selected", NotebookTheme.panel("263238", "a18a56", 4, 10))
	add_theme_stylebox_override("tab_unselected", NotebookTheme.panel("172126", "514936", 4, 10))
	add_theme_color_override("font_selected_color", Color("e7c887"))
	add_theme_color_override("font_unselected_color", Color("aeb8b6"))
	summary = text_page("Summary")
	accounts = text_page("Accounts")
	item_table = Tree.new()
	item_table.columns = 4
	item_table.hide_root = true
	item_table.column_titles_visible = true
	item_table.select_mode = Tree.SELECT_ROW
	for index in range(4):
		item_table.set_column_title(index, ["Item", "Kind", "Mark", "Last known location"][index])
		item_table.set_column_expand(index, index == 0 or index == 3)
		item_table.set_column_custom_minimum_width(index, [190, 65, 90, 170][index])
	item_table.add_theme_font_size_override("font_size", 13)
	item_table.add_theme_color_override("font_color", Color("e8e0d2"))
	item_table.add_theme_constant_override("v_separation", 12)
	page("Items").add_child(item_table)
	searches = text_page("Searches")

func populate(session: RefCounted) -> void:
	build()
	var progress: Dictionary = session.progress
	var crime: String = str(session.room_names[int(progress.crime_room)]) if progress.crime_room != null else "Not recorded"
	var wound: String = str(progress.wound).capitalize() if progress.wound != null else "Not recorded"
	var lines: Array[String] = ["[font_size=20][color=#d7b977]Case notes[/color][/font_size]", "",
		"[color=#9baaa9]CRIME SCENE[/color]", "[b]Blood discovered:[/b] " + escaped(crime),
		"[b]Wound kind:[/b] " + escaped(wound)]
	if progress.weapon != null:
		lines.append("[b]Identified weapon:[/b] " + escaped(session.item_name(int(progress.weapon))))
	lines.append_array(["", "[color=#9baaa9]INVESTIGATION[/color]",
		"[b]Victim:[/b] " + escaped(session.data.cast[-1]),
		"[b]Holding:[/b] " + escaped(session.held_item().get("name", "Nothing")),
		"[b]Accounts heard:[/b] %d / %d" % [progress.heard.size(), session.data.claims.size()],
		"[b]Items noted:[/b] %d" % progress.items_seen.size()])
	summary.text = "\n".join(lines)
	var statements: Array[String] = []
	for person in range(session.data.claims.size()):
		statements.append("[b][color=#d7b977]" + escaped(session.data.cast[person]) + "[/color][/b]")
		var claim: Variant = progress.heard.get(str(person))
		if claim == null:
			statements.append("[color=#899997]Not questioned[/color]")
		else:
			var partner := "Alone" if claim.partner == null else "With " + str(session.data.cast[int(claim.partner)])
			statements.append(escaped(session.room_names[int(claim.room)]) + "  ·  " + escaped(partner))
		statements.append("")
	accounts.text = "\n".join(statements)
	item_table.clear()
	var root := item_table.create_item()
	for key in progress.items_seen:
		var seen: Dictionary = progress.items_seen[key]
		var row := item_table.create_item(root)
		row.set_metadata(0, key)
		row.set_text(0, str(seen.name))
		row.set_text(1, "Tool" if seen.is_glass else str(seen.kind).capitalize())
		var mark: String = "—" if seen.is_glass else str({"present": "Stained", "absent": "Clean"}.get(str(seen.get("stain", "")), "Unchecked"))
		row.set_text(2, mark)
		row.set_custom_color(2, Color("FF9F40") if seen.get("stain") == "present" else Color("aeb8b6"))
		row.set_text(3, "Carried" if seen.held else str(session.screen_names.get(seen.screen, seen.screen)))
		for index in range(4): row.set_tooltip_text(index, row.get_text(index))
	var floors: Array[String] = ["[font_size=18][color=#d7b977]Floor searches[/color][/font_size]", ""]
	if progress.crime_room != null:
		floors.append("[b]Blood discovered:[/b] " + escaped(crime))
		floors.append("[b]Wound kind:[/b] " + escaped(wound))
		floors.append("")
	floors.append("[color=#9baaa9]CHECKED · NO CRIME TRACES[/color]")
	for room in progress.clean_floors:
		floors.append("•  " + escaped(session.room_names[int(room)]))
	if progress.clean_floors.is_empty(): floors.append("[color=#899997]None recorded[/color]")
	searches.text = "\n".join(floors)
	current_tab = 0
	for text in [summary, accounts, searches]: text.scroll_to_line(0)
