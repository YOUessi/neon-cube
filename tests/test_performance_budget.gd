extends SceneTree

const BUDGET: PerformanceBudget = preload("res://data/performance/desktop_high.tres")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(BUDGET.validation_errors().is_empty(), "desktop performance budget validates")
	_check(BUDGET.evaluate(12.0, 20.0, 10, 3).is_empty(), "healthy runtime stays inside budget")

	var frame_warnings := BUDGET.evaluate(20.0, 40.0, 10, 3)
	_check(frame_warnings.size() == 2, "frame-time budget reports average and peak overruns")

	var entity_warnings := BUDGET.evaluate(12.0, 20.0, 40, 20)
	_check(entity_warnings.size() == 2, "entity budget reports enemy and pickup overruns")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("performance budget tests: PASS")
		quit(0)
	else:
		print("performance budget tests: FAIL (%d)" % failures)
		quit(1)
