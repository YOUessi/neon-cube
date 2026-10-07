extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	MissionProgressStore.clear()
	var game: NeonGame = MAIN.instantiate() as NeonGame
	root.add_child(game)
	await process_frame
	await physics_frame

	var pickups := get_nodes_in_group("authored_pickup")
	_check(pickups.size() == 3, "fresh Mission 01 run spawns three authored level pickups")

	var by_name := {}
	for node in pickups:
		var pickup := node as NeonPickup
		if pickup != null:
			by_name[String(pickup.pickup_id)] = pickup

	_check(by_name.has("data_bridge_ammo"), "Data Bridge authored ammo pickup exists")
	_check(by_name.has("boss_left_gantry_shield"), "Boss left gantry authored shield pickup exists")
	_check(by_name.has("extraction_dock_health"), "Extraction dock authored health pickup exists")

	if by_name.has("data_bridge_ammo"):
		var pickup: NeonPickup = by_name["data_bridge_ammo"]
		_check(pickup.pickup_type == "ammo", "Data Bridge pickup is ammo")
		_check(is_equal_approx(pickup.amount, 40.0), "Data Bridge ammo amount matches authored value")
		_check(CubeGravity.nearest_down(pickup.global_position, 30.0).is_equal_approx(Vector3.LEFT), "Data Bridge pickup stays on Data Quarter face")

	if by_name.has("boss_left_gantry_shield"):
		var pickup: NeonPickup = by_name["boss_left_gantry_shield"]
		_check(pickup.pickup_type == "shield", "Boss gantry pickup is shield")
		_check(is_equal_approx(pickup.amount, 36.0), "Boss gantry shield amount matches authored value")
		_check(CubeGravity.nearest_down(pickup.global_position, 30.0).is_equal_approx(Vector3.BACK), "Boss gantry pickup stays on Void Docks face")

	if by_name.has("extraction_dock_health"):
		var pickup: NeonPickup = by_name["extraction_dock_health"]
		_check(pickup.pickup_type == "health", "Extraction dock pickup is health")
		_check(is_equal_approx(pickup.amount, 42.0), "Extraction dock health amount matches authored value")
		_check(CubeGravity.nearest_down(pickup.global_position, 30.0).is_equal_approx(Vector3.DOWN), "Extraction dock pickup stays on Neon Market face")

	if by_name.has("boss_left_gantry_shield"):
		var consumed_pickup: NeonPickup = by_name["boss_left_gantry_shield"]
		consumed_pickup._on_body_entered(game.player)
		await process_frame
		_check(game.mission_runtime.is_pickup_consumed(&"boss_left_gantry_shield"), "collecting authored pickup marks runtime consumption immediately")

		game._resume_story_from_save()
		await process_frame
		await physics_frame
		_check(game.mission_runtime.is_pickup_consumed(&"boss_left_gantry_shield"), "checkpoint reload restores consumed pickup state")
		var restored_names := {}
		for node in get_nodes_in_group("authored_pickup"):
			var restored_pickup := node as NeonPickup
			if restored_pickup != null:
				restored_names[String(restored_pickup.pickup_id)] = true
		_check(not restored_names.has("boss_left_gantry_shield"), "consumed Boss gantry shield does not respawn after checkpoint reload")
		_check(restored_names.has("data_bridge_ammo"), "unconsumed Data Bridge ammo remains available after checkpoint reload")
		_check(restored_names.has("extraction_dock_health"), "unconsumed Extraction health remains available after checkpoint reload")

	MissionProgressStore.clear()
	game.queue_free()
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
		print("authored level pickup tests: PASS")
		quit(0)
	else:
		print("authored level pickup tests: FAIL (%d)" % failures)
		quit(1)
