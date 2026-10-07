class_name EnemyCatalog
extends RefCounted

const GRUNT_PATH := "res://data/enemies/grunt.tres"
const RUNNER_PATH := "res://data/enemies/runner.tres"
const SNIPER_PATH := "res://data/enemies/sniper.tres"
const TANK_PATH := "res://data/enemies/tank.tres"
const BOSS_PATH := "res://data/enemies/boss.tres"

static func has_definition(kind: StringName) -> bool:
	return kind in [&"grunt", &"runner", &"sniper", &"tank", &"boss"]

static func get_definition(kind: StringName) -> EnemyDefinition:
	match kind:
		&"runner":
			return _load_definition(RUNNER_PATH)
		&"sniper":
			return _load_definition(SNIPER_PATH)
		&"tank":
			return _load_definition(TANK_PATH)
		&"boss":
			return _load_definition(BOSS_PATH)
		_:
			return _load_definition(GRUNT_PATH)

static func all() -> Array[EnemyDefinition]:
	return [
		_load_definition(GRUNT_PATH),
		_load_definition(RUNNER_PATH),
		_load_definition(SNIPER_PATH),
		_load_definition(TANK_PATH),
		_load_definition(BOSS_PATH),
	]

static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for definition in all():
		if definition == null:
			errors.append("enemy definition failed to load as EnemyDefinition")
			continue
		for error in definition.validation_errors():
			errors.append("%s: %s" % [definition.enemy_id, error])
	return errors

static func _load_definition(path: String) -> EnemyDefinition:
	var resource := load(path)
	if resource is EnemyDefinition:
		return resource as EnemyDefinition
	push_error("EnemyCatalog could not load typed resource: %s" % path)
	return null
