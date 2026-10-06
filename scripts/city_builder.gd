class_name CyberCityBuilder
extends RefCounted

static func build(parent: Node3D, cube_size: float) -> void:
	var half := cube_size * 0.5
	_build_environment(parent)
	for down in CubeGravity.AXIS_DOWNS:
		var district: DistrictDefinition = DistrictCatalog.for_face(down)
		_build_face(parent, down, cube_size, half, district)

static func _build_environment(parent: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.006, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.12, 0.32)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	parent.add_child(world)

	var key := DirectionalLight3D.new()
	key.light_color = Color(0.28, 0.46, 1.0)
	key.light_energy = 0.92
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.shadow_enabled = true
	parent.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.08, 0.42)
	fill.light_energy = 0.34
	fill.rotation_degrees = Vector3(30, 145, 0)
	parent.add_child(fill)

static func _build_face(
	parent: Node3D,
	down: Vector3,
	cube_size: float,
	half: float,
	district: DistrictDefinition
) -> void:
	var surface := StaticBody3D.new()
	surface.name = "Surface_%s" % CubeGravity.face_name(down).replace(" / ", "_")
	parent.add_child(surface)

	var thickness := 0.75
	var shape_size := Vector3(cube_size, cube_size, cube_size)
	if absf(down.x) > 0.5:
		shape_size.x = thickness
	elif absf(down.y) > 0.5:
		shape_size.y = thickness
	else:
		shape_size.z = thickness
	surface.position = down * half

	var collider := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = shape_size
	collider.shape = box_shape
	surface.add_child(collider)

	if DisplayServer.get_name() != "headless":
		var mesh_instance := MeshInstance3D.new()
		var floor_mesh := BoxMesh.new()
		floor_mesh.size = shape_size
		mesh_instance.mesh = floor_mesh
		mesh_instance.material_override = _material(
			Color(0.035, 0.05, 0.085),
			Color(0.01, 0.055, 0.09),
			0.65,
			0.74,
			0.31
		)
		surface.add_child(mesh_instance)

	_build_city_blocks(parent, down, half, district)
	_build_neon_grid(parent, down, half, district)
	_build_plaza(parent, down, half, district)
	_build_authored_props(parent, down, half, district)

static func _build_city_blocks(
	parent: Node3D,
	down: Vector3,
	half: float,
	district: DistrictDefinition
) -> void:
	var basis := CubeGravity.tangent_basis(down)
	var right := basis.x
	var inward_up := basis.y
	var forward := -basis.z
	var face_center := down * (half - 0.45)
	var coords := PackedFloat32Array([-22.0, -15.0, -8.0, 8.0, 15.0, 22.0])
	var idx := 0
	for u in coords:
		for v in coords:
			if absf(u) < 5.0 or absf(v) < 5.0:
				continue
			if _reserved_for_mission(district.district_id, u, v):
				continue
			if int((absf(u) + absf(v)) / 7.0 + float(district.prop_seed)) % district.density_skip_mod == 0:
				continue
			var height := (3.8 + float((idx * 37 + district.prop_seed * 11) % 9) * 0.78) * district.building_height_scale
			var width := 3.5 + float((idx * 13) % 3) * 0.55
			var depth := 3.6 + float((idx * 19) % 3) * 0.52
			var center: Vector3 = face_center + right * u + forward * v + inward_up * (height * 0.5)
			_add_building(parent, center, basis, Vector3(width, height, depth), idx, district)
			idx += 1

static func _reserved_for_mission(district_id: StringName, u: float, v: float) -> bool:
	match district_id:
		&"neon_market":
			# Arrival boulevard, market hall/seam, and the return extraction route.
			return (
				(absf(u) <= 7.0 and v >= -25.0 and v <= -2.0)
				or (u >= 4.0 and u <= 29.0 and v >= -5.0 and v <= 13.0)
				or (u >= -20.0 and u <= 6.0 and v >= -28.0 and v <= -6.0)
			)
		&"industrial_arc":
			# Bottom-to-east landing, breach arena, relay approach and east conduit.
			return (
				(u >= -14.0 and u <= 4.0 and v >= -29.0 and v <= 1.0)
				or (u >= -2.0 and u <= 29.0 and v >= -9.0 and v <= 1.0)
			)
		&"data_quarter":
			# West conduit, data-lane combat bowl and Warden access gate.
			return u >= -29.0 and u <= 16.0 and v >= 1.0 and v <= 20.0
		&"void_docks":
			# South-face transit band and Null Warden arena.
			return (
				(absf(u) <= 13.0 and v >= -16.0 and v <= 11.0)
				or (u >= -29.0 and u <= 29.0 and v >= 10.0 and v <= 21.0)
			)
	return false


