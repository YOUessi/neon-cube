class_name MissionObjectiveNode
extends StaticBody3D

signal destroyed(node: MissionObjectiveNode)

var encounter_id: StringName = &""
var objective_id: StringName = &""
var max_health := 100.0
var _health := 100.0
var _active := false
var _destroyed := false
var _pulse_time := 0.0
var _damage_flash := 0.0


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
	_pulse_time = 0.0
	_damage_flash = 0.0
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", false)
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual != null:
		visual.visible = true
		visual.scale = Vector3.ONE
	_set_visual_energy(0.35)


func set_active(active: bool) -> void:
	_active = active and not _destroyed
	_set_visual_energy(4.0 if _active else 0.35)


func is_active() -> bool:
	return _active


func is_destroyed() -> bool:
	return _destroyed


func health() -> float:
	return _health


func health_ratio() -> float:
	return clampf(_health / maxf(1.0, max_health), 0.0, 1.0)


func take_damage(amount: float, _hit_position := Vector3.ZERO, _direction := Vector3.ZERO) -> void:
	if not _active or _destroyed or amount <= 0.0:
		return
	_health = maxf(0.0, _health - amount)
	_damage_flash = 1.0
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


func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless" or _destroyed:
		return
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual == null:
		return
	_damage_flash = move_toward(_damage_flash, 0.0, maxf(0.0, delta) * 5.0)
	if not _active:
		visual.scale = Vector3.ONE
		_set_visual_energy(0.35)
		return
	_pulse_time += delta
	var pulse := 0.5 + 0.5 * sin(_pulse_time * 4.2)
	var damage_boost := _damage_flash * 3.4
	var ratio := health_ratio()
	_set_visual_energy(3.2 + pulse * 1.4 + damage_boost)
	visual.scale = Vector3(
		1.0 + pulse * 0.018,
		0.88 + ratio * 0.12 + pulse * 0.018,
		1.0 + pulse * 0.018
	)


func _set_visual_energy(energy: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual == null:
		return
	var material := visual.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_enabled = energy > 0.0
	if energy > 0.0:
		material.emission_energy_multiplier = energy
