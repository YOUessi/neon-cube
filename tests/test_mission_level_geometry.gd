extends SceneTree

const LEVEL := preload("res://scenes/missions/neon_market_siege.tscn")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL.instantiate()
	root.add_child(level)
	await process_frame

	var anchors := MissionAnchorRegistry.collect(level)
	_check(anchors.size() >= 14, "authored mission level preserves all traversal anchors")
	_check(anchors.has("player_start"), "authored mission level preserves player start")
	_check(anchors.has("null_warden_center"), "authored mission level preserves boss center")
	_check(anchors.has("extraction_point"), "authored mission level preserves extraction point")

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
	_check(int(summary.get("encounter_activation_zone", 0)) == 5, "five traversal-gated encounter zones exist")
	_check(int(summary.get("combat_lockdown_gate", 0)) == 5, "five authored combat lockdown gates exist")
	_check(int(summary.get("navigation_beacon", 0)) == 5, "five world-space navigation beacons exist")
	_check(int(summary.get("boss_hazard", 0)) == 4, "boss arena exposes four hazard pads")

	_check(StringName(level.call("current_navigation_target")) == &"", "navigation target starts clear")
	level.call("set_navigation_target", &"market_crossfire")
	_check(StringName(level.call("current_navigation_target")) == &"market_crossfire", "navigation target can point to next encounter")
	level.call("set_navigation_target", &"")
	_check(StringName(level.call("current_navigation_target")) == &"", "navigation target can be cleared")

	var phase_one: Dictionary = level.call("boss_hazard_state")
	_check(int(phase_one.get("phase", 0)) == 1 and int(phase_one.get("active_count", -1)) == 0, "boss phase one starts without arena hazards")
	level.call("set_boss_phase", 2)
	var phase_two: Dictionary = level.call("boss_hazard_state")
	_check(int(phase_two.get("phase", 0)) == 2 and int(phase_two.get("active_count", -1)) == 2, "boss phase two activates twin hazards")
	level.call("set_boss_phase", 3)
	var phase_three: Dictionary = level.call("boss_hazard_state")
	_check(int(phase_three.get("phase", 0)) == 3 and int(phase_three.get("active_count", -1)) == 4, "boss phase three overloads all hazard pads")
	level.call("set_boss_phase", 1)

	_check(not bool(level.call("is_encounter_locked", &"market_crossfire")), "market lockdown starts open")
	level.call("set_encounter_lockdown", &"market_crossfire", true)
	_check(bool(level.call("is_encounter_locked", &"market_crossfire")), "market lockdown can close")
	level.call("set_encounter_lockdown", &"market_crossfire", false)
	_check(not bool(level.call("is_encounter_locked", &"market_crossfire")), "market lockdown reopens")

	var market_zone := level.get_node_or_null("Geometry/EncounterActivationZones/MarketCrossfireActivation") as Area3D
	var breach_zone := level.get_node_or_null("Geometry/EncounterActivationZones/GravityBreachActivation") as Area3D
	_check(market_zone != null and breach_zone != null, "encounter activation areas are authored")
	if market_zone != null and breach_zone != null:
		_check(not market_zone.monitoring and not breach_zone.monitoring, "encounter zones start disarmed")
		level.call("arm_encounter_zone", &"market_crossfire", true)
		_check(market_zone.monitoring and not breach_zone.monitoring, "only requested encounter zone becomes active")
		level.call("arm_encounter_zone", &"gravity_breach", true)
		_check(not market_zone.monitoring and breach_zone.monitoring, "arming next arena disarms previous arena")
		level.call("arm_encounter_zone", &"gravity_breach", false)

	var market_routes: Array = level.call("route_points_for", &"market_crossfire")
	var breach_routes: Array = level.call("route_points_for", &"gravity_breach")
	var data_routes: Array = level.call("route_points_for", &"data_lane")
	var boss_routes: Array = level.call("route_points_for", &"null_warden")
	_check(market_routes.size() == 6, "market arena exposes six authored route waypoints")
	_check(breach_routes.size() == 5, "breach arena exposes five authored route waypoints")
	_check(data_routes.size() == 6, "data lane exposes six authored route waypoints")
	_check(boss_routes.size() == 6, "boss arena exposes six authored route waypoints")
	if not market_routes.is_empty():
		_check(CubeGravity.nearest_down(market_routes[0], 30.0).is_equal_approx(Vector3.DOWN), "market route stays on Neon Market face")
	if not boss_routes.is_empty():
		_check(CubeGravity.nearest_down(boss_routes[0], 30.0).is_equal_approx(Vector3.BACK), "boss route stays on Void Docks face")

	var market_spawns: Array = level.call("spawn_points_for", &"market_crossfire", 5, 0)
	var breach_spawns: Array = level.call("spawn_points_for", &"gravity_breach", 4, 0)
	var boss_spawns: Array = level.call("spawn_points_for", &"null_warden", 4, 0)
	_check(market_spawns.size() == 5, "market encounter exposes five authored spawn sockets")
	_check(breach_spawns.size() == 4, "breach encounter exposes four authored spawn sockets")
	_check(boss_spawns.size() == 4, "boss encounter exposes four authored spawn sockets")
	if not market_spawns.is_empty():
		_check(CubeGravity.nearest_down(market_spawns[0], 30.0).is_equal_approx(Vector3.DOWN), "market spawns stay on Neon Market face")
	if not breach_spawns.is_empty():
		_check(CubeGravity.nearest_down(breach_spawns[0], 30.0).is_equal_approx(Vector3.RIGHT), "breach spawns stay on Industrial Arc face")
	if not boss_spawns.is_empty():
		_check(CubeGravity.nearest_down(boss_spawns[0], 30.0).is_equal_approx(Vector3.BACK), "boss spawns stay on Void Docks face")

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
