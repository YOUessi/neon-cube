extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: NeonGame = MAIN.instantiate() as NeonGame
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.player.set_physics_process(false)

	# 1. Arrival Ambush
	_check(game.mission_runtime.current_encounter().encounter_id == &"arrival_ambush", "playthrough starts at Arrival Ambush")
	_check(game.session.alive_enemies == 4, "Arrival opens with four hostiles")
	await _kill_all_enemies(game)
	game._process(0.016)
	_check(game.mission_runtime.current_encounter().encounter_id == &"market_crossfire", "Arrival clear advances to Market Crossfire")
	game._advance_wave()
	_check(game._waiting_for_encounter_entry, "Market Crossfire waits for arena entry")

	# 2. Market Crossfire: 3 + 2.
	await _enter_encounter_zone(game, "MarketCrossfireActivation")
	_check(game.current_story_batch_number() == 1, "Market starts batch one")
	_check(game.session.alive_enemies == 3, "Market opening batch has three hostiles")
	await _kill_enemy_count(game, 2)
	game._process(0.016)
	_check(game._reinforcement_scheduled, "Market schedules second batch at threshold")
	game._on_reinforcement_ready(&"market_crossfire")
	_check(game.current_story_batch_number() == 2, "Market reinforcement becomes batch two")
	_check(game.session.alive_enemies == 3, "Market reinforcement joins surviving hostile")
	var market_high_sniper: NeonEnemy = null
	var market_ground_runner: NeonEnemy = null
	for enemy in get_nodes_in_group("enemies"):
		var typed_enemy := enemy as NeonEnemy
		if typed_enemy.get_tactical_slot_index() == 4 and typed_enemy.archetype == "sniper":
			market_high_sniper = typed_enemy
		elif typed_enemy.get_tactical_slot_index() == 3 and typed_enemy.archetype == "runner":
			market_ground_runner = typed_enemy
	_check(market_high_sniper != null, "Market reinforcement contains elevated slot-four sniper")
	_check(market_ground_runner != null, "Market reinforcement contains ground slot-three runner")
	if market_high_sniper != null:
		var market_authored_spawns: Array = game.mission_level.call("spawn_points_for", &"market_crossfire", 5, 0)
		_check(market_authored_spawns.size() == 5, "Market authored spawn list remains complete")
		if market_authored_spawns.size() == 5:
			_check(market_high_sniper.get_tactical_leash_center().distance_to(market_authored_spawns[4]) < 0.05, "Market sniper maps exactly to authored elevated socket")
		_check(market_high_sniper.global_position.distance_to(market_high_sniper.get_tactical_leash_center()) <= 0.80, "Market sniper begins inside catwalk perch leash")
	await _kill_all_enemies(game)
	game._process(0.016)
	_check(game.mission_runtime.current_encounter().encounter_id == &"gravity_breach", "Market clear advances to Gravity Breach")
	game._advance_wave()

	# 3. Gravity Breach: 2 + 2 plus continuous uplink.
	await _enter_encounter_zone(game, "GravityBreachActivation")
	_check(game.session.alive_enemies == 2, "Gravity Breach opens with two hostiles")
	await _kill_enemy_count(game, 1)
	game._process(0.016)
	_check(game._reinforcement_scheduled, "Gravity Breach schedules second batch")
	game._on_reinforcement_ready(&"gravity_breach")
	await _kill_all_enemies(game)
	game._process(0.016)
	_check(game.mission_runtime.current_encounter().encounter_id == &"gravity_breach", "hostile clear alone cannot bypass Gravity uplink")
	var hold_zone := game.mission_level.get_node("Geometry/HoldZones/GravityBreachHold") as Area3D
	await _move_player_into_area(game, hold_zone)
	game._process(4.1)
	_check(game._hold_completed, "Gravity uplink completes during full playthrough")
	_check(game.mission_runtime.current_encounter().encounter_id == &"data_lane", "Gravity objective advances to Data Lane")
	game._advance_wave()

	# 4. Data Lane: 3 + 2 plus two destructible relays.
	await _enter_encounter_zone(game, "DataLaneActivation")
	_check(game.session.alive_enemies == 3, "Data Lane opens with three hostiles")
	var relays := get_nodes_in_group("mission_objective_node")
	_check(relays.size() == 2, "Data Lane exposes both relay objectives")
	await _kill_enemy_count(game, 2)
	game._process(0.016)
	_check(game._reinforcement_scheduled, "Data Lane schedules second batch")
	game._on_reinforcement_ready(&"data_lane")
	var elevated_data_sniper: NeonEnemy = null
	var ground_data_tank: NeonEnemy = null
	for enemy in get_nodes_in_group("enemies"):
		var typed_enemy := enemy as NeonEnemy
		if typed_enemy.get_tactical_slot_index() == 3 and typed_enemy.archetype == "sniper":
			elevated_data_sniper = typed_enemy
		elif typed_enemy.get_tactical_slot_index() == 4 and typed_enemy.archetype == "tank":
			ground_data_tank = typed_enemy
	_check(elevated_data_sniper != null, "Data Lane reinforcement includes slot-three sniper")
	_check(ground_data_tank != null, "Data Lane reinforcement includes slot-four tank")
	if elevated_data_sniper != null:
		_check(elevated_data_sniper.get_route_point_count() == 9, "Data Lane runtime enemies receive Maintenance Bridge route waypoints")
	if elevated_data_sniper != null:
		_check(is_equal_approx(elevated_data_sniper.get_tactical_leash_radius(), 0.30), "Data Lane elevated sniper receives server-rack leash")
		var data_authored_spawns: Array = game.mission_level.call("spawn_points_for", &"data_lane", 5, 0)
		_check(data_authored_spawns.size() == 5, "Data Lane authored spawn list remains complete")
		if data_authored_spawns.size() == 5:
			_check(elevated_data_sniper.get_tactical_leash_center().distance_to(data_authored_spawns[3]) < 0.05, "Data Lane sniper maps exactly to authored server-rack socket")
		_check(elevated_data_sniper.global_position.distance_to(elevated_data_sniper.get_tactical_leash_center()) <= 0.35, "Data Lane sniper begins inside server-rack perch leash")
	if ground_data_tank != null:
		_check(is_equal_approx(ground_data_tank.get_tactical_leash_radius(), 0.0), "Data Lane ground tank remains unrestricted")
	await _kill_all_enemies(game)
	game._process(0.016)
	_check(game.mission_runtime.current_encounter().encounter_id == &"data_lane", "Data Lane hostile clear waits for relay destruction")
	for relay in relays:
		(relay as MissionObjectiveNode).take_damage(999.0)
		await process_frame
	_check(game.mission_runtime.current_encounter().encounter_id == &"null_warden", "relay destruction advances to Null Warden")
	_check(bool(game.mission_level.call("progression_gate_open", &"data_lane")), "Warden access is open after Data Lane")
	game._advance_wave()

	# 5. Null Warden.
	await _enter_encounter_zone(game, "NullWardenActivation")
	_check(game.session.alive_enemies == 4, "Null Warden encounter spawns boss squad")
	_check(get_nodes_in_group("enemies").any(func(enemy): return (enemy as NeonEnemy).archetype == "boss"), "boss squad contains Null Warden")
	var boss_gantry_sniper: NeonEnemy = null
	var boss_ground_tank: NeonEnemy = null
	for enemy in get_nodes_in_group("enemies"):
		var typed_enemy := enemy as NeonEnemy
		if typed_enemy.get_tactical_slot_index() == 2 and typed_enemy.archetype == "sniper":
			boss_gantry_sniper = typed_enemy
		elif typed_enemy.get_tactical_slot_index() == 3 and typed_enemy.archetype == "tank":
			boss_ground_tank = typed_enemy
	_check(boss_gantry_sniper != null, "Null Warden squad places sniper on authored gantry slot")
	_check(boss_ground_tank != null, "Null Warden squad keeps tank on ground slot")
	if boss_gantry_sniper != null:
		_check(boss_gantry_sniper.get_route_point_count() == 18, "Null Warden runtime enemies receive tread-by-tread dual-gantry routes")
	if boss_gantry_sniper != null:
		_check(is_equal_approx(boss_gantry_sniper.get_tactical_leash_radius(), 0.55), "Boss gantry sniper receives perch leash")
		var boss_authored_spawns: Array = game.mission_level.call("spawn_points_for", &"null_warden", 4, 0)
		_check(boss_authored_spawns.size() == 4, "Null Warden authored spawn list remains complete")
		if boss_authored_spawns.size() == 4:
			_check(boss_gantry_sniper.get_tactical_leash_center().distance_to(boss_authored_spawns[2]) < 0.05, "Boss sniper maps exactly to authored gantry socket")
		_check(boss_gantry_sniper.global_position.distance_to(boss_gantry_sniper.get_tactical_leash_center()) <= 0.60, "Boss sniper begins inside gantry perch leash")
	if boss_ground_tank != null:
		_check(is_equal_approx(boss_ground_tank.get_tactical_leash_radius(), 0.0), "Boss ground tank remains unrestricted")
	await _kill_all_enemies(game)
	game._process(0.016)
	_check(game.mission_runtime.current_encounter().encounter_id == &"extraction", "boss clear advances to Extraction")
	game._advance_wave()

	# 6. Extraction: 2 + 2, then three-second hold.
	await _enter_encounter_zone(game, "ExtractionActivation")
	_check(game.session.alive_enemies == 2, "Extraction opens with two hostiles")
	await _kill_all_enemies(game)
	game._process(0.016)
	_check(game._reinforcement_scheduled, "Extraction schedules final reinforcement")
	game._on_reinforcement_ready(&"extraction")
	_check(game.session.alive_enemies == 2, "final reinforcement contains two hostiles")
	await _kill_all_enemies(game)
	game._process(0.016)
	_check(game._waiting_for_extraction, "final hostile clear activates extraction hold")
	_check(game.game_state == NeonGame.GameState.PLAYING, "mission remains active until extraction hold finishes")

	var extraction_zone := game.mission_level.get_node(
		"Geometry/Extraction/ExtractionBeacon/ExtractionZone"
	) as Area3D
	await _move_player_into_area(game, extraction_zone)
	game._process(3.1)

	_check(game.game_state == NeonGame.GameState.VICTORY, "full mission playthrough ends in Victory")
	_check(game.mission_runtime.state == MissionRuntime.State.COMPLETED, "full mission playthrough completes MissionRuntime")
	_check(game.mission_runtime.completed_encounters.size() == 6, "all six encounters are recorded complete")

	paused = false
	game.queue_free()
	await process_frame
	_finish()


