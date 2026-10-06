class_name NeonGame
extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PICKUP_SCENE := preload("res://scenes/pickup.tscn")
const MISSION_LEVEL_SCENE := preload("res://scenes/missions/neon_market_siege.tscn")
const DESKTOP_PERFORMANCE_BUDGET: PerformanceBudget = preload("res://data/performance/desktop_high.tres")

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
var performance_monitor: RuntimePerformanceMonitor
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
var _waiting_for_extraction := false
var _waiting_for_encounter_entry := false
var _last_boss_phase := 1
var _encounter_enemy_kinds: Array[StringName] = []
var _encounter_positions: Array[Vector3] = []
var _encounter_route_points: Array[Vector3] = []
var _encounter_batch_sizes: Array[int] = []
var _encounter_batch_index := 0
var _encounter_spawned_count := 0
var _reinforcement_scheduled := false
var _hold_progress := 0.0
var _hold_completed := false
var _extraction_progress := 0.0

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
	InputBootstrap.ensure_defaults()
	_load_high_score()
	if story_mode:
		total_waves = mission_definition.encounter_count()
		starting_enemies = mission_definition.get_encounter(0).enemy_kinds.size()
	else:
		total_waves = campaign.wave_count()
		starting_enemies = campaign.get_wave(0).enemy_kinds.size()
	CyberCityBuilder.build(self, cube_size)
	mission_level = MISSION_LEVEL_SCENE.instantiate() as Node3D
	add_child(mission_level)
	mission_anchors = MissionAnchorRegistry.collect(mission_level)
	if mission_level.has_signal("extraction_reached"):
		mission_level.connect("extraction_reached", Callable(self, "_on_extraction_reached"))
	if mission_level.has_signal("encounter_zone_entered"):
		mission_level.connect("encounter_zone_entered", Callable(self, "_on_encounter_zone_entered"))
	if mission_level.has_signal("objective_node_destroyed"):
		mission_level.connect("objective_node_destroyed", Callable(self, "_on_objective_node_destroyed"))
	if DisplayServer.get_name() != "headless":
		performance_monitor = RuntimePerformanceMonitor.new()
		performance_monitor.name = "PerformanceMonitor"
		performance_monitor.budget = DESKTOP_PERFORMANCE_BUDGET
		performance_monitor.budget_warning.connect(_on_performance_budget_warning)
		add_child(performance_monitor)
	var audio: NeonAudio = NeonAudio.new()
	audio.name = "NeonAudio"
	add_child(audio)
	_create_ui()
	if DisplayServer.get_name() == "headless":
		start_game()
	else:
		_show_menu()

