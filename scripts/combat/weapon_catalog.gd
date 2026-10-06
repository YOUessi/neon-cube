class_name WeaponCatalog
extends RefCounted

const PULSE_RIFLE_PATH := "res://data/weapons/pulse_rifle.tres"
const ARC_SCATTERGUN_PATH := "res://data/weapons/arc_scattergun.tres"
const ION_MARKSMAN_PATH := "res://data/weapons/ion_marksman.tres"

static func all() -> Array[WeaponDefinition]:
	return [
		_load_definition(PULSE_RIFLE_PATH),
		_load_definition(ARC_SCATTERGUN_PATH),
		_load_definition(ION_MARKSMAN_PATH),
	]

static func get_definition(index: int) -> WeaponDefinition:
	var definitions := all()
	if index < 0 or index >= definitions.size():
		return definitions[0]
	return definitions[index]

static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for definition in all():
		if definition == null:
			errors.append("weapon definition failed to load as WeaponDefinition")
			continue
		for error in definition.validation_errors():
			errors.append("%s: %s" % [definition.weapon_id, error])
	return errors

static func _load_definition(path: String) -> WeaponDefinition:
	var resource := load(path)
	if resource is WeaponDefinition:
		return resource as WeaponDefinition
	push_error("WeaponCatalog could not load typed resource: %s" % path)
	return null
