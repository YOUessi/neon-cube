extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: NeonGame = MAIN_SCENE.instantiate() as NeonGame
	root.add_child(game)
	await process_frame
	await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual"))

	# Main menu proves the non-gameplay shell is rendered.
	game._show_menu()
	await process_frame
	await _capture("menu")

	game._start_with_difficulty("OPERATIVE", 1.0)
	await process_frame
	await physics_frame

	var player: NeonPlayer = game.player
	for index in range(3):
		player.switch_weapon(index)
		await process_frame
		await _capture("weapon_%d" % (index + 1))

	var faces := [
		Vector3.DOWN,
		Vector3.RIGHT,
		Vector3.UP,
		Vector3.LEFT,
		Vector3.BACK,
		Vector3.FORWARD,
	]
	for i in range(faces.size()):
		var down: Vector3 = faces[i]
		player.gravity_down = down
		player.up_direction = -down
		player.global_position = down * (game.cube_size * 0.5 - 1.7)
		player.global_transform.basis = CubeGravity.tangent_basis(down)
		player.velocity = Vector3.ZERO
		await physics_frame
		await process_frame
		await _capture("face_%d_%s" % [i, CubeGravity.face_name(down).replace(" / ", "_").replace(" ", "_")])

	# Place one boss in a deterministic camera-readable position.
	for node in get_nodes_in_group("enemies"):
		node.queue_free()
	await process_frame
	game._alive_enemies = 0
	game._spawn_enemy("boss", 0)
	await process_frame
	var enemies := get_nodes_in_group("enemies")
	if not enemies.is_empty():
		var boss: NeonEnemy = enemies[0] as NeonEnemy
		boss.set_physics_process(false)
		player.gravity_down = Vector3.DOWN
		player.global_position = Vector3(0, -game.cube_size * 0.5 + 1.7, 8.0)
		player.global_transform.basis = CubeGravity.tangent_basis(Vector3.DOWN)
		boss.global_position = Vector3(0, -game.cube_size * 0.5 + 1.3, -1.0)
		boss.gravity_down = Vector3.DOWN
		await process_frame
		player.camera.look_at(boss.global_position + Vector3.UP * 0.55, Vector3.UP)
		await process_frame
	await _capture("boss")

	game.queue_free()
	await process_frame
	print("visual matrix capture: PASS")
	quit(0)

func _capture(name: String) -> void:
	for i in range(3):
		await process_frame
	var image: Image = root.get_texture().get_image()
	var path := "res://artifacts/visual/%s.png" % name
	var result := image.save_png(path)
	if result != OK:
		push_error("could not save %s: %s" % [path, error_string(result)])
		quit(1)
