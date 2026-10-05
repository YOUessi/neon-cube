extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var defaults := ProfileStore.normalize(null)
	_check(defaults["high_score"] == 0, "invalid profile falls back to defaults")
	_check(is_equal_approx(float(defaults["mouse_sensitivity"]), 0.0022), "default mouse sensitivity preserved")

	var normalized := ProfileStore.normalize({
		"high_score": -10,
		"mouse_sensitivity": 99.0,
		"master_volume_db": -99.0,
	})
	_check(normalized["high_score"] == 0, "negative high score is rejected")
	_check(is_equal_approx(float(normalized["mouse_sensitivity"]), 0.0050), "mouse sensitivity is clamped")
	_check(is_equal_approx(float(normalized["master_volume_db"]), -30.0), "master volume is clamped")
	_check(normalized["version"] == ProfileStore.CURRENT_VERSION, "profile schema version is normalized")
	_check(normalized["mission_progress"] is Dictionary, "legacy profile gains mission progress container")

	var mission_snapshot := {
		"mission_id": "neon_market_siege",
		"checkpoint_id": "cp_market_core",
		"encounter_index": 2,
	}
	var with_progress := ProfileStore.normalize({
		"version": 1,
		"mission_progress": mission_snapshot,
	})
	_check(with_progress["mission_progress"]["checkpoint_id"] == "cp_market_core", "mission checkpoint survives profile normalization")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("profile store tests: PASS")
		quit(0)
	else:
		print("profile store tests: FAIL (%d)" % failures)
		quit(1)
