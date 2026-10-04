class_name NeonGame
extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

enum GameState { MENU, PLAYING, PAUSED, VICTORY, GAME_OVER }

@export var cube_size := 60.0
@export var starting_enemies := 6
@export var total_waves := 6

var player: NeonPlayer
var game_state: GameState = GameState.MENU
var difficulty_name := "OPERATIVE"
var difficulty_scale := 1.0
var _score := 0
var _high_score := 0
var _wave := 0
var _alive_enemies := 0
var _spawn_cursor := 0
var _kills := 0
var _wave_transitioning := false

var hud_layer: CanvasLayer
var hud_panel: Control
var menu_panel: Control
var pause_panel: Control
var end_panel: Control
var end_title: Label
var end_details: Label
var health_label: Label
var shield_label: Label
var ammo_label: Label
var weapon_label: Label
var face_label: Label
var dash_label: Label
var score_label: Label
var objective_label: Label
var message_label: Label
var damage_overlay: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	_load_high_score()
	CyberCityBuilder.build(self, cube_size)
	var audio: NeonAudio = NeonAudio.new()
	audio.name = "NeonAudio"
	add_child(audio)
	_create_ui()
	if DisplayServer.get_name() == "headless":
		start_game()
	else:
		_show_menu()

func _process(_delta: float) -> void:
	if game_state != GameState.PLAYING:
		return
	if is_instance_valid(player) and dash_label != null:
		var dash_remaining: float = player.get_dash_remaining()
		dash_label.text = "DASH READY" if dash_remaining <= 0.0 else "DASH %.1fs" % dash_remaining
	if _alive_enemies <= 0 and not _wave_transitioning:
		_finish_wave()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if game_state == GameState.PLAYING:
			_pause_game()
		elif game_state == GameState.PAUSED:
			_resume_game()

func _start_with_difficulty(name: String, scale: float) -> void:
	difficulty_name = name
	difficulty_scale = scale
	start_game()

func start_game() -> void:
	get_tree().paused = false
	_clear_runtime_entities()
	_score = 0
	_wave = 1
	_alive_enemies = 0
	_spawn_cursor = 0
	_kills = 0
	_wave_transitioning = false
	game_state = GameState.PLAYING
	menu_panel.visible = false
	pause_panel.visible = false
	end_panel.visible = false
	hud_panel.visible = true
	_create_player()
	_spawn_current_wave()
	_update_score()
	_update_objective()
	_show_message("%s // MISSION START" % difficulty_name, 2.0)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_menu() -> void:
	game_state = GameState.MENU
	hud_panel.visible = false
	menu_panel.visible = true
	pause_panel.visible = false
	end_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _pause_game() -> void:
	game_state = GameState.PAUSED
	pause_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume_game() -> void:
	get_tree().paused = false
	game_state = GameState.PLAYING
	pause_panel.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _finish_game(victory: bool) -> void:
	if victory:
		game_state = GameState.VICTORY
		_audio_call("play_victory")
		end_title.text = "CUBE BREACHED"
	else:
		game_state = GameState.GAME_OVER
		_audio_call("play_defeat")
		end_title.text = "SIGNAL LOST"
	_high_score = maxi(_high_score, _score)
	_save_high_score()
	end_details.text = "%s\nSCORE %06d\nHIGH SCORE %06d\nWAVES CLEARED %d / %d" % [difficulty_name, _score, _high_score, mini(_wave, total_waves), total_waves]
	end_panel.visible = true
	hud_panel.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _finish_wave() -> void:
	_wave_transitioning = true
	if _wave >= total_waves:
		_finish_game(true)
		return
	_show_message("WAVE %02d CLEARED" % _wave, 1.25)
	var completed_wave: int = _wave
	_spawn_reward_pickups(completed_wave)
	var timer: SceneTreeTimer = get_tree().create_timer(1.8)
	timer.timeout.connect(_advance_wave)

func _advance_wave() -> void:
	if game_state != GameState.PLAYING:
		return
	_wave += 1
	_wave_transitioning = false
	_spawn_current_wave()
	_update_score()
	_update_objective()
	if _wave == total_waves:
		_show_message("FINAL WAVE // NULL WARDEN ONLINE", 2.0)
	else:
		_show_message("WAVE %02d // INCOMING" % _wave, 1.5)

