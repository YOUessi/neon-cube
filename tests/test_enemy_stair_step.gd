extends SceneTree

const ENEMY := preload("res://scenes/enemy.tscn")
const PLAYER := preload("res://scenes/player.tscn")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_bottom_face_enemy_step()
	await _test_left_face_enemy_step()
	await _test_perch_leash_blocks_step()
	_finish()


func _test_bottom_face_enemy_step() -> void:
	var world := Node3D.new()
	root.add_child(world)

	_add_box(world, "Floor", Vector3(0, -29.60, 0), Vector3(12.0, 0.20, 12.0))
	var step := _add_box(
		world,
		"LowStep",
		Vector3(0, -29.29, -0.75),
		Vector3(3.0, 0.42, 0.70)
	)

	var target := _make_target(world, Vector3(0, -28.35, 0.2))
	var enemy := _make_enemy(world, target, Vector3(0, -28.35, 0))
	await _settle_enemy(enemy)

	_check(enemy.gravity_down.is_equal_approx(Vector3.DOWN), "enemy stair test uses floor gravity")
	_check(enemy.is_on_floor(), "enemy stair test settles on bottom floor")

	enemy.set_physics_process(false)
	var before := enemy.global_position
	var stepped := enemy._try_auto_step(Vector3.FORWARD)
	_check(stepped, "non-perch enemy auto-steps a 0.42m stair")
	_check(enemy.global_position.y > before.y + 0.35, "enemy stair lift follows bottom-face local up")

	step.queue_free()
	await physics_frame
	enemy.global_position = Vector3(0, -28.55, 0)
	enemy.velocity = Vector3.ZERO
	enemy.set_physics_process(true)
	await _settle_enemy(enemy)
	enemy.set_physics_process(false)

	_add_box(
		world,
		"TallWall",
		Vector3(0, -28.95, -0.75),
		Vector3(3.0, 1.10, 0.70)
	)
	await physics_frame
	var wall_before := enemy.global_position
	var climbed_wall := enemy._try_auto_step(Vector3.FORWARD)
	_check(not climbed_wall, "enemy does not auto-step a 1.10m wall")
	_check(enemy.global_position.distance_to(wall_before) < 0.02, "failed enemy wall step leaves position unchanged")

	world.queue_free()
	await process_frame


func _test_left_face_enemy_step() -> void:
	var world := Node3D.new()
	root.add_child(world)

	_add_box(world, "LeftFloor", Vector3(-29.60, 0, 0), Vector3(0.20, 12.0, 12.0))
	_add_box(
		world,
		"LeftLowStep",
		Vector3(-29.29, 0, -0.75),
		Vector3(0.42, 3.0, 0.70)
	)

	var target := _make_target(world, Vector3(-28.35, 0, 0.2))
	var enemy := _make_enemy(world, target, Vector3(-28.35, 0, 0))
	await _settle_enemy(enemy)

	_check(enemy.gravity_down.is_equal_approx(Vector3.LEFT), "enemy side-face stair acquires Data Quarter gravity")
	_check(enemy.is_on_floor(), "enemy side-face stair settles on wall-floor")

	enemy.set_physics_process(false)
	var before := enemy.global_position
	var stepped := enemy._try_auto_step(Vector3.FORWARD)
	_check(stepped, "enemy auto-steps on a non-horizontal cube face")
	_check(enemy.global_position.x > before.x + 0.35, "enemy side-face stair lift follows local +X up")

	world.queue_free()
	await process_frame


func _test_perch_leash_blocks_step() -> void:
	var world := Node3D.new()
	root.add_child(world)

	_add_box(world, "Floor", Vector3(0, -29.60, 0), Vector3(12.0, 0.20, 12.0))
	_add_box(
		world,
		"LowStep",
		Vector3(0, -29.29, -0.75),
		Vector3(3.0, 0.42, 0.70)
	)

	var target := _make_target(world, Vector3(0, -28.35, 0.2))
	var enemy := _make_enemy(world, target, Vector3(0, -28.35, 0))
	await _settle_enemy(enemy)
	enemy.set_physics_process(false)
	enemy.set_tactical_leash(enemy.global_position, 0.55)

	var before := enemy.global_position
	var stepped := enemy._try_auto_step(Vector3.FORWARD)
	_check(not stepped, "perch-leashed enemy never invokes automatic stair traversal")
	_check(enemy.global_position.distance_to(before) < 0.02, "perch-leashed enemy stays anchored on authored platform")

	world.queue_free()
	await process_frame


func _make_enemy(parent: Node3D, target: NeonPlayer, position: Vector3) -> NeonEnemy:
	var enemy := ENEMY.instantiate() as NeonEnemy
	enemy.cube_half_extent = 30.0
	enemy.configure("grunt", 1, 1.0)
	enemy.target = target
	enemy.position = position
	parent.add_child(enemy)
	return enemy


func _make_target(parent: Node3D, position: Vector3) -> NeonPlayer:
	var target := PLAYER.instantiate() as NeonPlayer
	target.cube_half_extent = 30.0
	target.position = position
	parent.add_child(target)
	target.set_physics_process(false)
	return target


func _settle_enemy(enemy: NeonEnemy, frames: int = 60) -> void:
	enemy.set_physics_process(true)
	for i in range(frames):
		await physics_frame
		await process_frame
		if enemy.is_on_floor():
			return


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
		print("enemy stair step tests: PASS")
		quit(0)
	else:
		print("enemy stair step tests: FAIL (%d)" % failures)
		quit(1)
