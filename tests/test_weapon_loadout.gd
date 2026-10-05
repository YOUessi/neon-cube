extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var loadout := WeaponLoadout.new()
	loadout.initialize()
	_check(loadout.current_definition().weapon_id == &"pulse_rifle", "loadout starts on pulse rifle")
	_check(loadout.current_ammo() == 30, "pulse rifle magazine comes from data")
	_check(loadout.current_reserve() == 150, "pulse rifle reserve comes from data")

	_check(loadout.consume_shot(), "first shot consumes ammo")
	_check(loadout.current_ammo() == 29, "shot decrements magazine")
	_check(not loadout.consume_shot(), "fire rate cooldown blocks immediate duplicate shot")
	loadout.tick(1.0)
	_check(loadout.consume_shot(), "weapon can fire after cooldown")

	_check(loadout.switch_weapon(1), "loadout switches weapon")
	_check(loadout.current_definition().weapon_id == &"arc_scattergun", "scattergun becomes current")
	var before := loadout.current_reserve()
	loadout.grant_ammo(5)
	_check(loadout.current_reserve() >= before, "ammo grant never reduces reserve")

	loadout.tick(2.0)
	_check(loadout.consume_shot(), "scattergun can fire")
	loadout.tick(2.0)
	_check(loadout.try_reload(), "reload succeeds when magazine is missing ammo")
	_check(loadout.current_ammo() == loadout.current_definition().magazine_size, "reload restores magazine")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("weapon loadout tests: PASS")
		quit(0)
	else:
		print("weapon loadout tests: FAIL (%d)" % failures)
		quit(1)
