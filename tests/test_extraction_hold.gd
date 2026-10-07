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

	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame

	game.mission_runtime.encounter_index = 5
	game.session.wave_index = 5
	game.session.alive_enemies = 0
	game._sync_session_fields()
	game._clear_encounter_batch_state()
	game._set_encounter_lockdown(&"extraction", true)
	game._waiting_for_encounter_entry = false
	game._wave_transitioning = false
	game.set_process(false)

	game._finish_wave()
	_check(game._waiting_for_extraction, "final hostile clear arms extraction instead of instant victory")
	_check(game.game_state == NeonGame.GameState.PLAYING, "game remains active while extraction hold is pending")

	var zone := game.mission_level.get_node_or_null(
		"Geometry/Extraction/ExtractionBeacon/ExtractionZone"
	) as Area3D
	_check(zone != null and zone.monitoring, "extraction beacon trigger is active")
	if zone == null:
		paused = false
		game.queue_free()
		await process_frame
		_finish()
		return

	game._process(1.0)
	_check(is_equal_approx(game._extraction_progress, 0.0), "extraction progress stays zero outside beacon")
	_check(game.game_state == NeonGame.GameState.PLAYING, "outside beacon cannot complete mission")

	game.player.global_position = zone.to_global(Vector3(0, 1.0, 0))
	game.player.velocity = Vector3.ZERO
	game.player.set_physics_process(false)
	for i in range(3):
		await physics_frame
		await process_frame

	_check(bool(game.mission_level.call("is_extraction_occupied")), "player occupancy is detected inside extraction beacon")
	game._process(1.5)
	_check(game._extraction_progress > 1.4 and game._extraction_progress < 1.6, "extraction hold accumulates while player remains inside")
	var world_extract_ratio := float(game.mission_level.call("extraction_progress_state"))
	_check(world_extract_ratio > 0.49 and world_extract_ratio < 0.51, "world extraction core mirrors fifty-percent countdown progress")
	_check(game.game_state == NeonGame.GameState.PLAYING, "partial extraction hold does not finish mission")

	game.player.global_position = zone.to_global(Vector3(7.0, 1.0, 0))
	for i in range(3):
		await physics_frame
		await process_frame
	game._process(0.1)
	_check(not bool(game.mission_level.call("is_extraction_occupied")), "leaving beacon clears extraction occupancy")
	_check(is_equal_approx(game._extraction_progress, 0.0), "leaving beacon resets extraction countdown")
	_check(is_equal_approx(float(game.mission_level.call("extraction_progress_state")), 0.0), "world extraction core resets when player leaves beacon")

	game.player.global_position = zone.to_global(Vector3(0, 1.0, 0))
	for i in range(3):
		await physics_frame
		await process_frame
	_check(bool(game.mission_level.call("is_extraction_occupied")), "player can re-enter extraction beacon")

	game._process(3.1)
	_check(game.game_state == NeonGame.GameState.VICTORY, "three-second continuous extraction hold completes mission")
	_check(not game._waiting_for_extraction, "extraction waiting state clears on victory")
	_check(game.mission_runtime.state == MissionRuntime.State.COMPLETED, "MissionRuntime records final completion")
	_check(bool(game.mission_level.call("extraction_complete_state")), "world extraction beacon remains in completed state behind Victory UI")
	_check(float(game.mission_level.call("extraction_progress_state")) >= 0.999, "completed extraction beacon remains visually full")
	_check(not zone.monitoring, "completed extraction trigger stops accepting further occupancy")

	paused = false
	game._set_extraction_armed(true)
	_check(not bool(game.mission_level.call("extraction_complete_state")), "re-arming extraction clears prior completed state")
	_check(is_equal_approx(float(game.mission_level.call("extraction_progress_state")), 0.0), "re-armed extraction restarts from zero progress")
	_check(zone.monitoring, "re-armed extraction trigger becomes active again")
	game._set_extraction_armed(false)
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
		print("extraction hold tests: PASS")
		quit(0)
	else:
		print("extraction hold tests: FAIL (%d)" % failures)
		quit(1)