func _enter_encounter_zone(game: NeonGame, node_name: String) -> void:
	var zone := game.mission_level.get_node(
		"Geometry/EncounterActivationZones/%s" % node_name
	) as Area3D
	await _move_player_into_area(game, zone)
	_check(not game._waiting_for_encounter_entry, "%s entry activates encounter" % node_name)


func _move_player_into_area(game: NeonGame, area: Area3D) -> void:
	_check(area != null, "target Area3D exists")
	if area == null:
		return
	game.player.global_position = area.global_position
	game.player.velocity = Vector3.ZERO
	for i in range(4):
		await physics_frame
		await process_frame


func _kill_enemy_count(game: NeonGame, count: int) -> void:
	var enemies := get_nodes_in_group("enemies")
	var kill_count := mini(count, enemies.size())
	for i in range(kill_count):
		var enemy := enemies[i] as NeonEnemy
		game._on_enemy_killed(enemy)
		enemy.queue_free()
	await process_frame


func _kill_all_enemies(game: NeonGame) -> void:
	var enemies := get_nodes_in_group("enemies")
	for node in enemies:
		var enemy := node as NeonEnemy
		game._on_enemy_killed(enemy)
		enemy.queue_free()
	await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if failures == 0:
		print("full mission playthrough tests: PASS")
		quit(0)
	else:
		print("full mission playthrough tests: FAIL (%d)" % failures)
		quit(1)
