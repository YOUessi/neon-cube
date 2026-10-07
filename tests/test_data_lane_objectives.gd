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

	var objective_nodes := get_nodes_in_group("mission_objective_node")
	_check(objective_nodes.size() == 2, "Data Lane exposes two destructible relay objectives")
	if objective_nodes.size() != 2:
		game.queue_free()
		await process_frame
		_finish()
		return

	var relay_a := objective_nodes[0] as MissionObjectiveNode
	var relay_b := objective_nodes[1] as MissionObjectiveNode
	_check(relay_a != null and relay_b != null, "relay objective nodes use MissionObjectiveNode runtime")
	_check(game.mission_level.call("objective_nodes_remaining", &"data_lane") == 2, "both relays begin intact")
	var initial_environment: Dictionary = game.mission_level.call("data_environment_state")
	_check(bool(initial_environment.get("relay_a_online", false)), "Relay A power environment begins online")
	_check(bool(initial_environment.get("relay_b_online", false)), "Relay B power environment begins online")
	_check(not bool(initial_environment.get("exit_ready", true)), "Warden route begins not ready")

	relay_a.take_damage(999.0)
	_check(not relay_a.is_destroyed(), "inactive relay cannot be destroyed before Data Lane begins")

	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame

	game.mission_runtime.encounter_index = 3
	game.session.wave_index = 3
	game.session.alive_enemies = 0
	game._sync_session_fields()
	game._clear_encounter_batch_state()
	game._set_encounter_lockdown(&"data_lane", true)
	game._arm_objective_nodes(&"data_lane", true)
	game._wave_transitioning = false

	_check(not game._story_objectives_complete(), "Data Lane cannot complete while relay objectives remain")
	_check(not bool(game.mission_level.call("progression_gate_open", &"data_lane")), "Warden access door starts closed during Data Lane")
	var relay_b_before := relay_b.health_ratio()
	relay_b.take_damage(30.0)
	_check(relay_b.health_ratio() < relay_b_before and relay_b.health_ratio() > 0.0, "active relay exposes partial health state before destruction")
	_check(not relay_b.is_destroyed(), "partial relay damage does not destroy objective")
	relay_a.take_damage(999.0)
	await process_frame
	_check(relay_a.is_destroyed(), "active relay can be destroyed by weapon-compatible damage")
	_check(game.mission_level.call("objective_nodes_remaining", &"data_lane") == 1, "destroying one relay leaves one objective")
	_check(game.mission_runtime.encounter_index == 3, "destroying first relay does not advance encounter")
	_check(not bool(game.mission_level.call("progression_gate_open", &"data_lane")), "first relay destruction does not open Warden access")
	var first_environment: Dictionary = game.mission_level.call("data_environment_state")
	_check(not bool(first_environment.get("relay_a_online", true)), "destroyed Relay A powers down its rack cluster")
	_check(bool(first_environment.get("relay_b_online", false)), "Relay B rack cluster remains online after Relay A destruction")
	_check(not bool(first_environment.get("exit_ready", true)), "Warden route does not advertise ready after one relay")

	game._process(0.016)
	_check(game.mission_runtime.encounter_index == 3, "zero hostiles alone cannot finish Data Lane")
	_check(bool(game.mission_level.call("is_encounter_locked", &"data_lane")), "Data Lane stays locked while final relay survives")

	game.session.alive_enemies = 1
	game._sync_session_fields()
	relay_b.take_damage(999.0)
	await process_frame
	_check(relay_b.is_destroyed(), "second relay can be destroyed")
	_check(is_equal_approx(relay_b.health_ratio(), 0.0), "destroyed relay reports zero health ratio for world status")
	_check(game.mission_level.call("objective_nodes_remaining", &"data_lane") == 0, "all Data Lane relay objectives are cleared")
	var relays_cleared_environment: Dictionary = game.mission_level.call("data_environment_state")
	_check(not bool(relays_cleared_environment.get("relay_a_online", true)), "Relay A environment remains offline")
	_check(not bool(relays_cleared_environment.get("relay_b_online", true)), "Relay B environment powers down after destruction")
	_check(not bool(relays_cleared_environment.get("exit_ready", true)), "Warden route stays locked while one hostile remains")
	_check(game.mission_runtime.encounter_index == 3, "relay clear alone waits for remaining hostile")
	_check(bool(game.mission_level.call("is_encounter_locked", &"data_lane")), "Data Lane remains locked until hostile clear")
	_check(not bool(game.mission_level.call("progression_gate_open", &"data_lane")), "Warden door does not open early when relays are down")

	game.session.alive_enemies = 0
	game._sync_session_fields()
	game._process(0.016)
	_check(game.mission_runtime.encounter_index == 4, "hostile clear after relay shutdown advances mission to Null Warden")
	_check(not bool(game.mission_level.call("is_encounter_locked", &"data_lane")), "Data Lane unlocks after enemies and objectives are cleared")
	_check(bool(game.mission_level.call("progression_gate_open", &"data_lane")), "Data Lane completion opens Warden access door")
	var complete_environment: Dictionary = game.mission_level.call("data_environment_state")
	_check(bool(complete_environment.get("exit_ready", false)), "completed Data Lane turns Warden route guidance ready")

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
		print("Data Lane objective tests: PASS")
		quit(0)
	else:
		print("Data Lane objective tests: FAIL (%d)" % failures)
		quit(1)
