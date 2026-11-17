extends RefCounted
## Python case_design.rng parity, without interpreting an unsigned hash as signed.
var key: PackedByteArray
var counter := 0

func _init(version: int, seed_value: int, stream_name: String) -> void:
	key = ("mm-case:%d:%d:%s" % [version, seed_value, stream_name]).to_utf8_buffer()

func below(bound: int) -> int:
	assert(bound > 0 and bound <= 1000000)
	var bytes := key.duplicate()
	for index in range(8):
		bytes.append((counter >> (8 * (7 - index))) & 255)
	counter += 1
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var digest := hashing.finish()
	var remainder := 0
	# Horner's method computes the first 8 bytes as unsigned u64 modulo bound.
	# intermediate values stay small even when the digest's top bit is set.
	for index in range(8):
		remainder = (remainder * 256 + int(digest[index])) % bound
	return remainder

func chance(probability: float) -> bool:
	if probability <= 0:
		return false
	if probability >= 1:
		return true
	return below(1000000) < int(probability * 1000000)

func choice(values: Array) -> Variant:
	return values[below(values.size())]

func shuffle(values: Array) -> Array:
	var result := values.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var other := below(index + 1)
		var saved: Variant = result[index]
		result[index] = result[other]
		result[other] = saved
	return result
