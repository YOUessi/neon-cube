extends SceneTree

const PLAYER_SCENE = preload("res://scenes/player.tscn")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player: NeonPlayer = PLAYER_SCENE.instantiate() as NeonPlayer
	root.add_child(player)
	await process_frame

	_check(player.get_health() == player.max_health, "player starts at max health")
	_check(player.get_shield() == player.max_shield, "player starts with full shield")
	_check(player.get_ammo() == player.magazine_size, "magazine starts full")
	_check(player.get_reserve_ammo() == player.reserve_ammo, "reserve ammo initialized")
	_check(player.gravity_down == Vector3.DOWN, "player starts with floor gravity")
	_check(player.up_direction == Vector3.UP, "up direction opposes initial gravity")
	_check(
		player.weapon_root.position.is_equal_approx(Vector3(0.31, -0.28, -0.58)),
		"weapon view-model keeps authored rest position after loadout initialization"
	)

	var health_before: float = player.get_health()
	player.take_damage(25.0)
	_check(player.get_health() == health_before, "shield absorbs damage before health")
	_check(player.get_shield() == player.max_shield - 25.0, "shield decreases by absorbed damage")
	player.take_damage(40.0)
	_check(player.get_shield() == 0.0, "shield can be depleted")
	_check(player.get_health() == health_before - 15.0, "overflow damage reaches health")
	player.heal(10.0)
	_check(is_equal_approx(player.get_health(), health_before - 5.0), "healing updates health")
	player.grant_shield(12.0)
	_check(player.get_shield() == 12.0, "shield pickup restores shield")

	player.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, label: String) -> void:
	if condition: print("PASS: %s" % label)
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
