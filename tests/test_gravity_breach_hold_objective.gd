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

	var hold_zone := game.mission_level.get_node_or_null(
		"Geometry/HoldZones/GravityBreachHold"
	) as Area3D
	_check(hold_zone != null, "Gravity Breach exposes an authored hold zone")
	if hold_zone == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame

	game.mission_runtime.encounter_index = 2
	game.session.wave_index = 2
	game.session.alive_enemies = 0
	game._sync_session_fields()
	game._clear_encounter_batch_state()
	game._reset_hold_zones()
	game._set_encounter_lockdown(&"gravity_breach", true)
	game._arm_hold_zone(&"gravity_breach", true)
	game._waiting_for_encounter_entry = false
	game._wave_transitioning = false
	game._hold_progress = 0.0
	game.set_process(false)

	game._process(1.0)
	_check(is_equal_approx(game._hold_progress, 0.0), "hold progress does not advance while player is outside zone")
	_check(game.mission_runtime.encounter_index == 2, "zero hostiles alone cannot finish Gravity Breach")
	_check(bool(game.mission_level.call("is_encounter_locked", &"gravity_breach")), "Gravity Breach stays locked before uplink hold")

	game.player.global_position = hold_zone.to_global(Vector3(0, 1.0, 0))
	game.player.velocity = Vector3.ZERO
	game.player.set_physics_process(false)
	for i in range(3):
		await physics_frame
		await process_frame

	_check(bool(game.mission_level.call("is_hold_zone_occupied", &"gravity_breach")), "player presence is detected inside hold zone")
	game._process(2.0)
	_check(game._hold_progress > 1.9 and game._hold_progress < 2.1, "continuous hold accumulates progress")
	var world_hold_ratio := float(game.mission_level.call("hold_zone_progress_state", &"gravity_breach"))
	_check(world_hold_ratio > 0.49 and world_hold_ratio < 0.51, "world uplink indicator mirrors fifty-percent hold progress")
	_check(game.mission_runtime.encounter_index == 2, "partial hold does not advance mission")

	game.player.global_position = hold_zone.to_global(Vector3(7.0, 1.0, 0))
	for i in range(3):
		await physics_frame
		await process_frame
	game._process(0.1)
	_check(not bool(game.mission_level.call("is_hold_zone_occupied", &"gravity_breach")), "leaving control zone clears occupancy")
	_check(is_equal_approx(game._hold_progress, 0.0), "leaving control zone resets continuous hold progress")
	_check(is_equal_approx(float(game.mission_level.call("hold_zone_progress_state", &"gravity_breach")), 0.0), "world uplink indicator resets when player leaves zone")

	game.player.global_position = hold_zone.to_global(Vector3(0, 1.0, 0))
	for i in range(3):
		await physics_frame
		await process_frame
	_check(bool(game.mission_level.call("is_hold_zone_occupied", &"gravity_breach")), "player can re-enter hold zone")

	game._process(4.1)
	_check(game.mission_runtime.encounter_index == 3, "four-second continuous hold advances mission to Data Lane")
	_check(not bool(game.mission_level.call("is_encounter_locked", &"gravity_breach")), "Gravity Breach unlocks after hold objective and hostile clear")

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
		print("Gravity Breach hold objective tests: PASS")
		quit(0)
	else:
		print("Gravity Breach hold objective tests: FAIL (%d)" % failures)
		quit(1)
