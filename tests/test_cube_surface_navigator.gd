extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var faces: Array = CubeGravity.AXIS_DOWNS
	for start in faces:
		for target in faces:
			var path := CubeSurfaceNavigator.shortest_face_path(start, target)
			_check(not path.is_empty(), "path exists %s -> %s" % [CubeGravity.face_name(start), CubeGravity.face_name(target)])
			_check(path[0].is_equal_approx(start), "path starts on requested face")
			_check(path[path.size() - 1].is_equal_approx(target), "path reaches requested face")
			for i in range(path.size() - 1):
				_check(
					CubeSurfaceNavigator.are_adjacent(path[i], path[i + 1]),
					"path only crosses shared cube edges"
				)
			if start.is_equal_approx(target):
				_check(path.size() == 1, "same-face path is one node")
			elif start.is_equal_approx(-target):
				_check(path.size() == 3, "opposite faces require two edge transitions")
			else:
				_check(path.size() == 2, "adjacent faces require one edge transition")

	var half := 30.0
	var from_position := Vector3(20.0, -29.0, 0.0)
	var opposite_target := Vector3(18.0, 29.0, 0.0)
	var direction := CubeSurfaceNavigator.route_direction(
		from_position,
		Vector3.DOWN,
		opposite_target,
		half
	)
	_check(direction.length() > 0.9, "opposite-face route produces a tangent direction")
	_check(absf(direction.dot(Vector3.DOWN)) < 0.01, "route direction remains tangent to current face")
	_check(direction.dot(Vector3.RIGHT) > 0.9, "opposite-face route chooses nearby east seam")

	var west_from := Vector3(-19.0, -29.0, 0.0)
	var west_target := Vector3(-17.0, 29.0, 0.0)
	var west_direction := CubeSurfaceNavigator.route_direction(
		west_from,
		Vector3.DOWN,
		west_target,
		half
	)
	_check(west_direction.dot(Vector3.LEFT) > 0.9, "opposite-face route chooses nearby west seam")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("cube surface navigator tests: PASS")
		quit(0)
	else:
		print("cube surface navigator tests: FAIL (%d)" % failures)
		quit(1)
