class_name NeonPlayer
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal ammo_changed(current: int, reserve: int)
signal weapon_changed(weapon_name: String, slot: int)
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
@export var magazine_size := 30
@export var reserve_ammo := 150

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var gravity_down := Vector3.DOWN
var _pitch := 0.0
var _health := 100.0
var _weapon_index := 0
var _weapon_ammo: Array[int] = [30, 8, 12]
var _weapon_reserve: Array[int] = [150, 40, 72]
var _fire_cooldown := 0.0
var _reload_cooldown := 0.0
var _last_face := ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_health = max_health
	_weapon_ammo = [30, 8, 12]
	_weapon_reserve = [reserve_ammo, 40, 72]
	up_direction = -gravity_down
	_rng.seed = 2049
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_emit_status()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_object_local(Vector3.UP, -mouse_event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - mouse_event.relative.y * mouse_sensitivity, deg_to_rad(-82.0), deg_to_rad(82.0))
		camera_pivot.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_reload_cooldown = maxf(0.0, _reload_cooldown - delta)

	var next_down: Vector3 = CubeGravity.nearest_down(global_position, cube_half_extent, gravity_down)
	if not next_down.is_equal_approx(gravity_down):
		gravity_down = next_down
	up_direction = -gravity_down
	global_transform.basis = CubeGravity.aligned_basis(global_transform.basis, gravity_down, delta, gravity_align_speed)

	var face: String = CubeGravity.face_name(gravity_down)
	if face != _last_face:
		_last_face = face
		face_changed.emit(face)

	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish: Vector3 = global_transform.basis.x * input_vec.x + global_transform.basis.z * input_vec.y
	wish = wish - gravity_down * wish.dot(gravity_down)
	if wish.length_squared() > 0.001:
		wish = wish.normalized()

	var fall_speed: float = velocity.dot(gravity_down)
	var horizontal: Vector3 = velocity - gravity_down * fall_speed
	var accel: float = ground_accel if is_on_floor() else air_accel
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
	if Input.is_action_just_pressed("weapon_1"):
		switch_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"):
		switch_weapon(1)
	elif Input.is_action_just_pressed("weapon_3"):
		switch_weapon(2)

	if global_position.length() > cube_half_extent * 2.2:
		global_position = Vector3(0, -cube_half_extent + 2.0, 0)
		velocity = Vector3.ZERO
		gravity_down = Vector3.DOWN

func _weapon_spec(index: int) -> Dictionary:
	match index:
		1:
			return {
				"name": "ARC SCATTERGUN",
				"damage": 16.0,
				"fire_rate": 1.25,
				"magazine": 8,
				"reserve_cap": 48,
				"reload": 1.05,
				"pellets": 8,
				"spread": 0.055,
				"range": 42.0,
			}
		2:
			return {
				"name": "ION MARKSMAN",
				"damage": 72.0,
				"fire_rate": 2.0,
				"magazine": 12,
				"reserve_cap": 84,
				"reload": 0.9,
				"pellets": 1,
				"spread": 0.002,
				"range": 150.0,
			}
		_:
			return {
				"name": "PULSE RIFLE",
				"damage": 26.0,
				"fire_rate": 9.5,
				"magazine": 30,
				"reserve_cap": 180,
				"reload": 0.72,
				"pellets": 1,
				"spread": 0.008,
				"range": 115.0,
			}

func switch_weapon(index: int) -> void:
	if index < 0 or index >= _weapon_ammo.size() or index == _weapon_index:
		return
	_weapon_index = index
	_reload_cooldown = 0.0
	var spec: Dictionary = _weapon_spec(_weapon_index)
	weapon_changed.emit(String(spec["name"]), _weapon_index + 1)
	ammo_changed.emit(_weapon_ammo[_weapon_index], _weapon_reserve[_weapon_index])

