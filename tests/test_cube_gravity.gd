extends SceneTree

const Gravity = preload("res://scripts/cube_gravity.gd")
var failures := 0

func _initialize() -> void:
	_check(Gravity.nearest_down(Vector3(0, -29, 0), 30.0) == Vector3.DOWN, "bottom face")
	_check(Gravity.nearest_down(Vector3(29, 0, 0), 30.0) == Vector3.RIGHT, "+X face")
	_check(Gravity.nearest_down(Vector3(-29, 0, 0), 30.0) == Vector3.LEFT, "-X face")
	_check(Gravity.nearest_down(Vector3(0, 29, 0), 30.0) == Vector3.UP, "ceiling face")
	_check(Gravity.nearest_down(Vector3(0, 0, 29), 30.0) == Vector3.BACK, "+Z face")
	_check(Gravity.nearest_down(Vector3(0, 0, -29), 30.0) == Vector3.FORWARD, "-Z face")
	var held := Gravity.nearest_down(Vector3(29.1, -28.7, 0), 30.0, Vector3.DOWN, 0.32)
	_check(held == Vector3.RIGHT, "edge gravity switches when adjacent face is closer")
	if failures == 0:
		print("cube gravity tests: PASS")
		quit(0)
	else:
		print("cube gravity tests: FAIL (%d)" % failures)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)
