class_name DistrictCatalog
extends RefCounted

const FLOOR_PATH := "res://data/districts/neon_market.tres"
const CEILING_PATH := "res://data/districts/sky_temple.tres"
const EAST_PATH := "res://data/districts/industrial_arc.tres"
const WEST_PATH := "res://data/districts/data_quarter.tres"
const SOUTH_PATH := "res://data/districts/void_docks.tres"
const NORTH_PATH := "res://data/districts/synth_garden.tres"

static func all() -> Array[DistrictDefinition]:
	return [
		_load_definition(FLOOR_PATH),
		_load_definition(CEILING_PATH),
		_load_definition(EAST_PATH),
		_load_definition(WEST_PATH),
		_load_definition(SOUTH_PATH),
		_load_definition(NORTH_PATH),
	]

static func has_definition(id: StringName) -> bool:
	for district in all():
		if district != null and district.district_id == id:
			return true
	return false

static func get_by_id(id: StringName) -> DistrictDefinition:
	for district in all():
		if district != null and district.district_id == id:
			return district
	return null

static func for_face(down: Vector3) -> DistrictDefinition:
	var districts := all()
	var best: DistrictDefinition = districts[0]
	var best_dot := -INF
	var normalized := down.normalized()
	for district in districts:
		if district == null:
			continue
		var score := normalized.dot(district.face_down.normalized())
		if score > best_dot:
			best_dot = score
			best = district
	return best

static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for district in all():
		if district == null:
			errors.append("district definition failed to load as DistrictDefinition")
			continue
		if ids.has(district.district_id):
			errors.append("duplicate district id: %s" % district.district_id)
		ids[district.district_id] = true
		for error in district.validation_errors():
			errors.append("%s: %s" % [district.district_id, error])
	return errors

static func _load_definition(path: String) -> DistrictDefinition:
	var resource := load(path)
	if resource is DistrictDefinition:
		return resource as DistrictDefinition
	push_error("DistrictCatalog could not load typed resource: %s" % path)
	return null
