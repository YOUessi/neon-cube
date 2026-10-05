extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var campaign := CampaignCatalog.primary()
	_check(CampaignCatalog.validate_all().is_empty(), "campaign definition validates")
	_check(campaign.wave_count() == 6, "campaign contains six authored waves")
	_check(campaign.get_wave(0).enemy_kinds.size() == 6, "first wave preserves six enemies")
	_check(campaign.get_wave(2).enemy_kinds.count(&"sniper") == 2, "third wave introduces two snipers")
	_check(campaign.get_wave(3).enemy_kinds.count(&"tank") == 2, "fourth wave introduces tanks")
	_check(campaign.get_wave(5).boss_wave, "final wave is marked as boss wave")
	_check(campaign.get_wave(5).enemy_kinds.count(&"boss") == 1, "final wave contains exactly one boss")
	_check(campaign.get_wave(2).reward_shield > 0.0, "campaign data owns reward progression")

	var session := GameSession.new()
	session.reset_run("NIGHTMARE", 1.28)
	_check(session.state == GameSession.State.PLAYING, "session reset enters playing state")
	session.add_enemy()
	session.register_kill(240)
	_check(session.score == 240, "session owns score accounting")
	_check(session.kills == 1, "session owns kill accounting")
	_check(session.alive_enemies == 0, "session owns hostile count")
	session.advance_wave()
	_check(session.current_wave_number() == 2, "session advances wave index")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("campaign definition tests: PASS")
		quit(0)
	else:
		print("campaign definition tests: FAIL (%d)" % failures)
		quit(1)
