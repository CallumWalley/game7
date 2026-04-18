@tool
extends "res://scripts/body/ComponentBase.gd"

## Base class for glucose-storing components (adipose tissue, etc).
## Uses composed GlucoseSystem for storage and charge/discharge mechanics.
## Visual scaling based on glucose levels.

@export var max_glucose: float = 100.0
@export var charge_rate: float = 5.0
@export var discharge_rate: float = 10.0
@export var scale_min: float = 0.7
@export var scale_max: float = 1.3

var _glucose: GlucoseSystem

signal glucose_changed(amount: float)


func _ready() -> void:
	_glucose = GlucoseSystem.new(max_glucose, charge_rate, discharge_rate * 2.0)
	super()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_visual_from_glucose()


func _get_component_type_id() -> String:
	return "biological"


func _get_registered_properties() -> Dictionary:
	var base_props := super()
	base_props["max_glucose"] = max_glucose
	base_props["charge_rate"] = charge_rate
	base_props["discharge_rate"] = discharge_rate
	base_props["current_glucose"] = _glucose.current_glucose
	return base_props


## Get current stored glucose amount.
func get_current_glucose() -> float:
	return _glucose.current_glucose


## Set current glucose amount (clamped to [0, max_glucose]).
func set_current_glucose(amount: float) -> void:
	var old := _glucose.current_glucose
	_glucose.set_glucose(amount)
	if _glucose.current_glucose != old:
		glucose_changed.emit(_glucose.current_glucose)


## Get maximum glucose storage capacity.
func get_max_glucose() -> float:
	return _glucose.max_glucose


## Get charge rate (rate at which glucose can be stored).
func get_charge_rate() -> float:
	return _glucose.get_effective_charge_rate(is_activated)


## Get discharge rate (rate at which glucose can be released).
func get_discharge_rate() -> float:
	return _glucose.get_effective_discharge_rate(is_activated)


## Attempt to charge glucose (add to storage).
## Returns the amount actually charged.
func charge_glucose(requested: float) -> float:
	var amount := _glucose.charge(requested, is_activated)
	if amount > 0.0:
		glucose_changed.emit(_glucose.current_glucose)
	return amount


## Attempt to discharge glucose (remove from storage).
## Returns the amount actually discharged.
func discharge_glucose(requested: float) -> float:
	var amount := _glucose.discharge(requested, is_activated)
	if amount > 0.0:
		glucose_changed.emit(_glucose.current_glucose)
	return amount


## Visual fill ratio based on current glucose.
func get_glucose_fill_ratio() -> float:
	return _glucose.get_fill_ratio()


## Update polygon scale and colors based on glucose level.
func _update_visual_from_glucose() -> void:
	if _polygon == null:
		return
	
	var glucose_ratio := _glucose.get_fill_ratio()
	var target_scale := lerpf(scale_min, scale_max, glucose_ratio)
	_polygon.scale = Vector2.ONE * target_scale
	
	# Update colors based on fill level
	if glucose_ratio < 0.2:  # Very low
		_polygon.modulate = Color(1.0, 0.3, 0.3, 1.0)
	elif glucose_ratio < 0.5:  # Low
		_polygon.modulate = Color(1.0, 0.7, 0.3, 1.0)
	else:  # Healthy
		_polygon.modulate = Color(1.0, 1.0, 1.0, 1.0)
