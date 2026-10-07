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
	_check(level.get_node_or_null("Geometry/DataLane/MaintenanceBridge/BridgeDeck") != null, "Data Lane maintenance bridge exists")
	_check(level.get_node_or_null("Geometry/VoidDocks/BossArena/ServiceGantries") != null, "Boss Arena service gantries exist")

	var boss_left_deck := level.get_node_or_null("Geometry/VoidDocks/BossArena/ServiceGantries/GantryDeck_L") as StaticBody3D
	var boss_left_step_02 := level.get_node_or_null("Geometry/VoidDocks/BossArena/ServiceGantries/GantryStep_L_02") as StaticBody3D
	var boss_left_step_03 := level.get_node_or_null("Geometry/VoidDocks/BossArena/ServiceGantries/GantryStep_L_03") as StaticBody3D
	if boss_left_deck != null and boss_left_step_02 != null and boss_left_step_03 != null:
		var deck_collision := boss_left_deck.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var step_02_collision := boss_left_step_02.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var step_03_collision := boss_left_step_03.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_check(deck_collision != null and step_02_collision != null and step_03_collision != null, "Boss gantry deck and upper stairs expose collision shapes")
		if deck_collision != null and step_02_collision != null and step_03_collision != null:
			var forward := -CubeGravity.tangent_basis(Vector3.BACK).z.normalized()
			var deck_shape := deck_collision.shape as BoxShape3D
			var step_02_shape := step_02_collision.shape as BoxShape3D
			var step_03_shape := step_03_collision.shape as BoxShape3D
			var deck_near := boss_left_deck.global_position.dot(forward) - deck_shape.size.z * 0.5
			var step_02_far := boss_left_step_02.global_position.dot(forward) + step_02_shape.size.z * 0.5
			var step_03_far := boss_left_step_03.global_position.dot(forward) + step_03_shape.size.z * 0.5
			_check(deck_near - step_02_far >= 0.35, "Boss gantry deck leaves headroom above third stair")
			_check(absf(deck_near - step_03_far) <= 0.12, "Boss gantry final stair meets deck without a large gap")
	_check(level.get_node_or_null("Geometry/Extraction/ExtractionDock/DockDeck") != null, "Extraction dock platform exists")

	var dock_deck := level.get_node_or_null("Geometry/Extraction/ExtractionDock/DockDeck") as StaticBody3D
	var dock_last_step := level.get_node_or_null("Geometry/Extraction/ExtractionDock/DockStep_02") as StaticBody3D
	if dock_deck != null and dock_last_step != null:
		var deck_collision := dock_deck.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var step_collision := dock_last_step.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_check(deck_collision != null and step_collision != null, "Extraction dock deck and final stair expose collision shapes")
		if deck_collision != null and step_collision != null:
			var inward := CubeGravity.tangent_basis(Vector3.DOWN).y.normalized()
			var deck_shape := deck_collision.shape as BoxShape3D
			var step_shape := step_collision.shape as BoxShape3D
			var deck_top := dock_deck.global_position.dot(inward) + deck_shape.size.y * 0.5
			var step_top := dock_last_step.global_position.dot(inward) + step_shape.size.y * 0.5
			var final_rise := deck_top - step_top
			_check(final_rise >= -0.01 and final_rise <= 0.10, "Extraction final stair transitions smoothly onto Dock deck")
	_check(level.get_node_or_null("Geometry/VoidDocks/BossArena") != null, "boss arena exists")
	_check(level.get_node_or_null("Geometry/Extraction/ExtractionYard") != null, "extraction yard exists")

	var summary: Dictionary = level.call("spatial_summary")
	_check(int(summary.get("mission_geometry", 0)) >= 25, "level has substantial collidable authored geometry")
	_check(int(summary.get("combat_cover", 0)) >= 12, "arenas expose combat cover")
	_check(int(summary.get("cross_face_passage", 0)) >= 5, "cross-face route is physically authored")
	_check(int(summary.get("boss_arena", 0)) >= 1, "boss arena is tagged")
	_check(int(summary.get("extraction_zone", 0)) == 1, "exactly one extraction zone exists")
	_check(int(summary.get("encounter_activation_zone", 0)) == 5, "five traversal-gated encounter zones exist")
	_check(int(summary.get("combat_lockdown_gate", 0)) == 6, "six authored combat lockdown barriers exist")
	_check(int(level.call("combat_gate_count", &"market_crossfire")) == 2, "Market Crossfire uses entry and exit lockdown barriers")
	_check(int(level.call("combat_gate_count", &"gravity_breach")) == 1, "Gravity Breach keeps one lockdown barrier")
	_check(int(level.call("combat_gate_count", &"data_lane")) == 1, "Data Lane keeps one lockdown barrier")
	_check(int(level.call("combat_gate_count", &"null_warden")) == 1, "Null Warden keeps one lockdown barrier")
	_check(int(level.call("combat_gate_count", &"extraction")) == 1, "Extraction keeps one lockdown barrier")
	_check(int(summary.get("navigation_beacon", 0)) == 5, "five world-space navigation beacons exist")
	_check(int(summary.get("boss_hazard", 0)) == 4, "boss arena exposes four hazard pads")
	_check(int(summary.get("mission_objective_node", 0)) == 2, "Data Lane exposes two mission objective nodes")
	_check(int(summary.get("mission_hold_zone", 0)) == 1, "Gravity Breach exposes one mission hold zone")
	_check(int(summary.get("market_kiosk_collision", 0)) == 6, "Arrival Street exposes six physical market kiosks")
	_check(int(summary.get("elevated_gameplay_space", 0)) >= 3, "Data and Boss spaces expose three elevated gameplay decks")
	_check(int(summary.get("data_maintenance_bridge", 0)) >= 6, "Data Lane bridge includes deck and climbable steps")
	_check(int(summary.get("boss_service_gantry", 0)) >= 10, "Boss Arena exposes two gantries with climbable steps")
	_check(int(summary.get("extraction_dock", 0)) >= 4, "Extraction dock includes deck and access steps")
	for kiosk in get_nodes_in_group("market_kiosk_collision"):
		_check(CubeGravity.nearest_down(kiosk.global_position, 30.0).is_equal_approx(Vector3.DOWN), "market kiosk collision remains on Neon Market face")

	for node in get_nodes_in_group("data_maintenance_bridge"):
		_check(CubeGravity.nearest_down(node.global_position, 30.0).is_equal_approx(Vector3.LEFT), "Data maintenance geometry remains on Data Quarter face")
	for node in get_nodes_in_group("boss_service_gantry"):
		_check(CubeGravity.nearest_down(node.global_position, 30.0).is_equal_approx(Vector3.BACK), "Boss service gantry remains on Void Docks face")
	for node in get_nodes_in_group("extraction_dock"):
		_check(CubeGravity.nearest_down(node.global_position, 30.0).is_equal_approx(Vector3.DOWN), "Extraction dock remains on Neon Market face")

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

	var market_entry_gate := level.get_node_or_null("Geometry/CombatLockdownGates/MarketEntryLockdown")
	var market_exit_gate := level.get_node_or_null("Geometry/CombatLockdownGates/MarketExitLockdown")
	_check(market_entry_gate != null and market_exit_gate != null, "Market Hall exposes both physical lockdown barriers")
	var market_entry_collision := market_entry_gate.get_node_or_null("CollisionShape3D") as CollisionShape3D if market_entry_gate != null else null
	var market_exit_collision := market_exit_gate.get_node_or_null("CollisionShape3D") as CollisionShape3D if market_exit_gate != null else null
	_check(market_entry_collision != null and market_exit_collision != null, "both Market lockdown barriers own collision shapes")
	_check(not bool(level.call("is_encounter_locked", &"market_crossfire")), "market lockdown starts open")
	if market_entry_collision != null and market_exit_collision != null:
		_check(market_entry_collision.disabled and market_exit_collision.disabled, "both Market barrier collisions start disabled")
	level.call("set_encounter_lockdown", &"market_crossfire", true)
	await process_frame
	_check(bool(level.call("is_encounter_locked", &"market_crossfire")), "market lockdown can close")
	if market_entry_collision != null and market_exit_collision != null:
		_check(not market_entry_collision.disabled and not market_exit_collision.disabled, "Market entry and exit collisions activate together")
	level.call("set_encounter_lockdown", &"market_crossfire", false)
	await process_frame
	_check(not bool(level.call("is_encounter_locked", &"market_crossfire")), "market lockdown reopens")
	if market_entry_collision != null and market_exit_collision != null:
		_check(market_entry_collision.disabled and market_exit_collision.disabled, "Market entry and exit collisions reopen together")

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

	_check(is_equal_approx(float(level.call("perch_radius_for", &"market_crossfire", 4)), 0.75), "Market slot-four sniper owns authored catwalk leash")
	_check(is_equal_approx(float(level.call("perch_radius_for", &"market_crossfire", 3)), 0.0), "Market ground reinforcement has no perch leash")
	_check(is_equal_approx(float(level.call("perch_radius_for", &"data_lane", 3)), 0.30), "Data Lane slot-three sniper owns authored rack leash")
	_check(is_equal_approx(float(level.call("perch_radius_for", &"data_lane", 4)), 0.0), "Data Lane ground tank has no perch leash")
	_check(is_equal_approx(float(level.call("perch_radius_for", &"null_warden", 2)), 0.55), "Null Warden slot-two sniper owns authored gantry leash")
	_check(is_equal_approx(float(level.call("perch_radius_for", &"null_warden", 3)), 0.0), "Null Warden ground tank remains unrestricted")

	var market_routes: Array = level.call("route_points_for", &"market_crossfire")
	var breach_routes: Array = level.call("route_points_for", &"gravity_breach")
	var data_routes: Array = level.call("route_points_for", &"data_lane")
	var boss_routes: Array = level.call("route_points_for", &"null_warden")
	_check(market_routes.size() == 6, "market arena exposes six authored route waypoints")
	_check(breach_routes.size() == 5, "breach arena exposes five authored route waypoints")
	_check(data_routes.size() == 13, "data lane exposes ground plus tread-by-tread Maintenance Bridge route waypoints")
	_check(boss_routes.size() == 18, "boss arena exposes ground plus dual six-point gantry ascent routes")
	if not market_routes.is_empty():
		_check(CubeGravity.nearest_down(market_routes[0], 30.0).is_equal_approx(Vector3.DOWN), "market route stays on Neon Market face")
	if not boss_routes.is_empty():
		_check(CubeGravity.nearest_down(boss_routes[0], 30.0).is_equal_approx(Vector3.BACK), "boss route stays on Void Docks face")
	if data_routes.size() == 13:
		_check(data_routes[12].x > data_routes[0].x + 1.5, "Data route includes elevated Maintenance Bridge deck waypoint")
	if boss_routes.size() == 18:
		var boss_up := -Vector3.BACK
		var ground_height: float = boss_routes[0].dot(boss_up)
		_check(boss_routes[11].dot(boss_up) > ground_height + 1.2, "Boss route includes elevated left gantry deck waypoint")
		_check(boss_routes[17].dot(boss_up) > ground_height + 1.2, "Boss route includes elevated right gantry deck waypoint")

	var market_spawns: Array = level.call("spawn_points_for", &"market_crossfire", 5, 0)
	var data_spawns: Array = level.call("spawn_points_for", &"data_lane", 5, 0)
	var breach_spawns: Array = level.call("spawn_points_for", &"gravity_breach", 4, 0)
	var boss_spawns: Array = level.call("spawn_points_for", &"null_warden", 4, 0)
	_check(market_spawns.size() == 5, "market encounter exposes five authored spawn sockets")
	if market_spawns.size() == 5:
		_check(market_spawns[4].y > market_spawns[0].y + 1.5, "Market reinforcement sniper spawn is elevated above ground squad")
	_check(breach_spawns.size() == 4, "breach encounter exposes four authored spawn sockets")
	_check(data_spawns.size() == 5, "Data Lane exposes five authored spawn sockets")
	if data_spawns.size() == 5:
		_check(data_spawns[3].x > data_spawns[0].x + 1.5, "Data Lane reinforcement sniper spawn is elevated above ground squad")
	_check(boss_spawns.size() == 4, "boss encounter exposes four authored spawn sockets")
	if boss_spawns.size() == 4:
		_check(CubeGravity.nearest_down(boss_spawns[2], 30.0).is_equal_approx(Vector3.BACK), "Boss gantry sniper socket remains on Void Docks face")
		_check(boss_spawns[2].distance_to(boss_spawns[3]) > 3.0, "Boss gantry sniper socket remains spatially distinct from ground tank")
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
