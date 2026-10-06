class_name EncounterDefinition
extends Resource

@export var encounter_id: StringName
@export var title := ""
@export var objective_text := ""
@export var district_id: StringName
@export var enemy_kinds: Array[StringName] = []
@export var spawn_batch_sizes: Array[int] = []
@export var reinforcement_trigger_remaining := 0
@export var reinforcement_delay := 0.75
@export var objective_node_count := 0
@export var hold_zone_seconds := 0.0
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
	if reinforcement_trigger_remaining < 0:
		errors.append("reinforcement_trigger_remaining must be non-negative")
	if reinforcement_delay < 0.0:
		errors.append("reinforcement_delay must be non-negative")
	if objective_node_count < 0:
		errors.append("objective_node_count must be non-negative")
	if hold_zone_seconds < 0.0:
		errors.append("hold_zone_seconds must be non-negative")
	if not spawn_batch_sizes.is_empty():
		var total := 0
		for batch_size in spawn_batch_sizes:
			if batch_size <= 0:
				errors.append("spawn_batch_sizes must contain only positive values")
			total += batch_size
		if total != enemy_kinds.size():
			errors.append("spawn_batch_sizes must sum to enemy_kinds size")
	if boss_encounter and not enemy_kinds.has(&"boss"):
		errors.append("boss encounter must include boss enemy")
	return errors


func effective_batch_sizes() -> Array[int]:
	if spawn_batch_sizes.is_empty():
		return [enemy_kinds.size()]
	return spawn_batch_sizes.duplicate()


func batch_count() -> int:
	return effective_batch_sizes().size()
