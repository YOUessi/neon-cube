class_name MissionCatalog
extends RefCounted

const NEON_MARKET_SIEGE_PATH := "res://data/missions/neon_market_siege.tres"

static func primary() -> MissionDefinition:
	var resource := load(NEON_MARKET_SIEGE_PATH)
	if resource is MissionDefinition:
		return resource as MissionDefinition
	push_error("MissionCatalog could not load typed mission resource")
	return null

static func validate_all() -> PackedStringArray:
	var mission := primary()
	if mission == null:
		return PackedStringArray(["primary mission failed to load as MissionDefinition"])
	return mission.validation_errors()
