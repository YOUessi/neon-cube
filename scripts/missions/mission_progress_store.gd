class_name MissionProgressStore
extends RefCounted

static func save_runtime(runtime: MissionRuntime, session: GameSession = null) -> Error:
	if runtime == null or runtime.definition == null:
		return ERR_INVALID_PARAMETER
	var profile := ProfileStore.load_profile()
	var progress := {
		"runtime": runtime.snapshot(),
	}
	if session != null:
		progress["session"] = session.snapshot()
	profile["mission_progress"] = progress
	return ProfileStore.save_profile(profile)

static func load_into(
	runtime: MissionRuntime,
	mission: MissionDefinition,
	session: GameSession = null
) -> bool:
	if runtime == null or mission == null:
		return false
	var profile := ProfileStore.load_profile()
	var progress: Variant = profile.get("mission_progress", {})
	if not progress is Dictionary:
		return false
	var data: Dictionary = progress as Dictionary

	var runtime_data: Dictionary
	if data.has("runtime") and data["runtime"] is Dictionary:
		runtime_data = data["runtime"] as Dictionary
	else:
		# Backward compatibility with the first checkpoint schema, where the
		# MissionRuntime snapshot lived directly in mission_progress.
		runtime_data = data

	if StringName(runtime_data.get("mission_id", "")) != mission.mission_id:
		return false

	runtime.restore(mission, runtime_data)
	if session != null and data.has("session") and data["session"] is Dictionary:
		session.restore(data["session"] as Dictionary)
	return true

static func clear() -> Error:
	var profile := ProfileStore.load_profile()
	profile["mission_progress"] = {}
	return ProfileStore.save_profile(profile)
