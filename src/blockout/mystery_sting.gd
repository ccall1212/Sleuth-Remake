extends AudioStreamPlayer
## User-selected encounter audio, preserved byte-for-byte from supplied MP3s.
const STING_PATH := "res://assets/audio/ambush-sting.mp3"
const DOOR_PATH := "res://assets/audio/door-lock.mp3"
const WIN_PATH := "res://assets/audio/case-win.mp3"

static func clip(path: String) -> AudioStreamMP3:
	var audio := AudioStreamMP3.new()
	audio.data = FileAccess.get_file_as_bytes(path)
	audio.loop = false
	return audio

static func create_stream() -> AudioStreamMP3:
	return clip(STING_PATH)

static func create_door_stream() -> AudioStreamMP3:
	return clip(DOOR_PATH)

static func create_win_stream() -> AudioStreamMP3:
	return clip(WIN_PATH)

func _ready() -> void:
	volume_db = 0.0
	stream = create_stream()

func play_sting() -> void:
	if stream == null: stream = create_stream()
	stop()
	play()
