class_name MissionObjectiveNode
extends StaticBody3D

signal destroyed(node: MissionObjectiveNode)

var encounter_id: StringName = &""
var objective_id: StringName = &""
var max_health := 100.0
var _health := 100.0
var _active := false
var _destroyed := false


func configure(
	next_encounter_id: StringName,
	next_objective_id: StringName,
	health: float
) -> void:
	encounter_id = next_encounter_id
	objective_id = next_objective_id
	max_health = maxf(1.0, health)
	reset_node()


func reset_node() -> void:
	_health = max_health
	_destroyed = false
	_active = false
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", false)
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual != null:
		visual.visible = true


func set_active(active: bool) -> void:
	_active = active and not _destroyed


func is_active() -> bool:
	return _active


func is_destroyed() -> bool:
	return _destroyed


func health() -> float:
	return _health


func take_damage(amount: float, _hit_position := Vector3.ZERO, _direction := Vector3.ZERO) -> void:
	if not _active or _destroyed or amount <= 0.0:
		return
	_health = maxf(0.0, _health - amount)
	if _health > 0.0:
		return
	_destroyed = true
	_active = false
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual != null:
		visual.visible = false
	destroyed.emit(self)
