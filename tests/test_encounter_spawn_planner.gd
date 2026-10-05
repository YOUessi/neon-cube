extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var mission := MissionCatalog.primary()
	for encounter in mission.encounters:
		var positions := EncounterSpawnPlanner.spawn_positions(encounter, encounter.enemy_kinds.size(), 60.0)
		_check(positions.size() == encounter.enemy_kinds.size(), "%s creates one position per hostile" % encounter.encounter_id)
		var unique := {}
		for position in positions:
			_check(EncounterSpawnPlanner.on_expected_face(position, encounter, 60.0), "%s spawn stays on authored district face" % encounter.encounter_id)
			var key := "%0.2f,%0.2f,%0.2f" % [position.x, position.y, position.z]
			_check(not unique.has(key), "%s spawn positions remain unique" % encounter.encounter_id)
			unique[key] = true

	var first := mission.encounters[0]
	var first_positions := EncounterSpawnPlanner.spawn_positions(first, 4, 60.0)
	var repeated_positions := EncounterSpawnPlanner.spawn_positions(first, 4, 60.0)
	_check(first_positions == repeated_positions, "spawn planning is deterministic")
	var shifted := EncounterSpawnPlanner.spawn_positions(first, 4, 60.0, 4)
	_check(first_positions != shifted, "sequence offset changes later encounter placement")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("encounter spawn planner tests: PASS")
		quit(0)
	else:
		print("encounter spawn planner tests: FAIL (%d)" % failures)
		quit(1)
