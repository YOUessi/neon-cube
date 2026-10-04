class_name CyberCityBuilder
extends RefCounted

static func build(parent: Node3D, cube_size: float) -> void:
	var half := cube_size * 0.5
	_build_environment(parent)
	for down in CubeGravity.AXIS_DOWNS:
		_build_face(parent, down, cube_size, half)

static func _build_environment(parent: Node3D) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.004, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.08, 0.3)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	parent.add_child(world)

	var light := DirectionalLight3D.new()
	light.light_color = Color(0.48, 0.5, 1.0)
	light.light_energy = 1.15
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.shadow_enabled = true
	parent.add_child(light)

static func _build_face(parent: Node3D, down: Vector3, cube_size: float, half: float) -> void:
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

	var mesh_instance := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = shape_size
	mesh_instance.mesh = floor_mesh
	mesh_instance.material_override = _material(Color(0.018, 0.022, 0.038), Color(0.02, 0.08, 0.12), 0.5)
	surface.add_child(mesh_instance)

	_build_city_blocks(parent, down, half)
	_build_neon_grid(parent, down, half)

static func _build_city_blocks(parent: Node3D, down: Vector3, half: float) -> void:
	var basis := CubeGravity.tangent_basis(down)
	var right := basis.x
	var inward_up := basis.y
	var back := basis.z
	var forward := -back
	var face_center := down * (half - 0.45)
	var coords := [-21.0, -14.0, -7.0, 7.0, 14.0, 21.0]
	var idx := 0
	for u in coords:
		for v in coords:
			if absf(u) < 4.0 or absf(v) < 4.0:
				continue
			if int((absf(u) + absf(v)) / 7.0) % 4 == 0:
				continue
			var height := 2.8 + float((idx * 37) % 8) * 0.65
			var width := 3.2 + float((idx * 13) % 3) * 0.45
			var depth := 3.2 + float((idx * 19) % 3) * 0.45
			var center := face_center + right * u + forward * v + inward_up * (height * 0.5)
			_add_building(parent, center, basis, Vector3(width, height, depth), idx)
			idx += 1

static func _add_building(parent: Node3D, position: Vector3, basis: Basis, size: Vector3, seed: int) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.basis = basis
	parent.add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var base := Color(0.025, 0.03, 0.05)
	var neon := Color(0.02, 0.85, 1.0) if seed % 2 == 0 else Color(1.0, 0.04, 0.55)
	visual.material_override = _material(base, neon * 0.08, 0.28)
	body.add_child(visual)

	if seed % 3 == 0:
		var sign := MeshInstance3D.new()
		var sign_mesh := BoxMesh.new()
		sign_mesh.size = Vector3(size.x * 0.7, 0.12, 0.08)
		sign.mesh = sign_mesh
		sign.position = Vector3(0, size.y * 0.22, -size.z * 0.505)
		sign.material_override = _material(neon * 0.15, neon, 7.0)
		body.add_child(sign)

static func _build_neon_grid(parent: Node3D, down: Vector3, half: float) -> void:
	var basis := CubeGravity.tangent_basis(down)
	var right := basis.x
	var inward_up := basis.y
	var forward := -basis.z
	var face_center := down * (half - 0.46)
	for offset in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		_add_strip(parent, face_center + right * offset + inward_up * 0.04, basis, Vector3(0.08, 0.05, 52.0), Color(0.0, 0.7, 1.0))
		_add_strip(parent, face_center + forward * offset + inward_up * 0.04, basis, Vector3(52.0, 0.05, 0.08), Color(1.0, 0.03, 0.48))

static func _add_strip(parent: Node3D, position: Vector3, basis: Basis, size: Vector3, color: Color) -> void:
	var strip := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	strip.mesh = mesh
	strip.position = position
	strip.basis = basis
	strip.material_override = _material(color * 0.2, color, 4.5)
	parent.add_child(strip)

static func _material(base: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.metallic = 0.55
	mat.roughness = 0.36
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat
