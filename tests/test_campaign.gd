extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: NeonGame = MAIN_SCENE.instantiate() as NeonGame
	root.add_child(game)
	await process_frame

	_check(game.game_state == NeonGame.GameState.PLAYING, "headless startup enters active game")
	_check(game.story_mode, "story mission is the default run mode")
	_check(game.mission_runtime.state == MissionRuntime.State.ACTIVE, "story mission runtime starts active")
	_check(game.mission_runtime.current_encounter().encounter_id == &"arrival_ambush", "story starts at authored arrival encounter")
	_check(game.mission_definition.encounter_count() == 6, "story contains six authored encounters")
	_check(game.mission_definition.get_encounter(2).enemy_kinds.has(&"sniper"), "mid-mission encounter includes sniper pressure")
	_check(game.mission_definition.get_encounter(3).enemy_kinds.has(&"tank"), "later mission encounter includes tanks")
	_check(game.mission_definition.get_encounter(4).enemy_kinds.count(&"boss") == 1, "story contains exactly one Null Warden boss")
	_check(game.mission_definition.get_encounter(5).encounter_id == &"extraction", "story ends with an extraction encounter")

	# The arcade campaign remains available as a separate data set during migration.
	_check(game.wave_plan(1).size() == game.campaign.get_wave(0).enemy_kinds.size(), "legacy arcade wave data remains accessible")
	var final_arcade_plan := game.wave_plan(game.campaign.wave_count())
	_check(final_arcade_plan.count("boss") == 1, "arcade campaign still retains boss finale")

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
		print("campaign tests: PASS")
		quit(0)
	else:
		print("campaign tests: FAIL (%d)" % failures)
		quit(1)
