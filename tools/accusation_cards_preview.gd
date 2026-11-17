extends SceneTree
const Cards = preload("res://src/blockout/accusation_cards.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(960, 720)
	var bg := ColorRect.new()
	bg.color = Color("0c0f11")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var d = Cards.new()
	root.add_child(d)
	d.setup(["Char", "Chris", "Justin", "Danny", "Gage", "Robbie"], "the Library")
	d.popup_centered(Vector2i(760, 560))
	for i in 5: await process_frame
	d.select(2)
	for i in 5: await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/screenshots"))
	var img := root.get_texture().get_image()
	print("save: ", img.save_png("res://test-results/screenshots/accusation_cards.png"))
	quit()
