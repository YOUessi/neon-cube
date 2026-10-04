extends SceneTree

const PLAYER_SCENE = preload("res://scenes/player.tscn")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player: NeonPlayer = PLAYER_SCENE.instantiate() as NeonPlayer
	root.add_child(player)
	await process_frame

	_check(player.get_weapon_index() == 0, "pulse rifle selected by default")
	_check(player.get_weapon_name() == "PULSE RIFLE", "default weapon name")
	player.switch_weapon(1)
	_check(player.get_weapon_index() == 1, "switches to scattergun")
	_check(player.get_weapon_name() == "ARC SCATTERGUN", "scattergun name")
	var before: int = player.get_reserve_ammo()
	player.grant_ammo(5)
	_check(player.get_reserve_ammo() >= before, "ammo pickup never reduces reserve")
	player.switch_weapon(2)
	_check(player.get_weapon_name() == "ION MARKSMAN", "switches to marksman weapon")

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
		print("weapon system tests: PASS")
		quit(0)
	else:
		print("weapon system tests: FAIL (%d)" % failures)
		quit(1)
