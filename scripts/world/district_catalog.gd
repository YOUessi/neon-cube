class_name DistrictCatalog
extends RefCounted

const FLOOR: DistrictDefinition = preload("res://data/districts/neon_market.tres")
const CEILING: DistrictDefinition = preload("res://data/districts/sky_temple.tres")
const EAST: DistrictDefinition = preload("res://data/districts/industrial_arc.tres")
const WEST: DistrictDefinition = preload("res://data/districts/data_quarter.tres")
const SOUTH: DistrictDefinition = preload("res://data/districts/void_docks.tres")
const NORTH: DistrictDefinition = preload("res://data/districts/synth_garden.tres")

static func all() -> Array[DistrictDefinition]:
	return [FLOOR, CEILING, EAST, WEST, SOUTH, NORTH]

static func for_face(down: Vector3) -> DistrictDefinition:
	var normalized := down.normalized()
	var best: DistrictDefinition = FLOOR
	var best_dot := -INF
	for district in all():
		var score := normalized.dot(district.face_down.normalized())
		if score > best_dot:
			best_dot = score
			best = district
	return best

static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for district in all():
		if ids.has(district.district_id):
			errors.append("duplicate district id: %s" % district.district_id)
		ids[district.district_id] = true
		for error in district.validation_errors():
			errors.append("%s: %s" % [district.district_id, error])
	return errors