func wave_plan(wave_number: int) -> Array[String]:
	var plan: Array[String] = []
	match wave_number:
		1:
			for i in range(starting_enemies): plan.append("grunt")
		2:
			for i in range(5): plan.append("grunt")
			for i in range(3): plan.append("runner")
		3:
			for i in range(4): plan.append("grunt")
			for i in range(3): plan.append("runner")
			for i in range(2): plan.append("sniper")
		4:
			for i in range(4): plan.append("grunt")
			for i in range(3): plan.append("runner")
			for i in range(3): plan.append("sniper")
			for i in range(2): plan.append("tank")
		5:
			for i in range(4): plan.append("grunt")
			for i in range(4): plan.append("runner")
			for i in range(3): plan.append("sniper")
			for i in range(3): plan.append("tank")
		_:
			plan.append("boss")
			for i in range(3): plan.append("runner")
			for i in range(3): plan.append("sniper")
			for i in range(2): plan.append("tank")
	return plan

func _spawn_current_wave() -> void:
	var plan: Array[String] = wave_plan(_wave)
	_alive_enemies = 0
	for i in range(plan.size()):
		_spawn_enemy(plan[i], i)

func _spawn_enemy(kind: String, index: int) -> void:
	if not is_instance_valid(player):
		return
	var enemy: NeonEnemy = ENEMY_SCENE.instantiate() as NeonEnemy
	enemy.cube_half_extent = cube_size * 0.5
	enemy.target = player
	enemy.configure(kind, _wave, difficulty_scale)
	enemy.position = _spawn_position(index + _spawn_cursor)
	enemy.killed.connect(_on_enemy_killed)
	add_child(enemy)
	_alive_enemies += 1
	_spawn_cursor += 1

func _spawn_position(index: int) -> Vector3:
	var half: float = cube_size * 0.5
	var faces: Array = CubeGravity.AXIS_DOWNS
	var down: Vector3 = faces[index % faces.size()]
	var basis: Basis = CubeGravity.tangent_basis(down)
	var right: Vector3 = basis.x
	var inward: Vector3 = basis.y
	var forward: Vector3 = -basis.z
	var u: float = -20.0 + float((index * 11) % 40)
	var v: float = -20.0 + float((index * 17 + 9) % 40)
	if absf(u) < 5.0: u += 7.0
	if absf(v) < 5.0: v -= 7.0
	return down * (half - 1.35) + right * u + forward * v + inward * 0.15

func _spawn_reward_pickups(completed_wave: int) -> void:
	if not is_instance_valid(player):
		return
	var position_a: Vector3 = player.global_position - player.gravity_down * 0.45 + player.global_transform.basis.x * 2.0
	var position_b: Vector3 = player.global_position - player.gravity_down * 0.45 - player.global_transform.basis.x * 2.0
	_spawn_pickup(position_a, "health", 20.0 + float(completed_wave * 2))
	_spawn_pickup(position_b, "ammo", 30.0 + float(completed_wave * 4))
	if completed_wave >= 3:
		_spawn_pickup(player.global_position - player.gravity_down * 0.45 + player.global_transform.basis.z * 2.2, "shield", 18.0)

func _spawn_pickup(world_position: Vector3, kind: String, amount: float) -> void:
	var pickup: NeonPickup = PICKUP_SCENE.instantiate() as NeonPickup
	pickup.configure(kind, amount)
	pickup.position = world_position
	add_child(pickup)

func _on_enemy_killed(enemy: NeonEnemy) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)
	_kills += 1
	_score += enemy.get_score_value()
	if _kills % 4 == 0:
		var drop_kind := "health" if (_kills / 4) % 2 == 0 else "ammo"
		_spawn_pickup(enemy.global_position, drop_kind, 24.0)
	_audio_call("play_enemy_down")
	_update_score()
	_update_objective()