func _try_fire() -> void:
	if _fire_cooldown > 0.0 or _reload_cooldown > 0.0:
		return
	if _weapon_ammo[_weapon_index] <= 0:
		_reload()
		return

	var spec: Dictionary = _weapon_spec(_weapon_index)
	_fire_cooldown = 1.0 / float(spec["fire_rate"])
	_weapon_ammo[_weapon_index] -= 1
	ammo_changed.emit(_weapon_ammo[_weapon_index], _weapon_reserve[_weapon_index])
	_audio_call("play_shot", [_weapon_index])

	var from: Vector3 = camera.global_position
	var base_direction: Vector3 = -camera.global_transform.basis.z.normalized()
	var right: Vector3 = camera.global_transform.basis.x.normalized()
	var up: Vector3 = camera.global_transform.basis.y.normalized()
	var pellets: int = int(spec["pellets"])
	var spread: float = float(spec["spread"])
	var weapon_range: float = float(spec["range"])
	var damage: float = float(spec["damage"])

	for pellet in range(pellets):
		var jitter_x: float = _rng.randf_range(-spread, spread)
		var jitter_y: float = _rng.randf_range(-spread, spread)
		var direction: Vector3 = (base_direction + right * jitter_x + up * jitter_y).normalized()
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + direction * weapon_range)
		query.exclude = [get_rid()]
		query.collide_with_areas = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider: Object = hit.get("collider") as Object
		if collider != null and collider.has_method("take_damage"):
			collider.call("take_damage", damage, hit.get("position", Vector3.ZERO), direction)
		if pellet == 0:
			_spawn_impact(hit.get("position", Vector3.ZERO), hit.get("normal", Vector3.UP))

func _spawn_impact(position: Vector3, normal: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var flash: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	flash.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.12, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.04, 0.7)
	mat.emission_energy_multiplier = 7.0
	flash.material_override = mat
	get_tree().current_scene.add_child(flash)
	flash.global_position = position + normal * 0.03
	get_tree().create_timer(0.08).timeout.connect(flash.queue_free)

func _reload() -> void:
	var spec: Dictionary = _weapon_spec(_weapon_index)
	var capacity: int = int(spec["magazine"])
	if _reload_cooldown > 0.0 or _weapon_ammo[_weapon_index] >= capacity or _weapon_reserve[_weapon_index] <= 0:
		return
	var needed: int = capacity - _weapon_ammo[_weapon_index]
	var amount: int = mini(needed, _weapon_reserve[_weapon_index])
	_weapon_ammo[_weapon_index] += amount
	_weapon_reserve[_weapon_index] -= amount
	_reload_cooldown = float(spec["reload"])
	ammo_changed.emit(_weapon_ammo[_weapon_index], _weapon_reserve[_weapon_index])
	_audio_call("play_reload")

func grant_ammo(amount: int) -> void:
	var spec: Dictionary = _weapon_spec(_weapon_index)
	var cap: int = int(spec["reserve_cap"])
	_weapon_reserve[_weapon_index] = mini(cap, _weapon_reserve[_weapon_index] + maxi(0, amount))
	ammo_changed.emit(_weapon_ammo[_weapon_index], _weapon_reserve[_weapon_index])

func take_damage(amount: float) -> void:
	if _health <= 0.0:
		return
	_health = maxf(0.0, _health - amount)
	health_changed.emit(_health, max_health)
	if _health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	_health = minf(max_health, _health + maxf(0.0, amount))
	health_changed.emit(_health, max_health)

func _audio_call(method: StringName, args: Array = []) -> void:
	var audio: Node = get_tree().get_first_node_in_group("neon_audio")
	if audio != null and audio.has_method(method):
		audio.callv(method, args)

func _emit_status() -> void:
	var spec: Dictionary = _weapon_spec(_weapon_index)
	health_changed.emit(_health, max_health)
	ammo_changed.emit(_weapon_ammo[_weapon_index], _weapon_reserve[_weapon_index])
	weapon_changed.emit(String(spec["name"]), _weapon_index + 1)
	face_changed.emit(CubeGravity.face_name(gravity_down))

func get_health() -> float:
	return _health

func get_ammo() -> int:
	return _weapon_ammo[_weapon_index]

func get_reserve_ammo() -> int:
	return _weapon_reserve[_weapon_index]

func get_weapon_index() -> int:
	return _weapon_index

func get_weapon_name() -> String:
	var spec: Dictionary = _weapon_spec(_weapon_index)
	return String(spec["name"])
