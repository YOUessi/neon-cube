class_name EnemyAttackRuntime
extends RefCounted

var _pending := false
var _remaining := 0.0


func begin(windup_seconds: float) -> void:
	_pending = true
	_remaining = maxf(0.0, windup_seconds)


func cancel() -> void:
	_pending = false
	_remaining = 0.0


func tick(delta: float) -> bool:
	if not _pending:
		return false
	_remaining = maxf(0.0, _remaining - maxf(0.0, delta))
	if _remaining > 0.0:
		return false
	_pending = false
	return true


func is_pending() -> bool:
	return _pending


func remaining() -> float:
	return _remaining
