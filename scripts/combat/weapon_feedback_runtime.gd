class_name WeaponFeedbackRuntime
extends RefCounted

var _view_kick := 0.0

func apply_shot(definition: WeaponDefinition, yaw_sample: float) -> Vector2:
	if definition == null:
		return Vector2.ZERO
	_view_kick = minf(
		_view_kick + definition.view_kick_distance,
		definition.view_kick_distance * 2.2
	)
	return Vector2(
		definition.recoil_pitch_degrees,
		definition.recoil_yaw_degrees * clampf(yaw_sample, -1.0, 1.0)
	)

func tick(delta: float, definition: WeaponDefinition) -> void:
	if definition == null:
		_view_kick = 0.0
		return
	_view_kick = move_toward(
		_view_kick,
		0.0,
		definition.view_kick_recovery_speed * maxf(delta, 0.0)
	)

func view_kick() -> float:
	return _view_kick

func reset() -> void:
	_view_kick = 0.0
