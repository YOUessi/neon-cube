extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	_check(game.player != null, "main scene creates a player")
	_check(is_instance_valid(game.player), "player remains valid after startup")
	_check(game.get_tree().get_nodes_in_group("enemies").size() == game.starting_enemies, "initial enemy wave spawned")

	var surface_count := 0
	for child in game.get_children():
		if child is StaticBody3D and child.name.begins_with("Surface_"):
			surface_count += 1
	_check(surface_count == 6, "all six cube surfaces exist")

	_check(game.health_label != null, "HUD health label created")
	_check(game.ammo_label != null, "HUD ammo label created")
	_check(game.face_label != null, "HUD gravity label created")
	_check(game.score_label != null, "HUD score label created")

	game.queue_free()
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
		print("project smoke tests: PASS")
		quit(0)
	else:
		print("project smoke tests: FAIL (%d)" % failures)
		quit(1)
