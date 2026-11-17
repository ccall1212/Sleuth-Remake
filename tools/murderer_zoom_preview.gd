extends SceneTree
## Run WITHOUT --headless. Saves zoom_1_anticipation / zoom_2_impact / zoom_3_hold screenshots.
const Zoom = preload("res://src/blockout/murderer_zoom.gd")
const CastPortrait = preload("res://src/blockout/cast_portrait.gd")

func _initialize() -> void:
	call_deferred("run")

func shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://test-results/screenshots/%s.png" % shot_name))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/screenshots"))
	var bg := ColorRect.new(); bg.color = Color("5a4a3a"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var label := Label.new(); label.text = "Mansion scene behind overlay"; label.position = Vector2(60, 60)
	bg.add_child(label)
	root.add_child(bg)
	var z: Control = Zoom.new()
	root.add_child(z)
	z.play(CastPortrait.figure("Char"))
	await create_timer(0.5).timeout
	await shot("zoom_1_anticipation")
	await create_timer(0.36).timeout
	await shot("zoom_2_impact")
	await create_timer(0.7).timeout
	await shot("zoom_3_hold")
	z.skip()
	quit()
