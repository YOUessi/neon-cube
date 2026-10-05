class_name MissionAnchor
extends Marker3D

enum Kind { PLAYER_START, ENCOUNTER_CENTER, CHECKPOINT, EXTRACTION }

@export var anchor_id: StringName
@export var encounter_id: StringName
@export var district_id: StringName
@export var kind: Kind = Kind.ENCOUNTER_CENTER

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if anchor_id == &"":
		errors.append("anchor_id must not be empty")
	if district_id == &"" or not DistrictCatalog.has_definition(district_id):
		errors.append("anchor must reference a valid district")
	if kind != Kind.PLAYER_START and encounter_id == &"":
		errors.append("non-start anchor must reference an encounter")
	return errors
