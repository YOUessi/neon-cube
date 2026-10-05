extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var weapon_errors := WeaponCatalog.validate_all()
	_check(weapon_errors.is_empty(), "all weapon definitions validate")

	var weapons := WeaponCatalog.all()
	_check(weapons.size() == 3, "three weapon definitions are registered")
	_check(weapons[0].weapon_id == &"pulse_rifle", "pulse rifle definition loaded")
	_check(weapons[1].pellets > 1, "scattergun remains multi-pellet")
	_check(weapons[2].max_range > weapons[0].max_range, "marksman keeps longest range")
	for definition in weapons:
		_check(definition.view_model_scene != null, "%s has a view-model scene" % definition.weapon_id)

	var enemy_errors := EnemyCatalog.validate_all()
	_check(enemy_errors.is_empty(), "all enemy definitions validate")

	var enemies := EnemyCatalog.all()
	_check(enemies.size() == 5, "five enemy definitions are registered")
	_check(EnemyCatalog.get_definition(&"runner").behavior_tags.has(&"rush"), "runner behavior metadata loaded")
	_check(EnemyCatalog.get_definition(&"sniper").attack_range > EnemyCatalog.get_definition(&"grunt").attack_range, "sniper range remains distinct")
	_check(EnemyCatalog.get_definition(&"tank").base_health > EnemyCatalog.get_definition(&"grunt").base_health, "tank durability remains distinct")
	_check(EnemyCatalog.get_definition(&"boss").model_scene != null, "boss production model is data-driven")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("definition catalog tests: PASS")
		quit(0)
	else:
		print("definition catalog tests: FAIL (%d)" % failures)
		quit(1)
