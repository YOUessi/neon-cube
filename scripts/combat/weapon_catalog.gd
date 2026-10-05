class_name WeaponCatalog
extends RefCounted

const PULSE_RIFLE: WeaponDefinition = preload("res://data/weapons/pulse_rifle.tres")
const ARC_SCATTERGUN: WeaponDefinition = preload("res://data/weapons/arc_scattergun.tres")
const ION_MARKSMAN: WeaponDefinition = preload("res://data/weapons/ion_marksman.tres")

static func all() -> Array[WeaponDefinition]:
	return [PULSE_RIFLE, ARC_SCATTERGUN, ION_MARKSMAN]

static func get_definition(index: int) -> WeaponDefinition:
	var definitions := all()
	if index < 0 or index >= definitions.size():
		return definitions[0]
	return definitions[index]

static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for definition in all():
		for error in definition.validation_errors():
			errors.append("%s: %s" % [definition.weapon_id, error])
	return errors
