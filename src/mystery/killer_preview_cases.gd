extends RefCounted
## Opt-in art playtests choose a naturally generated case, never rewrite truth.
const Case = preload("res://src/mystery/generated_case.gd")
const SEED_LIMIT := 1000000000
const SEARCH_LIMIT := 5000
const VOICE_ORDER := ["hot_tempered", "fragile", "proud", "nervous", "guarded", "curious", "warm", "calm"]

static func find_seed(start_seed: int, target: String, difficulty := "normal", voice := "") -> int:
	if not Case.POOL.has(target) or not Case.SETTINGS.has(difficulty):
		return -1
	if not voice.is_empty() and voice not in Case.PERSONALITIES: return -1
	var first := posmod(start_seed, SEED_LIMIT)
	for offset in range(SEARCH_LIMIT):
		var candidate := posmod(first + offset, SEED_LIMIT)
		var truth: Dictionary = Case.generate(candidate, 6, difficulty)
		if not truth.is_empty() and str(truth.cast[truth.culprit]) == target and (voice.is_empty() or truth.personalities[truth.culprit] == voice):
			return candidate
	return -1

static func confession_pose(voice: String, actor_name := "") -> String:
	if actor_name == "Chris" and voice in ["fragile", "nervous", "warm"]:
		return "crouching_cry_south"
	return {"hot_tempered": "standing_threaten_south", "fragile": "standing_cry_south",
		"nervous": "standing_cry_south", "warm": "standing_cry_south",
		"proud": "standing_accuse_south", "curious": "standing_laugh_south"}.get(voice, "standing_shrug_south")
