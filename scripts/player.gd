class_name NeonPlayer
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal ammo_changed(current: int, reserve: int)
signal face_changed(face_name: String)
signal died

@export var cube_half_extent := 30.0
@export var move_speed := 9.0
@export var ground_accel := 34.0
@export var air_accel := 10.0
@export var gravity_strength := 24.0
@export var jump_speed := 8.0
@export var mouse_sensitivity := 0.0022
@export var gravity_align_speed := 12.0
@export var max_health := 100.0
@export var magazine_size := 24
@export var reserve_ammo := 144
@export var fire_rate := 8.0
@export var weapon_damage := 34.0
@export var weapon_range := 120.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var gravity_down := Vector3.DOWN
var _pitch := 0.0
var _health := 100.0
var _ammo := 24
var _reserve := 144
var _fire_cooldown := 0.0
var _reload_cooldown := 0.0
var _last_face := ""

func _ready() -> void:
	_health = max_health
	_ammo = magazine_size
	_reserve = reserve_ammo
	up_direction = -gravity_down
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_emit_status()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-82.0), deg_to_rad(82.0))
		camera_pivot.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_reload_cooldown = maxf(0.0, _reload_cooldown - delta)

	var next_down := CubeGravity.nearest_down(global_position, cube_half_extent, gravity_down)
	if not next_down.is_equal_approx(gravity_down):
		gravity_down = next_down
	up_direction = -gravity_down
	global_transform.basis = CubeGravity.aligned_basis(global_transform.basis, gravity_down, delta, gravity_align_speed)

	var face := CubeGravity.face_name(gravity_down)
	if face != _last_face:
		_last_face = face
		face_changed.emit(face)

	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_transform.basis.x * input_vec.x + global_transform.basis.z * input_vec.y
	wish = wish - gravity_down * wish.dot(gravity_down)
	if wish.length_squared() > 0.001:
		wish = wish.normalized()

	var fall_speed := velocity.dot(gravity_down)
	var horizontal := velocity - gravity_down * fall_speed
	var accel := ground_accel if is_on_floor() else air_accel
	horizontal = horizontal.move_toward(wish * move_speed, accel * delta)
	fall_speed += gravity_strength * delta
	if is_on_floor() and fall_speed > 1.0:
		fall_speed = 1.0
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		fall_speed = -jump_speed
	velocity = horizontal + gravity_down * fall_speed

	move_and_slide()

	if Input.is_action_pressed("fire"):
		_try_fire()
	if Input.is_action_just_pressed("reload"):
		_reload()

	if global_position.length() > cube_half_extent * 2.2:
		global_position = Vector3(0, -cube_half_extent + 2.0, 0)
		velocity = Vector3.ZERO
		gravity_down = Vector3.DOWN

func _try_fire() -> void:
	if _fire_cooldown > 0.0 or _reload_cooldown > 0.0:
		return
	if _ammo <= 0:
		_reload()
		return
	_fire_cooldown = 1.0 / fire_rate
	_ammo -= 1
	ammo_changed.emit(_ammo, _reserve)

	var from := camera.global_position
	var direction := -camera.global_transform.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * weapon_range)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider := hit.get("collider") as Object
	if collider != null and collider.has_method("take_damage"):
		collider.take_damage(weapon_damage, hit.get("position", Vector3.ZERO), direction)
	_spawn_impact(hit.get("position", Vector3.ZERO), hit.get("normal", Vector3.UP))

func _spawn_impact(position: Vector3, normal: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	flash.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.12, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.04, 0.7)
	mat.emission_energy_multiplier = 7.0
	flash.material_override = mat
	get_tree().current_scene.add_child(flash)
	flash.global_position = position + normal * 0.03
	var timer := get_tree().create_timer(0.08)
	timer.timeout.connect(flash.queue_free)

func _reload() -> void:
	if _reload_cooldown > 0.0 or _ammo >= magazine_size or _reserve <= 0:
		return
	var needed := magazine_size - _ammo
	var amount := mini(needed, _reserve)
	_ammo += amount
	_reserve -= amount
	_reload_cooldown = 0.7
	ammo_changed.emit(_ammo, _reserve)

func take_damage(amount: float) -> void:
	if _health <= 0.0:
		return
	_health = maxf(0.0, _health - amount)
	health_changed.emit(_health, max_health)
	if _health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	_health = minf(max_health, _health + amount)
	health_changed.emit(_health, max_health)

func _emit_status() -> void:
	health_changed.emit(_health, max_health)
	ammo_changed.emit(_ammo, _reserve)
	face_changed.emit(CubeGravity.face_name(gravity_down))

func get_health() -> float:
	return _health

func get_ammo() -> int:
	return _ammo

func get_reserve_ammo() -> int:
	return _reserve
