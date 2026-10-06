extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var mission := MissionCatalog.primary()
	var runtime := MissionRuntime.new()
	runtime.start(mission)
	var session := GameSession.new()
	session.reset_run("NIGHTMARE", 1.28)
	session.add_enemy()
	session.register_kill(240)
	runtime.complete_current_encounter()
	runtime.mark_pickup_consumed(&"boss_left_gantry_shield")
	session.wave_index = runtime.encounter_index
	_check(runtime.checkpoint_id == &"cp_market_ingress", "runtime reached first checkpoint")

	var save_error := MissionProgressStore.save_runtime(runtime, session)
	_check(save_error == OK, "mission and session progress save through profile store")
	_check(MissionProgressStore.has_progress(mission), "saved checkpoint enables Continue Story")

	var restored := MissionRuntime.new()
	var restored_session := GameSession.new()
	_check(MissionProgressStore.load_into(restored, mission, restored_session), "saved mission progress can be loaded")
	_check(restored.checkpoint_id == &"cp_market_ingress", "loaded checkpoint matches saved checkpoint")
	_check(restored.current_encounter().encounter_id == &"market_crossfire", "loaded runtime restores current encounter")
	_check(restored_session.score == 240, "checkpoint restores accumulated score")
	_check(restored_session.kills == 1, "checkpoint restores kill count")
	_check(restored_session.difficulty_name == "NIGHTMARE", "checkpoint restores difficulty name")
	_check(restored.is_pickup_consumed(&"boss_left_gantry_shield"), "checkpoint restores consumed authored pickup IDs")
	_check(not restored.is_pickup_consumed(&"extraction_dock_health"), "checkpoint leaves unconsumed authored pickups available")
	_check(is_equal_approx(restored_session.difficulty_scale, 1.28), "checkpoint restores difficulty scale")

	var clear_error := MissionProgressStore.clear()
	_check(clear_error == OK, "mission progress can be cleared")
	_check(not MissionProgressStore.has_progress(mission), "clearing checkpoint disables Continue Story")
	var empty_runtime := MissionRuntime.new()
	_check(not MissionProgressStore.load_into(empty_runtime, mission), "cleared mission progress is not restored")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("mission progress store tests: PASS")
		quit(0)
	else:
		print("mission progress store tests: FAIL (%d)" % failures)
		quit(1)
