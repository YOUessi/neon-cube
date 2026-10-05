class_name MissionCatalog
extends RefCounted

const NEON_MARKET_SIEGE: MissionDefinition = preload("res://data/missions/neon_market_siege.tres")

static func primary() -> MissionDefinition:
	return NEON_MARKET_SIEGE

static func validate_all() -> PackedStringArray:
	return NEON_MARKET_SIEGE.validation_errors()
