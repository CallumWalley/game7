extends Node

const WORD_POOLS := preload("res://scripts/common/WordPools.gd")
const ENTITY_NONE: int = 0
const ENTITY_PLAYER: int = 1
const NODE_TYPE_NEURON_CLUSTER: String = "neuron_cluster"
const NODE_TYPE_ARITHMETIC_PROCESSOR: String = "arithmetic_processor"
const NODE_TYPE_QUANTUM_CALCULATOR: String = "quantum_calculator"
const NODE_TYPE_ORDER: Array[String] = [
	NODE_TYPE_NEURON_CLUSTER,
	NODE_TYPE_ARITHMETIC_PROCESSOR,
	NODE_TYPE_QUANTUM_CALCULATOR,
]
const NODE_TYPE_LABELS := {
	NODE_TYPE_NEURON_CLUSTER: "NeuronCluster",
	NODE_TYPE_ARITHMETIC_PROCESSOR: "ArithmeticProcessor",
	NODE_TYPE_QUANTUM_CALCULATOR: "QuantumCalculator",
}
const ENTITY_DEFS := {
	ENTITY_PLAYER: {
		"color": Color(0.35, 0.62, 1.0, 1.0),
	},
}

signal state_changed

var cycle: int = 0
# Simulation tuning (single place to tweak core body-resource gameplay).
@export var starting_food: float = 120.0
@export var food_regen_per_tick: float = 0.0
@export var coma_glucose_threshold: float = 30.0
@export var power_full_glucose: float = 100.0
@export var food_request_min: float = 0.1
@export var food_request_max: float = 1.0
@export var request_glucose_min: float = 0.0
@export var request_glucose_max: float = 100.0
@export var manual_disabled_request_glucose_equivalent: float = 30.0
@export var baseline_delta_request_zero: float = -1.0
@export var baseline_delta_at_critical_request: float = 0.0
@export var baseline_delta_at_full_request: float = 1.0
@export var critical_request_units: float = 0.2
@export var debug_log_food_ticks: bool = false
@export var enable_push_scroll: bool = false
@export var non_preferred_power_multiplier: float = 0.3
@export var node_power_neuron_cluster: float = 1.0
@export var node_power_arithmetic_processor: float = 1.0
@export var node_power_quantum_calculator: float = 1.0
@export var capture_progress_goal: float = 10.0
@export var capture_resistance_min: float = 0.5
@export var capture_resistance_max: float = 3.0
@export var capture_decay_per_cycle: float = 0.35

var food: float = 120.0
var last_tick_food_consumed: float = 0.0
var last_tick_power_total: float = 0.0
var unlocked_body_nodes: Dictionary = {"core_boot": true}
var contested_body_nodes: Dictionary = {}
var unlocked_memories: Dictionary = {"waking_fragment": true}
var unlocked_sensors: Dictionary = {"optical": true}
var observed_environment: Dictionary = {}
var thought_queue: Array[String] = []
@export var world_seed: int = -1

# Persistent assignments: cluster_id -> generated adjectiveNoun label.
var node_concept_names: Dictionary = {}

# Persistent assignments: node_id -> owned emotion.
var node_owned_emotions: Dictionary = {}

# Persistent assignments: node_id -> owned inactive emotion.
var node_inactive_owned_emotions: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _word_pools := WORD_POOLS.new()

# target_id -> {
#   "kind": String,
#   "preferred_type": String,
#   "non_preferred_multiplier": float,
#   "workers": Dictionary[node_type: String -> int],
#   "progress": float,
#   "progress_goal": float,
#   "resistance": float,
#   "target_node_path": String,
#   "source_node_path": String,
#   "component_path": String,
# }
var worker_targets: Dictionary = {}

# Dynamic codex entries (SSOT from runtime objects when available).
var dynamic_mind_entries: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	if world_seed < 0:
		world_seed = _rng.randi()
	food = starting_food


func set_world_seed(seed: int) -> void:
	if seed < 0:
		world_seed = _rng.randi()
		return
	world_seed = seed


func roll_new_world_seed() -> int:
	world_seed = _rng.randi()
	return world_seed


