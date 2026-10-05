class_name PlayerVitals
extends RefCounted

signal health_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

var max_health := 100.0
var max_shield := 50.0
var shield_regen_delay := 3.0
var shield_regen_rate := 8.0

var _health := 100.0
var _shield := 50.0
var _shield_delay_remaining := 0.0

func configure(
	health_max: float,
	shield_max: float,
	regen_delay: float,
	regen_rate: float
) -> void:
	max_health = maxf(1.0, health_max)
	max_shield = maxf(0.0, shield_max)
	shield_regen_delay = maxf(0.0, regen_delay)
	shield_regen_rate = maxf(0.0, regen_rate)
	reset()

func reset() -> void:
	_health = max_health
	_shield = max_shield
	_shield_delay_remaining = 0.0
	health_changed.emit(_health, max_health)
	shield_changed.emit(_shield, max_shield)

func tick(delta: float) -> void:
	_shield_delay_remaining = maxf(0.0, _shield_delay_remaining - delta)
	if _shield_delay_remaining > 0.0 or _shield >= max_shield:
		return
	var before := _shield
	_shield = minf(max_shield, _shield + shield_regen_rate * delta)
	if not is_equal_approx(before, _shield):
		shield_changed.emit(_shield, max_shield)

func take_damage(amount: float) -> void:
	if _health <= 0.0:
		return
	var requested := maxf(0.0, amount)
	var incoming := requested
	if _shield > 0.0:
		var absorbed := minf(_shield, incoming)
		_shield -= absorbed
		incoming -= absorbed
		shield_changed.emit(_shield, max_shield)
	if incoming > 0.0:
		_health = maxf(0.0, _health - incoming)
		health_changed.emit(_health, max_health)
	_shield_delay_remaining = shield_regen_delay
	damaged.emit(requested)
	if _health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	_health = minf(max_health, _health + maxf(0.0, amount))
	health_changed.emit(_health, max_health)

func grant_shield(amount: float) -> void:
	_shield = minf(max_shield, _shield + maxf(0.0, amount))
	shield_changed.emit(_shield, max_shield)

func health() -> float:
	return _health

func shield() -> float:
	return _shield

func regen_delay_remaining() -> float:
	return _shield_delay_remaining
