class_name NeonGame
extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PICKUP_SCENE := preload("res://scenes/pickup.tscn")
const MISSION_BLOCKOUT_SCENE := preload("res://scenes/missions/neon_market_siege_blockout.tscn")

enum GameState { MENU, PLAYING, PAUSED, VICTORY, GAME_OVER }

@export var cube_size := 60.0
@export var starting_enemies := 6
@export var total_waves := 6
@export var story_mode := true

var player: NeonPlayer
var campaign: CampaignDefinition = CampaignCatalog.primary()
var mission_definition: MissionDefinition = MissionCatalog.primary()
var mission_runtime: MissionRuntime = MissionRuntime.new()
var mission_level: Node3D
var mission_anchors: Dictionary = {}
var session: GameSession = GameSession.new()
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
var settings_panel: Control
var credits_panel: Control
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
var boss_label: Label
var boss_bar: ProgressBar
var message_label: Label
var damage_overlay: ColorRect
var continue_button: Button

var _mouse_sensitivity_setting := 0.0022
var _master_volume_db := -6.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	_load_high_score()
	if story_mode:
		total_waves = mission_definition.encounter_count()
		starting_enemies = mission_definition.get_encounter(0).enemy_kinds.size()
	else:
		total_waves = campaign.wave_count()
		starting_enemies = campaign.get_wave(0).enemy_kinds.size()
	CyberCityBuilder.build(self, cube_size)
	mission_level = MISSION_BLOCKOUT_SCENE.instantiate() as Node3D
	add_child(mission_level)
	mission_anchors = MissionAnchorRegistry.collect(mission_level)
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
	if story_mode:
		mission_runtime.start(mission_definition)
		MissionProgressStore.clear()
	session.reset_run(difficulty_name, difficulty_scale)
	_sync_session_fields()
	_spawn_cursor = 0
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
	session.set_state(GameSession.State.MENU)
	game_state = GameState.MENU
	hud_panel.visible = false
	menu_panel.visible = true
	pause_panel.visible = false
	end_panel.visible = false
	if continue_button != null:
		continue_button.visible = story_mode and MissionProgressStore.has_progress(mission_definition)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _pause_game() -> void:
	session.set_state(GameSession.State.PAUSED)
	game_state = GameState.PAUSED
	pause_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume_game() -> void:
	get_tree().paused = false
	session.set_state(GameSession.State.PLAYING)
	game_state = GameState.PLAYING
	pause_panel.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _finish_game(victory: bool) -> void:
	if victory:
		session.set_state(GameSession.State.VICTORY)
		game_state = GameState.VICTORY
		_audio_call("play_victory")
		end_title.text = "CUBE BREACHED"
	else:
		session.set_state(GameSession.State.GAME_OVER)
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
	if story_mode:
		var encounter := mission_runtime.current_encounter()
		_spawn_encounter_rewards(encounter)
		mission_runtime.complete_current_encounter()
		MissionProgressStore.save_runtime(mission_runtime, session)
		if mission_runtime.state == MissionRuntime.State.COMPLETED:
			_finish_game(true)
			return
		var timer := get_tree().create_timer(1.8)
		timer.timeout.connect(_advance_wave)
		return

	if session.is_last_wave(campaign):
		_finish_game(true)
		return
	var current_wave: WaveDefinition = campaign.get_wave(session.wave_index)
	_show_message("WAVE %02d CLEARED" % session.current_wave_number(), 1.25)
	_spawn_reward_pickups(session.wave_index)
	var timer: SceneTreeTimer = get_tree().create_timer(current_wave.intermission_seconds)
	timer.timeout.connect(_advance_wave)

func _advance_wave() -> void:
	if game_state != GameState.PLAYING:
		return
	session.advance_wave()
	_sync_session_fields()
	_wave_transitioning = false
	_spawn_current_wave()
	_update_score()
	_update_objective()
	if story_mode:
		var encounter := mission_runtime.current_encounter()
		_show_message("%s // %s" % [encounter.title, encounter.objective_text], 2.0)
		return
	var wave: WaveDefinition = campaign.get_wave(session.wave_index)
	if wave.boss_wave:
		_show_message("FINAL WAVE // %s ONLINE" % wave.title, 2.0)
	else:
		_show_message("WAVE %02d // %s" % [session.current_wave_number(), wave.title], 1.5)

func wave_plan(wave_number: int) -> Array[String]:
	var result: Array[String] = []
	var wave: WaveDefinition = campaign.get_wave(wave_number - 1)
	if wave == null:
		return result
	for kind in wave.enemy_kinds:
		result.append(String(kind))
	return result

