extends SceneTree

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const MISSION_LEVEL_SCENE = preload("res://scenes/missions/neon_market_siege.tscn")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player: NeonPlayer = PLAYER_SCENE.instantiate() as NeonPlayer
	root.add_child(player)
	player.global_position = Vector3(29.0, 0.0, 0.0)
	await process_frame

	var enemy: NeonEnemy = ENEMY_SCENE.instantiate() as NeonEnemy
	enemy.target = player
	enemy.cube_half_extent = 30.0
	enemy.configure("runner", 3)
	enemy.position = Vector3(0.0, -29.0, 0.0)
	root.add_child(enemy)
	await process_frame

	var direction: Vector3 = CubeGravity.surface_route_direction(enemy.global_position, Vector3.DOWN, player.global_position, 30.0)
	_check(direction.dot(Vector3.RIGHT) > 0.9, "cross-face route points toward shared +X edge")
	_check(enemy.move_speed > 6.0, "runner archetype applies fast movement")
	_check(enemy.get_score_value() == 130, "runner score value configured")

	var boss: NeonEnemy = ENEMY_SCENE.instantiate() as NeonEnemy
	boss.configure("boss", 6)
	boss.position = Vector3(0, -29, 4)
	root.add_child(boss)
	await process_frame
	_check(boss.max_health >= 800.0, "boss health profile applied")
	_check(boss.get_score_value() >= 2000, "boss score profile applied")

	var perched: NeonEnemy = ENEMY_SCENE.instantiate() as NeonEnemy
	perched.configure("sniper", 2)
	perched.position = Vector3(0.70, -29.0, 0.0)
	root.add_child(perched)
	await process_frame
	perched.set_physics_process(false)
	perched.set_tactical_leash(Vector3(0.0, -29.0, 0.0), 0.75)
	var outward_velocity := Vector3(4.0, 0.0, 0.0)
	var clamped_velocity := perched._clamp_tactical_leash_velocity(outward_velocity)
	_check(clamped_velocity.x < outward_velocity.x, "perch leash suppresses outward horizontal momentum near edge")
	_check(clamped_velocity.x >= 0.0, "perch leash does not reverse velocity before hard boundary")

	perched.set_tactical_leash(Vector3.ZERO, 0.0)
	var unrestricted_velocity := perched._clamp_tactical_leash_velocity(outward_velocity)
	_check(unrestricted_velocity.is_equal_approx(outward_velocity), "zero-radius leash leaves ordinary enemy momentum unchanged")

	await _test_enemy_auto_step_bottom_face()
	await _test_enemy_auto_step_side_face()
	await _test_perch_leash_blocks_stair_step()
	await _test_data_bridge_authored_route_pursuit()

	enemy.queue_free()
	boss.queue_free()
	perched.queue_free()
	player.queue_free()
	await process_frame
	_finish()

func _test_enemy_auto_step_bottom_face() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_add_test_box(world, Vector3(0, -29.60, 0), Vector3(12.0, 0.20, 12.0))
	var low_step := _add_test_box(
		world,
		Vector3(0, -29.29, -0.75),
		Vector3(3.0, 0.42, 0.70)
	)
	var target := _make_stair_target(world, Vector3(0, -26.35, 0.0))
	var stair_enemy := _make_stair_enemy(world, target, Vector3(0, -28.35, 0))
	await _settle_stair_enemy(stair_enemy)

	_check(stair_enemy.is_on_floor(), "enemy stair test settles on authored floor")
	stair_enemy.set_physics_process(false)
	var before := stair_enemy.global_position
	_check(stair_enemy._try_auto_step(Vector3.FORWARD), "ordinary enemy auto-steps a 0.42m stair")
	_check(stair_enemy.global_position.y > before.y + 0.35, "enemy bottom-face stair lift follows local up")

	low_step.queue_free()
	await physics_frame
	stair_enemy.global_position = Vector3(0, -28.55, 0)
	stair_enemy.velocity = Vector3.ZERO
	stair_enemy.set_physics_process(true)
	await _settle_stair_enemy(stair_enemy)
	stair_enemy.set_physics_process(false)
	_add_test_box(world, Vector3(0, -28.95, -0.75), Vector3(3.0, 1.10, 0.70))
	await physics_frame
	var wall_before := stair_enemy.global_position
	_check(not stair_enemy._try_auto_step(Vector3.FORWARD), "ordinary enemy cannot auto-step a 1.10m wall")
	_check(stair_enemy.global_position.distance_to(wall_before) < 0.02, "failed enemy wall step keeps position unchanged")

	world.queue_free()
	await process_frame


