extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	MissionProgressStore.clear()

	var game: NeonGame = MAIN.instantiate() as NeonGame
	root.add_child(game)
	await process_frame
	await physics_frame

	var mission := MissionCatalog.primary()
	var saved_runtime := MissionRuntime.new()
	saved_runtime.start(mission)
	for i in range(4):
		saved_runtime.complete_current_encounter()

	_check(saved_runtime.checkpoint_id == &"cp_warden_gate", "fixture reaches Warden gate checkpoint")
	_check(saved_runtime.completed_encounters.has(&"data_lane"), "fixture records Data Lane completion")
	_check(saved_runtime.current_encounter().encounter_id == &"null_warden", "fixture points at Null Warden encounter")

	var saved_session := GameSession.new()
	saved_session.reset_run("OPERATIVE", 1.0)
	saved_session.wave_index = saved_runtime.encounter_index
	saved_session.score = 1600
	saved_session.kills = 12

	var save_error := MissionProgressStore.save_runtime(saved_runtime, saved_session)
	_check(save_error == OK, "Warden checkpoint fixture saves successfully")

	game._resume_story_from_save()
	await process_frame

	_check(game.mission_runtime.current_encounter().encounter_id == &"null_warden", "Continue Story restores Null Warden encounter")
	_check(game.mission_runtime.completed_encounters.has(&"data_lane"), "Continue Story preserves Data Lane completion")
	_check(bool(game.mission_level.call("progression_gate_open", &"data_lane")), "Continue Story restores Warden access door as open")
	_check(game._waiting_for_encounter_entry, "restored Null Warden still waits for authored arena entry")
	_check(StringName(game.mission_level.call("current_navigation_target")) == &"null_warden", "restored checkpoint points navigation at Null Warden")

	var restored_pickups := get_nodes_in_group("authored_pickup")
	_check(restored_pickups.size() == 2, "checkpoint restore skips authored pickups from completed encounters")
	var restored_pickup_ids := {}
	for node in restored_pickups:
		var pickup := node as NeonPickup
		if pickup != null:
			restored_pickup_ids[String(pickup.pickup_id)] = true
	_check(not restored_pickup_ids.has("data_bridge_ammo"), "completed Data Lane ammo does not respawn at Warden checkpoint")
	_check(restored_pickup_ids.has("boss_left_gantry_shield"), "upcoming Boss gantry shield remains available after checkpoint restore")
	_check(restored_pickup_ids.has("extraction_dock_health"), "upcoming Extraction health remains available after checkpoint restore")

	MissionProgressStore.clear()
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
		print("checkpoint world restore tests: PASS")
		quit(0)
	else:
		print("checkpoint world restore tests: FAIL (%d)" % failures)
		quit(1)
