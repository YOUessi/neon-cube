extends SceneTree

const LEVEL := preload("res://scenes/missions/neon_market_siege.tscn")
const CELL := preload("res://scripts/world/explosive_power_cell.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const PLAYER := preload("res://scenes/player.tscn")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_authored_level_cells()
	await _test_blast_damage()
	_finish()


func _test_authored_level_cells() -> void:
	var level := LEVEL.instantiate() as NeonMarketSiegeLevel
	root.add_child(level)
	await process_frame

	var cells := get_nodes_in_group("explosive_power_cell")
	_check(cells.size() == 5, "Mission 01 exposes five authored explosive power cells")

	var market := level.get_node_or_null(
		"Geometry/NeonMarket/MarketHall/CrossfireArena/PowerCell_Market_A"
	) as ExplosivePowerCell
	var breach := level.get_node_or_null(
		"Geometry/GravityBreach/BreachArena/PowerCell_Breach"
	) as ExplosivePowerCell
	var data := level.get_node_or_null(
		"Geometry/DataLane/RelayStreet/PowerCell_Data"
	) as ExplosivePowerCell
	var extraction := level.get_node_or_null(
		"Geometry/Extraction/ExtractionYard/PowerCell_Extraction"
	) as ExplosivePowerCell

	_check(market != null, "Market Crossfire has an authored explosive cell")
	_check(breach != null, "Gravity Breach has an authored explosive cell")
	_check(data != null, "Data Lane has an authored explosive cell")
	_check(extraction != null, "Extraction Yard has an authored explosive cell")
	if market != null:
		_check(
			CubeGravity.nearest_down(market.global_position, 30.0).is_equal_approx(Vector3.DOWN),
			"Market explosive cell stays on Neon Market face"
		)
	if breach != null:
		_check(
			CubeGravity.nearest_down(breach.global_position, 30.0).is_equal_approx(Vector3.RIGHT),
			"Gravity Breach explosive cell stays on Industrial Arc face"
		)
	if data != null:
		_check(
			CubeGravity.nearest_down(data.global_position, 30.0).is_equal_approx(Vector3.LEFT),
			"Data explosive cell stays on Data Quarter face"
		)

	level.queue_free()
	await process_frame


func _test_blast_damage() -> void:
	var world := Node3D.new()
	world.name = "ExplosivePowerCellWorld"
	root.add_child(world)

	var cell := CELL.new() as ExplosivePowerCell
	cell.position = Vector3.ZERO
	world.add_child(cell)

	var near_enemy := ENEMY.instantiate() as NeonEnemy
	near_enemy.configure("tank", 1)
	near_enemy.position = Vector3(2.0, 0.0, 0.0)
	world.add_child(near_enemy)
	near_enemy.set_physics_process(false)

	var far_enemy := ENEMY.instantiate() as NeonEnemy
	far_enemy.configure("tank", 1)
	far_enemy.position = Vector3(7.0, 0.0, 0.0)
	world.add_child(far_enemy)
	far_enemy.set_physics_process(false)

	var player := PLAYER.instantiate() as NeonPlayer
	player.position = Vector3(-2.0, 0.0, 0.0)
	world.add_child(player)
	player.set_physics_process(false)

	await physics_frame
	await process_frame

	var near_health := near_enemy.get_health()
	var far_health := far_enemy.get_health()
	var player_health := player.get_health()
	var player_shield := player.get_shield()

	cell.take_damage(cell.max_health + 1.0)
	_check(cell.is_detonated(), "lethal weapon damage detonates the power cell immediately")
	_check(near_enemy.get_health() < near_health, "blast damages a nearby enemy")
	_check(is_equal_approx(far_enemy.get_health(), far_health), "blast leaves enemies outside radius untouched")
	_check(
		player.get_health() < player_health or player.get_shield() < player_shield,
		"blast also threatens the nearby player"
	)

	world.queue_free()
	await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if failures == 0:
		print("explosive power cell tests: PASS")
		quit(0)
	else:
		print("explosive power cell tests: FAIL (%d)" % failures)
		quit(1)
