extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := EnemyAttackRuntime.new()
	_check(not runtime.is_pending(), "attack runtime starts idle")

	runtime.begin(0.55)
	_check(runtime.is_pending(), "begin enters windup state")
	_check(is_equal_approx(runtime.remaining(), 0.55), "windup duration is recorded")
	_check(not runtime.tick(0.20), "partial tick does not fire attack")
	_check(runtime.is_pending(), "attack stays pending during windup")
	_check(runtime.remaining() > 0.34 and runtime.remaining() < 0.36, "remaining windup decreases with delta")
	_check(not runtime.tick(0.30), "attack remains pending before windup expires")
	_check(runtime.tick(0.06), "attack fires once windup expires")
	_check(not runtime.is_pending(), "runtime returns idle after firing")
	_check(not runtime.tick(1.0), "idle runtime never double-fires")

	runtime.begin(0.4)
	runtime.cancel()
	_check(not runtime.is_pending(), "cancel clears a pending attack")
	_check(is_equal_approx(runtime.remaining(), 0.0), "cancel clears remaining windup")

	var grunt := EnemyCatalog.get_definition(&"grunt")
	var runner := EnemyCatalog.get_definition(&"runner")
	var sniper := EnemyCatalog.get_definition(&"sniper")
	var tank := EnemyCatalog.get_definition(&"tank")
	var boss := EnemyCatalog.get_definition(&"boss")
	_check(sniper.attack_windup > grunt.attack_windup, "sniper has longer telegraph than grunt")
	_check(sniper.attack_windup > tank.attack_windup, "sniper remains the most readable precision windup")
	_check(runner.attack_windup < grunt.attack_interval, "runner windup fits inside attack cadence")
	_check(boss.attack_windup < boss.attack_interval, "boss windup fits inside pressure cadence")
	_check(not sniper.attack_fx_color.is_equal_approx(tank.attack_fx_color), "sniper and tank attack colors remain distinct")

	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if failures == 0:
		print("enemy attack runtime tests: PASS")
		quit(0)
	else:
		print("enemy attack runtime tests: FAIL (%d)" % failures)
		quit(1)
