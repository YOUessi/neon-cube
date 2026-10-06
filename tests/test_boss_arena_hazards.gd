extends SceneTree

const LEVEL := preload("res://scenes/missions/neon_market_siege.tscn")
const PLAYER := preload("res://scenes/player.tscn")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level: NeonMarketSiegeLevel = LEVEL.instantiate() as NeonMarketSiegeLevel
	root.add_child(level)
	level.set_physics_process(false)
	await process_frame

	var hazard := level.get_node_or_null("Geometry/BossHazards/BossHazard_00") as Area3D
	_check(hazard != null, "boss hazard test pad exists")
	if hazard == null:
		_finish()
		return

	var player: NeonPlayer = PLAYER.instantiate() as NeonPlayer
	player.cube_half_extent = 30.0
	level.add_child(player)
	level.set_player(player)
	player.set_physics_process(false)
	player.global_position = hazard.to_global(Vector3(0, 1.2, 0))
	await physics_frame
	await physics_frame

	level.set_boss_phase(2)
	await physics_frame
	await physics_frame
	var before := player.get_shield()
	level._physics_process(1.0)
	await process_frame
	var after := player.get_shield()
	_check(after < before, "phase two hazard damages a player standing on an active pad")
	_check(is_equal_approx(before - after, 6.0), "phase two hazard applies six damage per pulse")

	level.set_boss_phase(3)
	await physics_frame
	await physics_frame
	var before_phase_three := player.get_shield()
	level._physics_process(1.0)
	await process_frame
	var after_phase_three := player.get_shield()
	_check(after_phase_three < before_phase_three, "phase three hazard remains damaging")
	_check(is_equal_approx(before_phase_three - after_phase_three, 10.0), "phase three overload applies ten damage per pulse")

	level.set_boss_phase(1)
	var safe_before := player.get_shield()
	level._physics_process(1.0)
	await process_frame
	_check(is_equal_approx(player.get_shield(), safe_before), "phase one disables boss arena hazard damage")

	level.queue_free()
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
		print("boss arena hazard tests: PASS")
		quit(0)
	else:
		print("boss arena hazard tests: FAIL (%d)" % failures)
		quit(1)