func set_push_scroll_enabled(value: bool) -> void:
	if enable_push_scroll == value:
		return
	enable_push_scroll = value
	emit_signal("state_changed")


func get_world_seeded_value(key: String) -> int:
	return ("%s|%d" % [key, world_seed]).hash()


func advance_cycles(amount: int, _reason: String = "") -> void:
	var steps: int = maxi(amount, 0)
	for _i in steps:
		_simulate_food_tick()
		_simulate_worker_tick()
		cycle += 1
	emit_signal("state_changed")


func _simulate_food_tick() -> void:
	var all_clusters: Array = get_tree().get_nodes_in_group("nerve_clusters")
	var player_clusters: Array = []
	var requests: Array[float] = []
	var total_request: float = 0.0

	for cluster in all_clusters:
		if int(cluster.get("controlling_entity")) != ENTITY_PLAYER:
			continue
		var request: float = float(cluster.call("get_food_request_units"))
		if request <= 0.0:
			continue
		player_clusters.append(cluster)
		requests.append(request)
		total_request += request

	var available := maxf(food, 0.0)
	var allocation_ratio := 0.0
	if total_request > 0.0:
		allocation_ratio = clampf(available / total_request, 0.0, 1.0)

	var consumed_total: float = 0.0
	var node_logs: Array[String] = []
	for i in player_clusters.size():
		var cluster: Node = player_clusters[i]
		var request: float = requests[i]
		var allocated: float = request * allocation_ratio
		var delta: float = float(cluster.call("compute_glucose_delta", request, allocated))
		cluster.call("apply_food_result", request, allocated, delta)
		consumed_total += allocated
		if debug_log_food_ticks:
			node_logs.append("%s req=%.3f alloc=%.3f dG=%.3f" % [cluster.name, request, allocated, delta])

	food = maxf(0.0, food - consumed_total + food_regen_per_tick)
	last_tick_food_consumed = consumed_total

	var power_total: float = 0.0
	for cluster in all_clusters:
		if int(cluster.get("controlling_entity")) != ENTITY_PLAYER:
			continue
		power_total += float(cluster.call("get_hidden_power"))
	last_tick_power_total = power_total

	if debug_log_food_ticks:
		print("[Tick %d] food=%.3f consumed=%.3f requested=%.3f ratio=%.3f power=%.3f" % [cycle + 1, food, consumed_total, total_request, allocation_ratio, power_total])
		for line in node_logs:
			print("  - %s" % line)


func _simulate_worker_tick() -> void:
	var targets_to_complete: Array[String] = []
	for target_id in worker_targets.keys():
		var target: Dictionary = worker_targets[target_id]
		var workers: Dictionary = target.get("workers", {})
		var preferred_type := str(target.get("preferred_type", NODE_TYPE_NEURON_CLUSTER))
		var multiplier := float(target.get("non_preferred_multiplier", non_preferred_power_multiplier))
		var resistance := float(target.get("resistance", 0.0))
		var gain := _compute_worker_power(workers, preferred_type, multiplier) - resistance
		if gain > 0.0:
			target["progress"] = float(target.get("progress", 0.0)) + gain
		elif str(target.get("kind", "")) == "capture_node" and _total_workers(workers) == 0:
			target["progress"] = maxf(float(target.get("progress", 0.0)) - capture_decay_per_cycle, 0.0)
			worker_targets[target_id] = target
		var progress_goal := maxf(float(target.get("progress_goal", 0.0)), 0.0)
		if progress_goal > 0.0:
			target["progress"] = minf(float(target.get("progress", 0.0)), progress_goal)
			worker_targets[target_id] = target
		if target.get("kind", "") != "capture_node":
			continue
		if float(target.get("progress", 0.0)) >= float(target.get("progress_goal", capture_progress_goal)):
			targets_to_complete.append(target_id)

	for target_id in targets_to_complete:
		_complete_capture_task(target_id)

	for component in get_tree().get_nodes_in_group("worker_components"):
		var activated := bool(component.call("update_activation_from_workers"))
		if activated:
			food += float(component.call("get_food_output_per_cycle"))


