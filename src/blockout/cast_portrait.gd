extends RefCounted
## One source of character art for the accusation cards and the notebook.
## Char and Chris use their approved standing_idle_south pose; every other cast member uses the roster artwork.
## Never creates art. Returns null when no approved/roster artwork exists (callers show the name only).
const ActorArt = preload("res://src/mystery/case_actor_art.gd")
const Presentation = preload("res://src/mystery/guest_presentation.gd")
## name -> personality for guests the player has already questioned. Their portrait shows the approved standing pose that matches that
## personality (talk, think, fidget, cross_arms, hands_hips or withdraw) instead of the neutral idle. Unquestioned guests stay neutral,
## so the log book never gives away personality (or anything else) before the player has met them. Only Char and Chris have pose
## libraries today; other cast members keep their single roster image until approved poses exist for them.
static var expressions: Dictionary = {}
static var _art: RefCounted
static var _cache: Dictionary = {}

static func art() -> RefCounted:
	if _art == null: _art = ActorArt.new()
	return _art

## Full standing figure as a texture (an AtlasTexture cropped to the figure's bounds).
static func pose_for(actor_name: String) -> String:
	if not expressions.has(actor_name) or not ActorArt.ACTORS.has(actor_name): return "standing_idle_south"
	return "standing_%s_south" % Presentation.talking_action(str(expressions[actor_name]))

static func figure(actor_name: String) -> Texture2D:
	var pose := pose_for(actor_name)
	var key := actor_name + "|" + pose
	if _cache.has(key): return _cache[key]
	var record: Dictionary = art().asset(actor_name, pose) if ActorArt.ACTORS.has(actor_name) else art().playtest_asset(actor_name)
	if record.is_empty() and ActorArt.ACTORS.has(actor_name):
		record = art().asset(actor_name, "standing_idle_south") # a missing expression falls back to the neutral approved pose
	var result: Texture2D = null
	if not record.is_empty() and record.has("texture") and record.has("bounds"):
		var atlas := AtlasTexture.new()
		atlas.atlas = record.texture
		atlas.region = record.bounds
		result = atlas
	_cache[key] = result
	return result

## Head-and-shoulders crop for small cards: the top fraction of the figure (default 38%), same pixels, no scaling or recolouring.
static func bust(actor_name: String, fraction := 0.38) -> Texture2D:
	var whole := figure(actor_name)
	if whole == null: return null
	var atlas := whole as AtlasTexture
	var region: Rect2 = atlas.region
	var crop := AtlasTexture.new()
	crop.atlas = atlas.atlas
	crop.region = Rect2(region.position, Vector2(region.size.x, region.size.y * fraction))
	return crop
