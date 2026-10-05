extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var mission := MissionCatalog.primary()
	var runtime := MissionRuntime.new()
	runtime.start(mission)
	runtime.complete_current_encounter()
	_check(runtime.checkpoint_id == &"cp_market_ingress", "runtime reached first checkpoint")

	var save_error := MissionProgressStore.save_runtime(runtime)
	_check(save_error == OK, "mission progress saves through profile store")

	var restored := MissionRuntime.new()
	_check(MissionProgressStore.load_into(restored, mission), "saved mission progress can be loaded")
	_check(restored.checkpoint_id == &"cp_market_ingress", "loaded checkpoint matches saved checkpoint")
	_check(restored.current_encounter().encounter_id == &"market_crossfire", "loaded runtime restores current encounter")

	var clear_error := MissionProgressStore.clear()
	_check(clear_error == OK, "mission progress can be cleared")
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
