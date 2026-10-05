class_name EnemyBrain
extends RefCounted

static func desired_direction(
	definition: EnemyDefinition,
	same_face: bool,
	distance: float,
	route_direction: Vector3,
	current_down: Vector3,
	boss_phase: int = 1
) -> Vector3:
	if definition == null or route_direction.length_squared() < 0.001:
		return Vector3.ZERO

	var route := route_direction.normalized()
	var tags := definition.behavior_tags

	if tags.has(&"keep_distance") and same_face:
		var retreat_distance := definition.attack_range * 0.48
		var hold_distance := definition.attack_range * 0.78
		if distance < retreat_distance:
			return -route
		if distance <= hold_distance:
			return Vector3.ZERO
		return route

	if tags.has(&"anchor") and same_face:
		if distance <= definition.attack_range * 0.82:
			return Vector3.ZERO
		return route

	if tags.has(&"phase_driven") and same_face:
		if distance <= definition.attack_range * 0.62:
			var tangent := route.cross(-current_down).normalized()
			if tangent.length_squared() > 0.001:
				return tangent if boss_phase % 2 == 1 else -tangent
		return route

	# Rush / advance enemies keep closing distance. Their speed and attack data remain
	# independent in EnemyDefinition; this method owns only tactical movement choice.
	return route

static func wants_to_move(definition: EnemyDefinition, direction: Vector3) -> bool:
	return definition != null and direction.length_squared() > 0.01
