class_name NeonPlayer
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal ammo_changed(current: int, reserve: int)
signal weapon_changed(weapon_name: String, slot: int)
signal face_changed(face_name: String)
signal damaged(amount: float)
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
@export var max_shield := 50.0
@export var shield_regen_delay := 3.0
@export var shield_regen_rate := 8.0
@export var dash_speed := 18.0
@export var dash_cooldown := 1.25
@export var magazine_size := 30
@export var reserve_ammo := 150

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var weapon_root: Node3D = $CameraPivot/Camera3D/WeaponRoot

var gravity_down := Vector3.DOWN
var _pitch := 0.0
var _health := 100.0
var _shield := 50.0
var _shield_delay_remaining := 0.0
var _dash_remaining := 0.0
var _loadout: WeaponLoadout = WeaponLoadout.new()
var _last_face := ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_ensure_local_input_actions()
	_health = max_health
	_shield = max_shield
	_loadout.ammo_changed.connect(_on_loadout_ammo_changed)
	_loadout.weapon_changed.connect(_on_loadout_weapon_changed)
	_loadout.initialize()
	var starting_weapon: WeaponDefinition = _loadout.current_definition()
	magazine_size = starting_weapon.magazine_size
	reserve_ammo = starting_weapon.initial_reserve
	up_direction = -gravity_down
	_rng.seed = 2049
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_weapon_visual()
	_emit_status()

func _ensure_local_input_actions() -> void:
	var key_actions := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"reload": KEY_R,
		"weapon_1": KEY_1,
		"weapon_2": KEY_2,
		"weapon_3": KEY_3,
		"dash": KEY_SHIFT,
	}
	for action in key_actions:
		var action_name: StringName = StringName(action)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		if InputMap.action_get_events(action_name).is_empty():
			var event := InputEventKey.new()
			event.physical_keycode = int(key_actions[action])
			InputMap.action_add_event(action_name, event)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	if InputMap.action_get_events("fire").is_empty():
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mouse)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_object_local(Vector3.UP, -mouse_event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - mouse_event.relative.y * mouse_sensitivity, deg_to_rad(-82.0), deg_to_rad(82.0))
		camera_pivot.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_loadout.tick(delta)
	_dash_remaining = maxf(0.0, _dash_remaining - delta)
	_shield_delay_remaining = maxf(0.0, _shield_delay_remaining - delta)
	if _shield_delay_remaining <= 0.0 and _shield < max_shield:
		var before: float = _shield
		_shield = minf(max_shield, _shield + shield_regen_rate * delta)
		if not is_equal_approx(before, _shield):
			shield_changed.emit(_shield, max_shield)

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
	if Input.is_action_just_pressed("dash") and _dash_remaining <= 0.0:
		var dash_direction: Vector3 = wish
		if dash_direction.length_squared() < 0.01:
			dash_direction = -global_transform.basis.z
			dash_direction = dash_direction - gravity_down * dash_direction.dot(gravity_down)
		dash_direction = dash_direction.normalized()
		horizontal = dash_direction * dash_speed
		_dash_remaining = dash_cooldown
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

func _weapon_spec(index: int) -> WeaponDefinition:
	return WeaponCatalog.get_definition(index)

func switch_weapon(index: int) -> void:
	_loadout.switch_weapon(index)

func _try_fire() -> void:
	if not _loadout.consume_shot():
		if _loadout.current_ammo() <= 0:
			_reload()
		return
	var spec: WeaponDefinition = _loadout.current_definition()
	_audio_call("play_shot", [_loadout.current_index()])
	_recoil_weapon()

	var from: Vector3 = camera.global_position
	var base_direction: Vector3 = -camera.global_transform.basis.z.normalized()
	var right: Vector3 = camera.global_transform.basis.x.normalized()
	var up: Vector3 = camera.global_transform.basis.y.normalized()
	var pellets: int = spec.pellets
	var spread: float = spec.spread
	var weapon_range: float = spec.max_range
	var damage: float = spec.damage

	for pellet in range(pellets):
		var jitter_x: float = _rng.randf_range(-spread, spread)
		var jitter_y: float = _rng.randf_range(-spread, spread)
		var direction: Vector3 = (base_direction + right * jitter_x + up * jitter_y).normalized()
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + direction * weapon_range)
		query.exclude = [get_rid()]
		query.collide_with_areas = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		var end_point: Vector3 = from + direction * weapon_range
		if not hit.is_empty():
			end_point = hit.get("position", end_point)
			var collider: Object = hit.get("collider") as Object
			if collider != null and collider.has_method("take_damage"):
				collider.call("take_damage", damage, end_point, direction)
			if pellet == 0:
				_spawn_impact(end_point, hit.get("normal", Vector3.UP))
		if pellet == 0:
			_spawn_tracer(from, end_point, spec.accent_color)