static func _add_building(
	parent: Node3D,
	position: Vector3,
	basis: Basis,
	size: Vector3,
	seed: int,
	district: DistrictDefinition
) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.basis = basis
	parent.add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	if DisplayServer.get_name() == "headless":
		return

	var neon: Color = district.primary_neon if seed % 2 == 0 else district.secondary_neon
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var base := Color(0.045, 0.052, 0.078)
	if district.district_id == &"neon_market":
		base = Color(0.062, 0.052, 0.068)
	visual.material_override = _material(base, neon * 0.05, 0.22, 0.80, 0.28)
	body.add_child(visual)

	var floors := clampi(int(size.y / 1.4), 2, 6)
	for row in range(floors):
		var y: float = -size.y * 0.34 + float(row) * size.y * 0.68 / float(maxi(1, floors - 1))
		var window_neon := neon
		if district.district_id == &"neon_market" and row % 3 == 1:
			window_neon = Color(1.0, 0.38, 0.12)
		_add_window_strip(body, Vector3(0, y, -size.z * 0.505), Vector3(size.x * 0.68, 0.10, 0.04), window_neon)
		_add_window_strip(body, Vector3(0, y, size.z * 0.505), Vector3(size.x * 0.68, 0.10, 0.04), window_neon)
		_add_window_strip(body, Vector3(size.x * 0.505, y, 0), Vector3(0.04, 0.10, size.z * 0.68), window_neon)
		_add_window_strip(body, Vector3(-size.x * 0.505, y, 0), Vector3(0.04, 0.10, size.z * 0.68), window_neon)

	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(0.06, size.y * 0.9, 0.06)
		edge.mesh = edge_mesh
		edge.position = Vector3(size.x * 0.43 * side, 0, -size.z * 0.51)
		edge.material_override = _material(neon * 0.07, neon, 3.8, 0.05, 0.68)
		body.add_child(edge)

	if district.district_id == &"neon_market" and seed % 2 == 0:
		var storefront_accent := Color(1.0, 0.36, 0.12) if seed % 4 == 0 else neon

		var awning := MeshInstance3D.new()
		awning.name = "MarketAwning"
		var awning_mesh := BoxMesh.new()
		awning_mesh.size = Vector3(maxf(1.2, size.x * 0.62), 0.10, 0.42)
		awning.mesh = awning_mesh
		awning.position = Vector3(0, -size.y * 0.28, -size.z * 0.52)
		awning.material_override = _material(
			Color(0.055, 0.035, 0.055),
			storefront_accent,
			0.55,
			0.08,
			0.58
		)
		body.add_child(awning)

		var storefront := MeshInstance3D.new()
		storefront.name = "StorefrontLightbox"
		var storefront_mesh := BoxMesh.new()
		storefront_mesh.size = Vector3(maxf(0.9, size.x * 0.44), 0.32, 0.055)
		storefront.mesh = storefront_mesh
		storefront.position = Vector3(0, -size.y * 0.20, -size.z * 0.51 - 0.035)
		storefront.material_override = _material(
			storefront_accent * 0.08,
			storefront_accent,
			2.8,
			0.06,
			0.55
		)
		body.add_child(storefront)

	if seed % 3 == 0:
		var sign := Label3D.new()
		sign.text = "%s // %02d" % [district.sign_prefix, seed % 97]
		sign.font_size = 26
		sign.modulate = neon
		sign.outline_size = 5
		sign.outline_modulate = Color(0.01, 0.01, 0.03, 0.85)
		sign.position = Vector3(0, size.y * 0.22, -size.z * 0.505 - 0.08)
		sign.rotation_degrees = Vector3(0, 180, 0)
		body.add_child(sign)

	if size.y > 7.5 and seed % 2 == 0:
		var antenna := MeshInstance3D.new()
		var antenna_mesh := CylinderMesh.new()
		antenna_mesh.top_radius = 0.025
		antenna_mesh.bottom_radius = 0.045
		antenna_mesh.height = 1.4
		antenna.mesh = antenna_mesh
		antenna.position = Vector3(0, size.y * 0.5 + 0.7, 0)
		antenna.material_override = _material(neon * 0.07, neon, 4.0, 0.05, 0.72)
		body.add_child(antenna)

static func _add_window_strip(parent: Node3D, position: Vector3, size: Vector3, neon: Color) -> void:
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = size
	strip.mesh = strip_mesh
	strip.position = position
	strip.material_override = _material(neon * 0.10, neon, 2.8, 0.08, 0.62)
	parent.add_child(strip)