func _complete_capture_task(target_id: String) -> void:
	var task: Dictionary = worker_targets.get(target_id, {})
	var target_path := str(task.get("target_node_path", ""))
	if target_path == "":
		worker_targets.erase(target_id)
		return
	var node := get_node_or_null(NodePath(target_path))
	if node != null:
		node.call("set_controlling_entity", ENTITY_PLAYER)
	worker_targets.erase(target_id)


func _compute_worker_power(workers: Dictionary, preferred_type: String, non_preferred_multiplier_value: float) -> float:
	var total := 0.0
	for node_type in workers.keys():
		var count := int(workers[node_type])
		if count <= 0:
			continue
		var base_power := get_base_power_for_type(str(node_type))
		var mult := 1.0 if str(node_type) == preferred_type else non_preferred_multiplier_value
		total += float(count) * base_power * mult
	return total


func _total_workers(workers: Dictionary) -> int:
	var total := 0
	for node_type in workers.keys():
		total += int(workers[node_type])
	return total


func get_base_power_for_type(node_type: String) -> float:
	match node_type:
		NODE_TYPE_ARITHMETIC_PROCESSOR:
			return node_power_arithmetic_processor
		NODE_TYPE_QUANTUM_CALCULATOR:
			return node_power_quantum_calculator
		_:
			return node_power_neuron_cluster


func get_node_type_counts() -> Dictionary:
	var result: Dictionary = {}
	for node_type in NODE_TYPE_ORDER:
		result[node_type] = {"total": 0, "active": 0, "idle": 0}
	var assigned := _get_assigned_worker_counts_global()
	for node in get_tree().get_nodes_in_group("nerve_clusters"):
		if int(node.get("controlling_entity")) != ENTITY_PLAYER:
			continue
		var node_type := _resolve_node_type(node)
		var row: Dictionary = result.get(node_type, {"total": 0, "active": 0, "idle": 0})
		row["total"] = int(row.get("total", 0)) + 1
		var is_active := bool(node.get("is_enabled")) and not bool(node.call("is_in_coma"))
		if is_active:
			row["active"] = int(row.get("active", 0)) + 1
		result[node_type] = row
	for node_type in NODE_TYPE_ORDER:
		var row: Dictionary = result.get(node_type, {"total": 0, "active": 0, "idle": 0})
		var active := int(row.get("active", 0))
		var used := int(assigned.get(node_type, 0))
		row["idle"] = maxi(active - used, 0)
		result[node_type] = row
	return result


func get_available_idle_counts() -> Dictionary:
	var counts := get_node_type_counts()
	var result: Dictionary = {}
	for node_type in NODE_TYPE_ORDER:
		var row: Dictionary = counts.get(node_type, {})
		result[node_type] = int(row.get("idle", 0))
	return result


func _get_assigned_worker_counts_global() -> Dictionary:
	var result: Dictionary = {}
	for node_type in NODE_TYPE_ORDER:
		result[node_type] = 0
	for target in worker_targets.values():
		var workers: Dictionary = target.get("workers", {})
		for node_type in workers.keys():
			result[node_type] = int(result.get(node_type, 0)) + int(workers[node_type])
	return result


func _resolve_node_type(node: Node) -> String:
	if node.has_method("get_worker_node_type"):
		return str(node.call("get_worker_node_type"))
	return NODE_TYPE_NEURON_CLUSTER


func ensure_capture_task_for_node(target_node: Node) -> String:
	var target_path := str(target_node.get_path())
	var task_id := "capture|%s" % target_path
	if worker_targets.has(task_id):
		return task_id
	var preferred_type := _resolve_node_type(target_node)
	var source_path := _find_player_source_path_for_capture(target_node)
	var target_resistance := float(target_node.get("resistance"))
	if target_resistance < 0.0:
		target_resistance = _rng.randf_range(capture_resistance_min, capture_resistance_max)
	worker_targets[task_id] = {
		"kind": "capture_node",
		"preferred_type": preferred_type,
		"non_preferred_multiplier": non_preferred_power_multiplier,
		"workers": _empty_workers_dict(),
		"progress": 0.0,
		"progress_goal": capture_progress_goal,
		"resistance": target_resistance,
		"target_node_path": target_path,
		"source_node_path": source_path,
	}
	return task_id