func _process(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return
	if is_instance_valid(player) and dash_label != null:
		var dash_remaining: float = player.get_dash_remaining()
		dash_label.text = "DASH READY" if dash_remaining <= 0.0 else "DASH %.1fs" % dash_remaining
	if story_mode:
		_update_hold_objective(delta)
		if _waiting_for_extraction:
			_update_extraction_hold(delta)
			return
	if story_mode and _has_pending_reinforcements():
		var encounter := mission_runtime.current_encounter()
		if (
			encounter != null
			and _alive_enemies <= encounter.reinforcement_trigger_remaining
			and not _reinforcement_scheduled
			and not _wave_transitioning
		):
			_schedule_reinforcement(encounter)
		return
	if _alive_enemies <= 0 and not _wave_transitioning:
		if story_mode and not _story_objectives_complete():
			return
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
	_waiting_for_extraction = false
	_waiting_for_encounter_entry = false
	_last_boss_phase = 1
	_clear_encounter_batch_state()
	_hold_progress = 0.0
	_hold_completed = false
	_extraction_progress = 0.0
	_reset_objective_nodes()
	_reset_hold_zones()
	_reset_progression_gates()
	_set_extraction_armed(false)
	_set_encounter_zone_armed(&"", false)
	_set_encounter_lockdown(&"", false)
	game_state = GameState.PLAYING
	menu_panel.visible = false
	pause_panel.visible = false
	end_panel.visible = false
	hud_panel.visible = true
	_create_player()
	_spawn_authored_pickups()
	_spawn_current_wave()
	_update_score()
	_update_objective()
	if story_mode:
		_show_message("%s // %s" % [mission_definition.display_name, mission_runtime.current_encounter().title], 2.0)
	else:
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
	if story_mode:
		end_details.text = "%s\nSCORE %06d\nHIGH SCORE %06d\nENCOUNTERS CLEARED %d / %d" % [
			mission_definition.display_name,
			_score,
			_high_score,
			mini(_wave, total_waves),
			total_waves,
		]
	else:
		end_details.text = "%s\nSCORE %06d\nHIGH SCORE %06d\nWAVES CLEARED %d / %d" % [
			difficulty_name,
			_score,
			_high_score,
			mini(_wave, total_waves),
			total_waves,
		]
	end_panel.visible = true
	hud_panel.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _finish_wave() -> void:
	_wave_transitioning = true
	if story_mode:
		var encounter := mission_runtime.current_encounter()
		_clear_encounter_batch_state()
		if encounter != null:
			_arm_objective_nodes(encounter.encounter_id, false)
			_arm_hold_zone(encounter.encounter_id, false)
			_hold_progress = 0.0
			_set_encounter_lockdown(encounter.encounter_id, false)
			if encounter.encounter_id == &"data_lane":
				_set_progression_gate_open(&"data_lane", true, true)
			if encounter.encounter_id == &"null_warden":
				_set_boss_arena_phase(1)
		if encounter != null and encounter.encounter_id == &"extraction":
			_set_navigation_target(&"")
			_extraction_progress = 0.0
			_waiting_for_extraction = true
			_wave_transitioning = true
			_set_extraction_armed(true)
			_audio_call("play_extraction_ready")
			_show_message("HOSTILES CLEARED // REACH EXTRACTION", 2.0)
			_update_objective()
			return
		_spawn_encounter_rewards(encounter)
		mission_runtime.complete_current_encounter()
		MissionProgressStore.save_runtime(mission_runtime, session)
		if mission_runtime.state == MissionRuntime.State.COMPLETED:
			_finish_game(true)
			return
		var timer := get_tree().create_timer(1.8, false)
		timer.timeout.connect(_advance_wave)
		return

	if session.is_last_wave(campaign):
		_finish_game(true)
		return
	var current_wave: WaveDefinition = campaign.get_wave(session.wave_index)
	_show_message("WAVE %02d CLEARED" % session.current_wave_number(), 1.25)
	_spawn_reward_pickups(session.wave_index)
	var timer: SceneTreeTimer = get_tree().create_timer(current_wave.intermission_seconds, false)
	timer.timeout.connect(_advance_wave)

func _advance_wave() -> void:
	if game_state != GameState.PLAYING:
		return
	session.advance_wave()
	_sync_session_fields()
	if story_mode:
		var encounter := mission_runtime.current_encounter()
		_hold_progress = 0.0
		_hold_completed = false
		_waiting_for_encounter_entry = true
		_wave_transitioning = true
		_set_encounter_zone_armed(encounter.encounter_id, true)
		_set_navigation_target(encounter.encounter_id)
		_update_score()
		_update_objective()
		_show_message("ADVANCE // %s" % encounter.title, 2.0)
		return
	_wave_transitioning = false
	_spawn_current_wave()
	_update_score()
	_update_objective()
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
		_prepare_story_encounter(encounter)
		_spawn_next_story_batch()
		return

	var plan: Array[String] = wave_plan(session.current_wave_number())
	for i in range(plan.size()):
		_spawn_enemy(plan[i], i)


func _prepare_story_encounter(encounter: EncounterDefinition) -> void:
	_clear_encounter_batch_state()
	_encounter_enemy_kinds = encounter.enemy_kinds.duplicate()
	_encounter_batch_sizes = encounter.effective_batch_sizes()

	var center_anchor := MissionAnchorRegistry.find_for_encounter(
		mission_anchors,
		encounter.encounter_id,
		MissionAnchor.Kind.ENCOUNTER_CENTER
	)
	if is_instance_valid(mission_level) and mission_level.has_method("spawn_points_for"):
		var authored_positions: Variant = mission_level.call(
			"spawn_points_for",
			encounter.encounter_id,
			encounter.enemy_kinds.size(),
			0
		)
		if authored_positions is Array:
			for authored_position in authored_positions:
				if authored_position is Vector3:
					_encounter_positions.append(authored_position)

	if _encounter_positions.size() != encounter.enemy_kinds.size():
		_encounter_positions.clear()
		if center_anchor != null:
			_encounter_positions = EncounterSpawnPlanner.spawn_positions_around(
				encounter,
				encounter.enemy_kinds.size(),
				cube_size,
				center_anchor.global_position,
				_spawn_cursor
			)
		else:
			_encounter_positions = EncounterSpawnPlanner.spawn_positions(
				encounter,
				encounter.enemy_kinds.size(),
				cube_size,
				_spawn_cursor
			)

	if is_instance_valid(mission_level) and mission_level.has_method("route_points_for"):
		var authored_routes: Variant = mission_level.call("route_points_for", encounter.encounter_id)
		if authored_routes is Array:
			for route_point in authored_routes:
				if route_point is Vector3:
					_encounter_route_points.append(route_point)


func _spawn_next_story_batch() -> void:
	if not _has_pending_reinforcements():
		return
	var encounter := mission_runtime.current_encounter()
	var batch_size := _encounter_batch_sizes[_encounter_batch_index]
	var total_count := _encounter_enemy_kinds.size()
	var batch_number := _encounter_batch_index + 1
	for _batch_offset in range(batch_size):
		var enemy_index := _encounter_spawned_count
		if enemy_index >= total_count:
			break
		var leash_radius := 0.0
		if (
			encounter != null
			and is_instance_valid(mission_level)
			and mission_level.has_method("perch_radius_for")
		):
			leash_radius = float(
				mission_level.call("perch_radius_for", encounter.encounter_id, enemy_index)
			)
		_spawn_enemy_at(
			String(_encounter_enemy_kinds[enemy_index]),
			_encounter_positions[enemy_index],
			_encounter_route_points,
			enemy_index,
			total_count,
			leash_radius
		)
		_encounter_spawned_count += 1
	_encounter_batch_index += 1
	if batch_number > 1:
		_show_message(
			"REINFORCEMENTS // BATCH %d/%d" % [batch_number, _encounter_batch_sizes.size()],
			1.35
		)


func _has_pending_reinforcements() -> bool:
	return _encounter_batch_index < _encounter_batch_sizes.size()


func _schedule_reinforcement(encounter: EncounterDefinition) -> void:
	_reinforcement_scheduled = true
	_audio_call("play_reinforcement")
	_show_reinforcement_warning(encounter)
	_show_message("REINFORCEMENTS // INBOUND", maxf(0.45, encounter.reinforcement_delay))
	_update_objective()
	var timer := get_tree().create_timer(encounter.reinforcement_delay, false)
	timer.timeout.connect(_on_reinforcement_ready.bind(encounter.encounter_id))


func _on_reinforcement_ready(encounter_id: StringName) -> void:
	if game_state != GameState.PLAYING or not story_mode:
		_reinforcement_scheduled = false
		return
	var encounter := mission_runtime.current_encounter()
	if encounter == null or encounter.encounter_id != encounter_id:
		_reinforcement_scheduled = false
		return
	_clear_reinforcement_warning()
	_spawn_next_story_batch()
	_reinforcement_scheduled = false
	_update_objective()


func _clear_encounter_batch_state() -> void:
	_clear_reinforcement_warning()
	_encounter_enemy_kinds.clear()
	_encounter_positions.clear()
	_encounter_route_points.clear()
	_encounter_batch_sizes.clear()
	_encounter_batch_index = 0
	_encounter_spawned_count = 0
	_reinforcement_scheduled = false


func _show_reinforcement_warning(encounter: EncounterDefinition) -> void:
	if not is_instance_valid(mission_level) or not mission_level.has_method("show_reinforcement_warning"):
		return
	if not _has_pending_reinforcements():
		return
	var batch_size := _encounter_batch_sizes[_encounter_batch_index]
	var positions: Array[Vector3] = []
	for offset in range(batch_size):
		var index := _encounter_spawned_count + offset
		if index >= 0 and index < _encounter_positions.size():
			positions.append(_encounter_positions[index])
	mission_level.call(
		"show_reinforcement_warning",
		encounter.encounter_id,
		positions,
		encounter.reinforcement_delay
	)


func _clear_reinforcement_warning() -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("clear_reinforcement_warning"):
		mission_level.call("clear_reinforcement_warning")


func current_story_batch_number() -> int:
	return _encounter_batch_index


func current_story_batch_count() -> int:
	return _encounter_batch_sizes.size()
func _spawn_enemy(kind: String, index: int) -> void:
	_spawn_enemy_at(kind, _spawn_position(index + _spawn_cursor))

func _spawn_enemy_at(
	kind: String,
	world_position: Vector3,
	route_points: Array[Vector3] = [],
	tactical_slot_index: int = -1,
	tactical_slot_count: int = 0,
	tactical_leash_radius: float = 0.0
) -> void:
	if not is_instance_valid(player):
		return
	var enemy: NeonEnemy = ENEMY_SCENE.instantiate() as NeonEnemy
	enemy.cube_half_extent = cube_size * 0.5
	enemy.target = player
	enemy.configure(kind, session.current_wave_number(), session.difficulty_scale)
	enemy.set_route_points(route_points)
	enemy.set_tactical_slot(tactical_slot_index, tactical_slot_count)
	enemy.set_tactical_leash(world_position, tactical_leash_radius)
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

func _spawn_pickup(world_position: Vector3, kind: String, amount: float) -> NeonPickup:
	var pickup: NeonPickup = PICKUP_SCENE.instantiate() as NeonPickup
	pickup.configure(kind, amount)
	pickup.position = world_position
	add_child(pickup)
	return pickup


func _spawn_authored_pickups() -> void:
	if not story_mode:
		return
	if not is_instance_valid(mission_level) or not mission_level.has_method("authored_pickup_specs"):
		return
	var specs: Variant = mission_level.call("authored_pickup_specs")
	if not specs is Array:
		return
	for spec_variant in specs:
		if not spec_variant is Dictionary:
			continue
		var spec: Dictionary = spec_variant
		var encounter_id := StringName(spec.get("encounter_id", &""))
		if encounter_id != &"" and mission_runtime.completed_encounters.has(encounter_id):
			continue
		var position: Variant = spec.get("position", Vector3.ZERO)
		if not position is Vector3:
			continue
		var kind := String(spec.get("kind", "health"))
		var amount := float(spec.get("amount", 25.0))
		var pickup := _spawn_pickup(position, kind, amount)
		pickup.name = String(spec.get("pickup_id", &"authored_pickup"))
		pickup.add_to_group("authored_pickup")

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
	if is_instance_valid(mission_level) and mission_level.has_method("set_player"):
		mission_level.call("set_player", player)
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
	_wave_transitioning = true
	_waiting_for_extraction = false
	_waiting_for_encounter_entry = true
	_clear_encounter_batch_state()
	_hold_progress = 0.0
	_hold_completed = false
	_extraction_progress = 0.0
	_reset_objective_nodes()
	_reset_hold_zones()
	_reset_progression_gates()
	if mission_runtime.completed_encounters.has(&"data_lane"):
		_set_progression_gate_open(&"data_lane", true, false)
	_set_extraction_armed(false)
	_set_encounter_lockdown(&"", false)
	_set_encounter_zone_armed(mission_runtime.current_encounter().encounter_id, true)
	_set_navigation_target(mission_runtime.current_encounter().encounter_id)
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
	_spawn_authored_pickups()
	_update_score()
	_update_objective()
	_show_message("CHECKPOINT // ADVANCE TO %s" % mission_runtime.current_encounter().title, 1.8)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

	var right_panel := ColorRect.new()
	right_panel.color = Color(0.005, 0.008, 0.02, 0.78)
	right_panel.position = Vector2(930, 20)
	right_panel.size = Vector2(330, 102)
	hud_panel.add_child(right_panel)

	health_label = _make_label(Vector2(36, 30), 20, Color(0.1, 1.0, 0.85))
	shield_label = _make_label(Vector2(36, 58), 18, Color(0.2, 0.65, 1.0))
	ammo_label = _make_label(Vector2(36, 84), 20, Color(1.0, 0.12, 0.7))
	weapon_label = _make_label(Vector2(36, 112), 17, Color(1.0, 0.75, 0.2))
	face_label = _make_label(Vector2(36, 138), 15, Color(0.45, 0.72, 1.0))
	dash_label = _make_label(Vector2(36, 162), 15, Color(0.7, 1.0, 0.5))
	score_label = _make_label(Vector2(946, 30), 18, Color(1.0, 0.85, 0.2))
	score_label.size = Vector2(292, 24)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label = _make_label(Vector2(940, 58), 14, Color(0.25, 1.0, 0.95))
	objective_label.size = Vector2(300, 54)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.14, 0.75))
	message_label.add_theme_constant_override("outline_size", 4)
	message_label.add_theme_color_override("font_outline_color", Color(0.005, 0.008, 0.02, 0.95))
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-210, 28)
	message_label.size = Vector2(420, 42)
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
	if score_label == null:
		return
	if story_mode:
		score_label.text = "SCORE %06d   MISSION %02d/%02d" % [
			session.score,
			mission_runtime.encounter_index + 1,
			mission_definition.encounter_count(),
		]
	else:
		score_label.text = "SCORE %06d   WAVE %02d/%02d" % [
			session.score,
			session.current_wave_number(),
			total_waves,
		]

