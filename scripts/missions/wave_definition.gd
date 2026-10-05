class_name WaveDefinition
extends Resource

@export var wave_id: StringName
@export var title := ""
@export var enemy_kinds: Array[StringName] = []
@export var intermission_seconds := 1.8
@export var reward_health := 0.0
@export var reward_ammo := 0
@export var reward_shield := 0.0
@export var boss_wave := false

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if wave_id == &"":
		errors.append("wave_id must not be empty")
	if enemy_kinds.is_empty():
		errors.append("enemy_kinds must not be empty")
	if intermission_seconds < 0.0:
		errors.append("intermission_seconds must be non-negative")
	for kind in enemy_kinds:
		if EnemyCatalog.get_definition(kind) == null:
			errors.append("unknown enemy kind: %s" % kind)
	return errors