func _spawn_current_wave() -> void:
	session.alive_enemies = 0
	_sync_session_fields()

	if story_mode:
		var encounter := mission_runtime.current_encounter()
		if encounter == null:
			return
		var center_anchor := MissionAnchorRegistry.find_for_encounter(
			mission_anchors,
			encounter.encounter_id,
			MissionAnchor.Kind.ENCOUNTER_CENTER
		)
		var positions: Array[Vector3]
		if center_anchor != null:
			positions = EncounterSpawnPlanner.spawn_positions_around(
				encounter,
				encounter.enemy_kinds.size(),
				cube_size,
				center_anchor.global_position,
				_spawn_cursor
			)
		else:
			positions = EncounterSpawnPlanner.spawn_positions(
				encounter,
				encounter.enemy_kinds.size(),
				cube_size,
				_spawn_cursor
			)
		for i in range(encounter.enemy_kinds.size()):
			_spawn_enemy_at(String(encounter.enemy_kinds[i]), positions[i])
		return

	var plan: Array[String] = wave_plan(session.current_wave_number())
	for i in range(plan.size()):
		_spawn_enemy(plan[i], i)

func _spawn_enemy(kind: String, index: int) -> void:
	_spawn_enemy_at(kind, _spawn_position(index + _spawn_cursor))

func _spawn_enemy_at(kind: String, world_position: Vector3) -> void:
	if not is_instance_valid(player):
		return
	var enemy: NeonEnemy = ENEMY_SCENE.instantiate() as NeonEnemy
	enemy.cube_half_extent = cube_size * 0.5
	enemy.target = player
	enemy.configure(kind, session.current_wave_number(), session.difficulty_scale)
	enemy.position = world_position
	enemy.killed.connect(_on_enemy_killed)
	if kind == "boss":
		enemy.health_changed.connect(_on_boss_health_changed)
	add_child(enemy)
	session.add_enemy()
	_sync_session_fields()
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

func _spawn_reward_pickups(completed_wave_index: int) -> void:
	if not is_instance_valid(player):
		return
	var wave: WaveDefinition = campaign.get_wave(completed_wave_index)
	if wave == null:
		return
	var position_a: Vector3 = player.global_position - player.gravity_down * 0.45 + player.global_transform.basis.x * 2.0
	var position_b: Vector3 = player.global_position - player.gravity_down * 0.45 - player.global_transform.basis.x * 2.0
	if wave.reward_health > 0.0:
		_spawn_pickup(position_a, "health", wave.reward_health)
	if wave.reward_ammo > 0:
		_spawn_pickup(position_b, "ammo", float(wave.reward_ammo))
	if wave.reward_shield > 0.0:
		_spawn_pickup(player.global_position - player.gravity_down * 0.45 + player.global_transform.basis.z * 2.2, "shield", wave.reward_shield)

func _spawn_encounter_rewards(encounter: EncounterDefinition) -> void:
	if encounter == null or not is_instance_valid(player):
		return
	var position_a := player.global_position - player.gravity_down * 0.45 + player.global_transform.basis.x * 2.0
	var position_b := player.global_position - player.gravity_down * 0.45 - player.global_transform.basis.x * 2.0
	if encounter.reward_health > 0.0:
		_spawn_pickup(position_a, "health", encounter.reward_health)
	if encounter.reward_ammo > 0:
		_spawn_pickup(position_b, "ammo", float(encounter.reward_ammo))
	if encounter.reward_shield > 0.0:
		_spawn_pickup(
			player.global_position - player.gravity_down * 0.45 + player.global_transform.basis.z * 2.2,
			"shield",
			encounter.reward_shield
		)

func _spawn_pickup(world_position: Vector3, kind: String, amount: float) -> void:
	var pickup: NeonPickup = PICKUP_SCENE.instantiate() as NeonPickup
	pickup.configure(kind, amount)
	pickup.position = world_position
	add_child(pickup)

func _on_enemy_killed(enemy: NeonEnemy) -> void:
	session.register_kill(enemy.get_score_value())
	_sync_session_fields()
	if enemy.archetype == "boss" and boss_bar != null:
		boss_bar.visible = false
		boss_label.visible = false
	if _kills % 4 == 0:
		var drop_kind := "health" if (_kills / 4) % 2 == 0 else "ammo"
		_spawn_pickup(enemy.global_position, drop_kind, 24.0)
	_audio_call("play_enemy_down")
	_update_score()
	_update_objective()