func _create_player() -> void:
	player = PLAYER_SCENE.instantiate() as NeonPlayer
	player.cube_half_extent = cube_size * 0.5
	add_child(player)
	player.global_position = Vector3(0, -cube_size * 0.5 + 1.5, 0)
	player.health_changed.connect(_on_health_changed)
	player.shield_changed.connect(_on_shield_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.face_changed.connect(_on_face_changed)
	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)
	_on_health_changed(player.get_health(), player.max_health)
	_on_shield_changed(player.get_shield(), player.max_shield)
	_on_ammo_changed(player.get_ammo(), player.get_reserve_ammo())
	_on_weapon_changed(player.get_weapon_name(), player.get_weapon_index() + 1)
	_on_face_changed(CubeGravity.face_name(Vector3.DOWN))

func _clear_runtime_entities() -> void:
	for node in get_tree().get_nodes_in_group("enemies"): node.queue_free()
	for node in get_tree().get_nodes_in_group("pickups"): node.queue_free()
	if is_instance_valid(player): player.queue_free()
	player = null

func _on_player_died() -> void:
	if game_state == GameState.PLAYING: _finish_game(false)

func _ensure_input_actions() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("reload", KEY_R)
	_bind_key("weapon_1", KEY_1)
	_bind_key("weapon_2", KEY_2)
	_bind_key("weapon_3", KEY_3)
	_bind_key("dash", KEY_SHIFT)
	_bind_key("pause_game", KEY_ESCAPE)
	if not InputMap.has_action("fire"): InputMap.add_action("fire")
	if InputMap.action_get_events("fire").is_empty():
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mouse)

func _bind_key(action: StringName, key: int) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _create_ui() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud_layer)
	hud_panel = Control.new()
	hud_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(hud_panel)

	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.005, 0.008, 0.02, 0.78)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(430, 196)
	hud_panel.add_child(panel)

	health_label = _make_label(Vector2(36, 30), 20, Color(0.1, 1.0, 0.85))
	shield_label = _make_label(Vector2(36, 58), 18, Color(0.2, 0.65, 1.0))
	ammo_label = _make_label(Vector2(36, 84), 20, Color(1.0, 0.12, 0.7))
	weapon_label = _make_label(Vector2(36, 112), 17, Color(1.0, 0.75, 0.2))
	face_label = _make_label(Vector2(36, 138), 15, Color(0.45, 0.72, 1.0))
	dash_label = _make_label(Vector2(36, 162), 15, Color(0.7, 1.0, 0.5))
	score_label = _make_label(Vector2(990, 28), 20, Color(1.0, 0.85, 0.2))
	objective_label = _make_label(Vector2(980, 60), 16, Color(0.25, 1.0, 0.95))
	for label in [health_label, shield_label, ammo_label, weapon_label, face_label, dash_label, score_label, objective_label]:
		hud_panel.add_child(label)

	var crosshair: Label = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.add_theme_color_override("font_color", Color(0.1, 1.0, 0.95))
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-9, -18)
	hud_panel.add_child(crosshair)

	damage_overlay = ColorRect.new()
	damage_overlay.color = Color(1.0, 0.02, 0.15, 0.0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_panel.add_child(damage_overlay)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 30)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.14, 0.75))
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-300, 38)
	message_label.size = Vector2(600, 52)
	hud_panel.add_child(message_label)

	menu_panel = _create_full_overlay(Color(0.006, 0.005, 0.025, 0.94))
	_add_center_label(menu_panel, "NEON CUBE", Vector2(0, -190), 54, Color(0.1, 0.95, 1.0))
	_add_center_label(menu_panel, "Six faces. One gravity core. Survive the city.", Vector2(0, -128), 18, Color(1.0, 0.25, 0.75))
	_add_center_button(menu_panel, "ROOKIE", Vector2(-260, -24), _start_with_difficulty.bind("ROOKIE", 0.78))
	_add_center_button(menu_panel, "OPERATIVE", Vector2(0, -24), _start_with_difficulty.bind("OPERATIVE", 1.0))
	_add_center_button(menu_panel, "NIGHTMARE", Vector2(260, -24), _start_with_difficulty.bind("NIGHTMARE", 1.28))
	_add_center_label(menu_panel, "Choose difficulty", Vector2(0, -72), 15, Color(0.7, 0.78, 0.95))
	_add_center_label(menu_panel, "WASD move  •  Mouse aim  •  Space jump  •  Shift dash\n1/2/3 weapons  •  R reload  •  Esc pause", Vector2(0, 92), 16, Color(0.7, 0.78, 0.95))
	_add_center_label(menu_panel, "HIGH SCORE %06d" % _high_score, Vector2(0, 170), 16, Color(1.0, 0.8, 0.2))

	pause_panel = _create_full_overlay(Color(0.003, 0.004, 0.015, 0.86))
	_add_center_label(pause_panel, "PAUSED", Vector2(0, -80), 44, Color(0.1, 0.95, 1.0))
	_add_center_button(pause_panel, "RESUME", Vector2(0, 5), _resume_game)
	_add_center_button(pause_panel, "RESTART RUN", Vector2(0, 65), start_game)
	_add_center_button(pause_panel, "MAIN MENU", Vector2(0, 125), _show_menu)

	end_panel = _create_full_overlay(Color(0.004, 0.003, 0.018, 0.92))
	end_title = _add_center_label(end_panel, "", Vector2(0, -130), 48, Color(1.0, 0.18, 0.72))
	end_details = _add_center_label(end_panel, "", Vector2(0, -42), 19, Color(0.65, 0.95, 1.0))
	_add_center_button(end_panel, "RUN AGAIN", Vector2(0, 86), start_game)
	_add_center_button(end_panel, "MAIN MENU", Vector2(0, 146), _show_menu)

	menu_panel.visible = false
	pause_panel.visible = false
	end_panel.visible = false
	hud_panel.visible = false

