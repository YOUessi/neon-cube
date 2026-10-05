extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	InputBootstrap.ensure_defaults()
	for action in InputBootstrap.KEY_BINDINGS:
		_check(InputMap.has_action(action), "%s action exists" % action)
		_check(not InputMap.action_get_events(action).is_empty(), "%s has a default binding" % action)
	_check(InputMap.has_action(&"fire"), "fire action exists")
	_check(not InputMap.action_get_events(&"fire").is_empty(), "fire has a default binding")

	var counts := {}
	for action in InputBootstrap.KEY_BINDINGS:
		counts[action] = InputMap.action_get_events(action).size()
	var fire_count := InputMap.action_get_events(&"fire").size()
	InputBootstrap.ensure_defaults()
	for action in InputBootstrap.KEY_BINDINGS:
		_check(InputMap.action_get_events(action).size() == counts[action], "%s bootstrap is idempotent" % action)
	_check(InputMap.action_get_events(&"fire").size() == fire_count, "fire bootstrap is idempotent")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("input bootstrap tests: PASS")
		quit(0)
	else:
		print("input bootstrap tests: FAIL (%d)" % failures)
		quit(1)