func get_capture_task_id_if_exists(target_node: Node) -> String:
	var task_id := "capture|%s" % str(target_node.get_path())
	if worker_targets.has(task_id):
		return task_id
	return ""


func ensure_component_target(component: Node) -> String:
	var component_path := str(component.get_path())
	var target_id := "component|%s" % component_path
	if worker_targets.has(target_id):
		return target_id
	var preferred_type := NODE_TYPE_NEURON_CLUSTER
	if component.has_method("get_preferred_node_type"):
		preferred_type = str(component.call("get_preferred_node_type"))
	var target_multiplier := non_preferred_power_multiplier
	if component.has_method("get_non_preferred_multiplier"):
		target_multiplier = float(component.call("get_non_preferred_multiplier"))
	worker_targets[target_id] = {
		"kind": "component",
		"preferred_type": preferred_type,
		"non_preferred_multiplier": target_multiplier,
		"workers": _empty_workers_dict(),
		"progress": 0.0,
		"progress_goal": 0.0,
		"resistance": 0.0,
		"component_path": component_path,
		"source_node_path": component.call("get_connected_player_node_path"),
	}
	return target_id


func ensure_named_task_target(target_id: String, preferred_type: String, progress_goal: float, resistance: float, non_preferred_multiplier_value: float = -1.0) -> String:
	if worker_targets.has(target_id):
		return target_id
	var final_multiplier := non_preferred_power_multiplier
	if non_preferred_multiplier_value >= 0.0:
		final_multiplier = non_preferred_multiplier_value
	worker_targets[target_id] = {
		"kind": "named_task",
		"preferred_type": preferred_type,
		"non_preferred_multiplier": final_multiplier,
		"workers": _empty_workers_dict(),
		"progress": 0.0,
		"progress_goal": maxf(progress_goal, 0.0),
		"resistance": maxf(resistance, 0.0),
	}
	return target_id


func assign_worker_to_target(target_id: String) -> bool:
	if not worker_targets.has(target_id):
		return false
	var target: Dictionary = worker_targets[target_id]
	if str(target.get("kind", "")) == "component":
		var component_path := str(target.get("component_path", ""))
		var component := get_node_or_null(NodePath(component_path))
		if component == null:
			return false
		if not can_assign_to_component(component):
			return false
		target["source_node_path"] = component.call("get_connected_player_node_path")
	var preferred_type := str(target.get("preferred_type", NODE_TYPE_NEURON_CLUSTER))
	var workers: Dictionary = target.get("workers", _empty_workers_dict())
	var idle_counts := get_available_idle_counts()
	var selected_type := ""
	if int(idle_counts.get(preferred_type, 0)) > 0:
		selected_type = preferred_type
	else:
		selected_type = _pick_most_idle_type(idle_counts)
	if selected_type == "":
		return false
	workers[selected_type] = int(workers.get(selected_type, 0)) + 1
	target["workers"] = workers
	worker_targets[target_id] = target
	emit_signal("state_changed")
	return true


func remove_worker_from_target(target_id: String) -> bool:
	if not worker_targets.has(target_id):
		return false
	var target: Dictionary = worker_targets[target_id]
	var workers: Dictionary = target.get("workers", _empty_workers_dict())
	var preferred_type := str(target.get("preferred_type", NODE_TYPE_NEURON_CLUSTER))
	var selected_type := _pick_remove_type(workers, preferred_type)
	if selected_type == "":
		return false
	workers[selected_type] = maxi(int(workers.get(selected_type, 0)) - 1, 0)
	target["workers"] = workers
	worker_targets[target_id] = target
	emit_signal("state_changed")
	return true


func _pick_most_idle_type(idle_counts: Dictionary) -> String:
	var best_type := ""
	var best_count := -1
	for node_type in NODE_TYPE_ORDER:
		var count := int(idle_counts.get(node_type, 0))
		if count <= 0:
			continue
		if count > best_count:
			best_count = count
			best_type = node_type
	return best_type


func _pick_remove_type(workers: Dictionary, preferred_type: String) -> String:
	var candidate_types: Array[String] = []
	for node_type in NODE_TYPE_ORDER:
		if int(workers.get(node_type, 0)) > 0:
			candidate_types.append(node_type)
	if candidate_types.is_empty():
		return ""
	var best := ""
	for node_type in candidate_types:
		if best == "":
			best = node_type
			continue
		if _is_better_remove_candidate(node_type, best, workers, preferred_type):
			best = node_type
	return best


