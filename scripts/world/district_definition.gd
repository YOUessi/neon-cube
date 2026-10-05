class_name DistrictDefinition
extends Resource

@export var district_id: StringName
@export var display_name := ""
@export var face_down := Vector3.DOWN
@export var primary_neon := Color(0.0, 0.95, 1.0)
@export var secondary_neon := Color(1.0, 0.04, 0.62)
@export var road_neon := Color(1.0, 0.72, 0.08)
@export_range(0.6, 1.8, 0.05) var building_height_scale := 1.0
@export_range(3, 9, 1) var density_skip_mod := 5
@export var sign_prefix := "NEX"
@export var prop_seed := 0

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if district_id == &"":
		errors.append("district_id must not be empty")
	if display_name.is_empty():
		errors.append("display_name must not be empty")
	if face_down.length_squared() < 0.9:
		errors.append("face_down must be a cube-face axis")
	if sign_prefix.is_empty():
		errors.append("sign_prefix must not be empty")
	return errors
