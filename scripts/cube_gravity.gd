class_name CubeGravity
extends RefCounted

const AXIS_DOWNS := [
	Vector3.RIGHT,
	Vector3.LEFT,
	Vector3.UP,
	Vector3.DOWN,
	Vector3.BACK,
	Vector3.FORWARD,
]

static func face_distance(position: Vector3, down: Vector3, half_extent: float) -> float:
	if absf(down.x) > 0.5:
		return half_extent - position.x * signf(down.x)
	if absf(down.y) > 0.5:
		return half_extent - position.y * signf(down.y)
	return half_extent - position.z * signf(down.z)

static func nearest_down(
	position: Vector3,
	half_extent: float,
	current_down: Vector3 = Vector3.ZERO,
	switch_hysteresis: float = 0.32
) -> Vector3:
	var best_down := Vector3.DOWN
	var best_distance := INF
	for candidate in AXIS_DOWNS:
		var distance := face_distance(position, candidate, half_extent)
		if distance < best_distance:
			best_distance = distance
			best_down = candidate

	if current_down.length_squared() < 0.5:
		return best_down
	if best_down.is_equal_approx(current_down):
		return current_down

	var current_distance := face_distance(position, current_down, half_extent)
	if best_distance + switch_hysteresis < current_distance:
		return best_down
	return current_down

static func face_name(down: Vector3) -> String:
	if down.is_equal_approx(Vector3.DOWN):
		return "FLOOR / -Y"
	if down.is_equal_approx(Vector3.UP):
		return "CEILING / +Y"
	if down.is_equal_approx(Vector3.RIGHT):
		return "EAST / +X"
	if down.is_equal_approx(Vector3.LEFT):
		return "WEST / -X"
	if down.is_equal_approx(Vector3.BACK):
		return "SOUTH / +Z"
	if down.is_equal_approx(Vector3.FORWARD):
		return "NORTH / -Z"
	return "TRANSITION"

static func tangent_basis(down: Vector3) -> Basis:
	var up := -down.normalized()
	var helper := Vector3.UP
	if absf(up.dot(helper)) > 0.9:
		helper = Vector3.FORWARD
	var right := helper.cross(up).normalized()
	var forward := up.cross(right).normalized()
	return Basis(right, up, -forward).orthonormalized()

static func aligned_basis(current_basis: Basis, down: Vector3, delta: float, speed: float = 12.0) -> Basis:
	var up := -down.normalized()
	var forward := -current_basis.z.normalized()
	forward = forward - up * forward.dot(up)
	if forward.length_squared() < 0.001:
		forward = current_basis.x.cross(up)
	if forward.length_squared() < 0.001:
		forward = tangent_basis(down) * Vector3.FORWARD
	forward = forward.normalized()
	var right := forward.cross(up).normalized()
	var target := Basis(right, up, -forward).orthonormalized()
	var weight := 1.0 - exp(-speed * delta)
	var q := current_basis.get_rotation_quaternion().slerp(target.get_rotation_quaternion(), weight)
	return Basis(q).orthonormalized()