func _create_player() -> void:
	player = PLAYER_SCENE.instantiate() as NeonPlayer
	player.cube_half_extent = cube_size * 0.5
	player.mouse_sensitivity = _mouse_sensitivity_setting
	add_child(player)
	if story_mode and mission_anchors.has("player_start"):
		var start_anchor: MissionAnchor = mission_anchors["player_start"]
		player.global_position = start_anchor.global_position
	else:
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
	if game_state != GameState.PLAYING:
		return
	if story_mode:
		mission_runtime.fail()
	_finish_game(false)

func _continue_story() -> void:
	_resume_story_from_save()

func _restart_story_checkpoint() -> void:
	_resume_story_from_save()

func _resume_story_from_save() -> void:
	get_tree().paused = false
	_clear_runtime_entities()
	var restored := MissionProgressStore.load_into(mission_runtime, mission_definition, session)
	if not restored:
		start_game()
		return
	if mission_runtime.state == MissionRuntime.State.COMPLETED:
		start_game()
		return
	mission_runtime.restart_from_checkpoint()
	session.set_state(GameSession.State.PLAYING)
	session.wave_index = mission_runtime.encounter_index
	session.alive_enemies = 0
	_sync_session_fields()
	_spawn_cursor = mission_runtime.encounter_index * 8
	_wave_transitioning = false
	game_state = GameState.PLAYING
	menu_panel.visible = false
	pause_panel.visible = false
	end_panel.visible = false
	hud_panel.visible = true
	_create_player()
	if mission_runtime.checkpoint_id != &"":
		var checkpoint_key := String(mission_runtime.checkpoint_id)
		if mission_anchors.has(checkpoint_key):
			var checkpoint_anchor: MissionAnchor = mission_anchors[checkpoint_key]
			player.global_position = checkpoint_anchor.global_position
	_spawn_current_wave()
	_update_score()
	_update_objective()
	_show_message("CHECKPOINT // %s" % mission_runtime.current_encounter().title, 1.8)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

	boss_label = _make_label(Vector2(440, 94), 16, Color(1.0, 0.18, 0.72))
	boss_label.size = Vector2(400, 24)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_panel.add_child(boss_label)
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(440, 120)
	boss_bar.size = Vector2(400, 16)
	boss_bar.show_percentage = false
	hud_panel.add_child(boss_bar)
	boss_label.visible = false
	boss_bar.visible = false

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
	continue_button = _add_center_button(menu_panel, "CONTINUE STORY", Vector2(0, 154), _continue_story)
	continue_button.visible = false
	_add_center_label(menu_panel, "HIGH SCORE %06d" % _high_score, Vector2(0, 202), 16, Color(1.0, 0.8, 0.2))
	_add_center_button(menu_panel, "SETTINGS", Vector2(-240, 248), _show_settings)
	_add_center_button(menu_panel, "CREDITS", Vector2(0, 248), _show_credits)
	_add_center_button(menu_panel, "QUIT", Vector2(240, 248), _quit_game)

	pause_panel = _create_full_overlay(Color(0.003, 0.004, 0.015, 0.86))
	_add_center_label(pause_panel, "PAUSED", Vector2(0, -80), 44, Color(0.1, 0.95, 1.0))
	_add_center_button(pause_panel, "RESUME", Vector2(0, 5), _resume_game)
	_add_center_button(pause_panel, "RESTART RUN", Vector2(0, 65), start_game)
	_add_center_button(pause_panel, "MAIN MENU", Vector2(0, 125), _show_menu)
	_add_center_button(pause_panel, "SETTINGS", Vector2(0, 185), _show_settings)

	settings_panel = _create_full_overlay(Color(0.004, 0.006, 0.022, 0.96))
	_add_center_label(settings_panel, "SETTINGS", Vector2(0, -175), 42, Color(0.1, 0.95, 1.0))
	_add_center_label(settings_panel, "MOUSE SENSITIVITY", Vector2(-190, -78), 16, Color(0.75, 0.82, 1.0))
	var sensitivity_slider := HSlider.new()
	sensitivity_slider.min_value = 0.0008
	sensitivity_slider.max_value = 0.0050
	sensitivity_slider.step = 0.0001
	sensitivity_slider.value = _mouse_sensitivity_setting
	sensitivity_slider.position = Vector2(630, 248)
	sensitivity_slider.size = Vector2(300, 32)
	sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	settings_panel.add_child(sensitivity_slider)
	_add_center_label(settings_panel, "MASTER VOLUME", Vector2(-190, -18), 16, Color(0.75, 0.82, 1.0))
	var volume_slider := HSlider.new()
	volume_slider.min_value = -30.0
	volume_slider.max_value = 0.0
	volume_slider.step = 1.0
	volume_slider.value = _master_volume_db
	volume_slider.position = Vector2(630, 308)
	volume_slider.size = Vector2(300, 32)
	volume_slider.value_changed.connect(_on_master_volume_changed)
	settings_panel.add_child(volume_slider)
	_add_center_button(settings_panel, "BACK", Vector2(0, 112), _close_aux_panel)

	credits_panel = _create_full_overlay(Color(0.004, 0.006, 0.022, 0.97))
	_add_center_label(credits_panel, "CREDITS", Vector2(0, -185), 42, Color(1.0, 0.18, 0.72))
	_add_center_label(credits_panel, "DESIGN / CODE\nNeon Cube Project\n\n3D ASSETS\nKenney — Blaster Kit (CC0)\nQuaternius — Cyberpunk Game Kit (CC0)\n\nENGINE\nGodot 4.x", Vector2(0, -62), 18, Color(0.75, 0.9, 1.0))
	_add_center_button(credits_panel, "BACK", Vector2(0, 180), _close_aux_panel)

	end_panel = _create_full_overlay(Color(0.004, 0.003, 0.018, 0.92))
	end_title = _add_center_label(end_panel, "", Vector2(0, -130), 48, Color(1.0, 0.18, 0.72))
	end_details = _add_center_label(end_panel, "", Vector2(0, -42), 19, Color(0.65, 0.95, 1.0))
	_add_center_button(end_panel, "RUN AGAIN", Vector2(0, 86), start_game)
	_add_center_button(end_panel, "RESTART CHECKPOINT", Vector2(0, 146), _restart_story_checkpoint)
	_add_center_button(end_panel, "MAIN MENU", Vector2(0, 206), _show_menu)

	menu_panel.visible = false
	pause_panel.visible = false
	settings_panel.visible = false
	credits_panel.visible = false
	end_panel.visible = false
	hud_panel.visible = false

