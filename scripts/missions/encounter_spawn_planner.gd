class_name EncounterSpawnPlanner
extends RefCounted

static func spawn_positions(
	encounter: EncounterDefinition,
	count: int,
	cube_size: float,
	sequence_offset: int = 0
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if encounter == null or count <= 0:
		return result
	var district := DistrictCatalog.get_by_id(encounter.district_id)
	if district == null:
		return result

	var half := cube_size * 0.5
	var down := district.face_down.normalized()
	var basis := CubeGravity.tangent_basis(down)
	var right := basis.x
	var inward := basis.y
	var forward := -basis.z

	for i in range(count):
		var n := i + sequence_offset + district.prop_seed * 7
		var ring := n / 8
		var slot := n % 8
		var angle := TAU * float(slot) / 8.0
		var radius := 11.0 + float(ring % 3) * 4.0
		var u := cos(angle) * radius
		var v := sin(angle) * radius
		# Keep mission spawns away from the exact face center and cube corners.
		u = clampf(u, -21.0, 21.0)
		v = clampf(v, -21.0, 21.0)
		var position := down * (half - 1.35) + right * u + forward * v + inward * 0.15
		result.append(position)
	return result

static func on_expected_face(
	position: Vector3,
	encounter: EncounterDefinition,
	cube_size: float,
	tolerance: float = 2.0
) -> bool:
	if encounter == null:
		return false
	var district := DistrictCatalog.get_by_id(encounter.district_id)
	if district == null:
		return false
	var half := cube_size * 0.5
	var face_distance := CubeGravity.face_distance(position, district.face_down, half)
	return absf(face_distance) <= tolerance
