extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var vitals := PlayerVitals.new()
	vitals.configure(100.0, 50.0, 3.0, 10.0)
	_check(is_equal_approx(vitals.health(), 100.0), "vitals starts at full health")
	_check(is_equal_approx(vitals.shield(), 50.0), "vitals starts at full shield")

	vitals.take_damage(30.0)
	_check(is_equal_approx(vitals.health(), 100.0), "shield absorbs damage before health")
	_check(is_equal_approx(vitals.shield(), 20.0), "shield decreases by absorbed damage")

	vitals.take_damage(35.0)
	_check(is_equal_approx(vitals.shield(), 0.0), "shield can be depleted")
	_check(is_equal_approx(vitals.health(), 85.0), "overflow damage reaches health")

	vitals.tick(2.9)
	_check(is_equal_approx(vitals.shield(), 0.0), "shield does not regenerate before delay")
	vitals.tick(0.2)
	vitals.tick(1.0)
	_check(vitals.shield() > 0.0, "shield regenerates after delay")

	vitals.heal(999.0)
	_check(is_equal_approx(vitals.health(), 100.0), "healing clamps to max health")
	vitals.grant_shield(999.0)
	_check(is_equal_approx(vitals.shield(), 50.0), "shield grant clamps to max shield")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("player vitals tests: PASS")
		quit(0)
	else:
		print("player vitals tests: FAIL (%d)" % failures)
		quit(1)
