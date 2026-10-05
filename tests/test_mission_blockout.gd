extends SceneTree

const BLOCKOUT := preload("res://scenes/missions/neon_market_siege_blockout.tscn")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := BLOCKOUT.instantiate()
	root.add_child(level)
	await process_frame

	var mission := MissionCatalog.primary()
	var errors := MissionAnchorRegistry.validate(level, mission)
	_check(errors.is_empty(), "mission blockout anchors validate: %s" % errors)

	var anchors := MissionAnchorRegistry.collect(level)
	_check(anchors.size() >= 14, "mission blockout exposes authored traversal anchors")
	_check(anchors.has("player_start"), "mission has an authored player start")
	_check(anchors.has("null_warden_center"), "mission has an authored boss arena center")
	_check(anchors.has("extraction_point"), "mission has an authored extraction point")

	var player_start: MissionAnchor = anchors["player_start"]
	var boss_center: MissionAnchor = anchors["null_warden_center"]
	_check(player_start.district_id == &"neon_market", "player starts in Neon Market")
	_check(boss_center.district_id == &"void_docks", "boss encounter moves to Void Docks")

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
		print("mission blockout tests: PASS")
		quit(0)
	else:
		print("mission blockout tests: FAIL (%d)" % failures)
		quit(1)
