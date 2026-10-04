extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

@export var cube_size := 60.0
@export var starting_enemies := 8
@export var max_enemies := 18

var player: NeonPlayer
var _score := 0
var _wave := 1
var _alive_enemies := 0
var _respawn_timer := 0.0
var _spawn_cursor := 0

var health_label: Label
var ammo_label: Label
var face_label: Label
var score_label: Label
var message_label: Label

func _ready() -> void:
	_ensure_input_actions()
	CyberCityBuilder.build(self, cube_size)
	_create_player()
	_create_hud()
	_spawn_wave(starting_enemies)

func _process(delta: float) -> void:
	_respawn_timer = maxf(0.0, _respawn_timer - delta)
	if _alive_enemies <= 0 and _respawn_timer <= 0.0 and is_instance_valid(player):
		_wave += 1
		_respawn_timer = 1.8
		_show_message("WAVE %02d // INCOMING" % _wave, 1.5)
		var count := mini(max_enemies, starting_enemies + (_wave - 1) * 2)
		var timer := get_tree().create_timer(1.5)
		timer.timeout.connect(func(): _spawn_wave(count))

func _ensure_input_actions() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("reload", KEY_R)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	if InputMap.action_get_events("fire").is_empty():
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mouse)

func _bind_key(action: StringName, key: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _create_player() -> void:
	player = PLAYER_SCENE.instantiate() as NeonPlayer
	player.cube_half_extent = cube_size * 0.5
	add_child(player)
	player.global_position = Vector3(0, -cube_size * 0.5 + 1.5, 0)
	player.health_changed.connect(_on_health_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.face_changed.connect(_on_face_changed)
	player.died.connect(_on_player_died)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := ColorRect.new()
	panel.color = Color(0.005, 0.008, 0.02, 0.72)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(360, 116)
	layer.add_child(panel)

	health_label = _make_label(Vector2(36, 30), 20, Color(0.1, 1.0, 0.85))
	ammo_label = _make_label(Vector2(36, 58), 20, Color(1.0, 0.12, 0.7))
	face_label = _make_label(Vector2(36, 86), 16, Color(0.45, 0.72, 1.0))
	score_label = _make_label(Vector2(1040, 28), 20, Color(1.0, 0.85, 0.2))
	for label in [health_label, ammo_label, face_label, score_label]:
		layer.add_child(label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.add_theme_color_override("font_color", Color(0.1, 1.0, 0.95))
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-8, -18)
	layer.add_child(crosshair)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 30)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.14, 0.75))
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-260, 38)
	message_label.size = Vector2(520, 48)
	layer.add_child(message_label)

	_on_health_changed(player.get_health(), player.max_health)
	_on_ammo_changed(player.get_ammo(), player.get_reserve_ammo())
	_on_face_changed(CubeGravity.face_name(Vector3.DOWN))
	_update_score()
	_show_message("NEON CUBE // GRAVITY ONLINE", 2.3)

func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _spawn_wave(count: int) -> void:
	if not is_instance_valid(player):
		return
	for i in range(count):
		_spawn_enemy(i)

func _spawn_enemy(index: int) -> void:
	var enemy := ENEMY_SCENE.instantiate() as NeonEnemy
	enemy.cube_half_extent = cube_size * 0.5
	enemy.target = player
	add_child(enemy)
	enemy.global_position = _spawn_position(index + _spawn_cursor)
	enemy.killed.connect(_on_enemy_killed)
	_alive_enemies += 1
	_spawn_cursor += 1

func _spawn_position(index: int) -> Vector3:
	var half := cube_size * 0.5
	var faces := CubeGravity.AXIS_DOWNS
	var down: Vector3 = faces[index % faces.size()]
	var basis := CubeGravity.tangent_basis(down)
	var right := basis.x
	var inward := basis.y
	var forward := -basis.z
	var u := -20.0 + float((index * 11) % 40)
	var v := -20.0 + float((index * 17 + 9) % 40)
	if absf(u) < 5.0:
		u += 7.0
	if absf(v) < 5.0:
		v -= 7.0
	return down * (half - 1.35) + right * u + forward * v + inward * 0.15

func _on_enemy_killed(_enemy: NeonEnemy) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)
	_score += 100
	_update_score()

func _on_health_changed(current: float, maximum: float) -> void:
	if health_label != null:
		health_label.text = "HP  %03d / %03d" % [int(current), int(maximum)]

func _on_ammo_changed(current: int, reserve: int) -> void:
	if ammo_label != null:
		ammo_label.text = "AMMO  %02d / %03d" % [current, reserve]

func _on_face_changed(face_name: String) -> void:
	if face_label != null:
		face_label.text = "GRAVITY  %s" % face_name

func _update_score() -> void:
	if score_label != null:
		score_label.text = "SCORE %06d   WAVE %02d" % [_score, _wave]

func _show_message(text: String, duration: float) -> void:
	if message_label == null:
		return
	message_label.text = text
	var visible_color := message_label.modulate
	visible_color.a = 1.0
	message_label.modulate = visible_color
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.4)

func _on_player_died() -> void:
	_show_message("SIGNAL LOST // REBOOTING", 1.5)
	player.set_physics_process(false)
	var timer := get_tree().create_timer(1.7)
	timer.timeout.connect(_restart_player)

func _restart_player() -> void:
	if is_instance_valid(player):
		player.queue_free()
	_create_player()
	_on_health_changed(player.get_health(), player.max_health)
	_on_ammo_changed(player.get_ammo(), player.get_reserve_ammo())
	_on_face_changed(CubeGravity.face_name(Vector3.DOWN))
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is NeonEnemy:
			node.target = player
