extends SceneTree

const PLAYER_SCENE = preload("res://scenes/player.tscn")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame

	_check(player.get_health() == player.max_health, "player starts at max health")
	_check(player.get_ammo() == player.magazine_size, "magazine starts full")
	_check(player.get_reserve_ammo() == player.reserve_ammo, "reserve ammo initialized")
	_check(player.gravity_down == Vector3.DOWN, "player starts with floor gravity")
	_check(player.up_direction == Vector3.UP, "up direction opposes initial gravity")

	player.take_damage(25.0)
	_check(is_equal_approx(player.get_health(), player.max_health - 25.0), "damage updates health")
	player.heal(10.0)
	_check(is_equal_approx(player.get_health(), player.max_health - 15.0), "healing clamps and updates health")

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
		print("player contract tests: PASS")
		quit(0)
	else:
		print("player contract tests: FAIL (%d)" % failures)
		quit(1)
