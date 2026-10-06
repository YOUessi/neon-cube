extends SceneTree

const LEVEL := preload("res://scenes/missions/neon_market_siege.tscn")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL.instantiate()
	root.add_child(level)
	await process_frame

	var mission := MissionCatalog.primary()
	var anchor_errors := MissionAnchorRegistry.validate(level, mission)
	_check(anchor_errors.is_empty(), "authored mission level preserves mission anchor contract: %s" % anchor_errors)

	_check(level.get_node_or_null("Geometry/NeonMarket/ArrivalStreet") != null, "arrival street exists")
	_check(level.get_node_or_null("Geometry/NeonMarket/MarketHall") != null, "market interior exists")
	_check(level.get_node_or_null("Geometry/NeonMarket/MarketHall/ElevatedLane") != null, "elevated market lane exists")
	_check(level.get_node_or_null("Geometry/NeonMarket/SeamGateway") != null, "bottom-to-east gravity seam exists")
	_check(level.get_node_or_null("Geometry/GravityBreach/BreachArena") != null, "gravity breach arena exists")
	_check(level.get_node_or_null("Geometry/TransFaceTransit/SouthConduit") != null, "cross-face transit corridor exists")
	_check(level.get_node_or_null("Geometry/DataLane/RelayStreet") != null, "data lane combat space exists")
	_check(level.get_node_or_null("Geometry/VoidDocks/BossArena") != null, "boss arena exists")
	_check(level.get_node_or_null("Geometry/Extraction/ExtractionYard") != null, "extraction yard exists")

	var summary: Dictionary = level.call("spatial_summary")
	_check(int(summary.get("mission_geometry", 0)) >= 25, "level has substantial collidable authored geometry")
	_check(int(summary.get("combat_cover", 0)) >= 12, "arenas expose combat cover")
	_check(int(summary.get("cross_face_passage", 0)) >= 5, "cross-face route is physically authored")
	_check(int(summary.get("boss_arena", 0)) >= 1, "boss arena is tagged")
	_check(int(summary.get("extraction_zone", 0)) == 1, "exactly one extraction zone exists")

	var extraction_zone := level.get_node_or_null("Geometry/Extraction/ExtractionBeacon/ExtractionZone") as Area3D
	_check(extraction_zone != null, "extraction trigger exists")
	if extraction_zone != null:
		_check(not extraction_zone.monitoring, "extraction trigger starts disarmed")
		level.call("arm_extraction", true)
		_check(extraction_zone.monitoring, "extraction trigger can be armed after hostiles are cleared")

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
		print("mission level geometry tests: PASS")
		quit(0)
	else:
		print("mission level geometry tests: FAIL (%d)" % failures)
		quit(1)
