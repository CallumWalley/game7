@tool
extends "res://scripts/body/BodyObject.gd"

## Abstract base class for thought-processing nodes on the body map.
## Do not instantiate directly.

enum ControllingEntity {
	NONE,
	PLAYER,
}

## Ownership enum: NONE = unowned, PLAYER = player.
@export_enum("None", "Player") var controlling_entity: int = ControllingEntity.NONE

## Per-node innate tint used by renderers.
@export var node_tint: Color = Color(0.0, 0.0, 0.0, 0.0)

## Start nodes use the player color as their innate tint.
@export var startNode: bool = false

## Disabled nodes do not consume full resources.
@export var is_enabled: bool = true

## Conversion resistance used by capture tasks.
## If left at default, a seeded random value is generated at runtime.
@export var resistance: float = -1.0

## Human-facing concept label (adjectiveNoun), generated from the global word pool.
@export var concept_name: String = ""

@export var status: String = ""
@export var status_refresh_min_cycles: int = 14
@export var status_refresh_max_cycles: int = 32

## pressure[entity_id: String] = pressure_amount: int
## When the total pressure from one entity reaches the threshold,
## control transfers to that entity. Ticks down each cycle.
var pressure: Dictionary = {}
var _last_status_refresh_cycle: int = -1000000
var _next_status_refresh_cycle: int = 0
var _status_rng := RandomNumberGenerator.new()

signal ownership_changed(old_entity: int, new_entity: int)
signal enabled_changed(enabled: bool)
signal status_changed(new_status: String)


func _notification(what: int) -> void:
	if what != NOTIFICATION_READY:
		return
	if Engine.is_editor_hint():
		return
	_status_rng.seed = GameState.get_world_seeded_value(str(get_path()) + ":status")
	if resistance < 0.0:
		resistance = _status_rng.randf_range(0.5, 3.0)
	initialize_identity_if_needed()
	if controlling_entity == ControllingEntity.PLAYER:
		GameState.report_node_controlled(self)


func set_enabled(value: bool) -> void:
	if is_enabled == value:
		return
	is_enabled = value
	refresh_status(true)
	enabled_changed.emit(value)
	GameState.state_changed.emit()


func set_controlling_entity(entity: int) -> void:
	if controlling_entity == entity:
		return
	var old := controlling_entity
	controlling_entity = entity
	refresh_status(true)
	ownership_changed.emit(old, entity)
	if entity == ControllingEntity.PLAYER:
		GameState.report_node_controlled(self)
	GameState.state_changed.emit()


func is_player_owned() -> bool:
	return controlling_entity == ControllingEntity.PLAYER


func claim_by_player() -> void:
	set_controlling_entity(ControllingEntity.PLAYER)


func initialize_identity_if_needed() -> void:
	if not _can_generate_identity():
		return
	if concept_name.strip_edges() == "":
		var generated_name := _generate_concept_name()
		if generated_name.strip_edges() != "":
			concept_name = generated_name
	refresh_status(true)


## Re-evaluates status from high-level pools based on ownership.
## This can be extended later with additional condition layers.
func refresh_status(force: bool = false) -> void:
	if Engine.is_editor_hint():
		return
	if not _can_generate_identity():
		return
	if not _can_refresh_status():
		return
	if not force and GameState.cycle < _next_status_refresh_cycle:
			return
	var parts: Array[String] = []
	var base_status := _generate_base_status()
	if base_status != "":
		parts.append(base_status)
	var overlays := _get_condition_overlay_statuses()
	for tag in overlays:
		if tag == "":
			continue
		if parts.has(tag):
			continue
		parts.append(tag)
	var next_status := ", ".join(parts)
	_last_status_refresh_cycle = GameState.cycle
	_schedule_next_status_refresh()
	_set_status(next_status)


func _schedule_next_status_refresh() -> void:
	var min_cycles := maxi(status_refresh_min_cycles, 1)
	var max_cycles := maxi(status_refresh_max_cycles, min_cycles)
	_next_status_refresh_cycle = GameState.cycle + _status_rng.randi_range(min_cycles, max_cycles)


func _can_generate_identity() -> bool:
	return true


func _generate_concept_name() -> String:
	return GameState.get_or_assign_node_concept_name(_get_identity_key())


func _generate_base_status() -> String:
	if controlling_entity == ControllingEntity.NONE:
		GameState.clear_owned_emotion(_get_identity_key())
		GameState.clear_inactive_owned_emotion(_get_identity_key())
		return _generate_unowned_status()
	return _generate_owned_status()


func _generate_unowned_status() -> String:
	return GameState.get_random_unowned_status()


func _generate_owned_status() -> String:
	return GameState.get_or_assign_owned_emotion(_get_identity_key())


func _can_refresh_status() -> bool:
	return true


func _get_base_status_for_ownership() -> String:
	return _generate_base_status()


func _get_condition_overlay_statuses() -> Array[String]:
	var tags: Array[String] = []
	if controlling_entity == ControllingEntity.PLAYER and not is_enabled:
		tags.append(GameState.get_or_assign_inactive_owned_emotion(_get_identity_key()))
	var data := _get_status_condition_data()
	var glucose_value := int(data.get("glucose", -1))
	if glucose_value < 0:
		return tags
	if glucose_value <= 30:
		tags.append(GameState.get_random_very_hungry_status())
		return tags
	if glucose_value <= 60:
		tags.append(GameState.get_random_hungry_status())
	return tags


func _get_status_condition_data() -> Dictionary:
	return {}


func _set_status(value: String) -> void:
	var normalized := value.strip_edges().to_lower()
	if status == normalized:
		return
	status = normalized
	status_changed.emit(status)


func _get_status_pool_key() -> String:
	return _get_identity_key()


func _get_identity_key() -> String:
	if name.strip_edges() != "":
		return name
	if is_inside_tree():
		return str(get_path())
	return "node_%d" % get_instance_id()


## Resolves dragged inspector NodePaths into live node references.
func get_linked_nodes() -> Array:
	return get_linked_body_objects()


func get_worker_node_type() -> String:
	return GameState.NODE_TYPE_NEURON_CLUSTER


func get_mind_entry_data() -> Dictionary:
	return {
		"id": "node_type_neuron_cluster",
		"title": "NeuronCluster",
		"text": "Biological thought clusters. Flexible, adaptive, and baseline-efficient.",
	}
