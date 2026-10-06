class_name NeonMarketSiegeLevel
extends Node3D

signal extraction_reached

@export var cube_half_extent := 30.0

const CYAN := Color(0.05, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.08, 0.62)
const AMBER := Color(1.0, 0.68, 0.10)
const VIOLET := Color(0.62, 0.16, 1.0)
const DARK := Color(0.025, 0.035, 0.065)
const WALL := Color(0.055, 0.065, 0.10)
const COVER := Color(0.07, 0.085, 0.12)

var _geometry_root: Node3D
var _extraction_zone: Area3D
var _extraction_label: Label3D
var _extraction_armed := false


func _ready() -> void:
	if get_node_or_null("Geometry") != null:
		return
	_geometry_root = Node3D.new()
	_geometry_root.name = "Geometry"
	add_child(_geometry_root)
	_build_neon_market()
	_build_gravity_breach()
	_build_trans_face_transit()
	_build_data_lane()
	_build_boss_arena()
	_build_extraction()


func arm_extraction(active: bool = true) -> void:
	_extraction_armed = active
	if _extraction_zone != null:
		_extraction_zone.monitoring = active
	if _extraction_label != null:
		_extraction_label.visible = active


func spatial_summary() -> Dictionary:
	return {
		"mission_geometry": get_tree().get_nodes_in_group("mission_geometry").size(),
		"combat_cover": get_tree().get_nodes_in_group("combat_cover").size(),
		"cross_face_passage": get_tree().get_nodes_in_group("cross_face_passage").size(),
		"boss_arena": get_tree().get_nodes_in_group("boss_arena").size(),
		"extraction_zone": get_tree().get_nodes_in_group("extraction_zone").size(),
	}


