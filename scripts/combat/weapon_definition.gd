class_name WeaponDefinition
extends Resource

@export var weapon_id: StringName
@export var display_name := ""
@export var damage := 10.0
@export var fire_rate := 5.0
@export var magazine_size := 30
@export var initial_reserve := 120
@export var reserve_cap := 180
@export var reload_seconds := 1.0
@export var pellets := 1
@export var spread := 0.0
@export var max_range := 100.0
@export var accent_color := Color.WHITE
@export var view_model_scene: PackedScene
@export var view_model_scale := 0.38
@export var view_model_rotation_degrees := Vector3(-8.0, 180.0, 0.0)
@export var recoil_pitch_degrees := 1.0
@export var recoil_yaw_degrees := 0.25
@export var view_kick_distance := 0.035
@export var view_kick_recovery_speed := 0.45

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if weapon_id == &"":
		errors.append("weapon_id must not be empty")
	if display_name.is_empty():
		errors.append("display_name must not be empty")
	if damage <= 0.0:
		errors.append("damage must be positive")
	if fire_rate <= 0.0:
		errors.append("fire_rate must be positive")
	if magazine_size <= 0:
		errors.append("magazine_size must be positive")
	if initial_reserve < 0 or reserve_cap < initial_reserve:
		errors.append("reserve values are invalid")
	if reload_seconds < 0.0:
		errors.append("reload_seconds must be non-negative")
	if pellets <= 0:
		errors.append("pellets must be positive")
	if spread < 0.0:
		errors.append("spread must be non-negative")
	if max_range <= 0.0:
		errors.append("max_range must be positive")
	if recoil_pitch_degrees < 0.0 or recoil_yaw_degrees < 0.0:
		errors.append("recoil angles must be non-negative")
	if view_kick_distance < 0.0 or view_kick_recovery_speed <= 0.0:
		errors.append("view kick values are invalid")
	return errors
