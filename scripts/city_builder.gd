class_name CyberCityBuilder
extends RefCounted

const PROP_ROOT := "res://assets/third_party/quaternius_cyberpunk/"

static func build(parent: Node3D, cube_size: float) -> void:
	var half := cube_size * 0.5
	_build_environment(parent)
	for down in CubeGravity.AXIS_DOWNS:
		_build_face(parent, down, cube_size, half)

static func _build_environment(parent: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.006, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.15, 0.42)
	env.ambient_light_energy = 1.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	parent.add_child(world)

	var key := DirectionalLight3D.new()
	key.light_color = Color(0.34, 0.48, 1.0)
	key.light_energy = 1.15
	key.rotation_degrees = Vector3(-36, -28, 0)
	key.shadow_enabled = true
	parent.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.10, 0.42)
	fill.light_energy = 0.52
	fill.rotation_degrees = Vector3(28, 142, 0)
	parent.add_child(fill)

static func _theme(down: Vector3) -> Dictionary:
	if down.is_equal_approx(Vector3.DOWN):
		return {"name":"NEON MARKET","a":Color(0.0,0.95,1.0),"b":Color(1.0,0.04,0.58),"height":1.0,"props":0}
	if down.is_equal_approx(Vector3.UP):
		return {"name":"SKY TEMPLE","a":Color(0.50,0.25,1.0),"b":Color(0.20,0.62,1.0),"height":1.35,"props":1}
	if down.is_equal_approx(Vector3.RIGHT):
		return {"name":"INDUSTRIAL ARC","a":Color(1.0,0.45,0.05),"b":Color(1.0,0.08,0.25),"height":0.82,"props":2}
	if down.is_equal_approx(Vector3.LEFT):
		return {"name":"DATA QUARTER","a":Color(0.12,1.0,0.58),"b":Color(0.0,0.68,1.0),"height":1.12,"props":3}
	if down.is_equal_approx(Vector3.BACK):
		return {"name":"VOID DOCKS","a":Color(0.72,0.10,1.0),"b":Color(1.0,0.20,0.64),"height":0.94,"props":4}
	return {"name":"SYNTH GARDEN","a":Color(0.35,1.0,0.25),"b":Color(0.05,0.92,0.84),"height":1.08,"props":5}

static func _build_face(parent: Node3D, down: Vector3, cube_size: float, half: float) -> void:
	var theme := _theme(down)
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
		var floor_mesh := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape_size
		floor_mesh.mesh = mesh
		floor_mesh.material_override = _material(
			Color(0.028, 0.036, 0.06),
			(theme["a"] as Color) * 0.06,
			0.45,
			0.7,
			0.32
		)
		surface.add_child(floor_mesh)

	_build_city_blocks(parent, down, half, theme)
	_build_neon_grid(parent, down, half, theme)
	_build_landmark(parent, down, half, theme)
	_build_authored_props(parent, down, half, theme)

static func _build_city_blocks(parent: Node3D, down: Vector3, half: float, theme: Dictionary) -> void:
	var basis := CubeGravity.tangent_basis(down)
	var right := basis.x
	var inward := basis.y
	var forward := -basis.z
	var face_center := down * (half - 0.45)
	var coords := PackedFloat32Array([-22.0, -15.0, -8.0, 8.0, 15.0, 22.0])
	var idx := 0
	for u in coords:
		for v in coords:
			if absf(u) < 5.0 or absf(v) < 5.0:
				continue
			if (idx + int(theme["props"])) % 6 == 0:
				idx += 1
				continue
			var height_scale: float = float(theme["height"])
			var height := (3.8 + float((idx * 37 + int(theme["props"]) * 11) % 9) * 0.78) * height_scale
			var width := 3.4 + float((idx * 13) % 3) * 0.52
			var depth := 3.5 + float((idx * 19) % 3) * 0.52
			var center := face_center + right * u + forward * v + inward * (height * 0.5)
			var color := theme["a"] as Color if idx % 2 == 0 else theme["b"] as Color
			_add_building(parent, center, basis, Vector3(width,height,depth), idx, color, String(theme["name"]))
			idx += 1