func _build_neon_market() -> void:
	var root := _region("NeonMarket")
	var down := Vector3.DOWN

	var arrival := _section(root, "ArrivalStreet")
	_add_face_box(arrival, "ArrivalRoad", down, 0.0, -13.0, 0.02, Vector3(8.0, 0.05, 22.0), DARK, CYAN, false)
	_add_face_box(arrival, "WestCurb", down, -5.0, -13.0, 0.0, Vector3(0.45, 0.65, 22.0), WALL, CYAN, true, &"combat_cover")
	_add_face_box(arrival, "EastCurb", down, 5.0, -13.0, 0.0, Vector3(0.45, 0.65, 22.0), WALL, MAGENTA, true, &"combat_cover")
	for i in range(4):
		var side := -1.0 if i % 2 == 0 else 1.0
		var lane_v := -18.0 + float(i) * 4.5
		_add_face_box(
			arrival,
			"ArrivalCover_%02d" % i,
			down,
			side * 3.1,
			lane_v,
			0.0,
			Vector3(2.1, 1.0, 0.9),
			COVER,
			CYAN if side < 0.0 else MAGENTA,
			true,
			&"combat_cover"
		)
	_add_face_label(arrival, "ArrivalSign", down, 0.0, -22.0, 2.7, "NEON MARKET // NIGHT SHIFT", CYAN)

	var hall := _section(root, "MarketHall")
	_add_face_box(hall, "HallFloor", down, 13.0, 4.0, 0.025, Vector3(17.0, 0.05, 15.0), Color(0.035, 0.04, 0.07), MAGENTA, false)
	_add_face_box(hall, "HallWestWall", down, 5.2, 5.0, 0.0, Vector3(0.45, 4.8, 11.0), WALL, CYAN, true)
	_add_face_box(hall, "HallNorthWall", down, 13.0, 11.3, 0.0, Vector3(15.8, 4.8, 0.45), WALL, MAGENTA, true)
	_add_face_box(hall, "HallSouthPierA", down, 17.8, -3.2, 0.0, Vector3(5.2, 4.8, 0.45), WALL, AMBER, true)
	_add_face_box(hall, "HallSouthPierB", down, 7.0, -3.2, 0.0, Vector3(2.8, 4.8, 0.45), WALL, CYAN, true)
	_add_face_box(hall, "HallRoof", down, 13.0, 4.0, 5.6, Vector3(16.2, 0.20, 14.4), Color(0.02, 0.025, 0.05), MAGENTA, true)
	_add_face_label(hall, "MarketHallSign", down, 10.0, -3.0, 3.4, "SUBLEVEL 07 // NIGHT BAZAAR", MAGENTA)

	var crossfire := _section(hall, "CrossfireArena")
	var stall_specs := [
		[-1.0, 8.2, 0.0],
		[1.0, 11.8, 1.8],
		[-1.0, 15.4, 4.4],
		[1.0, 9.4, 7.0],
		[-1.0, 14.2, 8.4],
	]
	for i in range(stall_specs.size()):
		var spec: Array = stall_specs[i]
		var side: float = float(spec[0])
		var u: float = float(spec[1])
		var v: float = float(spec[2])
		_add_face_box(
			crossfire,
			"MarketStall_%02d" % i,
			down,
			u,
			v,
			0.0,
			Vector3(2.8, 1.25, 1.5),
			COVER,
			CYAN if side < 0.0 else MAGENTA,
			true,
			&"combat_cover"
		)
		_add_face_box(
			crossfire,
			"Canopy_%02d" % i,
			down,
			u,
			v,
			2.15,
			Vector3(3.1, 0.12, 1.8),
			Color(0.03, 0.04, 0.07),
			MAGENTA if side < 0.0 else CYAN,
			false
		)

	var catwalk := _section(hall, "ElevatedLane")
	for i in range(5):
		var step_height := 0.35 + float(i) * 0.38
		_add_face_box(
			catwalk,
			"Step_%02d" % i,
			down,
			18.4,
			-1.5 + float(i) * 0.8,
			0.0,
			Vector3(2.2, step_height, 0.72),
			WALL,
			AMBER,
			true
		)
	_add_face_box(catwalk, "CatwalkDeck", down, 18.4, 5.3, 2.05, Vector3(2.4, 0.22, 10.4), DARK, AMBER, true)
	_add_face_box(catwalk, "CatwalkRail", down, 17.2, 5.3, 2.25, Vector3(0.14, 0.75, 10.2), WALL, AMBER, true, &"combat_cover")

	var seam := _section(root, "SeamGateway")
	seam.add_to_group("cross_face_passage")
	_add_face_box(seam, "SeamRoad", down, 25.0, 8.0, 0.02, Vector3(9.0, 0.05, 5.5), DARK, AMBER, false)
	_add_face_box(seam, "SeamRailNorth", down, 25.0, 11.0, 0.0, Vector3(9.0, 0.85, 0.28), WALL, AMBER, true, &"cross_face_passage")
	_add_face_box(seam, "SeamRailSouth", down, 25.0, 5.0, 0.0, Vector3(9.0, 0.85, 0.28), WALL, CYAN, true, &"cross_face_passage")
	_add_face_box(seam, "SeamGateLeft", down, 22.0, 8.0, 0.0, Vector3(0.45, 4.0, 0.45), WALL, CYAN, true, &"cross_face_passage")
	_add_face_box(seam, "SeamGateRight", down, 28.0, 8.0, 0.0, Vector3(0.45, 4.0, 0.45), WALL, MAGENTA, true, &"cross_face_passage")
	_add_face_box(seam, "SeamGateHeader", down, 25.0, 8.0, 3.65, Vector3(6.5, 0.35, 0.45), WALL, AMBER, true, &"cross_face_passage")
	_add_face_label(seam, "SeamLabel", down, 25.0, 7.6, 3.1, "GRAVITY SEAM // EAST ARC", AMBER)