func _is_better_remove_candidate(candidate: String, current: String, workers: Dictionary, preferred_type: String) -> bool:
	var candidate_preferred := candidate == preferred_type
	var current_preferred := current == preferred_type
	if candidate_preferred != current_preferred:
		return not candidate_preferred
	var candidate_count := int(workers.get(candidate, 0))
	var current_count := int(workers.get(current, 0))
	if candidate_count != current_count:
		return candidate_count < current_count
	return NODE_TYPE_ORDER.find(candidate) < NODE_TYPE_ORDER.find(current)


func _empty_workers_dict() -> Dictionary:
	return {
		NODE_TYPE_NEURON_CLUSTER: 0,
		NODE_TYPE_ARITHMETIC_PROCESSOR: 0,
		NODE_TYPE_QUANTUM_CALCULATOR: 0,
	}


func get_target_workers(target_id: String) -> Dictionary:
	if not worker_targets.has(target_id):
		return _empty_workers_dict()
	var target: Dictionary = worker_targets[target_id]
	return target.get("workers", _empty_workers_dict())


func get_target_total_power(target_id: String) -> float:
	if not worker_targets.has(target_id):
		return 0.0
	var target: Dictionary = worker_targets[target_id]
	return _compute_worker_power(
		target.get("workers", {}),
		str(target.get("preferred_type", NODE_TYPE_NEURON_CLUSTER)),
		float(target.get("non_preferred_multiplier", non_preferred_power_multiplier))
	)


func get_target_progress_ratio(target_id: String) -> float:
	if not worker_targets.has(target_id):
		return 0.0
	var target: Dictionary = worker_targets[target_id]
	var goal := maxf(float(target.get("progress_goal", 0.0)), 0.0)
	if goal <= 0.0:
		return 0.0
	return clampf(float(target.get("progress", 0.0)) / goal, 0.0, 1.0)


func has_target(target_id: String) -> bool:
	return worker_targets.has(target_id)


func get_capture_progress_for_node(node: Node) -> float:
	var target_id := "capture|%s" % str(node.get_path())
	if not worker_targets.has(target_id):
		return 0.0
	var target: Dictionary = worker_targets[target_id]
	var goal := maxf(float(target.get("progress_goal", capture_progress_goal)), 0.01)
	return clampf(float(target.get("progress", 0.0)) / goal, 0.0, 1.0)


func get_capture_progress_for_link(path_a: String, path_b: String) -> float:
	for target in worker_targets.values():
		if str(target.get("kind", "")) != "capture_node":
			continue
		var source_path := str(target.get("source_node_path", ""))
		var target_path := str(target.get("target_node_path", ""))
		if (source_path == path_a and target_path == path_b) or (source_path == path_b and target_path == path_a):
			var goal := maxf(float(target.get("progress_goal", capture_progress_goal)), 0.01)
			return clampf(float(target.get("progress", 0.0)) / goal, 0.0, 1.0)
	return 0.0


func get_capture_workers_for_link(path_a: String, path_b: String) -> Dictionary:
	for target in worker_targets.values():
		if str(target.get("kind", "")) != "capture_node":
			continue
		var source_path := str(target.get("source_node_path", ""))
		var target_path := str(target.get("target_node_path", ""))
		if (source_path == path_a and target_path == path_b) or (source_path == path_b and target_path == path_a):
			return target.get("workers", _empty_workers_dict())
	return _empty_workers_dict()


func _find_player_source_path_for_capture(target_node: Node) -> String:
	return str(target_node.call("get_connected_player_node_path"))


func can_create_capture_task(target_node: Node) -> bool:
	if int(target_node.get("controlling_entity")) == ENTITY_PLAYER:
		return false
	return _find_player_source_path_for_capture(target_node) != ""


func can_assign_to_component(component: Node) -> bool:
	return bool(component.call("is_connected_to_player_node"))


func unlock_body_node(node_id: String) -> void:
	if unlocked_body_nodes.has(node_id):
		return
	unlocked_body_nodes[node_id] = true
	emit_signal("state_changed")


