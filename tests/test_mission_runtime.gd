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
	_check(mission.get_encounter(0).batch_count() == 1, "arrival remains a single-batch encounter")
	var market_batches := mission.get_encounter(1).effective_batch_sizes()
	_check(market_batches.size() == 2 and market_batches[0] == 3 and market_batches[1] == 2, "market crossfire uses 3+2 reinforcement pacing")
	_check(mission.get_encounter(1).reinforcement_trigger_remaining == 1, "market reinforcement triggers with one hostile remaining")
	var breach_batches := mission.get_encounter(2).effective_batch_sizes()
	_check(breach_batches.size() == 2 and breach_batches[0] == 2 and breach_batches[1] == 2, "gravity breach uses 2+2 pacing")
	_check(mission.get_encounter(4).batch_count() == 1, "Null Warden remains a single opening batch")
	_check(mission.get_encounter(3).objective_node_count == 2, "Data Lane requires two relay objectives")
	var extraction_batches := mission.get_encounter(5).effective_batch_sizes()
	_check(extraction_batches.size() == 2 and extraction_batches[0] == 2 and extraction_batches[1] == 2, "extraction uses 2+2 final pressure")

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
