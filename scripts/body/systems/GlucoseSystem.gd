extends RefCounted

## Reusable glucose storage and flow system.
## Handles charge/discharge with rate limits and fill tracking.
## Used by both NerveCluster and Biological (adipose) components.

class_name GlucoseSystem

var current_glucose: float = 0.0
var max_glucose: float = 100.0
var charge_rate: float = 5.0
var discharge_rate: float = 10.0


func _init(p_max: float = 100.0, p_charge: float = 5.0, p_discharge: float = 10.0) -> void:
	max_glucose = p_max
	charge_rate = p_charge
	discharge_rate = p_discharge
	current_glucose = max_glucose * 0.5


## Charge glucose into storage (e.g., from photosynthetic production).
## Returns actual amount charged (limited by space, rate, and active state).
func charge(requested: float, is_active: bool = true) -> float:
	if not is_active:
		return 0.0
	var space_available := max_glucose - current_glucose
	var amount := minf(requested, space_available, charge_rate)
	current_glucose += amount
	return amount


## Discharge glucose from storage (e.g., to feed a node).
## Returns actual amount discharged (limited by available glucose, rate, and active state).
func discharge(requested: float, is_active: bool = true) -> float:
	if not is_active:
		return 0.0
	var amount := minf(requested, current_glucose, discharge_rate)
	current_glucose -= amount
	return amount


## Set glucose to a specific amount (clamped to valid range).
func set_glucose(amount: float) -> void:
	current_glucose = clampf(amount, 0.0, max_glucose)


## Get current glucose as a ratio [0..1].
func get_fill_ratio() -> float:
	if max_glucose <= 0.0:
		return 0.0
	return current_glucose / max_glucose


## Get charge rate (capped at available space).
func get_effective_charge_rate(is_active: bool = true) -> float:
	if not is_active:
		return 0.0
	var space_available := max_glucose - current_glucose
	return minf(charge_rate, space_available)


## Get discharge rate (capped at available glucose).
func get_effective_discharge_rate(is_active: bool = true) -> float:
	if not is_active:
		return 0.0
	return minf(discharge_rate, current_glucose)
