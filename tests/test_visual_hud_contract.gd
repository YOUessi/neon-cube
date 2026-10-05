extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: NeonGame = MAIN_SCENE.instantiate() as NeonGame
	root.add_child(game)
	await process_frame

	_check(game.boss_bar != null, "boss health bar exists")
	_check(game.boss_label != null, "boss label exists")
	game._on_boss_health_changed(425.0, 850.0, 2)
	_check(game.boss_bar.visible, "boss bar becomes visible")
	_check(is_equal_approx(game.boss_bar.value, 425.0), "boss bar value updates")
	_check(game.boss_label.text.contains("PHASE 2"), "boss phase is visible in HUD")

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
		print("visual hud contract tests: PASS")
		quit(0)
	else:
		print("visual hud contract tests: FAIL (%d)" % failures)
		quit(1)
