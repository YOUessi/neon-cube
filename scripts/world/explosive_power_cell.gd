class_name ExplosivePowerCell
extends StaticBody3D

signal detonated(cell)

@export var max_health := 36.0
@export var blast_radius := 4.6
@export var blast_damage := 95.0
@export var accent_color := Color(1.0, 0.48, 0.08, 1.0)

var _health := 36.0
var _detonated := false


func _ready() -> void:
	add_to_group("explosive_power_cell")
	_health = max_health
	_ensure_collision()
	if DisplayServer.get_name() != "headless":
		_build_visual()


func take_damage(
	amount: float,
	_hit_position: Vector3 = Vector3.ZERO,
	_direction: Vector3 = Vector3.ZERO
) -> void:
	if _detonated or amount <= 0.0:
		return
	_health = maxf(0.0, _health - amount)
	if _health <= 0.0:
		_detonate()


func get_health() -> float:
	return _health


func is_detonated() -> bool:
	return _detonated


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	detonated.emit(self)
	_apply_blast()
	_play_explosion_audio()
	_spawn_explosion_vfx()

	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	queue_free()


func _apply_blast() -> void:
	if blast_radius <= 0.0 or blast_damage <= 0.0:
		return

	var center := _blast_center()
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	var seen := {}
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 64)
	for hit_variant in hits:
		var hit: Dictionary = hit_variant
		var collider := hit.get("collider") as Object
		if collider == null or not is_instance_valid(collider):
			continue
		var instance_id := collider.get_instance_id()
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		if not (
			collider is NeonEnemy
			or collider is NeonPlayer
			or collider is ExplosivePowerCell
		):
			continue
		if not _blast_reaches(collider as CollisionObject3D, center):
			continue

		var target_node := collider as Node3D
		var distance := center.distance_to(target_node.global_position)
		var ratio := clampf(distance / maxf(0.01, blast_radius), 0.0, 1.0)
		var damage := blast_damage * lerpf(1.0, 0.35, ratio)
		var direction := target_node.global_position - center
		if direction.length_squared() <= 0.001:
			direction = global_transform.basis.y
		else:
			direction = direction.normalized()

		if collider is NeonPlayer:
			(collider as NeonPlayer).take_damage(damage)
		else:
			collider.call("take_damage", damage, center, direction)


func _blast_reaches(collider: CollisionObject3D, center: Vector3) -> bool:
	if collider == null:
		return false
	var target_node := collider as Node3D
	if target_node == null:
		return false
	var destination := target_node.global_position
	if center.distance_squared_to(destination) <= 0.01:
		return true
	var ray := PhysicsRayQueryParameters3D.create(center, destination)
	ray.exclude = [get_rid()]
	ray.collision_mask = 1
	ray.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.get("collider") == collider


func _blast_center() -> Vector3:
	var up := global_transform.basis.y.normalized()
	return global_position + up * 0.70


func _ensure_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.position = Vector3(0, 0.70, 0)
	var shape := CylinderShape3D.new()
	shape.radius = 0.40
	shape.height = 1.35
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	var shell_mesh := CylinderMesh.new()
	shell_mesh.top_radius = 0.40
	shell_mesh.bottom_radius = 0.40
	shell_mesh.height = 1.35
	shell_mesh.radial_segments = 24
	shell.mesh = shell_mesh
	shell.position = Vector3(0, 0.70, 0)
	shell.material_override = _material(Color(0.035, 0.04, 0.055), accent_color, 1.1)
	add_child(shell)

	var core := MeshInstance3D.new()
	core.name = "VolatileCore"
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.17
	core_mesh.bottom_radius = 0.17
	core_mesh.height = 1.10
	core_mesh.radial_segments = 20
	core.mesh = core_mesh
	core.position = Vector3(0, 0.70, 0)
	core.material_override = _material(accent_color * 0.06, accent_color, 7.5)
	add_child(core)

	for y in [0.18, 1.22]:
		var band := MeshInstance3D.new()
		band.name = "WarningBand"
		var band_mesh := TorusMesh.new()
		band_mesh.inner_radius = 0.34
		band_mesh.outer_radius = 0.43
		band_mesh.rings = 24
		band_mesh.ring_segments = 10
		band.mesh = band_mesh
		band.position = Vector3(0, float(y), 0)
		band.material_override = _material(accent_color * 0.06, accent_color, 5.8)
		add_child(band)

	var label := Label3D.new()
	label.name = "VolatileLabel"
	label.text = "VOLATILE"
	label.font_size = 22
	label.outline_size = 5
	label.modulate = accent_color
	label.outline_modulate = Color(0.004, 0.006, 0.015, 0.96)
	label.position = Vector3(0, 1.62, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _spawn_explosion_vfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var pulse := MeshInstance3D.new()
	pulse.name = "PowerCellBlast"
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.90
	mesh.radial_segments = 28
	mesh.rings = 16
	pulse.mesh = mesh

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.18)
	material.emission_enabled = true
	material.emission = accent_color
	material.emission_energy_multiplier = 8.0
	pulse.material_override = material

	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(pulse)
	pulse.global_position = _blast_center()
	pulse.scale = Vector3.ONE * 0.25
	var target_scale := Vector3.ONE * (blast_radius / 0.45)
	var tween := pulse.create_tween()
	tween.tween_property(pulse, "scale", target_scale, 0.18)
	tween.tween_callback(pulse.queue_free)


func _play_explosion_audio() -> void:
	for node in get_tree().get_nodes_in_group("neon_audio"):
		if node.has_method("play_explosion"):
			node.call("play_explosion")
			return


func _material(base: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.metallic = 0.65
	material.roughness = 0.24
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
