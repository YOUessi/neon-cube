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
	_check(game.session.alive_enemies == 5, "Market Crossfire spawns five hostiles on entry")
	var enemies := get_nodes_in_group("enemies")
	_check(enemies.size() == 5, "five enemy bodies exist after activation")
	for enemy in enemies:
		var down := CubeGravity.nearest_down(enemy.global_position, game.cube_size * 0.5)
		_check(down.is_equal_approx(Vector3.DOWN), "Market Crossfire hostile uses authored Neon Market spawn face")
		break

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
