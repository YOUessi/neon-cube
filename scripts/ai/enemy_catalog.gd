class_name EnemyCatalog
extends RefCounted

const GRUNT: EnemyDefinition = preload("res://data/enemies/grunt.tres")
const RUNNER: EnemyDefinition = preload("res://data/enemies/runner.tres")
const SNIPER: EnemyDefinition = preload("res://data/enemies/sniper.tres")
const TANK: EnemyDefinition = preload("res://data/enemies/tank.tres")
const BOSS: EnemyDefinition = preload("res://data/enemies/boss.tres")

static func get_definition(kind: StringName) -> EnemyDefinition:
	match kind:
		&"runner":
			return RUNNER
		&"sniper":
			return SNIPER
		&"tank":
			return TANK
		&"boss":
			return BOSS
		_:
			return GRUNT

static func all() -> Array[EnemyDefinition]:
	return [GRUNT, RUNNER, SNIPER, TANK, BOSS]

static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for definition in all():
		for error in definition.validation_errors():
			errors.append("%s: %s" % [definition.enemy_id, error])
	return errors