func _update_objective() -> void:
	if objective_label == null:
		return
	if story_mode and mission_runtime.current_encounter() != null:
		var encounter := mission_runtime.current_encounter()
		if encounter.encounter_id == &"extraction" and _waiting_for_extraction:
			objective_label.text = "HOLD EXTRACTION\nEXTRACT %.1f/%.1fs" % [
				_extraction_progress,
				encounter.extraction_hold_seconds,
			]
			return
		if _waiting_for_encounter_entry:
			objective_label.text = "ADVANCE TO\n%s" % encounter.title
			return
		if encounter.hold_zone_seconds > 0.0:
			var hold_status := "UPLINK STABLE" if _hold_completed else "UPLINK %.1f/%.1fs" % [_hold_progress, encounter.hold_zone_seconds]
			if _reinforcement_scheduled:
				objective_label.text = "%s\n%s  //  INBOUND" % [encounter.objective_text, hold_status]
				return
			var hold_batch_count := current_story_batch_count()
			if hold_batch_count > 1:
				objective_label.text = "%s\n%s  //  HOSTILES %02d  //  BATCH %d/%d" % [
					encounter.objective_text,
					hold_status,
					session.alive_enemies,
					current_story_batch_number(),
					hold_batch_count,
				]
				return
			objective_label.text = "%s\n%s  //  HOSTILES %02d" % [
				encounter.objective_text,
				hold_status,
				session.alive_enemies,
			]
			return
		var remaining_nodes := _objective_nodes_remaining(encounter.encounter_id)
		if encounter.objective_node_count > 0:
			if _reinforcement_scheduled:
				objective_label.text = "%s\nRELAYS %02d LEFT  //  INBOUND" % [
					encounter.objective_text,
					remaining_nodes,
				]
				return
			var objective_batch_count := current_story_batch_count()
			if objective_batch_count > 1:
				objective_label.text = "%s\nRELAYS %02d  //  HOSTILES %02d  //  BATCH %d/%d" % [
					encounter.objective_text,
					remaining_nodes,
					session.alive_enemies,
					current_story_batch_number(),
					objective_batch_count,
				]
				return
			objective_label.text = "%s\nRELAYS %02d  //  HOSTILES %02d" % [
				encounter.objective_text,
				remaining_nodes,
				session.alive_enemies,
			]
			return
		if _reinforcement_scheduled:
			objective_label.text = "%s\nHOSTILES %02d  //  INBOUND" % [
				encounter.objective_text,
				session.alive_enemies,
			]
			return
		var batch_count := current_story_batch_count()
		if batch_count > 1:
			objective_label.text = "%s\nHOSTILES %02d  //  BATCH %d/%d" % [
				encounter.objective_text,
				session.alive_enemies,
				current_story_batch_number(),
				batch_count,
			]
			return
		objective_label.text = "%s\nHOSTILES %02d" % [
			encounter.objective_text,
			session.alive_enemies,
		]
	else:
		objective_label.text = "HOSTILES %02d" % session.alive_enemies

