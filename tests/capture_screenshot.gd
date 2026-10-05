extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: NeonGame = MAIN_SCENE.instantiate() as NeonGame
	root.add_child(game)
	await process_frame
	game._start_with_difficulty("OPERATIVE", 1.0)
	await process_frame
	await physics_frame

	var enemies := get_nodes_in_group("enemies")
	if not enemies.is_empty() and is_instance_valid(game.player):
		var enemy: NeonEnemy = enemies[0] as NeonEnemy
		enemy.set_physics_process(false)
		var player: NeonPlayer = game.player
		var forward: Vector3 = -player.global_transform.basis.z.normalized()
		enemy.global_position = player.global_position + forward * 8.0 - player.gravity_down * 0.05
		enemy.global_transform.basis = player.global_transform.basis.rotated(-player.gravity_down, PI)
		player.camera.look_at(enemy.global_position - enemy.gravity_down * 0.4, -player.gravity_down)

	for i in range(6):
		await process_frame

	var output_dir := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image: Image = root.get_texture().get_image()
	var result: Error = image.save_png("res://artifacts/neon_cube_ci.png")
	if result != OK:
		push_error("visual capture save failed: %s" % error_string(result))
		quit(1)
		return
	print("visual capture: res://artifacts/neon_cube_ci.png")
	game.queue_free()
	await process_frame
	quit(0)
