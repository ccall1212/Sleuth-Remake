extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var entry: String = ProjectSettings.get_setting("application/run/main_scene")
	check(entry == "res://src/mystery/painted_mystery.tscn", "F5 points to current painted entry")
	var scene = load(entry).instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.painted and scene.model.data.get("mode") == "painted_investigation", "Default entry binds actual painted investigation without CLI flags")
	check(scene.random_on_start and scene.random_case.button_pressed, "F5 starts a randomized case")
	check(scene.investigation.data.claims.size() == 6 and scene.investigation.items.size() == 10, "Default game has six suspects and portable items")
	check(scene.model.current_id == scene.model.data.start and scene.investigation.active(), "Default entry starts a live mystery at front entry")
	check(scene.killer_preview_remaining == 0 and not scene.diagnostics, "Default entry is normal play without debug or forced-killer mode")
	if "--capture-ui" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/main-entry"))
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/main-entry/game.png")
	scene.queue_free()
	await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
