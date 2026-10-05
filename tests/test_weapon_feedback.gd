extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runtime := WeaponFeedbackRuntime.new()
	var rifle := WeaponCatalog.get_definition(0)
	var shotgun := WeaponCatalog.get_definition(1)
	var marksman := WeaponCatalog.get_definition(2)

	var rifle_recoil := runtime.apply_shot(rifle, 1.0)
	_check(is_equal_approx(rifle_recoil.x, rifle.recoil_pitch_degrees), "rifle pitch impulse follows weapon data")
	_check(is_equal_approx(rifle_recoil.y, rifle.recoil_yaw_degrees), "rifle yaw impulse follows weapon data")
	_check(runtime.view_kick() > 0.0, "firing creates view-model kick")

	var before_recovery := runtime.view_kick()
	runtime.tick(0.1, rifle)
	_check(runtime.view_kick() < before_recovery, "view-model kick recovers over time")

	runtime.reset()
	var shotgun_recoil := runtime.apply_shot(shotgun, 1.0)
	_check(shotgun_recoil.x > rifle_recoil.x, "scattergun has heavier pitch recoil than rifle")
	_check(shotgun.view_kick_distance > rifle.view_kick_distance, "scattergun has stronger view kick")

	runtime.reset()
	var marksman_recoil := runtime.apply_shot(marksman, -1.0)
	_check(marksman_recoil.y < 0.0, "signed yaw sample changes recoil direction")
	_check(marksman.recoil_yaw_degrees < shotgun.recoil_yaw_degrees, "marksman remains more horizontally stable than scattergun")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("weapon feedback tests: PASS")
		quit(0)
	else:
		print("weapon feedback tests: FAIL (%d)" % failures)
		quit(1)
