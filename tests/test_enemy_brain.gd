extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var route := Vector3.RIGHT
	var down := Vector3.DOWN

	var runner := EnemyCatalog.get_definition(&"runner")
	var runner_dir := EnemyBrain.desired_direction(runner, true, 4.0, route, down)
	_check(runner_dir.dot(route) > 0.9, "runner keeps closing distance")

	var sniper := EnemyCatalog.get_definition(&"sniper")
	var sniper_retreat := EnemyBrain.desired_direction(sniper, true, 4.0, route, down)
	_check(sniper_retreat.dot(route) < -0.9, "sniper retreats when player is too close")
	var sniper_hold := EnemyBrain.desired_direction(sniper, true, 18.0, route, down)
	_check(sniper_hold.length_squared() < 0.01, "sniper holds preferred firing distance")
	var sniper_cross_face := EnemyBrain.desired_direction(sniper, false, 18.0, route, down)
	_check(sniper_cross_face.dot(route) > 0.9, "sniper still traverses edges to reach target face")

	var tank := EnemyCatalog.get_definition(&"tank")
	var tank_hold := EnemyBrain.desired_direction(tank, true, 8.0, route, down)
	_check(tank_hold.length_squared() < 0.01, "tank anchors inside combat range")

	var boss := EnemyCatalog.get_definition(&"boss")
	var boss_strafe := EnemyBrain.desired_direction(boss, true, 8.0, route, down, 1)
	_check(absf(boss_strafe.dot(route)) < 0.1, "boss strafes instead of standing still at close range")
	_check(absf(boss_strafe.dot(down)) < 0.1, "boss strafe remains tangent to current face")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("enemy brain tests: PASS")
		quit(0)
	else:
		print("enemy brain tests: FAIL (%d)" % failures)
		quit(1)