func _build_gravity_breach() -> void:
	var root := _region("GravityBreach")
	var down := Vector3.RIGHT
	root.add_to_group("cross_face_passage")

	var landing := _section(root, "EastFaceLanding")
	_add_face_box(landing, "LandingLane", down, -8.0, -20.0, 0.02, Vector3(7.0, 0.05, 16.0), DARK, CYAN, false)
	_add_face_box(landing, "LandingRailA", down, -11.8, -20.0, 0.0, Vector3(0.30, 0.8, 16.0), WALL, CYAN, true, &"cross_face_passage")
	_add_face_box(landing, "LandingRailB", down, -4.2, -20.0, 0.0, Vector3(0.30, 0.8, 16.0), WALL, MAGENTA, true, &"cross_face_passage")

	var arena := _section(root, "BreachArena")
	_add_face_box(arena, "BreachDeck", down, -8.0, -12.0, 0.02, Vector3(15.0, 0.05, 15.0), Color(0.03, 0.04, 0.065), CYAN, false)
	var covers := [
		[-12.0, -15.0, 2.8, 1.25, 1.6],
		[-4.0, -15.0, 2.8, 1.25, 1.6],
		[-12.0, -9.0, 2.0, 1.65, 2.4],
		[-4.0, -8.0, 2.0, 1.65, 2.4],
	]
	for i in range(covers.size()):
		var c: Array = covers[i]
		_add_face_box(
			arena,
			"BreachCover_%02d" % i,
			down,
			float(c[0]),
			float(c[1]),
			0.0,
			Vector3(float(c[2]), float(c[3]), float(c[4])),
			COVER,
			AMBER if i >= 2 else CYAN,
			true,
			&"combat_cover"
		)
	_add_face_label(arena, "BreachSign", down, -8.0, -18.5, 3.0, "INDUSTRIAL ARC // BREACH CONTROL", CYAN)

	var relay := _section(root, "RelayApproach")
	_add_face_box(relay, "RelayLane", down, -3.0, -6.0, 0.02, Vector3(8.0, 0.05, 13.0), DARK, AMBER, false)
	_add_face_box(relay, "RelayBarrierA", down, -7.0, -5.0, 0.0, Vector3(2.4, 1.0, 0.8), WALL, AMBER, true, &"combat_cover")
	_add_face_box(relay, "RelayBarrierB", down, 1.0, -3.0, 0.0, Vector3(2.4, 1.0, 0.8), WALL, MAGENTA, true, &"combat_cover")


func _build_trans_face_transit() -> void:
	var root := _region("TransFaceTransit")
	root.add_to_group("cross_face_passage")

	var east := _section(root, "EastToSouthConduit")
	_add_face_box(east, "EastConduitLane", Vector3.RIGHT, 14.0, -4.0, 0.02, Vector3(27.0, 0.05, 5.5), DARK, AMBER, false)
	_add_face_box(east, "EastConduitRailA", Vector3.RIGHT, 14.0, -7.0, 0.0, Vector3(27.0, 0.75, 0.25), WALL, AMBER, true, &"cross_face_passage")
	_add_face_box(east, "EastConduitRailB", Vector3.RIGHT, 14.0, -1.0, 0.0, Vector3(27.0, 0.75, 0.25), WALL, CYAN, true, &"cross_face_passage")

	var south := _section(root, "SouthConduit")
	for i in range(5):
		var u := -24.0 + float(i) * 12.0
		var v := -2.0 + float(i) * 4.5
		_add_face_box(
			south,
			"SouthTransit_%02d" % i,
			Vector3.BACK,
			u,
			v,
			0.02,
			Vector3(13.5, 0.05, 6.0),
			DARK,
			VIOLET,
			false
		)
		if i % 2 == 1:
			_add_face_box(
				south,
				"SouthTransitCover_%02d" % i,
				Vector3.BACK,
				u,
				v + 2.0,
				0.0,
				Vector3(2.6, 1.0, 0.9),
				COVER,
				VIOLET,
				true,
				&"combat_cover"
			)
	_add_face_label(south, "TransitSign", Vector3.BACK, 0.0, 8.0, 2.8, "TRANS-FACE CONDUIT // WEST RELAY", VIOLET)

	var west := _section(root, "SouthToWestConduit")
	_add_face_box(west, "WestConduitLane", Vector3.LEFT, -10.0, 15.0, 0.02, Vector3(35.0, 0.05, 6.0), DARK, CYAN, false)
	_add_face_box(west, "WestConduitRail", Vector3.LEFT, -10.0, 18.2, 0.0, Vector3(35.0, 0.75, 0.25), WALL, CYAN, true, &"cross_face_passage")


