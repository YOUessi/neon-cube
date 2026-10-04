extends SceneTree

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var boss: NeonEnemy = ENEMY_SCENE.instantiate() as NeonEnemy
	boss.configure("boss", 6, 1.0)
	root.add_child(boss)
	await process_frame
	_check(boss.get_boss_phase() == 1, "boss starts in phase one")
	var start_health: float = boss.get_health()
	boss.take_damage(start_health * 0.45)
	_check(boss.get_boss_phase() == 2, "boss enters phase two below sixty percent")
	boss.take_damage(start_health * 0.30)
	_check(boss.get_boss_phase() == 3, "boss enters phase three below thirty percent")
	boss.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, label: String) -> void:
	if condition: print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("boss phase tests: PASS")
		quit(0)
	else:
		print("boss phase tests: FAIL (%d)" % failures)
		quit(1)
