extends RefCounted
## Presentation-only typewriter. Does not rewrite text or advance game clocks.
var characters_per_second := 160.0
var punctuation_pause := 0.03
var sentence_pause := 0.06
var _label: RichTextLabel
var _total := 0
var _shown := 0
var _wait := 0.0

func start(label: RichTextLabel) -> void:
	stop()
	if not is_instance_valid(label): return
	_label = label
	_total = label.get_total_character_count()
	_shown = 0
	_wait = 1.0 / maxf(1.0, characters_per_second)
	_label.visible_characters = 0

func is_active() -> bool:
	return is_instance_valid(_label) and _shown < _total

func advance(delta: float) -> void:
	if not is_active() or delta <= 0.0: return
	_wait -= delta
	var plain := _label.get_parsed_text()
	while _wait <= 0.0 and _shown < _total:
		_shown += 1
		_label.visible_characters = _shown
		_wait += 1.0 / maxf(1.0, characters_per_second)
		if _shown <= plain.length():
			var character := plain.substr(_shown - 1, 1)
			if character in [".", "!", "?", "\n"]:
				_wait += sentence_pause
			elif character in [",", ";", ":"]:
				_wait += punctuation_pause

func finish() -> void:
	if not is_instance_valid(_label):
		stop()
		return
	_shown = _total
	_label.visible_characters = _total

func stop() -> void:
	_label = null
	_total = 0
	_shown = 0
	_wait = 0.0