func _build_data_lane() -> void:
	var root := _region("DataLane")
	var down := Vector3.LEFT

	var lane := _section(root, "RelayStreet")
	_add_face_box(lane, "DataDeck", down, 8.0, 8.0, 0.02, Vector3(18.0, 0.05, 15.0), Color(0.025, 0.035, 0.07), CYAN, false)
	for i in range(6):
		var u := 2.5 + float(i % 3) * 5.0
		var v := 3.5 + float(i / 3) * 6.0
		_add_face_box(
			lane,
			"ServerRack_%02d" % i,
			down,
			u,
			v,
			0.0,
			Vector3(1.6, 2.2, 1.0),
			Color(0.04, 0.055, 0.09),
			CYAN if i % 2 == 0 else VIOLET,
			true,
			&"combat_cover"
		)
	_add_face_box(lane, "LaneCoverA", down, 13.0, 6.0, 0.0, Vector3(3.0, 1.0, 0.9), COVER, MAGENTA, true, &"combat_cover")
	_add_face_box(lane, "LaneCoverB", down, 4.0, 13.0, 0.0, Vector3(3.0, 1.0, 0.9), COVER, CYAN, true, &"combat_cover")
	_add_face_label(lane, "DataLaneSign", down, 8.0, 1.0, 3.0, "DATA QUARTER // RELAY LANE", CYAN)

	var gate := _section(root, "WardenGate")
	_add_face_box(gate, "GateLeft", down, -4.5, 14.0, 0.0, Vector3(0.45, 4.6, 0.55), WALL, VIOLET, true)
	_add_face_box(gate, "GateRight", down, 4.5, 14.0, 0.0, Vector3(0.45, 4.6, 0.55), WALL, VIOLET, true)
	_add_face_box(gate, "GateHeader", down, 0.0, 14.0, 4.25, Vector3(9.4, 0.35, 0.55), WALL, MAGENTA, true)
	_add_face_label(gate, "GateLabel", down, 0.0, 13.7, 3.3, "NULL WARDEN ACCESS", MAGENTA)


func _build_boss_arena() -> void:
	var root := _region("VoidDocks")
	var arena := _section(root, "BossArena")
	arena.add_to_group("boss_arena")
	var down := Vector3.BACK

	_add_ring_visual(arena, "BossArenaRing", down, 0.0, -4.0, 0.06, 10.8, Color(0.035, 0.02, 0.07), VIOLET)
	_add_face_box(arena, "BossGateLeft", down, -6.0, 8.5, 0.0, Vector3(0.55, 5.2, 0.65), WALL, VIOLET, true)
	_add_face_box(arena, "BossGateRight", down, 6.0, 8.5, 0.0, Vector3(0.55, 5.2, 0.65), WALL, MAGENTA, true)
	_add_face_box(arena, "BossGateHeader", down, 0.0, 8.5, 4.8, Vector3(12.5, 0.4, 0.65), WALL, MAGENTA, true)

	var pylons := [
		[-6.4, -4.0],
		[6.4, -4.0],
		[0.0, -10.2],
		[0.0, 2.2],
	]
	for i in range(pylons.size()):
		var p: Array = pylons[i]
		_add_face_box(
			arena,
			"ArenaPylon_%02d" % i,
			down,
			float(p[0]),
			float(p[1]),
			0.0,
			Vector3(2.0, 2.2, 2.0),
			COVER,
			VIOLET if i % 2 == 0 else MAGENTA,
			true,
			&"combat_cover"
		)
		var pylon := arena.get_node("ArenaPylon_%02d" % i)
		pylon.add_to_group("boss_arena")
	_add_face_box(arena, "RearCoverA", down, -4.0, -13.0, 0.0, Vector3(3.4, 1.1, 1.0), COVER, CYAN, true, &"combat_cover")
	_add_face_box(arena, "RearCoverB", down, 4.0, -13.0, 0.0, Vector3(3.4, 1.1, 1.0), COVER, MAGENTA, true, &"combat_cover")
	_add_face_label(arena, "BossArenaLabel", down, 0.0, 7.8, 3.8, "VOID DOCKS // NULL WARDEN", VIOLET)