func _sync_session_fields() -> void:
	_score = session.score
	_wave = session.current_wave_number()
	_alive_enemies = session.alive_enemies
	_kills = session.kills
	difficulty_name = session.difficulty_name
	difficulty_scale = session.difficulty_scale


func _on_boss_health_changed(current: float, maximum: float, phase: int) -> void:
	_set_boss_arena_phase(phase)
	if phase > _last_boss_phase:
		_last_boss_phase = phase
		_audio_call("play_boss_phase")
		if phase == 2:
			_show_message("NULL WARDEN // PHASE 2 // TWIN HAZARDS ONLINE", 2.0)
		elif phase >= 3:
			_show_message("NULL WARDEN // PHASE 3 // ARENA OVERLOAD", 2.0)
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


func _set_extraction_armed(active: bool) -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("arm_extraction"):
		mission_level.call("arm_extraction", active)
	if is_instance_valid(mission_level) and mission_level.has_method("set_extraction_progress"):
		mission_level.call("set_extraction_progress", 0.0, 1.0)


func _complete_extraction_world_state() -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("complete_extraction"):
		mission_level.call("complete_extraction")


func _set_encounter_zone_armed(encounter_id: StringName, active: bool) -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("arm_encounter_zone"):
		mission_level.call("arm_encounter_zone", encounter_id, active)


