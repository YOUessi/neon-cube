extends SceneTree

const PLAYER := preload("res://scenes/player.tscn")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_bottom_face_step_and_wall()
	await _test_left_face_step()
	_finish()


func _test_bottom_face_step_and_wall() -> void:
	var world := Node3D.new()
	world.name = "BottomFaceStairWorld"
	root.add_child(world)

	_add_box(world, "Floor", Vector3(0, -29.60, 0), Vector3(12.0, 0.20, 12.0))
	var step := _add_box(
		world,
		"LowStep",
		Vector3(0, -29.29, -0.75),
		Vector3(3.0, 0.42, 0.70)
	)

	var player: NeonPlayer = PLAYER.instantiate() as NeonPlayer
	player.position = Vector3(0, -28.35, 0)
	world.add_child(player)
	await _settle_player(player)

	_check(player.gravity_down.is_equal_approx(Vector3.DOWN), "bottom stair test uses floor gravity")
	_check(player.is_on_floor(), "bottom stair test player settles on floor")

	player.set_physics_process(false)
	var before := player.global_position
	var stepped := player._try_auto_step(Vector3.FORWARD)
	_check(stepped, "player auto-steps a 0.42m authored stair")
	_check(
		player.global_position.y > before.y + 0.35,
		"bottom-face stair lift moves player along local up"
	)

	step.queue_free()
	await physics_frame

	player.global_position = Vector3(0, -28.55, 0)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await _settle_player(player)
	player.set_physics_process(false)

	_add_box(
		world,
		"TallWall",
		Vector3(0, -28.95, -0.75),
		Vector3(3.0, 1.10, 0.70)
	)
	await physics_frame
	var wall_before := player.global_position
	var climbed_wall := player._try_auto_step(Vector3.FORWARD)
	_check(not climbed_wall, "player does not auto-step a 1.10m wall")
	_check(
		player.global_position.distance_to(wall_before) < 0.02,
		"failed wall step leaves player position unchanged"
	)

	world.queue_free()
	await process_frame


func _test_left_face_step() -> void:
	var world := Node3D.new()
	world.name = "LeftFaceStairWorld"
	root.add_child(world)

	_add_box(world, "LeftFloor", Vector3(-29.60, 0, 0), Vector3(0.20, 12.0, 12.0))
	_add_box(
		world,
		"LeftLowStep",
		Vector3(-29.29, 0, -0.75),
		Vector3(0.42, 3.0, 0.70)
	)

	var player: NeonPlayer = PLAYER.instantiate() as NeonPlayer
	player.position = Vector3(-28.35, 0, 0)
	world.add_child(player)
	await _settle_player(player, 10)

	_check(player.gravity_down.is_equal_approx(Vector3.LEFT), "side stair test acquires Data Quarter gravity")
	_check(player.is_on_floor(), "side stair test player settles onto wall-floor")

	player.set_physics_process(false)
	var before := player.global_position
	var stepped := player._try_auto_step(Vector3.FORWARD)
	_check(stepped, "player auto-steps on a non-horizontal cube face")
	_check(
		player.global_position.x > before.x + 0.35,
		"side-face stair lift follows local +X up instead of world Y"
	)

	world.queue_free()
	await process_frame


func _settle_player(player: NeonPlayer, frames: int = 8) -> void:
	player.set_physics_process(true)
	for i in range(frames):
		await physics_frame
		await process_frame


func _add_box(parent: Node3D, name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if failures == 0:
		print("player stair step tests: PASS")
		quit(0)
	else:
		print("player stair step tests: FAIL (%d)" % failures)
		quit(1)
