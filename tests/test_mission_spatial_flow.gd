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

	_check(game.game_state == NeonGame.GameState.PLAYING, "headless game starts in playing state")
	_check(get_nodes_in_group("enemies").size() == 4, "arrival ambush starts with four hostiles")

	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	game.session.alive_enemies = 0
	game._sync_session_fields()
	game._finish_wave()
	_check(game.mission_runtime.current_encounter().encounter_id == &"market_crossfire", "clearing arrival advances mission runtime")

	# Invoke the already-scheduled transition immediately so the test can verify
	# the gate without sleeping through the production intermission.
	game._advance_wave()
	_check(game._waiting_for_encounter_entry, "next encounter waits for arena entry")
	_check(game.session.alive_enemies == 0, "no next-wave enemies spawn while player is travelling")
	_check(get_nodes_in_group("enemies").is_empty(), "world remains clear during traversal")
	_check(StringName(game.mission_level.call("current_navigation_target")) == &"market_crossfire", "travel phase exposes Market Crossfire world beacon")

	var zone := game.mission_level.get_node_or_null(
		"Geometry/EncounterActivationZones/MarketCrossfireActivation"
	) as Area3D
	_check(zone != null and zone.monitoring, "Market Crossfire activation volume is armed")
	if zone != null and is_instance_valid(game.player):
		game.player.global_position = zone.global_position
		game.player.velocity = Vector3.ZERO
		for i in range(4):
			await physics_frame
			await process_frame

	_check(not game._waiting_for_encounter_entry, "entering the arena releases the encounter gate")
	_check(StringName(game.mission_level.call("current_navigation_target")) == &"", "entering arena clears navigation beacon")
	_check(bool(game.mission_level.call("is_encounter_locked", &"market_crossfire")), "arena closes its combat lockdown on activation")
	_check(game.current_story_batch_number() == 1 and game.current_story_batch_count() == 2, "Market Crossfire starts on batch one of two")
	_check(game.session.alive_enemies == 3, "Market Crossfire opens with three hostiles")
	var enemies := get_nodes_in_group("enemies")
	_check(enemies.size() == 3, "three enemy bodies exist in the opening batch")
	var slot_ids := {}
	for enemy in enemies:
		var typed_enemy := enemy as NeonEnemy
		typed_enemy.set_physics_process(false)
		var down := CubeGravity.nearest_down(typed_enemy.global_position, game.cube_size * 0.5)
		_check(down.is_equal_approx(Vector3.DOWN), "Market Crossfire hostile uses authored Neon Market spawn face")
		_check(typed_enemy.get_route_point_count() == 6, "Market Crossfire hostile receives authored route network")
		_check(typed_enemy.get_tactical_slot_count() == 5, "Market Crossfire hostile knows total encounter slot count")
		slot_ids[typed_enemy.get_tactical_slot_index()] = true
	_check(slot_ids.size() == 3, "opening batch uses three unique tactical slots")

	for i in range(2):
		var defeated := enemies[i] as NeonEnemy
		game._on_enemy_killed(defeated)
		defeated.queue_free()
	await process_frame
	_check(game.session.alive_enemies == 1, "reinforcement threshold is reached with one hostile remaining")
	_check(game._reinforcement_scheduled, "second Market Crossfire batch is scheduled instead of ending encounter")
	var warning_state: Dictionary = game.mission_level.call("reinforcement_warning_state")
	_check(StringName(warning_state.get("encounter_id", &"")) == &"market_crossfire", "reinforcement warning belongs to Market Crossfire")
	_check(int(warning_state.get("count", 0)) == 2, "two upcoming spawn sockets are telegraphed")
	_check(bool(game.mission_level.call("is_encounter_locked", &"market_crossfire")), "combat lockdown stays closed while reinforcements are inbound")

	await create_timer(0.85).timeout
	await process_frame
	_check(not game._reinforcement_scheduled, "reinforcement timer completes")
	var cleared_warning: Dictionary = game.mission_level.call("reinforcement_warning_state")
	_check(int(cleared_warning.get("count", -1)) == 0, "reinforcement warning clears when batch arrives")
	_check(game.current_story_batch_number() == 2, "second Market Crossfire batch becomes active")
	_check(game.session.alive_enemies == 3, "two reinforcements join the surviving hostile")
	var reinforced_enemies := get_nodes_in_group("enemies")
	_check(reinforced_enemies.size() == 3, "three hostile bodies remain after reinforcement arrival")
	var reinforced_slots := {}
	for enemy in reinforced_enemies:
		var typed_enemy := enemy as NeonEnemy
		typed_enemy.set_physics_process(false)
		reinforced_slots[typed_enemy.get_tactical_slot_index()] = true
	_check(reinforced_slots.has(3) and reinforced_slots.has(4), "reinforcement batch occupies the remaining authored tactical slots")
	var elevated_sniper: NeonEnemy = null
	for enemy in reinforced_enemies:
		var typed_enemy := enemy as NeonEnemy
		if typed_enemy.archetype == "sniper":
			elevated_sniper = typed_enemy
			break
	_check(elevated_sniper != null, "Market second batch includes authored sniper reinforcement")
	if elevated_sniper != null:
		_check(elevated_sniper.global_position.y > -27.0, "Market sniper reinforcement enters from elevated lane")

	for enemy in reinforced_enemies:
		var typed_enemy := enemy as NeonEnemy
		game._on_enemy_killed(typed_enemy)
		typed_enemy.queue_free()
	game._finish_wave()
	await process_frame
	_check(not bool(game.mission_level.call("is_encounter_locked", &"market_crossfire")), "only final batch clear reopens combat lockdown")

	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if failures == 0:
		print("mission spatial flow tests: PASS")
		quit(0)
	else:
		print("mission spatial flow tests: FAIL (%d)" % failures)
		quit(1)