func _create_full_overlay(color: Color) -> Control:
	var root: ColorRect = ColorRect.new()
	root.color = color
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(root)
	return root

func _add_center_label(parent: Control, text: String, offset: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(-360, -28) + offset
	label.size = Vector2(720, 90)
	parent.add_child(label)
	return label

func _add_center_button(parent: Control, text: String, offset: Vector2, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 48)
	button.set_anchors_preset(Control.PRESET_CENTER)
	button.position = Vector2(-110, -24) + offset
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _on_health_changed(current: float, maximum: float) -> void:
	if health_label != null: health_label.text = "HP  %03d / %03d" % [int(current), int(maximum)]

func _on_shield_changed(current: float, maximum: float) -> void:
	if shield_label != null: shield_label.text = "SHIELD  %03d / %03d" % [int(current), int(maximum)]

func _on_ammo_changed(current: int, reserve: int) -> void:
	if ammo_label != null: ammo_label.text = "AMMO  %02d / %03d" % [current, reserve]

func _on_weapon_changed(weapon_name: String, slot: int) -> void:
	if weapon_label != null: weapon_label.text = "WEAPON %d  //  %s" % [slot, weapon_name]

func _on_face_changed(face_name: String) -> void:
	if face_label != null: face_label.text = "GRAVITY  %s" % face_name

func _on_player_damaged(_amount: float) -> void:
	if damage_overlay == null: return
	damage_overlay.color.a = 0.22
	var tween: Tween = create_tween()
	tween.tween_property(damage_overlay, "color:a", 0.0, 0.24)

func _update_score() -> void:
	if score_label != null: score_label.text = "SCORE %06d   WAVE %02d/%02d" % [_score, _wave, total_waves]

func _update_objective() -> void:
	if objective_label != null: objective_label.text = "HOSTILES %02d" % _alive_enemies

func _show_message(text: String, duration: float) -> void:
	if message_label == null: return
	message_label.text = text
	var visible_color: Color = message_label.modulate
	visible_color.a = 1.0
	message_label.modulate = visible_color
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(duration)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.4)

func _audio_call(method: StringName) -> void:
	var audio: Node = get_tree().get_first_node_in_group("neon_audio")
	if audio != null and audio.has_method(method): audio.call(method)

func _load_high_score() -> void:
	if not FileAccess.file_exists("user://neon_cube_save.json"): return
	var file: FileAccess = FileAccess.open("user://neon_cube_save.json", FileAccess.READ)
	if file == null: return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var data: Dictionary = parsed as Dictionary
		_high_score = int(data.get("high_score", 0))

func _save_high_score() -> void:
	var file: FileAccess = FileAccess.open("user://neon_cube_save.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"high_score": _high_score}))
