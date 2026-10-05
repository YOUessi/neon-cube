class_name CubeSurfaceNavigator
extends RefCounted

static func are_adjacent(a: Vector3, b: Vector3) -> bool:
	return absf(a.normalized().dot(b.normalized())) < 0.1

static func shortest_face_path(start_down: Vector3, target_down: Vector3) -> Array[Vector3]:
	var start := _canonical_face(start_down)
	var target := _canonical_face(target_down)
	var result: Array[Vector3] = []
	if start.is_equal_approx(target):
		result.append(start)
		return result

	var queue: Array[Vector3] = [start]
	var visited := {}
	visited[_face_key(start)] = true
	var parent := {}

	while not queue.is_empty():
		var current: Vector3 = queue.pop_front()
		for candidate in CubeGravity.AXIS_DOWNS:
			if not are_adjacent(current, candidate):
				continue
			var key := _face_key(candidate)
			if visited.has(key):
				continue
			visited[key] = true
			parent[key] = current
			if candidate.is_equal_approx(target):
				return _reconstruct_path(start, target, parent)
			queue.append(candidate)

	# Six cube faces are fully connected through adjacent edges; this is only a safe fallback.
	result.append(start)
	return result

static func route_direction(
	position: Vector3,
	current_down: Vector3,
	target_position: Vector3,
	half_extent: float
) -> Vector3:
	var current := _canonical_face(current_down)
	var target_down := CubeGravity.nearest_down(target_position, half_extent)
	var next_down := _best_next_face(position, current, target_position, target_down, half_extent)

	if not next_down.is_equal_approx(current):
		var edge_direction := next_down - current * next_down.dot(current)
		if edge_direction.length_squared() > 0.001:
			return edge_direction.normalized()

	var to_target := target_position - position
	var tangent := to_target - current * to_target.dot(current)
	if tangent.length_squared() > 0.001:
		return tangent.normalized()
	return CubeGravity.tangent_basis(current).x

static func _canonical_face(direction: Vector3) -> Vector3:
	var best := CubeGravity.AXIS_DOWNS[0]
	var best_dot := -INF
	var normalized := direction.normalized()
	for face in CubeGravity.AXIS_DOWNS:
		var score := normalized.dot(face)
		if score > best_dot:
			best_dot = score
			best = face
	return best

static func _reconstruct_path(
	start: Vector3,
	target: Vector3,
	parent: Dictionary
) -> Array[Vector3]:
	var reverse_path: Array[Vector3] = [target]
	var cursor := target
	while not cursor.is_equal_approx(start):
		var key := _face_key(cursor)
		if not parent.has(key):
			return [start]
		cursor = parent[key]
		reverse_path.append(cursor)
	reverse_path.reverse()
	return reverse_path

static func _face_key(face: Vector3) -> String:
	return "%d,%d,%d" % [int(round(face.x)), int(round(face.y)), int(round(face.z))]


static func _best_next_face(
	position: Vector3,
	current_down: Vector3,
	target_position: Vector3,
	target_down: Vector3,
	half_extent: float
) -> Vector3:
	if current_down.is_equal_approx(target_down):
		return current_down
	if are_adjacent(current_down, target_down):
		return target_down

	# Opposite faces have four equally short topological routes. Prefer the side
	# whose shared edges are physically closest to both actors so enemies do not
	# run to an arbitrary cube edge.
	var best := current_down
	var best_score := INF
	for candidate in CubeGravity.AXIS_DOWNS:
		if not are_adjacent(current_down, candidate):
			continue
		if not are_adjacent(candidate, target_down):
			continue
		var from_cost := CubeGravity.face_distance(position, candidate, half_extent)
		var target_cost := CubeGravity.face_distance(target_position, candidate, half_extent)
		var score := from_cost + target_cost
		if score < best_score:
			best_score = score
			best = candidate
	return best
