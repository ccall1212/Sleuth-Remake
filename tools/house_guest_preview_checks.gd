extends SceneTree
const Preview = preload("res://src/blockout/house_guest_preview.gd")
const RoomTexture = preload("res://src/blockout/approved_room_texture.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/house-02.painted.layout.json"))
	var preview := Preview.new()
	check(preview.load_placements(layout), "Imported placements load: " + preview.error)
	var total_spots := 0
	var total_masks := 0
	for screen in layout.screens:
		var spots := preview.spots(screen.id)
		var masks := preview.masks(screen.id)
		total_spots += spots.size()
		total_masks += masks.size()
		if spots.is_empty() and masks.is_empty():
			continue
		var background := RoomTexture.load_approved(screen.background, screen.background_sha256)
		check(background != null, str(screen.id) + ": background loaded")
		for spot in spots:
			var pose := preview.render_pose(spot)
			check(not pose.is_empty(), str(spot.id) + ": exact saved pose")
			if pose.is_empty():
				continue
			check(pose.source == spot.render.source and pose.sha256 == spot.render.sha256, "Imported indexed source preserved")
			check(pose.contact == spot.source_contact, "Saved contact preserved")
			check(preview.texture(pose) != null, "Approved character texture loads")
			var rect := preview.render_rect(spot, pose)
			var scale := preview.adult_height / float(pose.standing_reference)
			check((rect.position + Vector2(pose.contact[0], pose.contact[1]) * scale).distance_to(Vector2(spot.at[0], spot.at[1])) < 0.001, "PNG contact lands exactly on saved anchor")
		for mask in masks:
			var texture := preview.mask_texture(mask, background)
			check(texture != null, str(mask.id) + ": rasterizes, including crossing edges")
			if texture == null:
				continue
			var image := texture.get_image()
			check(image.get_size() == Vector2i(background.get_size()), "Foreground retains original room resolution")
			check(image.get_used_rect().size != Vector2i.ZERO, "Foreground has visible pixels")
			check(image.get_pixel(0, 0).a == 0, "Pixels outside furniture remain transparent")
		var commands := preview.commands(screen.id)
		check(commands.size() == spots.size() + masks.size(), "All guests and masks enter painter order")
		for index in range(1, commands.size()):
			check(commands[index].depth >= commands[index-1].depth, "Painter order follows feet/seat contact")
		preview.show_masks = false
		check(preview.commands(screen.id).size() == spots.size(), "Mask toggle preserves guests")
		preview.show_masks = true
		for actor in ["Char", "Chris"]:
			preview.actor_override = actor
			for activity in ["idle", "read", "look_up", "look_down", "sleep"]:
				preview.activity_override = activity
				for spot in spots:
					var pose := preview.render_pose(spot)
					check(not pose.is_empty() and pose.posture == spot.posture and pose.facing == spot.facing, "Pose switching preserves slot posture/facing with safe fallback")
		preview.actor_override = ""
		preview.activity_override = ""
	var imported: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Preview.PATH))
	check(total_spots == int(imported.validation.guest_spots) and total_masks == int(imported.validation.foreground_masks), "Every validated slot and mask reaches the renderer")
	var changed := layout.duplicate(true)
	changed.screens[0].background_sha256 = "changed"
	check(not preview.load_placements(changed) and preview.rooms.is_empty(), "Changed room artwork rejects stale placements")
	print(JSON.stringify({"checks": checks, "failures": failures, "spots": total_spots, "masks": total_masks}))
	quit(0 if failures.is_empty() else 1)