static func _build_neon_grid(
	parent: Node3D,
	down: Vector3,
	half: float,
	district: DistrictDefinition
) -> void:
	var basis := CubeGravity.tangent_basis(down)
	var right := basis.x
	var inward_up := basis.y
	var forward := -basis.z
	var face_center := down * (half - 0.46)
	for offset in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		_add_strip(parent, face_center + right * offset + inward_up * 0.05, basis, Vector3(0.09, 0.045, 53.0), district.primary_neon)
		_add_strip(parent, face_center + forward * offset + inward_up * 0.05, basis, Vector3(53.0, 0.045, 0.09), district.secondary_neon)
	for offset in [-4.0, 4.0]:
		_add_strip(parent, face_center + right * offset + inward_up * 0.055, basis, Vector3(0.045, 0.04, 54.0), district.road_neon)

static func _build_authored_props(
	parent: Node3D,
	down: Vector3,
	half: float,
	district: DistrictDefinition
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var basis: Basis = CubeGravity.tangent_basis(down)
	var right: Vector3 = basis.x
	var inward: Vector3 = basis.y
	var forward: Vector3 = -basis.z
	var center: Vector3 = down * (half - 0.48) + inward * 0.04

	var placements := [
		["res://assets/third_party/quaternius_cyberpunk/street_light.gltf", center + right * 5.0 + forward * 6.0, 0.72],
		["res://assets/third_party/quaternius_cyberpunk/street_light.gltf", center - right * 5.0 + forward * 6.0, 0.72],
		["res://assets/third_party/quaternius_cyberpunk/street_light.gltf", center + right * 5.0 - forward * 6.0, 0.72],
		["res://assets/third_party/quaternius_cyberpunk/street_light.gltf", center - right * 5.0 - forward * 6.0, 0.72],
		["res://assets/third_party/quaternius_cyberpunk/computer.gltf", center + right * 7.5 + forward * 1.5, 0.55],
		["res://assets/third_party/quaternius_cyberpunk/door.gltf", center - right * 8.0 - forward * 2.0, 1.0],
		["res://assets/third_party/quaternius_cyberpunk/antenna.gltf", center + right * 10.5 - forward * 9.0, 1.0],
		["res://assets/third_party/quaternius_cyberpunk/fence.gltf", center - right * 10.0 + forward * 9.0, 1.15],
	]
	var rotation_offset := district.prop_seed % placements.size()
	for i in range(placements.size()):
		var placement: Array = placements[(i + rotation_offset) % placements.size()]
		var path: String = placement[0]
		if not ResourceLoader.exists(path):
			continue
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			continue
		var prop: Node3D = packed.instantiate() as Node3D
		if prop == null:
			continue
		var prop_kind := path.get_file().get_basename()
		prop.name = "CityProp_%s_%02d" % [prop_kind.to_pascal_case(), i]
		prop.position = placement[1]
		prop.basis = basis
		prop.scale = Vector3.ONE * float(placement[2])
		prop.add_to_group("city_authored_prop")
		prop.add_to_group("city_prop_%s" % prop_kind)
		parent.add_child(prop)

	for light_offset in [-8.0, 8.0]:
		var glow_light := OmniLight3D.new()
		glow_light.light_color = district.primary_neon if light_offset < 0.0 else district.secondary_neon
		glow_light.light_energy = 1.3
		glow_light.omni_range = 9.0
		glow_light.position = center + right * light_offset + inward * 2.2
		parent.add_child(glow_light)

static func _build_plaza(
	parent: Node3D,
	down: Vector3,
	half: float,
	district: DistrictDefinition
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var basis := CubeGravity.tangent_basis(down)
	var inward := basis.y
	var face_center := down * (half - 0.42)
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 3.2
	mesh.bottom_radius = 3.2
	mesh.height = 0.08
	mesh.radial_segments = 48
	ring.mesh = mesh
	ring.position = face_center + inward * 0.06
	ring.basis = basis
	ring.material_override = _material(Color(0.02,0.025,0.05), district.primary_neon * 0.55, 1.1, 0.75, 0.18)
	parent.add_child(ring)

	var label := Label3D.new()
	label.text = district.display_name
	label.font_size = 36
	label.modulate = district.primary_neon
	label.outline_size = 7
	label.outline_modulate = Color(0.005, 0.008, 0.02, 0.92)
	label.position = face_center + inward * 0.55
	label.basis = basis
	parent.add_child(label)

static func _add_strip(parent: Node3D, position: Vector3, basis: Basis, size: Vector3, color: Color) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var strip := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	strip.mesh = mesh
	strip.position = position
	strip.basis = basis
	strip.material_override = _material(color * 0.07, color, 2.6, 0.02, 0.78)
	parent.add_child(strip)

static func _material(
	base: Color,
	emission: Color,
	energy: float,
	metallic: float = 0.55,
	roughness: float = 0.36
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.metallic = metallic
	mat.roughness = roughness
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat
