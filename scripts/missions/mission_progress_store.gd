class_name MissionProgressStore
extends RefCounted

static func save_runtime(runtime: MissionRuntime) -> Error:
	if runtime == null or runtime.definition == null:
		return ERR_INVALID_PARAMETER
	var profile := ProfileStore.load_profile()
	profile["mission_progress"] = runtime.snapshot()
	return ProfileStore.save_profile(profile)

static func load_into(runtime: MissionRuntime, mission: MissionDefinition) -> bool:
	if runtime == null or mission == null:
		return false
	var profile := ProfileStore.load_profile()
	var progress: Variant = profile.get("mission_progress", {})
	if not progress is Dictionary:
		return false
	var data: Dictionary = progress as Dictionary
	if StringName(data.get("mission_id", "")) != mission.mission_id:
		return false
	runtime.restore(mission, data)
	return true

static func clear() -> Error:
	var profile := ProfileStore.load_profile()
	profile["mission_progress"] = {}
	return ProfileStore.save_profile(profile)
