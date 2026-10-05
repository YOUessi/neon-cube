extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(DistrictCatalog.validate_all().is_empty(), "all district definitions validate")
	_check(DistrictCatalog.all().size() == 6, "all six cube districts are defined")

	var ids := {}
	for face in CubeGravity.AXIS_DOWNS:
		var district := DistrictCatalog.for_face(face)
		_check(district != null, "each gravity face resolves to a district")
		_check(not ids.has(district.district_id), "each face maps to a unique district")
		ids[district.district_id] = true
		_check(district.face_down.is_equal_approx(face), "district face axis matches gravity face")

	_check(DistrictCatalog.FLOOR.display_name != DistrictCatalog.CEILING.display_name, "floor and ceiling identities differ")
	_check(not DistrictCatalog.EAST.primary_neon.is_equal_approx(DistrictCatalog.WEST.primary_neon), "east/west art palettes differ")
	_check(DistrictCatalog.CEILING.building_height_scale > DistrictCatalog.EAST.building_height_scale, "district skyline profiles differ")

	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)

func _finish() -> void:
	if failures == 0:
		print("district catalog tests: PASS")
		quit(0)
	else:
		print("district catalog tests: FAIL (%d)" % failures)
		quit(1)