func mark_node_contested(node_id: String) -> void:
	if contested_body_nodes.has(node_id):
		return
	contested_body_nodes[node_id] = true
	emit_signal("state_changed")


func clear_node_contested(node_id: String) -> void:
	if not contested_body_nodes.has(node_id):
		return
	contested_body_nodes.erase(node_id)
	emit_signal("state_changed")


func unlock_memory(_memory_id: String) -> void:
	var memory_id := _memory_id.strip_edges()
	if memory_id == "":
		return
	if unlocked_memories.has(memory_id):
		return
	unlocked_memories[memory_id] = true
	emit_signal("state_changed")


func unlock_sensor(sensor_id: String) -> void:
	if unlocked_sensors.has(sensor_id):
		return
	unlocked_sensors[sensor_id] = true
	emit_signal("state_changed")


func record_observation(observation_id: String) -> void:
	if observed_environment.has(observation_id):
		return
	observed_environment[observation_id] = true
	emit_signal("state_changed")


func get_or_assign_node_concept_name(node_id: String) -> String:
	return _word_pools.get_or_assign_node_concept_name(node_id, node_concept_names, _rng)


func get_random_unowned_status() -> String:
	return _word_pools.get_random_unowned_status(_rng)


func get_or_assign_owned_emotion(node_id: String) -> String:
	return _word_pools.get_or_assign_owned_emotion(node_id, node_owned_emotions, _rng)


func get_or_assign_inactive_owned_emotion(node_id: String) -> String:
	return _word_pools.get_or_assign_inactive_owned_emotion(node_id, node_inactive_owned_emotions, _rng)


func clear_owned_emotion(node_id: String) -> void:
	var key := node_id.strip_edges()
	if key == "":
		return
	node_owned_emotions.erase(key)


func clear_inactive_owned_emotion(node_id: String) -> void:
	var key := node_id.strip_edges()
	if key == "":
		return
	node_inactive_owned_emotions.erase(key)


func get_random_hungry_status() -> String:
	return _word_pools.get_random_hungry_status(_rng)


func get_random_very_hungry_status() -> String:
	return _word_pools.get_random_very_hungry_status(_rng)


func sample_initial_node_glucose_percent() -> int:
	var sampled := _sample_normal_clamped(40.0, 12.0, 0.0, 100.0)
	return int(round(sampled))


func get_node_type_label(node_type: String) -> String:
	return str(NODE_TYPE_LABELS.get(node_type, node_type))


func report_node_controlled(node: Node) -> void:
	if not node.has_method("get_mind_entry_data"):
		return
	var data: Dictionary = node.call("get_mind_entry_data")
	_register_and_unlock_runtime_mind_entry(data)


func report_component_controlled(component: Node) -> void:
	if not component.has_method("get_mind_entry_data"):
		return
	var data: Dictionary = component.call("get_mind_entry_data")
	_register_and_unlock_runtime_mind_entry(data)


func _register_and_unlock_runtime_mind_entry(data: Dictionary) -> void:
	var entry_id := str(data.get("id", "")).strip_edges()
	if entry_id == "":
		return
	register_dynamic_mind_entry(entry_id, str(data.get("title", "")), str(data.get("text", "")))
	unlock_memory(entry_id)


func register_dynamic_mind_entry(entry_id: String, title: String, text: String) -> void:
	if entry_id.strip_edges() == "":
		return
	dynamic_mind_entries[entry_id] = {
		"id": entry_id,
		"title": title,
		"text": text,
	}


func get_dynamic_mind_entries() -> Array:
	var result: Array = []
	for value in dynamic_mind_entries.values():
		result.append(value)
	return result


func get_entity_color(entity_id: int) -> Color:
	var entity_data: Dictionary = ENTITY_DEFS.get(entity_id, {})
	return entity_data.get("color", Color(1.0, 1.0, 1.0, 1.0))


func _sample_normal_clamped(mean: float, stddev: float, min_value: float, max_value: float) -> float:
	var u1 := maxf(_rng.randf(), 0.0001)
	var u2 := _rng.randf()
	var z0 := sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return clampf(mean + z0 * stddev, min_value, max_value)
