extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: NeonGame = MAIN_SCENE.instantiate() as NeonGame
	root.add_child(game)
	await process_frame
	game._start_with_difficulty("OPERATIVE", 1.0)
	for i in range(12):
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