func _refresh_weapon_visual() -> void:
	if DisplayServer.get_name() == "headless" or weapon_root == null:
		return
	for child in weapon_root.get_children():
		child.queue_free()

	var model_paths := [
		"res://assets/third_party/kenney_blaster/blaster-e.glb",
		"res://assets/third_party/kenney_blaster/blaster-p.glb",
		"res://assets/third_party/kenney_blaster/blaster-r.glb",
	]
	var model_path: String = model_paths[_weapon_index]
	if ResourceLoader.exists(model_path):
		var packed: PackedScene = load(model_path) as PackedScene
		if packed != null:
			var model: Node3D = packed.instantiate() as Node3D
			if model != null:
				model.scale = Vector3.ONE * 0.38
				model.rotation_degrees = Vector3(-8, 180, 0)
				weapon_root.add_child(model)
				return

	var spec: WeaponDefinition = _weapon_spec(_weapon_index)
	var neon: Color = spec.accent_color
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.035, 0.045, 0.075)
	dark.metallic = 0.8
	dark.roughness = 0.2
	var glow := StandardMaterial3D.new()
	glow.albedo_color = neon * 0.2
	glow.emission_enabled = true
	glow.emission = neon
	glow.emission_energy_multiplier = 4.5
	glow.metallic = 0.45
	glow.roughness = 0.15

	if _loadout.current_index() == 1:
		_weapon_box(Vector3(0, 0, 0), Vector3(0.15, 0.11, 0.42), dark)
		_weapon_box(Vector3(0, 0.0, -0.29), Vector3(0.10, 0.08, 0.20), glow)
		for side in [-1.0, 1.0]:
			_weapon_box(Vector3(0.09 * side, -0.015, -0.20), Vector3(0.045, 0.045, 0.24), dark)
	elif _loadout.current_index() == 2:
		_weapon_box(Vector3(0, 0, 0), Vector3(0.09, 0.075, 0.50), dark)
		_weapon_box(Vector3(0, 0.035, -0.28), Vector3(0.055, 0.035, 0.16), glow)
		_weapon_box(Vector3(0, -0.055, 0.11), Vector3(0.07, 0.11, 0.16), dark)
	else:
		_weapon_box(Vector3(0, 0, 0), Vector3(0.12, 0.09, 0.44), dark)
		_weapon_box(Vector3(0, 0.035, -0.22), Vector3(0.065, 0.035, 0.16), glow)
		_weapon_box(Vector3(0, -0.055, 0.09), Vector3(0.08, 0.12, 0.14), dark)

func _weapon_box(pos: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	weapon_root.add_child(instance)

func _recoil_weapon() -> void:
	if DisplayServer.get_name() == "headless" or weapon_root == null:
		return
	weapon_root.position = Vector3(0.25, -0.23, -0.61)
	var tween: Tween = create_tween()
	tween.tween_property(weapon_root, "position", Vector3(0.25, -0.23, -0.65), 0.09)

func _spawn_tracer(from: Vector3, to: Vector3, color: Color) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var length: float = from.distance_to(to)
	if length <= 0.01:
		return
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.018, length)
	tracer.mesh = mesh
	tracer.global_position = (from + to) * 0.5
	tracer.look_at(to, Vector3.UP)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 8.0
	tracer.material_override = mat
	get_tree().current_scene.add_child(tracer)
	var tween := create_tween()
	tween.tween_property(tracer, "scale", Vector3(1.0, 1.0, 0.15), 0.055)
	tween.tween_callback(tracer.queue_free)

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
	if _loadout.try_reload():
		_audio_call("play_reload")

func grant_ammo(amount: int) -> void:
	_loadout.grant_ammo(amount)

func take_damage(amount: float) -> void:
	if _health <= 0.0:
		return
	var incoming: float = maxf(0.0, amount)
	if _shield > 0.0:
		var absorbed: float = minf(_shield, incoming)
		_shield -= absorbed
		incoming -= absorbed
		shield_changed.emit(_shield, max_shield)
	if incoming > 0.0:
		_health = maxf(0.0, _health - incoming)
		health_changed.emit(_health, max_health)
	_shield_delay_remaining = shield_regen_delay
	damaged.emit(amount)
	if _health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	_health = minf(max_health, _health + maxf(0.0, amount))
	health_changed.emit(_health, max_health)

func grant_shield(amount: float) -> void:
	_shield = minf(max_shield, _shield + maxf(0.0, amount))
	shield_changed.emit(_shield, max_shield)

func _audio_call(method: StringName, args: Array = []) -> void:
	var audio: Node = get_tree().get_first_node_in_group("neon_audio")
	if audio != null and audio.has_method(method):
		audio.callv(method, args)

func _on_loadout_ammo_changed(current: int, reserve: int) -> void:
	ammo_changed.emit(current, reserve)

func _on_loadout_weapon_changed(definition: WeaponDefinition, slot: int) -> void:
	_refresh_weapon_visual()
	weapon_changed.emit(definition.display_name, slot)

func _emit_status() -> void:
	health_changed.emit(_health, max_health)
	shield_changed.emit(_shield, max_shield)
	_on_loadout_ammo_changed(_loadout.current_ammo(), _loadout.current_reserve())
	var definition: WeaponDefinition = _loadout.current_definition()
	weapon_changed.emit(definition.display_name, _loadout.current_index() + 1)
	face_changed.emit(CubeGravity.face_name(gravity_down))

func get_health() -> float:
	return _health

func get_shield() -> float:
	return _shield

func get_dash_remaining() -> float:
	return _dash_remaining

func get_ammo() -> int:
	return _loadout.current_ammo()

func get_reserve_ammo() -> int:
	return _loadout.current_reserve()

func get_weapon_index() -> int:
	return _loadout.current_index()

func get_weapon_name() -> String:
	var spec: WeaponDefinition = _loadout.current_definition()
	return spec.display_name
