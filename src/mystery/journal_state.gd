class_name JournalState
extends RefCounted
## Player-owned journal notes. Pure data: never reads or changes case truth.
const SUSPECT_FLAGS: Array = ["suspect", "cleared", "alibi_checked", "needs_questioning", "important"]
const EVIDENCE_FLAGS: Array = ["interesting", "connected", "ruled_out", "investigate", "room_searched", "contradiction"]
const NOTE_KINDS: Array = ["suspect", "evidence", "general"]
const NOTE_LIMIT := 400

var _flags: Dictionary = {}  # kind -> key -> {flag: true}
var _notes: Dictionary = {}  # kind -> key -> text

func reset() -> void:
	_flags = {"suspect": {}, "evidence": {}}
	_notes = {"suspect": {}, "evidence": {}, "general": {}}

func _init() -> void:
	reset()

static func valid_flags(kind: String) -> Array:
	if kind == "suspect": return SUSPECT_FLAGS
	if kind == "evidence": return EVIDENCE_FLAGS
	return []

func set_flag(kind: String, key: String, flag: String, value: bool) -> bool:
	if not valid_flags(kind).has(flag): return false
	var entry: Dictionary = _flags[kind].get(key, {})
	if value: entry[flag] = true
	else: entry.erase(flag)
	if entry.is_empty(): _flags[kind].erase(key)
	else: _flags[kind][key] = entry
	return true

func has_flag(kind: String, key: String, flag: String) -> bool:
	if not _flags.has(kind): return false
	return _flags[kind].get(key, {}).has(flag)

func flags_for(kind: String, key: String) -> Array:
	if not _flags.has(kind): return []
	return _flags[kind].get(key, {}).keys()

func set_note(kind: String, key: String, text: String) -> bool:
	if not NOTE_KINDS.has(kind): return false
	var clipped := text.substr(0, NOTE_LIMIT)
	if clipped.is_empty(): _notes[kind].erase(key)
	else: _notes[kind][key] = clipped
	return true

func get_note(kind: String, key: String = "") -> String:
	if not _notes.has(kind): return ""
	return str(_notes[kind].get(key, ""))

func to_dict() -> Dictionary:
	return {"flags": _flags.duplicate(true), "notes": _notes.duplicate(true)}

func from_dict(data: Dictionary) -> void:
	reset()
	var flags: Dictionary = data.get("flags", {})
	for kind in ["suspect", "evidence"]:
		for key in flags.get(kind, {}):
			for flag in flags[kind][key]:
				set_flag(kind, str(key), str(flag), true)
	var notes: Dictionary = data.get("notes", {})
	for kind in NOTE_KINDS:
		for key in notes.get(kind, {}):
			set_note(kind, str(key), str(notes[kind][key]))
