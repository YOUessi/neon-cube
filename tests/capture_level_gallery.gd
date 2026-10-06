extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://artifacts"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: NeonGame = MAIN_SCENE.instantiate() as NeonGame
	root.add_child(game)
	await process_frame
	game._start_with_difficulty("OPERATIVE", 1.0)
	await process_frame
	await physics_frame

	game.set_process(false)
	if is_instance_valid(game.player):
		game.player.set_physics_process(false)
		game.player.visible = false
	for enemy in get_nodes_in_group("enemies"):
		if enemy is NeonEnemy:
			(enemy as NeonEnemy).set_physics_process(false)
			(enemy as NeonEnemy).visible = false
	for pickup in get_nodes_in_group("pickups"):
		if pickup is Node3D:
			(pickup as Node3D).visible = false

	if game.hud_panel != null:
		game.hud_panel.visible = false
	if game.menu_panel != null:
		game.menu_panel.visible = false
	if game.pause_panel != null:
		game.pause_panel.visible = false
	if game.end_panel != null:
		game.end_panel.visible = false

	var camera := Camera3D.new()
	camera.name = "LevelGalleryCamera"
	camera.fov = 72.0
	game.add_child(camera)
	camera.current = true
	if is_instance_valid(game.player) and game.player.camera != null:
		game.player.camera.current = false

	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)

	# Market Hall: show both lockdown barriers as a real enclosed Arena.
	game.mission_level.call("set_encounter_lockdown", &"market_crossfire", true)
	await _capture_anchor(
		game,
		camera,
		"market_crossfire_center",
		Vector3.DOWN,
		"neon_market_hall.png",
		0.0,
		5.8,
		15.5
	)
	game.mission_level.call("set_encounter_lockdown", &"market_crossfire", false)

	# Gravity Breach: capture the uplink objective halfway through stabilization.
	game.mission_level.call("arm_hold_zone", &"gravity_breach", true)
	game.mission_level.call("set_hold_zone_progress", &"gravity_breach", 2.0, 4.0)
	game.mission_level.call("set_encounter_lockdown", &"gravity_breach", true)
	await _capture_anchor(
		game,
		camera,
		"gravity_breach_center",
		Vector3.RIGHT,
		"gravity_breach.png",
		13.0,
		4.0,
		1.5
	)


	game.mission_level.call("set_encounter_lockdown", &"gravity_breach", false)
	game.mission_level.call("reset_hold_zones")

	# Data Lane: Relay A offline, Relay B online, Warden route still locked.
	game.mission_level.call("arm_objective_nodes", &"data_lane", true)
	var relays := get_nodes_in_group("mission_objective_node")
	for relay_node in relays:
		var relay := relay_node as MissionObjectiveNode
		if relay != null and relay.objective_id == &"relay_a":
			relay.take_damage(999.0)
			break
	await process_frame
	await _capture_anchor(
		game,
		camera,
		"data_lane_center",
		Vector3.LEFT,
		"data_lane_relays.png",
		12.0,
		4.2,
		-1.5
	)
	game.mission_level.call("reset_objective_nodes")

	# Boss Arena: Phase 2 shows twin hazard telegraphs and phase lighting.
	game.mission_level.call("set_boss_phase", 2)
	await _capture_anchor(
		game,
		camera,
		"null_warden_center",
		Vector3.BACK,
		"void_docks_boss.png",
		14.0,
		5.0,
		0.0
	)
	game.mission_level.call("set_boss_phase", 1)

	# Extraction: capture active beacon at 50 percent hold.
	game.mission_level.call("arm_extraction", true)
	game.mission_level.call("set_extraction_progress", 1.5, 3.0)
	await _capture_anchor(
		game,
		camera,
		"extraction_point",
		Vector3.DOWN,
		"extraction_yard.png",
		-18.0,
		5.5,
		3.0
	)
	game.mission_level.call("arm_extraction", false)

	game.queue_free()
	await process_frame
	print("level gallery capture: PASS")
	quit(0)


func _capture_anchor(
	game: NeonGame,
	camera: Camera3D,
	anchor_key: String,
	down: Vector3,
	filename: String,
	distance: float,
	height: float,
	lateral: float
) -> void:
	if not game.mission_anchors.has(anchor_key):
		push_error("gallery anchor missing: %s" % anchor_key)
		quit(1)
		return
	var anchor: MissionAnchor = game.mission_anchors[anchor_key]
	var target := anchor.global_position
	var basis := CubeGravity.tangent_basis(down)
	var inward := basis.y
	var forward := -basis.z
	var right := basis.x
	camera.global_position = target - forward * distance + inward * height + right * lateral
	camera.look_at(target + inward * 1.2, inward)

	for i in range(5):
		await process_frame

	var image: Image = root.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, filename]
	var result := image.save_png(path)
	if result != OK:
		push_error("gallery capture save failed for %s: %s" % [filename, error_string(result)])
		quit(1)
		return
	print("gallery capture: %s" % path)
