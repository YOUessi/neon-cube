class_name ProfileStore
extends RefCounted

const SAVE_PATH := "user://neon_cube_save.json"
const CURRENT_VERSION := 2

static func defaults() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"high_score": 0,
		"mouse_sensitivity": 0.0022,
		"master_volume_db": -6.0,
		"mission_progress": {},
	}

static func normalize(raw: Variant) -> Dictionary:
	var result := defaults()
	if raw is not Dictionary:
		return result
	var data: Dictionary = raw as Dictionary
	result["version"] = CURRENT_VERSION
	result["high_score"] = maxi(0, int(data.get("high_score", result["high_score"])))
	result["mouse_sensitivity"] = clampf(
		float(data.get("mouse_sensitivity", result["mouse_sensitivity"])),
		0.0008,
		0.0050
	)
	result["master_volume_db"] = clampf(
		float(data.get("master_volume_db", result["master_volume_db"])),
		-30.0,
		0.0
	)
	var progress: Variant = data.get("mission_progress", {})
	result["mission_progress"] = progress.duplicate(true) if progress is Dictionary else {}
	return result

static func load_profile() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return defaults()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return defaults()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return normalize(parsed)

static func save_profile(profile: Dictionary) -> Error:
	var normalized := normalize(profile)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(normalized))
	return OK
