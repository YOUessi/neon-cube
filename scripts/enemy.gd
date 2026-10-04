class_name NeonEnemy
extends CharacterBody3D

signal killed(enemy: NeonEnemy)

@export var cube_half_extent := 30.0
@export var max_health := 70.0
@export var move_speed := 4.8
@export var acceleration := 16.0
@export var gravity_strength := 24.0
@export var gravity_align_speed := 10.0
@export var attack_range := 15.0
@export var attack_damage := 8.0
@export var attack_interval := 0.8

@onready var visual_root: Node3D = $VisualRoot

var target: NeonPlayer
var gravity_down := Vector3.DOWN
var _health := 70.0
var _attack_cooldown := 0.0
var _dead := false
var _anim: AnimationPlayer

func _ready() -> void:
	add_to_group("enemies")
	_health = max_health
	_build_visual()
	gravity_down = CubeGravity.nearest_down(global_position, cube_half_extent)
	up_direction = -gravity_down

func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(target):
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	gravity_down = CubeGravity.nearest_down(global_position, cube_half_extent, gravity_down, 0.24)
	up_direction = -gravity_down
	global_transform.basis = CubeGravity.aligned_basis(global_transform.basis, gravity_down, delta, gravity_align_speed)

	var to_target := target.global_position - global_position
	var tangent := to_target - gravity_down * to_target.dot(gravity_down)
	var distance := to_target.length()
	var wish := tangent.normalized() if tangent.length_squared() > 0.05 else Vector3.ZERO

	var fall_speed := velocity.dot(gravity_down)
	var horizontal := velocity - gravity_down * fall_speed
	if distance > 3.0:
		horizontal = horizontal.move_toward(wish * move_speed, acceleration * delta)
		_play_animation(["Run", "run", "Walking", "walking"])
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, acceleration * delta)
		_play_animation(["Idle", "idle"])
	fall_speed += gravity_strength * delta
	if is_on_floor() and fall_speed > 1.0:
		fall_speed = 1.0
	velocity = horizontal + gravity_down * fall_speed

	if wish.length_squared() > 0.05:
		_face_tangent_direction(wish, delta)
	move_and_slide()

	if distance <= attack_range and _attack_cooldown <= 0.0 and _has_line_of_sight():
		_attack_cooldown = attack_interval
		target.take_damage(attack_damage)
		_play_animation(["Attack", "attack", "Shooting", "shooting"])

func _face_tangent_direction(direction: Vector3, delta: float) -> void:
	var up := -gravity_down
	var forward := direction.normalized()
	var right := forward.cross(up).normalized()
	if right.length_squared() < 0.001:
		return
	var target_basis := Basis(right, up, -forward).orthonormalized()
	var weight := 1.0 - exp(-9.0 * delta)
	var q := global_transform.basis.get_rotation_quaternion().slerp(target_basis.get_rotation_quaternion(), weight)
	global_transform.basis = Basis(q).orthonormalized()

func _has_line_of_sight() -> bool:
	if not is_instance_valid(target):
		return false
	var from := global_position - gravity_down * 0.6
	var to := target.global_position
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == target

func take_damage(amount: float, _hit_position := Vector3.ZERO, _direction := Vector3.ZERO) -> void:
	if _dead:
		return
	_health -= amount
	if _health <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	set_physics_process(false)
	$CollisionShape3D.set_deferred("disabled", true)
	_play_animation(["Death", "death", "Dying", "dying"])
	killed.emit(self)
	var tween := create_tween()
	tween.tween_property(visual_root, "scale", Vector3(0.01, 0.01, 0.01), 0.28)
	tween.tween_callback(queue_free)

func _build_visual() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var model_path := "res://assets/models/enemy.glb"
	if ResourceLoader.exists(model_path):
		var packed := load(model_path) as PackedScene
		if packed != null:
			var model := packed.instantiate()
			visual_root.add_child(model)
			_anim = _find_animation_player(model)
			return

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.7
	body.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.08, 0.12)
	mat.metallic = 0.65
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.05, 0.38)
	mat.emission_energy_multiplier = 2.8
	body.material_override = mat
	visual_root.add_child(body)

	var eye := MeshInstance3D.new()
	var eye_mesh := BoxMesh.new()
	eye_mesh.size = Vector3(0.52, 0.12, 0.08)
	eye.mesh = eye_mesh
	eye.position = Vector3(0, 0.35, -0.42)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.02, 0.01, 0.02)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.0, 0.95, 1.0)
	eye_mat.emission_energy_multiplier = 8.0
	eye.material_override = eye_mat
	visual_root.add_child(eye)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _play_animation(candidates: Array) -> void:
	if _anim == null:
		return
	for candidate in candidates:
		if _anim.has_animation(candidate):
			if _anim.current_animation != candidate:
				_anim.play(candidate)
			return
