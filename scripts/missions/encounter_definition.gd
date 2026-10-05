class_name EncounterDefinition
extends Resource

@export var encounter_id: StringName
@export var title := ""
@export var objective_text := ""
@export var district_id: StringName
@export var enemy_kinds: Array[StringName] = []
@export var checkpoint_id: StringName
@export var boss_encounter := false
@export var reward_health := 0.0
@export var reward_ammo := 0
@export var reward_shield := 0.0

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if encounter_id == &"":
		errors.append("encounter_id must not be empty")
	if title.is_empty():
		errors.append("title must not be empty")
	if objective_text.is_empty():
		errors.append("objective_text must not be empty")
	if district_id == &"":
		errors.append("district_id must not be empty")
	elif not DistrictCatalog.has_definition(district_id):
		errors.append("unknown district_id: %s" % district_id)
	if enemy_kinds.is_empty():
		errors.append("enemy_kinds must not be empty")
	for kind in enemy_kinds:
		if not EnemyCatalog.has_definition(kind):
			errors.append("unknown enemy kind: %s" % kind)
	if boss_encounter and not enemy_kinds.has(&"boss"):
		errors.append("boss encounter must include boss enemy")
	return errors