static func _add_building(parent: Node3D, position: Vector3, basis: Basis, size: Vector3, seed: int, neon: Color, district: String) -> void:
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

	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material(Color(0.04,0.05,0.075), neon * 0.045, 0.24, 0.78, 0.23)
	body.add_child(visual)

	var floors := clampi(int(size.y / 1.25), 2, 7)
	for row in range(floors):
		var y := -size.y * 0.34 + float(row) * size.y * 0.68 / float(maxi(1, floors - 1))
		_add_window(body, Vector3(0,y,-size.z*0.505), Vector3(size.x*0.68,0.09,0.035), neon)
		_add_window(body, Vector3(0,y,size.z*0.505), Vector3(size.x*0.68,0.09,0.035), neon)
		_add_window(body, Vector3(size.x*0.505,y,0), Vector3(0.035,0.09,size.z*0.68), neon)
		_add_window(body, Vector3(-size.x*0.505,y,0), Vector3(0.035,0.09,size.z*0.68), neon)

	for side in [-1.0,1.0]:
		var edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(0.055,size.y*0.9,0.055)
		edge.mesh = edge_mesh
		edge.position = Vector3(size.x*0.43*side,0,-size.z*0.51)
		edge.material_override = _material(neon*0.10, neon, 7.5, 0.05, 0.62)
		body.add_child(edge)

	if seed % 3 == 0:
		var sign := Label3D.new()
		sign.text = "%s // %02d" % [district, seed % 97]
		sign.font_size = 24
		sign.modulate = neon
		sign.outline_size = 5
		sign.outline_modulate = Color(0.01,0.01,0.03,0.92)
		sign.position = Vector3(0,size.y*0.20,-size.z*0.54)
		sign.rotation_degrees = Vector3(0,180,0)
		body.add_child(sign)

	if size.y > 7.0 and seed % 2 == 0:
		var antenna := MeshInstance3D.new()
		var antenna_mesh := CylinderMesh.new()
		antenna_mesh.top_radius = 0.025
		antenna_mesh.bottom_radius = 0.045
		antenna_mesh.height = 1.3
		antenna.mesh = antenna_mesh
		antenna.position = Vector3(0,size.y*0.5+0.65,0)
		antenna.material_override = _material(neon*0.08,neon,8.0,0.05,0.7)
		body.add_child(antenna)

static func _add_window(parent: Node3D, pos: Vector3, size: Vector3, neon: Color) -> void:
	var strip := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	strip.mesh = mesh
	strip.position = pos
	strip.material_override = _material(neon*0.16,neon,5.8,0.08,0.55)
	parent.add_child(strip)

static func _build_neon_grid(parent: Node3D, down: Vector3, half: float, theme: Dictionary) -> void:
	var basis := CubeGravity.tangent_basis(down)
	var right := basis.x
	var inward := basis.y
	var forward := -basis.z
	var face_center := down * (half - 0.46)
	var a := theme["a"] as Color
	var b := theme["b"] as Color
	for offset in [-24.0,-12.0,0.0,12.0,24.0]:
		_add_strip(parent,face_center+right*offset+inward*0.045,basis,Vector3(0.09,0.045,53.0),a)
		_add_strip(parent,face_center+forward*offset+inward*0.045,basis,Vector3(53.0,0.045,0.09),b)
	for offset in [-4.0,4.0]:
		_add_strip(parent,face_center+right*offset+inward*0.05,basis,Vector3(0.045,0.035,54.0),Color(1.0,0.68,0.08))

static func _build_landmark(parent: Node3D, down: Vector3, half: float, theme: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var basis := CubeGravity.tangent_basis(down)
	var inward := basis.y
	var center := down * (half - 0.42) + inward * 0.08
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.55
	mesh.bottom_radius = 1.55
	mesh.height = 0.055
	mesh.radial_segments = 48
	ring.mesh = mesh
	ring.position = center
	ring.basis = basis
	var a := theme["a"] as Color
	ring.material_override = _material(Color(0.012,0.018,0.038),a*0.42,0.75,0.72,0.28)
	parent.add_child(ring)

	var label := Label3D.new()
	label.text = String(theme["name"])
	label.font_size = 44
	label.modulate = a
	label.outline_size = 8
	label.outline_modulate = Color(0,0,0,0.9)
	label.position = center + inward * 0.55
	label.basis = basis
	parent.add_child(label)

static func _build_authored_props(parent: Node3D, down: Vector3, half: float, theme: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var basis := CubeGravity.tangent_basis(down)
	var right := basis.x
	var inward := basis.y
	var forward := -basis.z
	var center := down * (half - 0.47) + inward * 0.05
	var prop_paths := [
		PROP_ROOT+"street_light.gltf",
		PROP_ROOT+"computer.gltf",
		PROP_ROOT+"door.gltf",
		PROP_ROOT+"antenna.gltf",
		PROP_ROOT+"fence.gltf",
	]
	var index := int(theme["props"])
	for i in range(6):
		var path: String = prop_paths[(index+i)%prop_paths.size()]
		if not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var prop := packed.instantiate() as Node3D
		if prop == null:
			continue
		var u := -9.0 + float((i*7+index*3)%18)
		var v := -10.0 + float((i*11+index*5)%20)
		prop.position = center + right*u + forward*v
		prop.basis = basis
		prop.scale = Vector3.ONE * (1.25 + float(i%3)*0.18)
		parent.add_child(prop)

	for side in [-1.0,1.0]:
		var light := OmniLight3D.new()
		light.light_color = theme["a"] as Color if side < 0.0 else theme["b"] as Color
		light.light_energy = 2.0
		light.omni_range = 8.5
		light.position = center + right * (side * 7.0) + inward * 2.0
		parent.add_child(light)

static func _add_strip(parent: Node3D, position: Vector3, basis: Basis, size: Vector3, color: Color) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var strip := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	strip.mesh = mesh
	strip.position = position
	strip.basis = basis
	strip.material_override = _material(color*0.12,color,6.0,0.04,0.7)
	parent.add_child(strip)

static func _material(base: Color, emission: Color, energy: float, metallic: float = 0.55, roughness: float = 0.36) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.metallic = metallic
	mat.roughness = roughness
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat
