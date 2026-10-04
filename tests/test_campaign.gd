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
	_check(game.wave_plan(1).size() == game.starting_enemies, "wave one uses configured starting count")
	_check(game.wave_plan(3).has("sniper"), "mid campaign introduces snipers")
	_check(game.wave_plan(4).has("tank"), "later campaign introduces tanks")
	var final_plan: Array[String] = game.wave_plan(game.total_waves)
	_check(final_plan.count("boss") == 1, "final wave contains exactly one boss")
	_check(final_plan.size() >= 6, "final wave includes boss support units")

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
