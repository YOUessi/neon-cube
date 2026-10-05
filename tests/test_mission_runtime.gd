extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var mission := MissionCatalog.primary()
	_check(MissionCatalog.validate_all().is_empty(), "Neon Market Siege definition validates")
	_check(mission.encounter_count() == 6, "mission contains six authored encounters")
	_check(mission.get_encounter(2).district_id == &"industrial_arc", "mission crosses to Industrial Arc")
	_check(mission.get_encounter(4).boss_encounter, "mission contains authored boss encounter")

	var runtime := MissionRuntime.new()
	runtime.start(mission)
	_check(runtime.state == MissionRuntime.State.ACTIVE, "mission runtime starts active")
	_check(runtime.current_encounter().encounter_id == &"arrival_ambush", "mission begins at arrival encounter")

	runtime.complete_current_encounter()
	_check(runtime.checkpoint_id == &"cp_market_ingress", "encounter completion records checkpoint")
	_check(runtime.current_encounter().encounter_id == &"market_crossfire", "runtime advances to next encounter")

	var snapshot := runtime.snapshot()
	var restored := MissionRuntime.new()
	restored.restore(mission, snapshot)
	_check(restored.current_encounter().encounter_id == &"market_crossfire", "mission snapshot restores active encounter")
	_check(restored.checkpoint_id == &"cp_market_ingress", "mission snapshot restores checkpoint")

	restored.fail()
	_check(restored.state == MissionRuntime.State.FAILED, "mission can enter failed state")
	restored.restart_from_checkpoint()
	_check(restored.state == MissionRuntime.State.ACTIVE, "mission restarts from checkpoint")
	_check(restored.current_encounter().encounter_id == &"market_crossfire", "checkpoint restart resumes after completed encounter")

	while restored.state == MissionRuntime.State.ACTIVE:
		restored.complete_current_encounter()
	_check(restored.state == MissionRuntime.State.COMPLETED, "mission completes after final encounter")
	_check(restored.completed_encounters.size() == mission.encounter_count(), "all encounters recorded complete")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("mission runtime tests: PASS")
		quit(0)
	else:
		print("mission runtime tests: FAIL (%d)" % failures)
		quit(1)
