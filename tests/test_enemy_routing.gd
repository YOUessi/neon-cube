extends SceneTree

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const PLAYER_SCENE = preload("res://scenes/player.tscn")
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

	enemy.queue_free()
	boss.queue_free()
	perched.queue_free()
	player.queue_free()
	await process_frame
	_finish()

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