func _test_enemy_auto_step_side_face() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_add_test_box(world, Vector3(-29.60, 0, 0), Vector3(0.20, 12.0, 12.0))
	_add_test_box(world, Vector3(-29.29, 0, -0.75), Vector3(0.42, 3.0, 0.70))
	var target := _make_stair_target(world, Vector3(-26.35, 0, 0.0))
	var stair_enemy := _make_stair_enemy(world, target, Vector3(-28.35, 0, 0))
	await _settle_stair_enemy(stair_enemy)

	_check(stair_enemy.gravity_down.is_equal_approx(Vector3.LEFT), "enemy stair solver acquires Data Quarter gravity")
	stair_enemy.set_physics_process(false)
	var before := stair_enemy.global_position
	_check(stair_enemy._try_auto_step(Vector3.FORWARD), "enemy auto-steps on non-horizontal cube face")
	_check(stair_enemy.global_position.x > before.x + 0.35, "enemy side-face stair lift follows local +X up")

	world.queue_free()
	await process_frame


func _test_perch_leash_blocks_stair_step() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_add_test_box(world, Vector3(0, -29.60, 0), Vector3(12.0, 0.20, 12.0))
	_add_test_box(world, Vector3(0, -29.29, -0.75), Vector3(3.0, 0.42, 0.70))
	var target := _make_stair_target(world, Vector3(0, -26.35, 0.0))
	var stair_enemy := _make_stair_enemy(world, target, Vector3(0, -28.35, 0))
	await _settle_stair_enemy(stair_enemy)
	stair_enemy.set_physics_process(false)
	stair_enemy.set_tactical_leash(stair_enemy.global_position, 0.55)

	var before := stair_enemy.global_position
	_check(not stair_enemy._try_auto_step(Vector3.FORWARD), "perch-leashed enemy ignores stair traversal")
	_check(stair_enemy.global_position.distance_to(before) < 0.02, "perch-leashed enemy stays on authored perch")

	world.queue_free()
	await process_frame


func _test_data_bridge_authored_route_pursuit() -> void:
	var world := Node3D.new()
	world.name = "DataBridgePursuitWorld"
	root.add_child(world)

	# Supply the physical cube-face floor that CyberCityBuilder normally owns.
	_add_test_box(
		world,
		# Data Lane authored surface is x=-29.55 on the LEFT face. With a
		# 0.20m test slab, center at -29.65 so its top matches the real floor;
		# otherwise the authored 0.46m first step becomes an artificial 0.81m.
		Vector3(-29.65, 8.0, -8.0),
		Vector3(0.20, 30.0, 30.0)
	)

	var level := MISSION_LEVEL_SCENE.instantiate() as NeonMarketSiegeLevel
	world.add_child(level)
	await process_frame
	var routes: Array = level.route_points_for(&"data_lane")
	_check(routes.size() == 9, "Data pursuit fixture receives elevated authored route chain")
	if routes.size() != 9:
		world.queue_free()
		await process_frame
		return

	var target := _make_stair_target(world, routes[8])
	var pursuer := _make_stair_enemy(world, target, routes[6])
	pursuer.set_route_points(routes)
	await _settle_stair_enemy(pursuer)

	var up := -Vector3.LEFT
	var start_position := pursuer.global_position
	var initial_distance := start_position.distance_to(target.global_position)
	var climbed := false
	for i in range(360):
		await physics_frame
		await process_frame
		var elevation_gain := (pursuer.global_position - start_position).dot(up)
		if elevation_gain > 1.20:
			climbed = true
			break

	_check(climbed, "Data Lane pursuer uses authored stairs to gain bridge elevation")
	_check(
		pursuer.global_position.distance_to(target.global_position) < initial_distance,
		"Data Lane pursuer closes distance toward player on Maintenance Bridge"
	)

	world.queue_free()
	await process_frame


func _make_stair_enemy(parent: Node3D, target: NeonPlayer, position: Vector3) -> NeonEnemy:
	var enemy := ENEMY_SCENE.instantiate() as NeonEnemy
	enemy.cube_half_extent = 30.0
	enemy.configure("grunt", 1)
	enemy.target = target
	enemy.position = position
	parent.add_child(enemy)
	return enemy


func _make_stair_target(parent: Node3D, position: Vector3) -> NeonPlayer:
	var target := PLAYER_SCENE.instantiate() as NeonPlayer
	target.cube_half_extent = 30.0
	target.position = position
	parent.add_child(target)
	target.set_physics_process(false)
	return target


func _settle_stair_enemy(enemy: NeonEnemy, frames: int = 60) -> void:
	enemy.set_physics_process(true)
	for i in range(frames):
		await physics_frame
		await process_frame
		if enemy.is_on_floor():
			return


func _add_test_box(parent: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
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
		print("enemy routing tests: PASS")
		quit(0)
	else:
		print("enemy routing tests: FAIL (%d)" % failures)
		quit(1)
