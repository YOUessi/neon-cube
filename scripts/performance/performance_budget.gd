class_name PerformanceBudget
extends Resource

@export var target_frame_ms := 16.67
@export var hard_frame_ms := 33.33
@export var max_active_enemies := 32
@export var max_active_pickups := 12

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if target_frame_ms <= 0.0:
		errors.append("target_frame_ms must be positive")
	if hard_frame_ms < target_frame_ms:
		errors.append("hard_frame_ms must not be lower than target_frame_ms")
	if max_active_enemies <= 0:
		errors.append("max_active_enemies must be positive")
	if max_active_pickups < 0:
		errors.append("max_active_pickups must be non-negative")
	return errors

func evaluate(
	average_frame_ms: float,
	peak_frame_ms: float,
	active_enemies: int,
	active_pickups: int
) -> PackedStringArray:
	var warnings := PackedStringArray()
	if average_frame_ms > target_frame_ms:
		warnings.append("average frame %.2fms exceeds %.2fms target" % [average_frame_ms, target_frame_ms])
	if peak_frame_ms > hard_frame_ms:
		warnings.append("peak frame %.2fms exceeds %.2fms hard budget" % [peak_frame_ms, hard_frame_ms])
	if active_enemies > max_active_enemies:
		warnings.append("active enemies %d exceed budget %d" % [active_enemies, max_active_enemies])
	if active_pickups > max_active_pickups:
		warnings.append("active pickups %d exceed budget %d" % [active_pickups, max_active_pickups])
	return warnings
