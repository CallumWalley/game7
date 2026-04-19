extends Node
## Debug system for controlling UI element visibility during development.
## Allows toggling Mind, Environment, Time Controls, Timeline, and resource/worker visibility.

signal visibility_changed(feature: String, visible: bool)
signal debug_mode_changed(enabled: bool)
signal option_changed(option: String, value: bool)

const OPTION_SHOW_DEBUG_WINDOW: String = "show_debug_window"
const OPTION_DEBUG_LOG_FOOD_TICKS: String = "debug_log_food_ticks"
const OPTION_BODY_HOVER_STATS: String = "body_hover_stats"
const OPTION_DEBUG_ADI_STATS: String = "debug_adi_stats"

## Tracks which UI features are visible
var _visibility_state: Dictionary = {
	"mind_window": true,
	"environment_window": true,
	"time_controls": true,
	"timeline_bar": true,
	"resource_list": true,
	"worker_list": true,
	"speed_10_visible": true,
	"speed_100_visible": true,
	"env_sidebar": true,
}

## Tracks which worker/resource types have been encountered
var _encountered_types: Dictionary = {
	GameState.NODE_TYPE_NEURON_CLUSTER: true,
	GameState.NODE_TYPE_ARITHMETIC_PROCESSOR: false,
	GameState.NODE_TYPE_QUANTUM_CALCULATOR: false,
}

## Tracks which resource types have been encountered
var _encountered_resources: Dictionary = {}

## Debug overrides for sensor visibility (independent of GameState tier)
var _debug_sensor_overrides: Dictionary = {}

var _debug_mode_enabled: bool = false
var _debug_options: Dictionary = {
	OPTION_SHOW_DEBUG_WINDOW: true,
	OPTION_DEBUG_LOG_FOOD_TICKS: false,
	OPTION_BODY_HOVER_STATS: true,
	OPTION_DEBUG_ADI_STATS: false,
}

func _ready() -> void:
	_encountered_resources = {
		GameState.RESOURCE_TYPE_FOOD: false,
	}
	_debug_mode_enabled = OS.has_feature("debug")
	_debug_options[OPTION_SHOW_DEBUG_WINDOW] = _debug_mode_enabled
	_debug_options[OPTION_DEBUG_LOG_FOOD_TICKS] = GameState.debug_log_food_ticks
	if OS.has_feature("debug"):
		print("DebugVisibilityManager initialized")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_QUOTELEFT or key_event.keycode == KEY_ASCIITILDE:
		toggle_debug_mode()


func is_debug_mode_enabled() -> bool:
	return _debug_mode_enabled


func set_debug_mode_enabled(enabled: bool) -> void:
	if _debug_mode_enabled == enabled:
		return
	_debug_mode_enabled = enabled
	if not _debug_mode_enabled:
		set_option(OPTION_SHOW_DEBUG_WINDOW, false)
	debug_mode_changed.emit(_debug_mode_enabled)


func toggle_debug_mode() -> void:
	set_debug_mode_enabled(not _debug_mode_enabled)


func set_option(option: String, value: bool) -> void:
	if option not in _debug_options:
		push_warning("Unknown debug option: %s" % option)
		return
	if option == OPTION_SHOW_DEBUG_WINDOW and not _debug_mode_enabled and value:
		return
	if _debug_options[option] == value:
		return
	_debug_options[option] = value
	_match_option_to_system(option, value)
	option_changed.emit(option, value)


func toggle_option(option: String) -> void:
	set_option(option, not bool(_debug_options.get(option, false)))


func get_option(option: String) -> bool:
	return bool(_debug_options.get(option, false))


func get_debug_options() -> Dictionary:
	return _debug_options.duplicate()


func _match_option_to_system(option: String, value: bool) -> void:
	if option == OPTION_DEBUG_LOG_FOOD_TICKS:
		GameState.debug_log_food_ticks = value


func set_visibility(feature: String, visible: bool) -> void:
	"""Toggle visibility of a UI feature."""
	if feature not in _visibility_state:
		push_warning("Unknown feature: %s" % feature)
		return
	
	if _visibility_state[feature] == visible:
		return
	
	_visibility_state[feature] = visible
	visibility_changed.emit(feature, visible)


func is_visible(feature: String) -> bool:
	"""Check if a UI feature is visible."""
	return _visibility_state.get(feature, true)


func encounter_worker_type(node_type: String) -> void:
	set_worker_type_encountered(node_type, true)


func set_worker_type_encountered(node_type: String, encountered: bool) -> void:
	if node_type not in _encountered_types:
		push_warning("Unknown worker type: %s" % node_type)
		return
	if _encountered_types[node_type] == encountered:
		return
	_encountered_types[node_type] = encountered
	visibility_changed.emit("worker_type_%s" % node_type, encountered)


func is_worker_type_encountered(node_type: String) -> bool:
	"""Check if a worker type has been encountered."""
	return _encountered_types.get(node_type, false)


func get_visibility_state() -> Dictionary:
	"""Get a copy of the current visibility state for debug UI."""
	return _visibility_state.duplicate()


func get_encountered_types() -> Dictionary:
	"""Get a copy of the encountered worker types for debug UI."""
	return _encountered_types.duplicate()


func encounter_resource_type(resource_type: String) -> void:
	set_resource_type_encountered(resource_type, true)


func set_resource_type_encountered(resource_type: String, encountered: bool) -> void:
	if resource_type not in _encountered_resources:
		push_warning("Unknown resource type: %s" % resource_type)
		return
	if _encountered_resources[resource_type] == encountered:
		return
	_encountered_resources[resource_type] = encountered
	visibility_changed.emit("resource_type_%s" % resource_type, encountered)


func is_resource_type_encountered(resource_type: String) -> bool:
	return _encountered_resources.get(resource_type, false)


func get_encountered_resources() -> Dictionary:
	return _encountered_resources.duplicate()


func get_sensor_visible(sensor_id: String) -> bool:
	return _debug_sensor_overrides.get(sensor_id, false)


func set_sensor_visible(sensor_id: String, value: bool) -> void:
	_debug_sensor_overrides[sensor_id] = value
	visibility_changed.emit("sensor_%s" % sensor_id, value)


func reset_all_visibility() -> void:
	"""Reset all visibility states to default (used for testing)."""
	_visibility_state = {
		"mind_window": true,
		"environment_window": true,
		"time_controls": true,
		"timeline_bar": true,
		"resource_list": true,
		"worker_list": true,
		"speed_10_visible": true,
		"speed_100_visible": true,
		"env_sidebar": true,
	}
	_encountered_types = {
		GameState.NODE_TYPE_NEURON_CLUSTER: true,
		GameState.NODE_TYPE_ARITHMETIC_PROCESSOR: false,
		GameState.NODE_TYPE_QUANTUM_CALCULATOR: false,
	}
	_encountered_resources = {
		GameState.RESOURCE_TYPE_FOOD: false,
	}
	_debug_sensor_overrides = {}
	set_option(OPTION_DEBUG_LOG_FOOD_TICKS, false)
	set_option(OPTION_BODY_HOVER_STATS, true)
