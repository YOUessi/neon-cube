class_name NeonEnemy
extends CharacterBody3D

signal killed(enemy: NeonEnemy)

@export var cube_half_extent := 30.0
@export var archetype := "grunt"
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
var score_value := 100
var _health := 70.0
var _attack_cooldown := 0.0
var _dead := false
var _anim: AnimationPlayer
var _wave_level := 1
var _difficulty_scale := 1.0
var _boss_phase := 1
var _visual_time := 0.0

func configure(kind: String, wave_level: int, difficulty_scale: float = 1.0) -> void:
	archetype = kind
	_wave_level = maxi(1, wave_level)
	_difficulty_scale = maxf(0.5, difficulty_scale)
	_apply_archetype()

func _ready() -> void:
	add_to_group("enemies")
	_apply_archetype()
	_health = max_health
	_build_visual()
	gravity_down = CubeGravity.nearest_down(global_position, cube_half_extent)
	up_direction = -gravity_down

func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless" or visual_root == null or _dead:
		return
	_visual_time += delta
	visual_root.position.y = sin(_visual_time * (4.5 if archetype == "runner" else 2.4)) * 0.035

func _apply_archetype() -> void:
	var scale_factor: float = (1.0 + float(_wave_level - 1) * 0.045) * _difficulty_scale
	match archetype:
		"runner":
			max_health = 44.0 * scale_factor
			move_speed = 7.2
			attack_range = 9.0
			attack_damage = 6.0 * scale_factor
			attack_interval = 0.48
			score_value = 130
		"sniper":
			max_health = 58.0 * scale_factor
			move_speed = 3.4
			attack_range = 27.0
			attack_damage = 17.0 * scale_factor
			attack_interval = 1.55
			score_value = 180
		"tank":
			max_health = 185.0 * scale_factor
			move_speed = 2.7
			attack_range = 12.0
			attack_damage = 13.0 * scale_factor
			attack_interval = 0.9
			score_value = 240
		"boss":
			max_health = 850.0 * _difficulty_scale
			move_speed = 3.6
			attack_range = 23.0
			attack_damage = 19.0 * _difficulty_scale
			attack_interval = 0.5
			score_value = 2200
		_:
			max_health = 72.0 * scale_factor
			move_speed = 4.8
			attack_range = 15.0
			attack_damage = 8.0 * scale_factor
			attack_interval = 0.82
			score_value = 100

func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(target):
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	gravity_down = CubeGravity.nearest_down(global_position, cube_half_extent, gravity_down, 0.24)
	up_direction = -gravity_down
	global_transform.basis = CubeGravity.aligned_basis(global_transform.basis, gravity_down, delta, gravity_align_speed)

	var distance: float = (target.global_position - global_position).length()
	var wish: Vector3 = CubeGravity.surface_route_direction(global_position, gravity_down, target.global_position, cube_half_extent)
	wish = _avoid_obstacles(wish)

	var fall_speed: float = velocity.dot(gravity_down)
	var horizontal: Vector3 = velocity - gravity_down * fall_speed
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
		var burst_multiplier: float = 1.0
		if archetype == "boss":
			burst_multiplier = 1.0 + float(_boss_phase - 1) * 0.22
		target.take_damage(attack_damage * burst_multiplier)
		_play_animation(["Attack", "attack", "Shooting", "shooting"])