func _set_encounter_lockdown(encounter_id: StringName, active: bool) -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("set_encounter_lockdown"):
		mission_level.call("set_encounter_lockdown", encounter_id, active)


func _reset_progression_gates() -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("reset_progression_gates"):
		mission_level.call("reset_progression_gates")


func _set_progression_gate_open(
	encounter_id: StringName,
	open: bool,
	animate: bool = true
) -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("set_progression_gate_open"):
		mission_level.call("set_progression_gate_open", encounter_id, open, animate)


func _set_navigation_target(encounter_id: StringName) -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("set_navigation_target"):
		mission_level.call("set_navigation_target", encounter_id)


func _set_boss_arena_phase(phase: int) -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("set_boss_phase"):
		mission_level.call("set_boss_phase", phase)


func _extraction_zone_occupied() -> bool:
	if not is_instance_valid(mission_level) or not mission_level.has_method("is_extraction_occupied"):
		return false
	return bool(mission_level.call("is_extraction_occupied"))


func _update_extraction_hold(delta: float) -> void:
	if not _waiting_for_extraction:
		return
	var encounter := mission_runtime.current_encounter()
	if encounter == null:
		return
	var required := maxf(0.0, encounter.extraction_hold_seconds)
	if required <= 0.0:
		_on_extraction_reached()
		return
	if _extraction_zone_occupied():
		_extraction_progress = minf(required, _extraction_progress + maxf(0.0, delta))
		_set_extraction_world_progress(_extraction_progress, required)
		_update_objective()
		if _extraction_progress >= required:
			_on_extraction_reached()
	else:
		if _extraction_progress > 0.0:
			_extraction_progress = 0.0
			_set_extraction_world_progress(0.0, required)
			_update_objective()


