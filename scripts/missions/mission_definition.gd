class_name MissionDefinition
extends Resource

@export var mission_id: StringName
@export var display_name := ""
@export_multiline var briefing := ""
@export var encounters: Array[EncounterDefinition] = []

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if mission_id == &"":
		errors.append("mission_id must not be empty")
	if display_name.is_empty():
		errors.append("display_name must not be empty")
	if briefing.is_empty():
		errors.append("briefing must not be empty")
	if encounters.is_empty():
		errors.append("mission must contain encounters")
	var seen := {}
	var checkpoints := {}
	for encounter in encounters:
		if encounter == null:
			errors.append("mission contains null encounter")
			continue
		if seen.has(encounter.encounter_id):
			errors.append("duplicate encounter_id: %s" % encounter.encounter_id)
		seen[encounter.encounter_id] = true
		if encounter.checkpoint_id != &"":
			if checkpoints.has(encounter.checkpoint_id):
				errors.append("duplicate checkpoint_id: %s" % encounter.checkpoint_id)
			checkpoints[encounter.checkpoint_id] = true
		for error in encounter.validation_errors():
			errors.append("%s: %s" % [encounter.encounter_id, error])
	return errors

func encounter_count() -> int:
	return encounters.size()

func get_encounter(index: int) -> EncounterDefinition:
	if encounters.is_empty():
		return null
	return encounters[clampi(index, 0, encounters.size() - 1)]