func _avoid_obstacles(wish: Vector3) -> Vector3:
	if wish.length_squared() < 0.01:
		return wish
	var origin: Vector3 = global_position - gravity_down * 0.55
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + wish * 1.65)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") == target:
		return wish
	var up: Vector3 = -gravity_down
	var side: Vector3 = up.cross(wish).normalized()
	if side.length_squared() < 0.01:
		return wish
	var side_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + side * 1.4)
	side_query.exclude = [get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(side_query).is_empty():
		return (wish + side * 1.2).normalized()
	return (wish - side * 1.2).normalized()

func _face_tangent_direction(direction: Vector3, delta: float) -> void:
	var up: Vector3 = -gravity_down
	var forward: Vector3 = direction.normalized()
	var right: Vector3 = forward.cross(up).normalized()
	if right.length_squared() < 0.001:
		return
	var target_basis: Basis = Basis(right, up, -forward).orthonormalized()
	var weight: float = 1.0 - exp(-9.0 * delta)
	var q: Quaternion = global_transform.basis.get_rotation_quaternion().slerp(target_basis.get_rotation_quaternion(), weight)
	global_transform.basis = Basis(q).orthonormalized()

func _has_line_of_sight() -> bool:
	if not is_instance_valid(target):
		return false
	var from: Vector3 = global_position - gravity_down * 0.6
	var to: Vector3 = target.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == target

func take_damage(amount: float, _hit_position := Vector3.ZERO, _direction := Vector3.ZERO) -> void:
	if _dead:
		return
	_health -= amount
	if archetype == "boss":
		_update_boss_phase()
	if _health <= 0.0:
		_die()

func _update_boss_phase() -> void:
	if max_health <= 0.0:
		return
	var ratio: float = _health / max_health
	var next_phase := 1
	if ratio <= 0.30:
		next_phase = 3
	elif ratio <= 0.60:
		next_phase = 2
	if next_phase > _boss_phase:
		_boss_phase = next_phase
		move_speed += 0.75
		attack_interval = maxf(0.24, attack_interval - 0.08)

func _die() -> void:
	_dead = true
	set_physics_process(false)
	$CollisionShape3D.set_deferred("disabled", true)
	_play_animation(["Death", "death", "Dying", "dying"])
	killed.emit(self)
	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	var tween: Tween = create_tween()
	tween.tween_property(visual_root, "scale", Vector3(0.01, 0.01, 0.01), 0.28)
	tween.tween_callback(queue_free)

func _build_visual() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var model_path := "res://assets/models/enemy.glb"
	if ResourceLoader.exists(model_path):
		var packed: PackedScene = load(model_path) as PackedScene
		if packed != null:
			var model: Node = packed.instantiate()
			visual_root.add_child(model)
			_anim = _find_animation_player(model)
			if archetype == "boss":
				visual_root.scale = Vector3.ONE * 1.75
			return
	_build_procedural_humanoid()

func _build_procedural_humanoid() -> void:
	var neon := _archetype_color()
	var scale_factor := 1.0
	if archetype == "runner":
		scale_factor = 0.9
	elif archetype == "tank":
		scale_factor = 1.25
	elif archetype == "boss":
		scale_factor = 1.75

	var armor := _part_material(Color(0.055, 0.065, 0.09), neon, 1.8)
	var glow := _part_material(neon * 0.08, neon, 7.2)

	_add_box_part("Torso", Vector3(0, 0.25, 0), Vector3(0.62, 0.82, 0.34) * scale_factor, armor)
	_add_box_part("ChestCore", Vector3(0, 0.28, -0.19 * scale_factor), Vector3(0.28, 0.12, 0.05) * scale_factor, glow)
	_add_box_part("Head", Vector3(0, 0.83 * scale_factor, 0), Vector3(0.38, 0.32, 0.34) * scale_factor, armor)
	_add_box_part("Visor", Vector3(0, 0.84 * scale_factor, -0.19 * scale_factor), Vector3(0.28, 0.07, 0.05) * scale_factor, glow)

	for side in [-1.0, 1.0]:
		_add_box_part("Arm", Vector3(0.44 * side, 0.28, 0), Vector3(0.16, 0.66, 0.18) * scale_factor, armor)
		_add_box_part("Leg", Vector3(0.18 * side, -0.48 * scale_factor, 0), Vector3(0.20, 0.62, 0.22) * scale_factor, armor)

	if archetype == "sniper":
		_add_box_part("Rail", Vector3(0.52, 0.18, -0.24), Vector3(0.10, 0.10, 0.85) * scale_factor, glow)
	elif archetype == "tank" or archetype == "boss":
		for side in [-1.0, 1.0]:
			_add_box_part("Shoulder", Vector3(0.50 * side, 0.53, 0), Vector3(0.28, 0.22, 0.32) * scale_factor, glow)

	visual_root.scale = Vector3.ONE * scale_factor

func _add_box_part(_name: String, pos: Vector3, size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = _name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = pos
	part.material_override = material
	visual_root.add_child(part)

func _part_material(base: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.metallic = 0.72
	mat.roughness = 0.24
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat

func _archetype_color() -> Color:
	match archetype:
		"runner": return Color(1.0, 0.18, 0.7)
		"sniper": return Color(0.35, 0.55, 1.0)
		"tank": return Color(1.0, 0.48, 0.08)
		"boss": return Color(0.82, 0.05, 1.0)
		_: return Color(0.0, 0.95, 1.0)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _play_animation(candidates: Array) -> void:
	if _anim == null:
		return
	for candidate in candidates:
		var animation_name: StringName = StringName(candidate)
		if _anim.has_animation(animation_name):
			if _anim.current_animation != animation_name:
				_anim.play(animation_name)
			return

func get_health() -> float:
	return _health

func get_score_value() -> int:
	return score_value

func get_boss_phase() -> int:
	return _boss_phase
