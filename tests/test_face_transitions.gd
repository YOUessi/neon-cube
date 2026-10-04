extends SceneTree

const Gravity = preload("res://scripts/cube_gravity.gd")
var failures := 0

func _init() -> void:
	_check(Gravity.nearest_down(Vector3(0, -29.4, 0), 30.0) == Vector3.DOWN, "bottom face selected")
	_check(Gravity.nearest_down(Vector3(29.4, 0, 0), 30.0) == Vector3.RIGHT, "+X face selected")
	_check(Gravity.nearest_down(Vector3(-29.4, 0, 0), 30.0) == Vector3.LEFT, "-X face selected")
	_check(Gravity.nearest_down(Vector3(0, 29.4, 0), 30.0) == Vector3.UP, "ceiling selected")
	_check(Gravity.nearest_down(Vector3(0, 0, 29.4), 30.0) == Vector3.BACK, "+Z face selected")
	_check(Gravity.nearest_down(Vector3(0, 0, -29.4), 30.0) == Vector3.FORWARD, "-Z face selected")

	var current := Vector3.DOWN
	current = Gravity.nearest_down(Vector3(29.0, -29.15, 0), 30.0, current, 0.32)
	_check(current == Vector3.DOWN, "hysteresis holds current face near tie")
	current = Gravity.nearest_down(Vector3(29.55, -28.7, 0), 30.0, current, 0.32)
	_check(current == Vector3.RIGHT, "gravity switches once adjacent face is decisively closer")

	for down in Gravity.AXIS_DOWNS:
		var basis := Gravity.tangent_basis(down)
		_check(absf(basis.y.normalized().dot(-down.normalized()) - 1.0) < 0.0001, "basis up opposes gravity for %s" % Gravity.face_name(down))
		_check(absf(basis.determinant() - 1.0) < 0.0001, "basis remains orthonormal for %s" % Gravity.face_name(down))

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("face transition tests: PASS")
		quit(0)
	else:
		print("face transition tests: FAIL (%d)" % failures)
		quit(1)