func _show_settings() -> void:
	menu_panel.visible = false
	pause_panel.visible = false
	settings_panel.visible = true
	credits_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _show_credits() -> void:
	menu_panel.visible = false
	pause_panel.visible = false
	settings_panel.visible = false
	credits_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_aux_panel() -> void:
	settings_panel.visible = false
	credits_panel.visible = false
	if game_state == GameState.PAUSED:
		pause_panel.visible = true
	else:
		menu_panel.visible = true

func _on_mouse_sensitivity_changed(value: float) -> void:
	_mouse_sensitivity_setting = clampf(value, 0.0008, 0.0050)
	if is_instance_valid(player):
		player.mouse_sensitivity = _mouse_sensitivity_setting
	_save_high_score()

func _on_master_volume_changed(value: float) -> void:
	_master_volume_db = clampf(value, -30.0, 0.0)
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_volume_db(master_index, _master_volume_db)
	_save_high_score()

func _quit_game() -> void:
	get_tree().quit()

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
	if score_label != null:
		score_label.text = "SCORE %06d   WAVE %02d/%02d" % [session.score, session.current_wave_number(), total_waves]

func _update_objective() -> void:
	if objective_label != null: objective_label.text = "HOSTILES %02d" % session.alive_enemies

func _sync_session_fields() -> void:
	_score = session.score
	_wave = session.current_wave_number()
	_alive_enemies = session.alive_enemies
	_kills = session.kills
	difficulty_name = session.difficulty_name
	difficulty_scale = session.difficulty_scale


func _on_boss_health_changed(current: float, maximum: float, phase: int) -> void:
	if boss_bar == null or boss_label == null:
		return
	boss_bar.visible = true
	boss_label.visible = true
	boss_bar.max_value = maximum
	boss_bar.value = current
	boss_label.text = "NULL WARDEN  //  PHASE %d  //  %03d / %03d" % [phase, int(current), int(maximum)]

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
	var profile := ProfileStore.load_profile()
	_high_score = int(profile["high_score"])
	_mouse_sensitivity_setting = float(profile["mouse_sensitivity"])
	_master_volume_db = float(profile["master_volume_db"])
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_volume_db(master_index, _master_volume_db)

func _save_high_score() -> void:
	var profile := ProfileStore.load_profile()
	profile["high_score"] = _high_score
	profile["mouse_sensitivity"] = _mouse_sensitivity_setting
	profile["master_volume_db"] = _master_volume_db
	var error := ProfileStore.save_profile(profile)
	if error != OK:
		push_warning("Could not save profile: %s" % error_string(error))


func get_mouse_sensitivity_setting() -> float:
	return _mouse_sensitivity_setting

func get_master_volume_db() -> float:
	return _master_volume_db
