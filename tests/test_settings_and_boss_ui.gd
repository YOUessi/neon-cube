extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: NeonGame = MAIN_SCENE.instantiate() as NeonGame
	root.add_child(game)
	await process_frame

	_check(game.settings_panel != null, "settings panel exists")
	_check(game.credits_panel != null, "credits panel exists")
	_check(game.boss_bar != null, "boss health bar exists")
	game._on_mouse_sensitivity_changed(0.0031)
	_check(absf(game.get_mouse_sensitivity_setting() - 0.0031) < 0.00001, "mouse sensitivity setting updates")
	game._on_master_volume_changed(-12.0)
	_check(is_equal_approx(game.get_master_volume_db(), -12.0), "master volume setting updates")
	game._on_boss_health_changed(400.0, 800.0, 2)
	_check(game.boss_bar.visible, "boss health bar becomes visible")
	_check(is_equal_approx(game.boss_bar.value, 400.0), "boss health value updates")
	_check(game.boss_label.text.contains("PHASE 2"), "boss phase label updates")

	game.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, label: String) -> void:
	if condition: print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("settings and boss UI tests: PASS")
		quit(0)
	else:
		print("settings and boss UI tests: FAIL (%d)" % failures)
		quit(1)