func _set_extraction_world_progress(current: float, required: float) -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("set_extraction_progress"):
		mission_level.call("set_extraction_progress", current, required)


func _set_hold_world_progress(
	encounter_id: StringName,
	current: float,
	required: float
) -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("set_hold_zone_progress"):
		mission_level.call("set_hold_zone_progress", encounter_id, current, required)


func _reset_hold_zones() -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("reset_hold_zones"):
		mission_level.call("reset_hold_zones")


func _arm_hold_zone(encounter_id: StringName, active: bool) -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("arm_hold_zone"):
		mission_level.call("arm_hold_zone", encounter_id, active)
	if is_instance_valid(mission_level) and mission_level.has_method("set_hold_zone_progress"):
		mission_level.call("set_hold_zone_progress", encounter_id, 0.0, 1.0)


func _hold_zone_occupied(encounter_id: StringName) -> bool:
	if not is_instance_valid(mission_level) or not mission_level.has_method("is_hold_zone_occupied"):
		return false
	return bool(mission_level.call("is_hold_zone_occupied", encounter_id))


func _update_hold_objective(delta: float) -> void:
	var encounter := mission_runtime.current_encounter()
	if encounter == null or encounter.hold_zone_seconds <= 0.0 or _waiting_for_encounter_entry:
		return
	if _hold_completed:
		return
	if _hold_zone_occupied(encounter.encounter_id):
		var previous := _hold_progress
		_hold_progress = minf(encounter.hold_zone_seconds, _hold_progress + maxf(0.0, delta))
		_set_hold_world_progress(encounter.encounter_id, _hold_progress, encounter.hold_zone_seconds)
		if previous < encounter.hold_zone_seconds and _hold_progress >= encounter.hold_zone_seconds:
			_hold_completed = true
			_audio_call("play_uplink_complete")
			_show_message("UPLINK STABLE // HOLD COMPLETE", 1.4)
		if not is_equal_approx(previous, _hold_progress):
			_update_objective()
	else:
		if _hold_progress > 0.0:
			_hold_progress = 0.0
			_set_hold_world_progress(encounter.encounter_id, 0.0, encounter.hold_zone_seconds)
			_update_objective()


