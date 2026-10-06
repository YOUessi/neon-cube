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
	game.session.alive_enemies = 0
	game._sync_session_fields()
	game._finish_wave()

	_check(game.mission_runtime.current_encounter().encounter_id == &"market_crossfire", "arrival clear advances mission definition immediately")
	_check(game._wave_transitioning, "intermission begins in transition state")
	_check(not game._waiting_for_encounter_entry, "next arena is not armed before intermission finishes")

	game._pause_game()
	_check(paused, "pause action pauses SceneTree")
	_check(game.game_state == NeonGame.GameState.PAUSED, "game enters paused state")

	await create_timer(2.05, true).timeout
	_check(game._wave_transitioning, "gameplay transition timer stays frozen while paused")
	_check(not game._waiting_for_encounter_entry, "paused intermission cannot arm next encounter")
	_check(game.session.wave_index == 0, "paused intermission does not advance session wave index")

	game._resume_game()
	_check(not paused, "resume unpauses SceneTree")
	await create_timer(1.9, true).timeout
	await process_frame

	_check(game._waiting_for_encounter_entry, "intermission resumes and arms next encounter after unpause")
	_check(game.session.wave_index == 1, "session advances exactly once after resumed intermission")
	_check(StringName(game.mission_level.call("current_navigation_target")) == &"market_crossfire", "resumed transition restores Market Crossfire navigation target")

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
		print("pause-safe mission timer tests: PASS")
		quit(0)
	else:
		print("pause-safe mission timer tests: FAIL (%d)" % failures)
		quit(1)
