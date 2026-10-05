class_name EnemyDefinition
extends Resource

@export var enemy_id: StringName
@export var display_name := ""
@export var base_health := 70.0
@export var move_speed := 4.8
@export var attack_range := 15.0
@export var attack_damage := 8.0
@export var attack_interval := 0.8
@export var score_value := 100
@export var model_scene: PackedScene
@export var model_scale := 0.72
@export var behavior_tags: Array[StringName] = []

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if enemy_id == &"":
		errors.append("enemy_id must not be empty")
	if display_name.is_empty():
		errors.append("display_name must not be empty")
	if base_health <= 0.0:
		errors.append("base_health must be positive")
	if move_speed <= 0.0:
		errors.append("move_speed must be positive")
	if attack_range <= 0.0:
		errors.append("attack_range must be positive")
	if attack_damage <= 0.0:
		errors.append("attack_damage must be positive")
	if attack_interval <= 0.0:
		errors.append("attack_interval must be positive")
	if score_value <= 0:
		errors.append("score_value must be positive")
	return errors
