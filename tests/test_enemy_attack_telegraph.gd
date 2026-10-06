extends SceneTree

const PLAYER := preload("res://scenes/player.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var player: NeonPlayer = PLAYER.instantiate() as NeonPlayer
	player.cube_half_extent = 30.0
	world.add_child(player)
	player.global_position = Vector3(0, -28.5, 0)
	player.set_physics_process(false)

	var sniper: NeonEnemy = ENEMY.instantiate() as NeonEnemy
	sniper.cube_half_extent = 30.0
	sniper.target = player
	sniper.configure("sniper", 1, 1.0)
	world.add_child(sniper)
	sniper.global_position = Vector3(0, -28.5, 12.0)
	sniper.set_physics_process(false)

	await physics_frame
	await physics_frame

	var initial_shield := player.get_shield()
	sniper._begin_attack()
	_check(sniper.is_attack_winding_up(), "sniper enters attack windup before damage")

	var wall := StaticBody3D.new()
	wall.position = Vector3(0, -28.5, 6.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 3.0, 0.5)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	await physics_frame
	await physics_frame

	var fired := sniper._attack_runtime.tick(0.60)
	_check(fired, "sniper windup expires after configured telegraph")
	if fired:
		sniper._resolve_pending_attack()
	await process_frame

	_check(is_equal_approx(player.get_shield(), initial_shield), "cover acquired during windup cancels sniper damage")

	wall.queue_free()
	await physics_frame
	await physics_frame

	sniper._begin_attack()
	var second_fired := sniper._attack_runtime.tick(0.60)
	_check(second_fired, "sniper can begin a new attack after blocked shot")
	if second_fired:
		sniper._resolve_pending_attack()
	await process_frame

	_check(player.get_shield() < initial_shield, "sniper damages player when LOS remains open through windup")

	world.queue_free()
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
		print("enemy attack telegraph tests: PASS")
		quit(0)
	else:
		print("enemy attack telegraph tests: FAIL (%d)" % failures)
		quit(1)
