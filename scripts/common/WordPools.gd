extends RefCounted
class_name WordPools

# Base vocabulary pool for early-game body node concept names.
var base_name_adjectives: Array[String] = [
	"calm", "dim", "hollow", "faint", "still", "dull", "soft", "blank", "slow", "small",
	"pale", "mute", "vague", "quiet", "cold", "gray", "blurred", "raw", "odd", "latent",
    "distant", "wrong", "thin", "sunken",
	"aching", "flat", "tired", "decaying", "forgotten", "half", "folded", "worn", "absent", "bad"
]
var base_name_nouns: Array[String] = [
	"spark", "echo", "shape", "hue", "pulse", "thread", "drift", "knot", "signal", "memory",
	"angle", "form", "rhythm", "trace", "field", "tone", "shadow", "core", "glimmer", "vector",
	"hunger", "seam", "noise", "weight", "absence", "polygon", "node", "cluster", "fragment", "residue", "remnant", "whisper", "vessel",
    "circle", "line", "point", "void", "space", "part", "piece", "bit", "lump", "clump",
    "square", "gleam"
]

# Static pool for unowned node emotional labels.
var unowned_confused_status_pool: Array[String] = [
	"confused", "disoriented", "dazed", "panicked", "scared", "unsettled",
	"unhinged", "fragmented", "frayed", "shattered", "lost", "fading",
	"flickering", "unstable", "looping",
	"screaming quietly", "not here", "elsewhere", "repeating", "out of sequence",
	"looking for something", "mistaken", "homesick"
]

# Dynamic pool for owned node emotional labels.
var base_owned_emotions: Array[String] = [
	"calm", "sad", "angry", "fearful", "trusting", "convinced of something", "thinking"
]

# Dynamic pool for owned but disabled/inactive node emotional labels.
var inactive_owned_status_pool: Array[String] = [
	"sleeping", "resting", "dormant", "waiting",
	"dreaming of something", "not quite gone", "held", "between things",
	"still", "quiet now", "listening", "suspended"
]

# Condition overlays applied on top of ownership emotion status.
var hungry_status_pool: Array[String] = [
	"hungry", "ravenous", "peckish", "craving", "flagging", "wavering", "dizzy",
	"gnawing", "thinning", "running low", "asking for something", "hollow-edged", "wilting", "frail", "fading fast"
]
var very_hungry_status_pool: Array[String] = [
	"autophagic", "starving", "famished", "hollow", "depleted", "too hungry to feel",
    "eating itself", "past hungry", "forgetting its shape", "dissolving", "barely here"
]


func get_or_assign_node_concept_name(node_id: String, node_concept_names: Dictionary, rng: RandomNumberGenerator) -> String:
	var key := node_id.strip_edges()
	if key == "":
		return ""
	if node_concept_names.has(key):
		return str(node_concept_names[key])

	var existing: Dictionary = {}
	for value in node_concept_names.values():
		existing[str(value)] = true

	var candidates: Array[String] = []
	for adjective in base_name_adjectives:
		for noun in base_name_nouns:
			var candidate := _compose_adjective_noun(str(adjective), str(noun))
			if existing.has(candidate):
				continue
			candidates.append(candidate)

	if not candidates.is_empty():
		var selected := candidates[rng.randi_range(0, candidates.size() - 1)]
		node_concept_names[key] = selected
		return selected

	var fallback_base := _compose_adjective_noun("faint", "signal")
	var suffix := 2
	while true:
		var candidate := "%s%d" % [fallback_base, suffix]
		if not existing.has(candidate):
			node_concept_names[key] = candidate
			return candidate
		suffix += 1
	return fallback_base


func get_or_assign_owned_emotion(node_id: String, assignments: Dictionary, rng: RandomNumberGenerator) -> String:
	return _get_or_assign_unique_word(assignments, node_id, base_owned_emotions, "neutral", rng)


func get_or_assign_inactive_owned_emotion(node_id: String, assignments: Dictionary, rng: RandomNumberGenerator) -> String:
	return _get_or_assign_unique_word(assignments, node_id, inactive_owned_status_pool, "sleeping", rng)


func get_random_unowned_status(rng: RandomNumberGenerator) -> String:
	return _pick_random_word(unowned_confused_status_pool, "confused", rng)


func get_random_hungry_status(rng: RandomNumberGenerator) -> String:
	return _pick_random_word(hungry_status_pool, "hungry", rng)


func get_random_very_hungry_status(rng: RandomNumberGenerator) -> String:
	return _pick_random_word(very_hungry_status_pool, "starving", rng)


func _get_or_assign_unique_word(assignments: Dictionary, key_raw: String, pool: Array[String], fallback_base: String, rng: RandomNumberGenerator) -> String:
	var key := key_raw.strip_edges()
	if key == "":
		return ""
	if assignments.has(key):
		return str(assignments[key])

	var existing: Dictionary = {}
	for value in assignments.values():
		existing[str(value)] = true

	var candidates: Array[String] = []
	for raw in pool:
		var candidate := _sanitize_word(str(raw)).to_lower()
		if candidate == "":
			continue
		if existing.has(candidate):
			continue
		candidates.append(candidate)

	if not candidates.is_empty():
		var idx := rng.randi_range(0, candidates.size() - 1)
		var selected := candidates[idx]
		assignments[key] = selected
		return selected

	var base := _sanitize_word(fallback_base).to_lower()
	if base == "":
		base = "status"
	var suffix := 2
	while true:
		var generated := "%s%d" % [base, suffix]
		if not existing.has(generated):
			assignments[key] = generated
			return generated
		suffix += 1
	return base


func _pick_random_word(pool: Array[String], fallback: String, rng: RandomNumberGenerator) -> String:
	var candidates: Array[String] = []
	for raw in pool:
		var sanitized := _sanitize_word(str(raw)).to_lower()
		if sanitized == "":
			continue
		candidates.append(sanitized)
	if candidates.is_empty():
		var normalized_fallback := _sanitize_word(fallback).to_lower()
		return normalized_fallback if normalized_fallback != "" else "status"
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _compose_adjective_noun(adjective: String, noun: String) -> String:
	var a := _sanitize_word(adjective).to_lower()
	var n := _sanitize_word(noun)
	if a == "":
		a = "unnamed"
	if n == "":
		n = "Node"
	else:
		n = n.substr(0, 1).to_upper() + n.substr(1)
	return "%s%s" % [a, n]


func _sanitize_word(word: String) -> String:
	var out := ""
	for c in word.strip_edges():
		var code := c.unicode_at(0)
		var is_alpha := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if is_alpha:
			out += c
	return out