func _build_extraction() -> void:
	var root := _region("Extraction")
	var down := Vector3.DOWN

	var yard := _section(root, "ExtractionYard")
	_add_face_box(yard, "YardDeck", down, -12.0, -12.0, 0.02, Vector3(15.0, 0.05, 14.0), Color(0.025, 0.045, 0.055), AMBER, false)
	_add_face_box(yard, "YardBarricadeA", down, -17.0, -12.0, 0.0, Vector3(3.2, 1.0, 0.9), COVER, AMBER, true, &"combat_cover")
	_add_face_box(yard, "YardBarricadeB", down, -10.0, -8.5, 0.0, Vector3(3.2, 1.0, 0.9), COVER, CYAN, true, &"combat_cover")
	_add_face_box(yard, "YardBarricadeC", down, -7.0, -15.0, 0.0, Vector3(3.2, 1.0, 0.9), COVER, MAGENTA, true, &"combat_cover")

	var route := _section(root, "ExtractionRoute")
	_add_face_box(route, "ExtractionLane", down, -5.0, -20.0, 0.02, Vector3(14.0, 0.05, 10.0), DARK, AMBER, false)
	_add_face_box(route, "RouteRail", down, -11.5, -20.0, 0.0, Vector3(0.3, 0.75, 10.0), WALL, AMBER, true, &"combat_cover")

	var zone_container := _section(root, "ExtractionBeacon")
	_add_ring_visual(zone_container, "ExtractionRing", down, 0.0, -25.0, 0.05, 3.4, Color(0.03, 0.06, 0.055), AMBER)
	_extraction_zone = Area3D.new()
	_extraction_zone.name = "ExtractionZone"
	_extraction_zone.position = _face_point(down, 0.0, -25.0, 1.6)
	_extraction_zone.monitoring = false
	_extraction_zone.add_to_group("extraction_zone")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.5, 3.2, 6.5)
	shape_node.shape = shape
	_extraction_zone.add_child(shape_node)
	_extraction_zone.body_entered.connect(_on_extraction_body_entered)
	zone_container.add_child(_extraction_zone)

	if DisplayServer.get_name() != "headless":
		_extraction_label = Label3D.new()
		_extraction_label.name = "ExtractionStatus"
		_extraction_label.text = "EXTRACTION // READY"
		_extraction_label.font_size = 44
		_extraction_label.outline_size = 8
		_extraction_label.modulate = AMBER
		_extraction_label.outline_modulate = Color(0.01, 0.015, 0.02, 0.95)
		_extraction_label.position = _face_point(down, 0.0, -25.0, 3.5)
		_extraction_label.basis = CubeGravity.tangent_basis(down)
		_extraction_label.visible = false
		zone_container.add_child(_extraction_label)


func _on_extraction_body_entered(body: Node3D) -> void:
	if not _extraction_armed:
		return
	if body is NeonPlayer:
		_extraction_armed = false
		if _extraction_zone != null:
			_extraction_zone.set_deferred("monitoring", false)
		extraction_reached.emit()


func _region(name: String) -> Node3D:
	var node := Node3D.new()
	node.name = name
	_geometry_root.add_child(node)
	return node


func _section(parent: Node3D, name: String) -> Node3D:
	var node := Node3D.new()
	node.name = name
	parent.add_child(node)
	return node


func _face_point(down: Vector3, u: float, v: float, height: float) -> Vector3:
	var basis := CubeGravity.tangent_basis(down)
	var right := basis.x
	var inward := basis.y
	var forward := -basis.z
	var surface_center := down.normalized() * (cube_half_extent - 0.45)
	return surface_center + right * u + forward * v + inward * height


func _add_face_box(
	parent: Node3D,
	name: String,
	down: Vector3,
	u: float,
	v: float,
	bottom_height: float,
	size: Vector3,
	base_color: Color,
	emission_color: Color,
	collidable: bool,
	group_name: StringName = &""
) -> Node3D:
	var node: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.name = name
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		node = body
		node.add_to_group("mission_geometry")
		if group_name != &"":
			node.add_to_group(group_name)
	else:
		var visual_root := Node3D.new()
		visual_root.name = name
		node = visual_root

	node.position = _face_point(down, u, v, bottom_height + size.y * 0.5)
	node.basis = CubeGravity.tangent_basis(down)
	parent.add_child(node)

	if DisplayServer.get_name() != "headless":
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = _material(base_color, emission_color, 2.4 if collidable else 1.6)
		node.add_child(visual)
	return node


func _add_ring_visual(
	parent: Node3D,
	name: String,
	down: Vector3,
	u: float,
	v: float,
	height: float,
	radius: float,
	base_color: Color,
	emission_color: Color
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ring := MeshInstance3D.new()
	ring.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.08
	mesh.radial_segments = 64
	ring.mesh = mesh
	ring.position = _face_point(down, u, v, height)
	ring.basis = CubeGravity.tangent_basis(down)
	ring.material_override = _material(base_color, emission_color, 2.8)
	parent.add_child(ring)


func _add_face_label(
	parent: Node3D,
	name: String,
	down: Vector3,
	u: float,
	v: float,
	height: float,
	text: String,
	color: Color
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var label := Label3D.new()
	label.name = name
	label.text = text
	label.font_size = 30
	label.outline_size = 6
	label.modulate = color
	label.outline_modulate = Color(0.005, 0.01, 0.02, 0.92)
	label.position = _face_point(down, u, v, height)
	label.basis = CubeGravity.tangent_basis(down)
	parent.add_child(label)


func _material(base_color: Color, emission_color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.metallic = 0.65
	material.roughness = 0.28
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material
