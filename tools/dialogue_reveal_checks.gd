extends SceneTree
const Reveal = preload("res://src/blockout/dialogue_reveal.gd")
const Sting = preload("res://src/blockout/mystery_sting.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var label := RichTextLabel.new()
	label.text = "Hello, Char."
	root.add_child(label)
	await process_frame
	var reveal = Reveal.new()
	reveal.start(label)
	check(label.visible_characters == 0 and reveal.is_active(), "Dialogue begins hidden and active")
	reveal.advance(0.05)
	check(label.visible_characters > 0 and label.visible_characters < label.get_total_character_count(), "Time reveals a partial line")
	reveal.finish()
	check(label.visible_characters == label.get_total_character_count() and not reveal.is_active(), "Continue immediately reveals the complete line")
	label.text = "A.B"
	reveal.start(label)
	reveal.advance(2.0 / reveal.characters_per_second + 0.0001)
	check(label.visible_characters == 2, "Punctuation is revealed in order")
	reveal.advance(reveal.sentence_pause * 0.5)
	check(label.visible_characters == 2, "Sentence punctuation creates a brief pause")
	reveal.advance(0.30)
	check(label.visible_characters == 3 and not reveal.is_active(), "Reveal resumes after punctuation")
	label.text = "É—猫🙂"
	reveal.start(label)
	reveal.advance(1.0)
	check(label.visible_characters == label.get_total_character_count() and label.text == "É—猫🙂", "Unicode reveals without rewriting its source")
	label.text = "Another message"
	reveal.start(label)
	check(label.visible_characters == 0 and reveal.is_active(), "New message resets reveal")
	reveal.advance(-1)
	check(label.visible_characters == 0, "Negative time cannot advance reveal")
	reveal.stop()
	reveal.advance(1)
	check(not reveal.is_active() and label.visible_characters == 0, "Closing stops the presentation clock")
	label.text = ""
	reveal.start(label)
	check(not reveal.is_active(), "Empty text is immediately complete")
	reveal.start(label)
	label.queue_free()
	await process_frame
	reveal.finish()
	check(not reveal.is_active(), "Freed label is handled safely")
	var audio: AudioStreamMP3 = Sting.create_stream()
	var door: AudioStreamMP3 = Sting.create_door_stream()
	check(audio != null and door != null, "Both selected MP3 clips load")
	if audio != null and door != null:
		check(audio.get_length() > 0.0 and door.get_length() > 0.0, "Both clips have playable durations")
		check(not audio.loop and not door.loop, "One-shot encounter sounds do not loop")
		check(audio.data == FileAccess.get_file_as_bytes("res://assets/audio/ambush-sting.mp3"), "Sting playback uses exact user-selected MP3 bytes")
		check(door.data == FileAccess.get_file_as_bytes("res://assets/audio/door-lock.mp3"), "Door playback uses exact user-selected MP3 bytes")
		check(FileAccess.get_sha256("res://assets/audio/ambush-sting.mp3") == "5337a88e1412f8e47e5f8b2666f0a1457d3f037c642efec44b1505821d7e064e", "Selected sting source remains byte-identical")
		check(FileAccess.get_sha256("res://assets/audio/door-lock.mp3") == "0c0667792c6c9c2a2c593ee041c8dbeaeb6e6f4dc0f073dc9647b8e27c42c2bc", "Selected door source remains byte-identical")
		check(Sting.create_stream().data == audio.data, "Repeated playback retains exact chosen clip")
	print(JSON.stringify({"checks": checks, "failures": failures, "sting_duration": audio.get_length() if audio != null else 0.0, "door_duration": door.get_length() if door != null else 0.0}))
	quit(0 if failures.is_empty() else 1)