func _reset_objective_nodes() -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("reset_objective_nodes"):
		mission_level.call("reset_objective_nodes")


func _arm_objective_nodes(encounter_id: StringName, active: bool) -> void:
	if is_instance_valid(mission_level) and mission_level.has_method("arm_objective_nodes"):
		mission_level.call("arm_objective_nodes", encounter_id, active)


func _objective_nodes_remaining(encounter_id: StringName) -> int:
	if not is_instance_valid(mission_level) or not mission_level.has_method("objective_nodes_remaining"):
		return 0
	return int(mission_level.call("objective_nodes_remaining", encounter_id))


func _story_objectives_complete() -> bool:
	if not story_mode:
		return true
	var encounter := mission_runtime.current_encounter()
	if encounter == null:
		return true
	if encounter.objective_node_count > 0 and _objective_nodes_remaining(encounter.encounter_id) > 0:
		return false
	if encounter.hold_zone_seconds > 0.0 and not _hold_completed:
		return false
	return true


func _on_encounter_zone_entered(encounter_id: StringName) -> void:
	if not story_mode or not _waiting_for_encounter_entry:
		return
	var encounter := mission_runtime.current_encounter()
	if encounter == null or encounter.encounter_id != encounter_id:
		return
	_waiting_for_encounter_entry = false
	_set_navigation_target(&"")
	_set_encounter_lockdown(encounter_id, true)
	_audio_call("play_lockdown")
	_arm_objective_nodes(encounter_id, true)
	_arm_hold_zone(encounter_id, true)
	_hold_progress = 0.0
	_hold_completed = false
	_spawn_current_wave()
	_wave_transitioning = false
	_update_score()
	_update_objective()
	_show_message("%s // %s" % [encounter.title, encounter.objective_text], 2.0)


func _on_objective_node_destroyed(
	encounter_id: StringName,
	objective_id: StringName,
	remaining: int
) -> void:
	if not story_mode:
		return
	var encounter := mission_runtime.current_encounter()
	if encounter == null or encounter.encounter_id != encounter_id:
		return
	_audio_call("play_objective_destroyed")
	_show_message(
		"OBJECTIVE DESTROYED // %s // %d REMAINING" % [
			String(objective_id).replace("_", " ").to_upper(),
			remaining,
		],
		1.4
	)
	_update_objective()
	if (
		remaining <= 0
		and _alive_enemies <= 0
		and not _has_pending_reinforcements()
		and not _reinforcement_scheduled
		and not _wave_transitioning
	):
		_finish_wave()


func _on_extraction_reached() -> void:
	if not story_mode or not _waiting_for_extraction:
		return
	var encounter := mission_runtime.current_encounter()
	if encounter == null or encounter.encounter_id != &"extraction":
		return
	_waiting_for_extraction = false
	_extraction_progress = encounter.extraction_hold_seconds
	_complete_extraction_world_state()
	_spawn_encounter_rewards(encounter)
	mission_runtime.complete_current_encounter()
	MissionProgressStore.save_runtime(mission_runtime, session)
	_finish_game(true)


func _on_performance_budget_warning(messages: PackedStringArray) -> void:
	for message in messages:
		push_warning("Performance budget: %s" % message)


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
