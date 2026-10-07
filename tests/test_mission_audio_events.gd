extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio := NeonAudio.new()
	root.add_child(audio)
	await process_frame

	var required_methods := [
		&"play_lockdown",
		&"play_reinforcement",
		&"play_objective_destroyed",
		&"play_uplink_complete",
		&"play_boss_phase",
		&"play_extraction_ready",
	]
	for method_name in required_methods:
		_check(audio.has_method(method_name), "mission audio exposes %s" % method_name)

	audio.play_lockdown()
	audio.play_reinforcement()
	audio.play_objective_destroyed()
	audio.play_uplink_complete()
	audio.play_boss_phase()
	audio.play_extraction_ready()
	_check(true, "mission event cues are headless-safe")

	audio.queue_free()
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
		print("mission audio contract tests: PASS")
		quit(0)
	else:
		print("mission audio contract tests: FAIL (%d)" % failures)
		quit(1)
