class_name NeonMarketSiegeLevel
extends Node3D

signal extraction_reached
signal encounter_zone_entered(encounter_id: StringName)
signal objective_node_destroyed(encounter_id: StringName, objective_id: StringName, remaining: int)

@export var cube_half_extent := 30.0

const CYAN := Color(0.05, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.08, 0.62)
const AMBER := Color(1.0, 0.68, 0.10)
const VIOLET := Color(0.62, 0.16, 1.0)
const WARM := Color(1.0, 0.36, 0.12)
const DARK := Color(0.025, 0.035, 0.065)
const WALL := Color(0.055, 0.065, 0.10)
const COVER := Color(0.07, 0.085, 0.12)

var _geometry_root: Node3D
var _extraction_zone: Area3D
var _extraction_label: Label3D
var _extraction_progress_core: MeshInstance3D
var _extraction_progress_ratio := 0.0
var _extraction_complete := false
var _extraction_armed := false
var _extraction_occupied := false
var _encounter_zones: Dictionary = {}
var _combat_gates: Dictionary = {}
var _lockdown_state: Dictionary = {}
var _navigation_beacons: Dictionary = {}
var _navigation_target: StringName = &""
var _navigation_update_remaining := 0.0
var _boss_hazards: Array[Area3D] = []
var _boss_hazard_active: Array[bool] = []
var _boss_phase := 1
var _boss_hazard_tick_remaining := 0.0
var _boss_hazard_damage_armed := false
var _boss_hazard_phase_serial := 0
const BOSS_HAZARD_TELEGRAPH_SECONDS := 0.9
var _tracked_player: NeonPlayer
var _reinforcement_warning_root: Node3D
var _reinforcement_warning_encounter: StringName = &""
var _reinforcement_warning_count := 0
var _reinforcement_warning_serial := 0
var _objective_nodes: Dictionary = {}
var _hold_zones: Dictionary = {}
var _hold_zone_occupied: Dictionary = {}
var _hold_zone_progress: Dictionary = {}
var _hold_zone_stable: Dictionary = {}
var _progression_gate_state: Dictionary = {&"data_lane": false}


func _ready() -> void:
	if get_node_or_null("Geometry") != null:
		return
	_geometry_root = Node3D.new()
	_geometry_root.name = "Geometry"
	add_child(_geometry_root)
	_build_neon_market()
	_build_gravity_breach()
	_build_hold_zones()
	_build_trans_face_transit()
	_build_data_lane()
	_build_boss_arena()
	_build_boss_hazards()
	_build_extraction()
	_build_combat_lockdown_gates()
	_build_encounter_activation_zones()


func set_player(player: NeonPlayer) -> void:
	_tracked_player = player


func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _navigation_target == &"" or not is_instance_valid(_tracked_player):
		return
	_navigation_update_remaining -= maxf(0.0, delta)
	if _navigation_update_remaining > 0.0:
		return
	_navigation_update_remaining = 0.15
	if not _navigation_beacons.has(_navigation_target):
		return
	var beacon := _navigation_beacons[_navigation_target] as Node3D
	if beacon == null:
		return
	var label := beacon.get_node_or_null("Label") as Label3D
	if label == null:
		return
	var distance := _tracked_player.global_position.distance_to(beacon.global_position)
	label.text = "OBJECTIVE // %s\n%03dm" % [
		String(_navigation_target).replace("_", " ").to_upper(),
		int(round(distance)),
	]


func show_reinforcement_warning(
	encounter_id: StringName,
	positions: Array[Vector3],
	duration: float
) -> void:
	clear_reinforcement_warning()
	_reinforcement_warning_encounter = encounter_id
	_reinforcement_warning_count = positions.size()
	_reinforcement_warning_serial += 1
	var serial := _reinforcement_warning_serial

	if DisplayServer.get_name() != "headless":
		_reinforcement_warning_root = Node3D.new()
		_reinforcement_warning_root.name = "ReinforcementWarning"
		_geometry_root.add_child(_reinforcement_warning_root)
		for i in range(positions.size()):
			_add_reinforcement_warning_visual(
				_reinforcement_warning_root,
				"Warning_%02d" % i,
				positions[i]
			)

	var timer := get_tree().create_timer(maxf(0.05, duration), false)
	timer.timeout.connect(_clear_reinforcement_warning_if.bind(serial))


func clear_reinforcement_warning() -> void:
	_reinforcement_warning_encounter = &""
	_reinforcement_warning_count = 0
	if is_instance_valid(_reinforcement_warning_root):
		_reinforcement_warning_root.queue_free()
	_reinforcement_warning_root = null


func reinforcement_warning_state() -> Dictionary:
	return {
		"encounter_id": _reinforcement_warning_encounter,
		"count": _reinforcement_warning_count,
	}


func _clear_reinforcement_warning_if(serial: int) -> void:
	if serial == _reinforcement_warning_serial:
		clear_reinforcement_warning()


func _add_reinforcement_warning_visual(parent: Node3D, name: String, spawn_position: Vector3) -> void:
	var down := CubeGravity.nearest_down(spawn_position, cube_half_extent)
	var inward := -down
	var ground_position := spawn_position + down * 1.0

	var root := Node3D.new()
	root.name = name
	root.position = ground_position + inward * 1.45
	root.basis = CubeGravity.tangent_basis(down)
	parent.add_child(root)

	var beam := MeshInstance3D.new()
	beam.name = "IngressBeam"
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.14
	beam_mesh.bottom_radius = 0.38
	beam_mesh.height = 2.9
	beam_mesh.radial_segments = 24
	beam.mesh = beam_mesh
	beam.material_override = _material(AMBER * 0.06, AMBER, 8.5)
	root.add_child(beam)

	var ring := MeshInstance3D.new()
	ring.name = "LandingRing"
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.9
	ring_mesh.bottom_radius = 0.9
	ring_mesh.height = 0.05
	ring_mesh.radial_segments = 40
	ring.mesh = ring_mesh
	ring.position = Vector3(0, -1.42, 0)
	ring.material_override = _material(MAGENTA * 0.05, MAGENTA, 7.0)
	root.add_child(ring)


func reset_hold_zones() -> void:
	for key in _hold_zones:
		var key_id := StringName(key)
		var zone := _hold_zones[key] as Area3D
		_hold_zone_occupied[key_id] = false
		_hold_zone_progress[key_id] = 0.0
		_hold_zone_stable[key_id] = false
		if zone != null:
			zone.monitoring = false
			var visual := zone.get_node_or_null("HoldVisual") as MeshInstance3D
			if visual != null:
				visual.visible = false
			var core := zone.get_node_or_null("ProgressCore") as MeshInstance3D
			if core != null:
				core.visible = false
			var label := zone.get_node_or_null("ProgressLabel") as Label3D
			if label != null:
				label.visible = false


func arm_hold_zone(encounter_id: StringName, active: bool) -> void:
	for key in _hold_zones:
		var key_id := StringName(key)
		var zone := _hold_zones[key] as Area3D
		var enabled := active and key_id == encounter_id
		_hold_zone_occupied[key_id] = false
		if enabled:
			_hold_zone_progress[key_id] = 0.0
			_hold_zone_stable[key_id] = false
		if zone != null:
			zone.monitoring = enabled
			var visual := zone.get_node_or_null("HoldVisual") as MeshInstance3D
			if visual != null:
				visual.visible = enabled
				var visual_material := visual.material_override as StandardMaterial3D
				if visual_material != null:
					visual_material.albedo_color = CYAN * 0.045
					visual_material.emission = CYAN
					visual_material.emission_energy_multiplier = 4.8
			var core := zone.get_node_or_null("ProgressCore") as MeshInstance3D
			if core != null:
				core.visible = enabled
				core.scale.y = 0.03
				core.position.y = 0.0
				var core_material := core.material_override as StandardMaterial3D
				if core_material != null:
					core_material.albedo_color = CYAN * 0.08
					core_material.emission = CYAN
					core_material.emission_energy_multiplier = 2.8
			var label := zone.get_node_or_null("ProgressLabel") as Label3D
			if label != null:
				label.visible = enabled
				label.text = "UPLINK 000%"
				label.modulate = CYAN


func is_hold_zone_occupied(encounter_id: StringName) -> bool:
	return bool(_hold_zone_occupied.get(encounter_id, false))


func hold_zone_world_position(encounter_id: StringName) -> Vector3:
	if not _hold_zones.has(encounter_id):
		return Vector3.ZERO
	var zone := _hold_zones[encounter_id] as Area3D
	return zone.global_position if zone != null else Vector3.ZERO


func set_hold_zone_progress(encounter_id: StringName, current: float, required: float) -> void:
	var was_stable := bool(_hold_zone_stable.get(encounter_id, false))
	var ratio := 0.0
	if required > 0.0:
		ratio = clampf(current / required, 0.0, 1.0)
	_hold_zone_progress[encounter_id] = ratio
	var stable := ratio >= 0.999
	_hold_zone_stable[encounter_id] = stable
	if not _hold_zones.has(encounter_id):
		return
	var zone := _hold_zones[encounter_id] as Area3D
	if zone == null:
		return

	if stable:
		_hold_zone_occupied[encounter_id] = false
		zone.monitoring = false

	var stable_color := Color(0.22, 1.0, 0.52)
	var active_color := CYAN

	var visual := zone.get_node_or_null("HoldVisual") as MeshInstance3D
	if visual != null:
		visual.visible = zone.monitoring or stable
		var visual_material := visual.material_override as StandardMaterial3D
		if visual_material != null:
			visual_material.albedo_color = (stable_color if stable else active_color) * 0.045
			visual_material.emission = stable_color if stable else active_color
			visual_material.emission_energy_multiplier = 6.5 if stable else 4.8

	var core := zone.get_node_or_null("ProgressCore") as MeshInstance3D
	if core != null:
		core.visible = zone.monitoring or stable
		core.scale.y = maxf(0.03, ratio)
		core.position.y = 0.92 * ratio
		var material := core.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = (stable_color if stable else active_color) * 0.08
			material.emission = stable_color if stable else active_color
			material.emission_energy_multiplier = 7.2 if stable else 2.8 + ratio * 4.2

	var label := zone.get_node_or_null("ProgressLabel") as Label3D
	if label != null:
		label.visible = zone.monitoring or stable
		label.text = "UPLINK STABLE" if stable else "UPLINK %03d%%" % int(round(ratio * 100.0))
		label.modulate = stable_color if stable else active_color

	if stable and not was_stable:
		_spawn_event_pulse(
			zone.global_position,
			CubeGravity.nearest_down(zone.global_position, cube_half_extent),
			stable_color,
			3.4,
			0.55
		)


func hold_zone_progress_state(encounter_id: StringName) -> float:
	return float(_hold_zone_progress.get(encounter_id, 0.0))


func hold_zone_stable_state(encounter_id: StringName) -> bool:
	return bool(_hold_zone_stable.get(encounter_id, false))


func set_extraction_progress(current: float, required: float) -> void:
	_extraction_progress_ratio = 0.0
	if required > 0.0:
		_extraction_progress_ratio = clampf(current / required, 0.0, 1.0)
	if _extraction_progress_core != null:
		_extraction_progress_core.visible = _extraction_armed
		_extraction_progress_core.scale.y = maxf(0.03, _extraction_progress_ratio)
		_extraction_progress_core.position.y = 1.35 * _extraction_progress_ratio
		var material := _extraction_progress_core.material_override as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 3.0 + _extraction_progress_ratio * 5.0
	var extraction_ring := get_node_or_null("Geometry/Extraction/ExtractionBeacon/ExtractionRing") as MeshInstance3D
	if extraction_ring != null:
		var ring_material := extraction_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.emission_energy_multiplier = 2.5 + _extraction_progress_ratio * 5.5
	if _extraction_label != null and _extraction_armed:
		_extraction_label.text = "EXTRACTION // %03d%%" % int(round(_extraction_progress_ratio * 100.0))


func extraction_progress_state() -> float:
	return _extraction_progress_ratio


func reset_objective_nodes() -> void:
	for encounter_id in _objective_nodes:
		var nodes: Array = _objective_nodes[encounter_id]
		for node in nodes:
			var objective := node as MissionObjectiveNode
			if objective != null:
				objective.reset_node()


func arm_objective_nodes(encounter_id: StringName, active: bool) -> void:
	for key in _objective_nodes:
		var nodes: Array = _objective_nodes[key]
		for node in nodes:
			var objective := node as MissionObjectiveNode
			if objective != null:
				objective.set_active(active and StringName(key) == encounter_id)


func objective_nodes_remaining(encounter_id: StringName) -> int:
	if not _objective_nodes.has(encounter_id):
		return 0
	var remaining := 0
	var nodes: Array = _objective_nodes[encounter_id]
	for node in nodes:
		var objective := node as MissionObjectiveNode
		if objective != null and not objective.is_destroyed():
			remaining += 1
	return remaining


func arm_extraction(active: bool = true) -> void:
	_extraction_armed = active
	_extraction_complete = false
	_extraction_occupied = false
	_extraction_progress_ratio = 0.0
	var active_color := AMBER

	if _extraction_zone != null:
		_extraction_zone.monitoring = active

	if _extraction_progress_core != null:
		_extraction_progress_core.visible = active
		_extraction_progress_core.scale.y = 0.03
		_extraction_progress_core.position.y = 0.0
		var core_material := _extraction_progress_core.material_override as StandardMaterial3D
		if core_material != null:
			core_material.albedo_color = active_color * 0.08
			core_material.emission = active_color
			core_material.emission_energy_multiplier = 3.0

	var extraction_ring := get_node_or_null("Geometry/Extraction/ExtractionBeacon/ExtractionRing") as MeshInstance3D
	if extraction_ring != null:
		var ring_material := extraction_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.albedo_color = Color(0.03, 0.06, 0.055)
			ring_material.emission = active_color
			ring_material.emission_energy_multiplier = 2.5 if active else 1.0

	if _extraction_label != null:
		_extraction_label.visible = active
		_extraction_label.modulate = active_color
		if active:
			_extraction_label.text = "EXTRACTION // 000%"


func complete_extraction() -> void:
	_extraction_armed = false
	_extraction_complete = true
	_extraction_occupied = false
	_extraction_progress_ratio = 1.0
	var complete_color := Color(0.24, 1.0, 0.56)

	if _extraction_zone != null:
		_extraction_zone.monitoring = false

	if _extraction_progress_core != null:
		_extraction_progress_core.visible = true
		_extraction_progress_core.scale.y = 1.0
		_extraction_progress_core.position.y = 1.35
		var core_material := _extraction_progress_core.material_override as StandardMaterial3D
		if core_material != null:
			core_material.albedo_color = complete_color * 0.08
			core_material.emission = complete_color
			core_material.emission_energy_multiplier = 8.0

	var extraction_ring := get_node_or_null("Geometry/Extraction/ExtractionBeacon/ExtractionRing") as MeshInstance3D
	if extraction_ring != null:
		var ring_material := extraction_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.albedo_color = complete_color * 0.05
			ring_material.emission = complete_color
			ring_material.emission_energy_multiplier = 8.0

	if _extraction_label != null:
		_extraction_label.visible = true
		_extraction_label.text = "EXTRACTION COMPLETE"
		_extraction_label.modulate = complete_color

	if _extraction_zone != null:
		var extraction_down := CubeGravity.nearest_down(_extraction_zone.global_position, cube_half_extent)
		_spawn_event_pulse(_extraction_zone.global_position, extraction_down, complete_color, 4.2, 0.75)
		_spawn_event_sparks(_extraction_zone.global_position, extraction_down, complete_color, 10)


func extraction_complete_state() -> bool:
	return _extraction_complete


func is_extraction_occupied() -> bool:
	return _extraction_armed and _extraction_occupied


func arm_encounter_zone(encounter_id: StringName, active: bool = true) -> void:
	for key in _encounter_zones:
		var zone: Area3D = _encounter_zones[key]
		zone.monitoring = active and StringName(key) == encounter_id


func set_encounter_lockdown(encounter_id: StringName, active: bool) -> void:
	if encounter_id == &"" and not active:
		for key in _combat_gates:
			_apply_gate_state(StringName(key), false)
		return
	if not _combat_gates.has(encounter_id):
		return
	_apply_gate_state(encounter_id, active)


func is_encounter_locked(encounter_id: StringName) -> bool:
	return bool(_lockdown_state.get(encounter_id, false))


func reset_progression_gates() -> void:
	_progression_gate_state[&"data_lane"] = false
	_reset_visual_gate("Geometry/DataLane/WardenGate/WardenAccessDoor")
	_set_data_lane_gate_status(false)


func set_progression_gate_open(encounter_id: StringName, open: bool, animate: bool = true) -> void:
	_progression_gate_state[encounter_id] = open
	match encounter_id:
		&"data_lane":
			_set_data_lane_gate_status(open)
			_set_visual_gate_open(
				"Geometry/DataLane/WardenGate/WardenAccessDoor",
				open,
				animate,
				3.4
			)


func progression_gate_open(encounter_id: StringName) -> bool:
	return bool(_progression_gate_state.get(encounter_id, false))


func _set_data_lane_gate_status(open: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var label := get_node_or_null("Geometry/DataLane/WardenGate/GateStatus") as Label3D
	if label == null:
		return
	label.text = "ACCESS OPEN" if open else "ACCESS LOCKED"
	label.modulate = Color(0.28, 1.0, 0.58) if open else Color(1.0, 0.26, 0.34)


func _reset_visual_gate(path: String) -> void:
	var door := get_node_or_null(path) as Node3D
	if door == null:
		return
	if not door.has_meta("closed_position"):
		door.set_meta("closed_position", door.position)
	var closed_position: Vector3 = door.get_meta("closed_position")
	door.position = closed_position
	door.set_meta("progression_open", false)


func _set_visual_gate_open(
	path: String,
	open: bool,
	animate: bool,
	travel_distance: float
) -> void:
	var door := get_node_or_null(path) as Node3D
	if door == null:
		return
	if not door.has_meta("closed_position"):
		door.set_meta("closed_position", door.position)
	var closed_position: Vector3 = door.get_meta("closed_position")
	var target_position := closed_position
	if open:
		target_position = closed_position + door.basis.y.normalized() * travel_distance
	door.set_meta("progression_open", open)
	if not animate or DisplayServer.get_name() == "headless":
		door.position = target_position
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(door, "position", target_position, 0.75)


func set_navigation_target(encounter_id: StringName) -> void:
	_navigation_target = encounter_id
	_navigation_update_remaining = 0.0
	for key in _navigation_beacons:
		var beacon: Node3D = _navigation_beacons[key]
		beacon.visible = encounter_id != &"" and StringName(key) == encounter_id


func current_navigation_target() -> StringName:
	return _navigation_target


func set_boss_phase(phase: int) -> void:
	_boss_phase = clampi(phase, 1, 3)
	_update_boss_arena_visual_state()
	_boss_hazard_tick_remaining = 0.0
	_boss_hazard_damage_armed = false
	_boss_hazard_phase_serial += 1
	var serial := _boss_hazard_phase_serial

	for i in range(_boss_hazards.size()):
		var active := false
		if _boss_phase == 2:
			active = i == 0 or i == 1
		elif _boss_phase >= 3:
			active = true
		_boss_hazard_active[i] = active
		_boss_hazards[i].set_deferred("monitoring", active)
		var visual := _boss_hazards[i].get_node_or_null("HazardVisual") as MeshInstance3D
		if visual != null:
			visual.visible = active
			var material := visual.material_override as StandardMaterial3D
			if material != null and active:
				material.emission_energy_multiplier = 3.6

	if _boss_phase <= 1:
		return
	var timer := get_tree().create_timer(BOSS_HAZARD_TELEGRAPH_SECONDS, false)
	timer.timeout.connect(_arm_boss_hazard_damage_if.bind(serial, _boss_phase))


func _arm_boss_hazard_damage_if(serial: int, phase: int) -> void:
	if serial != _boss_hazard_phase_serial or phase != _boss_phase or _boss_phase <= 1:
		return
	_boss_hazard_damage_armed = true
	_boss_hazard_tick_remaining = 0.0
	for i in range(_boss_hazards.size()):
		if not _boss_hazard_active[i]:
			continue
		var visual := _boss_hazards[i].get_node_or_null("HazardVisual") as MeshInstance3D
		if visual == null:
			continue
		var material := visual.material_override as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 7.0


func _update_boss_arena_visual_state() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var arena := get_node_or_null("Geometry/VoidDocks/BossArena")
	if arena == null:
		return

	var ring := arena.get_node_or_null("BossArenaRing") as MeshInstance3D
	if ring != null:
		var material := ring.material_override as StandardMaterial3D
		if material != null:
			var energy := 1.8
			if _boss_phase == 2:
				energy = 4.2
			elif _boss_phase >= 3:
				energy = 7.5
			material.emission_energy_multiplier = energy

	var label := arena.get_node_or_null("BossPhaseStatus") as Label3D
	if label != null:
		match _boss_phase:
			2:
				label.text = "WARDEN // PHASE 2 // TWIN HAZARDS"
				label.modulate = MAGENTA
			3:
				label.text = "WARDEN // PHASE 3 // OVERLOAD"
				label.modulate = Color(1.0, 0.20, 0.24)
			_:
				label.text = "WARDEN // PHASE 1"
				label.modulate = VIOLET


func boss_hazard_state() -> Dictionary:
	var active_count := 0
	for active in _boss_hazard_active:
		if active:
			active_count += 1
	return {
		"phase": _boss_phase,
		"active_count": active_count,
		"damage": 10.0 if _boss_phase >= 3 else 6.0 if _boss_phase == 2 else 0.0,
		"damage_armed": _boss_hazard_damage_armed,
		"telegraph_seconds": BOSS_HAZARD_TELEGRAPH_SECONDS,
	}


func _physics_process(delta: float) -> void:
	if (
		_boss_phase < 2
		or not _boss_hazard_damage_armed
		or _boss_hazards.is_empty()
		or not is_instance_valid(_tracked_player)
	):
		return
	_boss_hazard_tick_remaining -= delta
	if _boss_hazard_tick_remaining > 0.0:
		return
	_boss_hazard_tick_remaining = 0.75
	var damage := 10.0 if _boss_phase >= 3 else 6.0
	for i in range(_boss_hazards.size()):
		if not _boss_hazard_active[i]:
			continue
		if _player_inside_boss_hazard(_boss_hazards[i]):
			_tracked_player.take_damage(damage)
			return


func _player_inside_boss_hazard(hazard: Area3D) -> bool:
	if hazard == null or not is_instance_valid(_tracked_player):
		return false
	var local_position := hazard.to_local(_tracked_player.global_position)
	var planar_distance := Vector2(local_position.x, local_position.z).length()
	return planar_distance <= 2.25 and local_position.y >= -0.25 and local_position.y <= 2.9


func _apply_gate_state(encounter_id: StringName, active: bool) -> void:
	var gates: Array = _combat_gates.get(encounter_id, [])
	if gates.is_empty():
		return
	_lockdown_state[encounter_id] = active
	for gate_variant in gates:
		var gate_data: Dictionary = gate_variant
		var collision := gate_data.get("collision") as CollisionShape3D
		if collision != null:
			collision.set_deferred("disabled", not active)
		var visual := gate_data.get("visual") as MeshInstance3D
		if visual != null:
			visual.visible = active


func combat_gate_count(encounter_id: StringName) -> int:
	var gates: Array = _combat_gates.get(encounter_id, [])
	return gates.size()


func spawn_points_for(encounter_id: StringName, count: int, sequence_offset: int = 0) -> Array[Vector3]:
	var authored := _authored_spawn_specs(encounter_id)
	var result: Array[Vector3] = []
	if authored.is_empty() or count <= 0:
		return result
	for i in range(count):
		var spec: Array = authored[(i + sequence_offset) % authored.size()]
		var down: Vector3 = spec[0]
		var u: float = float(spec[1])
		var v: float = float(spec[2])
		var height := 1.05
		if spec.size() >= 4:
			height = float(spec[3])
		result.append(_face_point(down, u, v, height))
	return result


func perch_radius_for(encounter_id: StringName, enemy_index: int) -> float:
	match encounter_id:
		&"market_crossfire":
			return 0.75 if enemy_index == 4 else 0.0
		&"data_lane":
			return 0.30 if enemy_index == 3 else 0.0
	return 0.0


func route_points_for(encounter_id: StringName) -> Array[Vector3]:
	var authored := _authored_route_specs(encounter_id)
	var result: Array[Vector3] = []
	for spec in authored:
		var down: Vector3 = spec[0]
		var u: float = float(spec[1])
		var v: float = float(spec[2])
		result.append(_face_point(down, u, v, 1.05))
	return result


func _authored_route_specs(encounter_id: StringName) -> Array:
	match encounter_id:
		&"arrival_ambush":
			return [
				[Vector3.DOWN, -3.5, -20.0],
				[Vector3.DOWN, 3.5, -15.0],
				[Vector3.DOWN, -3.5, -10.0],
				[Vector3.DOWN, 3.5, -5.5],
			]
		&"market_crossfire":
			return [
				[Vector3.DOWN, 6.5, -1.0],
				[Vector3.DOWN, 10.0, 0.8],
				[Vector3.DOWN, 14.2, 2.2],
				[Vector3.DOWN, 16.8, 5.4],
				[Vector3.DOWN, 11.2, 8.8],
				[Vector3.DOWN, 18.2, 8.4],
			]
		&"gravity_breach":
			return [
				[Vector3.RIGHT, -12.2, -18.0],
				[Vector3.RIGHT, -6.0, -16.5],
				[Vector3.RIGHT, -12.0, -11.5],
				[Vector3.RIGHT, -5.0, -9.0],
				[Vector3.RIGHT, -1.5, -5.0],
			]
		&"data_lane":
			return [
				[Vector3.LEFT, 1.0, 4.0],
				[Vector3.LEFT, 5.0, 2.5],
				[Vector3.LEFT, 8.0, 6.0],
				[Vector3.LEFT, 13.0, 3.0],
				[Vector3.LEFT, 12.0, 11.0],
				[Vector3.LEFT, 5.0, 14.0],
			]
		&"null_warden":
			return [
				[Vector3.BACK, -9.0, -10.5],
				[Vector3.BACK, 9.0, -10.5],
				[Vector3.BACK, -9.0, 3.5],
				[Vector3.BACK, 9.0, 3.5],
				[Vector3.BACK, 0.0, -14.0],
				[Vector3.BACK, 0.0, 6.0],
			]
		&"extraction":
			return [
				[Vector3.DOWN, -18.0, -15.0],
				[Vector3.DOWN, -14.0, -10.0],
				[Vector3.DOWN, -9.0, -16.5],
				[Vector3.DOWN, -6.0, -10.0],
				[Vector3.DOWN, -4.0, -19.0],
			]
	return []


func _authored_spawn_specs(encounter_id: StringName) -> Array:
	match encounter_id:
		&"arrival_ambush":
			return [
				[Vector3.DOWN, -3.2, -16.8],
				[Vector3.DOWN, 3.4, -13.2],
				[Vector3.DOWN, -2.4, -9.0],
				[Vector3.DOWN, 3.0, -5.8],
			]
		&"market_crossfire":
			return [
				[Vector3.DOWN, 7.0, 1.5],
				[Vector3.DOWN, 12.2, 4.0],
				[Vector3.DOWN, 16.8, 1.0],
				[Vector3.DOWN, 8.0, 8.3],
				[Vector3.DOWN, 18.4, 7.4, 3.25],
			]
		&"gravity_breach":
			return [
				[Vector3.RIGHT, -10.0, -17.2],
				[Vector3.RIGHT, -5.0, -13.0],
				[Vector3.RIGHT, -11.0, -8.0],
				[Vector3.RIGHT, -3.2, -7.0],
			]
		&"data_lane":
			return [
				[Vector3.LEFT, 1.0, 13.0],
				[Vector3.LEFT, 5.5, 6.2],
				[Vector3.LEFT, 10.3, 13.2],
				[Vector3.LEFT, 12.5, 9.5, 3.25],
				[Vector3.LEFT, 8.0, 15.0],
			]
		&"null_warden":
			return [
				[Vector3.BACK, 0.0, -4.0],
				[Vector3.BACK, -7.2, -8.0],
				[Vector3.BACK, 7.2, -8.0],
				[Vector3.BACK, 0.0, 3.5],
			]
		&"extraction":
			return [
				[Vector3.DOWN, -17.5, -9.0],
				[Vector3.DOWN, -13.0, -16.8],
				[Vector3.DOWN, -7.0, -11.0],
				[Vector3.DOWN, -10.0, -7.5],
			]
	return []


func spatial_summary() -> Dictionary:
	return {
		"mission_geometry": get_tree().get_nodes_in_group("mission_geometry").size(),
		"combat_cover": get_tree().get_nodes_in_group("combat_cover").size(),
		"cross_face_passage": get_tree().get_nodes_in_group("cross_face_passage").size(),
		"boss_arena": get_tree().get_nodes_in_group("boss_arena").size(),
		"extraction_zone": get_tree().get_nodes_in_group("extraction_zone").size(),
		"encounter_activation_zone": get_tree().get_nodes_in_group("encounter_activation_zone").size(),
		"combat_lockdown_gate": get_tree().get_nodes_in_group("combat_lockdown_gate").size(),
		"navigation_beacon": get_tree().get_nodes_in_group("navigation_beacon").size(),
		"boss_hazard": get_tree().get_nodes_in_group("boss_hazard").size(),
		"mission_objective_node": get_tree().get_nodes_in_group("mission_objective_node").size(),
		"mission_hold_zone": get_tree().get_nodes_in_group("mission_hold_zone").size(),
		"market_kiosk_collision": get_tree().get_nodes_in_group("market_kiosk_collision").size(),
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
	_add_face_trim(arrival, "ArrivalLaneWest", down, -1.85, -13.0, 0.07, Vector3(0.07, 0.035, 21.0), CYAN)
	_add_face_trim(arrival, "ArrivalLaneEast", down, 1.85, -13.0, 0.07, Vector3(0.07, 0.035, 21.0), MAGENTA)
	_add_face_trim(arrival, "ArrivalStopLine", down, 0.0, -3.6, 0.075, Vector3(7.0, 0.035, 0.08), AMBER)
	_add_face_light(arrival, "ArrivalLightA", down, -3.8, -17.0, 3.2, CYAN, 1.35, 8.5)
	_add_face_light(arrival, "ArrivalLightB", down, 3.8, -8.0, 3.0, MAGENTA, 1.15, 7.5)
	_add_prop(arrival, "StreetLight_A", "res://assets/third_party/quaternius_cyberpunk/street_light.gltf", down, -4.4, -19.5, 0.0, 1.25, 0.0)
	_add_prop(arrival, "StreetLight_B", "res://assets/third_party/quaternius_cyberpunk/street_light.gltf", down, 4.4, -13.0, 0.0, 1.25, 180.0)
	_add_prop(arrival, "StreetLight_C", "res://assets/third_party/quaternius_cyberpunk/street_light.gltf", down, -4.4, -6.5, 0.0, 1.25, 0.0)
	_add_market_kiosk(arrival, "Kiosk_West_A", down, -7.0, -18.0, CYAN, "NOODLES // 24H")
	_add_market_kiosk(arrival, "Kiosk_East_A", down, 7.0, -16.0, MAGENTA, "SYNTH TEA")
	_add_market_kiosk(arrival, "Kiosk_West_B", down, -7.0, -11.0, WARM, "NIGHT GRILL")
	_add_market_kiosk(arrival, "Kiosk_East_B", down, 7.0, -9.0, CYAN, "BYTE MART")
	_add_market_kiosk(arrival, "Kiosk_West_C", down, -7.0, -5.5, MAGENTA, "AUGMENT REPAIR")
	_add_market_kiosk(arrival, "Kiosk_East_C", down, 7.0, -4.0, WARM, "HOT POT // B7")
	_add_market_signboard(arrival, "MarketBanner_A", down, 0.0, -15.0, 4.4, "NEON MARKET // NIGHT BAZAAR", MAGENTA)
	_add_market_signboard(arrival, "MarketBanner_B", down, 0.0, -6.8, 4.2, "SUBLEVEL 07 // OPEN ALL NIGHT", CYAN)
	_add_market_string_lights(arrival, "StringLights_A", down, 0.0, -19.0, 4.8, 11.5, CYAN, WARM)
	_add_market_string_lights(arrival, "StringLights_B", down, 0.0, -12.5, 4.6, 11.5, MAGENTA, CYAN)
	_add_market_string_lights(arrival, "StringLights_C", down, 0.0, -5.5, 4.5, 11.5, WARM, MAGENTA)

	var hall := _section(root, "MarketHall")
	_add_face_box(hall, "HallFloor", down, 13.0, 4.0, 0.025, Vector3(17.0, 0.05, 15.0), Color(0.035, 0.04, 0.07), MAGENTA, false)
	_add_face_box(hall, "HallWestWall", down, 5.2, 5.0, 0.0, Vector3(0.45, 4.8, 11.0), WALL, CYAN, true)
	_add_face_box(hall, "HallNorthWall", down, 13.0, 11.3, 0.0, Vector3(15.8, 4.8, 0.45), WALL, MAGENTA, true)
	_add_face_box(hall, "HallSouthPierA", down, 17.8, -3.2, 0.0, Vector3(5.2, 4.8, 0.45), WALL, AMBER, true)
	_add_face_box(hall, "HallSouthPierB", down, 7.0, -3.2, 0.0, Vector3(2.8, 4.8, 0.45), WALL, CYAN, true)
	_add_face_box(hall, "HallRoof", down, 13.0, 4.0, 5.6, Vector3(16.2, 0.20, 14.4), Color(0.02, 0.025, 0.05), MAGENTA, true)
	_add_face_label(hall, "MarketHallSign", down, 10.0, -3.0, 3.4, "SUBLEVEL 07 // NIGHT BAZAAR", MAGENTA)
	_add_face_trim(hall, "HallCenterGuide", down, 12.7, 4.0, 0.08, Vector3(0.08, 0.035, 13.0), MAGENTA)
	_add_face_trim(hall, "HallCrossGuide", down, 13.0, 4.1, 0.085, Vector3(14.5, 0.035, 0.07), CYAN)
	_add_face_light(hall, "HallLightA", down, 9.0, 2.0, 4.0, MAGENTA, 1.25, 8.0)
	_add_face_light(hall, "HallLightB", down, 16.0, 7.0, 4.2, CYAN, 1.15, 8.0)
	_add_market_ceiling_strip(hall, "CeilingStrip_A", down, 8.0, 1.0, 5.35, 5.0, CYAN)
	_add_market_ceiling_strip(hall, "CeilingStrip_B", down, 13.0, 4.0, 5.35, 5.0, MAGENTA)
	_add_market_ceiling_strip(hall, "CeilingStrip_C", down, 17.5, 7.0, 5.35, 4.5, WARM)
	_add_hanging_market_panel(hall, "AislePanel_A", down, 8.5, 2.0, 4.35, "FOOD // A1", CYAN)
	_add_hanging_market_panel(hall, "AislePanel_B", down, 14.0, 5.2, 4.25, "TECH // B4", MAGENTA)
	_add_hanging_market_panel(hall, "AislePanel_C", down, 17.0, 8.2, 4.15, "EXIT // EAST", AMBER)
	_add_prop(hall, "MarketDoor", "res://assets/third_party/quaternius_cyberpunk/door.gltf", down, 9.0, -3.0, 0.0, 1.55, 180.0)
	_add_prop(hall, "HallFence", "res://assets/third_party/quaternius_cyberpunk/fence.gltf", down, 16.8, 10.8, 0.0, 1.55, 90.0)

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
		_add_prop(crossfire, "Terminal_%02d" % i, "res://assets/third_party/quaternius_cyberpunk/computer.gltf", down, u, v, 1.28, 1.05, 180.0 if side < 0.0 else 0.0)
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
	_add_prop(seam, "SeamAntenna", "res://assets/third_party/quaternius_cyberpunk/antenna.gltf", down, 27.2, 10.2, 0.0, 1.45, 0.0)
	_add_prop(seam, "SeamFence", "res://assets/third_party/quaternius_cyberpunk/fence.gltf", down, 23.8, 10.6, 0.0, 1.35, 0.0)


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
	_add_face_trim(arena, "BreachAxisA", down, -8.0, -12.0, 0.08, Vector3(0.08, 0.035, 13.5), CYAN)
	_add_face_trim(arena, "BreachAxisB", down, -8.0, -12.0, 0.085, Vector3(13.5, 0.035, 0.08), AMBER)
	_add_face_light(arena, "BreachLocalLight", down, -8.0, -12.0, 4.4, CYAN, 1.35, 9.0)
	_add_prop(arena, "BreachAntenna", "res://assets/third_party/quaternius_cyberpunk/antenna.gltf", down, -13.0, -18.0, 0.0, 1.65, 25.0)
	_add_prop(arena, "BreachLight", "res://assets/third_party/quaternius_cyberpunk/street_light.gltf", down, -2.5, -17.5, 0.0, 1.30, 180.0)

	var relay := _section(root, "RelayApproach")
	_add_face_box(relay, "RelayLane", down, -3.0, -6.0, 0.02, Vector3(8.0, 0.05, 13.0), DARK, AMBER, false)
	_add_face_box(relay, "RelayBarrierA", down, -7.0, -5.0, 0.0, Vector3(2.4, 1.0, 0.8), WALL, AMBER, true, &"combat_cover")
	_add_face_box(relay, "RelayBarrierB", down, 1.0, -3.0, 0.0, Vector3(2.4, 1.0, 0.8), WALL, MAGENTA, true, &"combat_cover")


func _build_hold_zones() -> void:
	var root := _section(_geometry_root, "HoldZones")
	var encounter_id := &"gravity_breach"
	var down := Vector3.RIGHT
	var area := Area3D.new()
	area.name = "GravityBreachHold"
	area.position = _face_point(down, -8.0, -12.0, 0.05)
	area.basis = CubeGravity.tangent_basis(down)
	area.monitoring = false
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 1
	area.add_to_group("mission_hold_zone")

	var collision := CollisionShape3D.new()
	collision.position = Vector3(0, 1.35, 0)
	var shape := CylinderShape3D.new()
	shape.radius = 3.0
	shape.height = 2.7
	collision.shape = shape
	area.add_child(collision)

	if DisplayServer.get_name() != "headless":
		var visual := MeshInstance3D.new()
		visual.name = "HoldVisual"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 3.0
		mesh.bottom_radius = 3.0
		mesh.height = 0.07
		mesh.radial_segments = 56
		visual.mesh = mesh
		visual.material_override = _material(CYAN * 0.045, CYAN, 4.8)
		visual.visible = false
		area.add_child(visual)

	if DisplayServer.get_name() != "headless":
		var core := MeshInstance3D.new()
		core.name = "ProgressCore"
		var core_mesh := CylinderMesh.new()
		core_mesh.top_radius = 0.38
		core_mesh.bottom_radius = 0.50
		core_mesh.height = 1.85
		core_mesh.radial_segments = 32
		core.mesh = core_mesh
		core.scale.y = 0.03
		core.position.y = 0.0
		core.material_override = _material(CYAN * 0.08, CYAN, 2.8)
		core.visible = false
		area.add_child(core)

		var progress_label := Label3D.new()
		progress_label.name = "ProgressLabel"
		progress_label.text = "UPLINK 000%"
		progress_label.font_size = 28
		progress_label.outline_size = 6
		progress_label.modulate = CYAN
		progress_label.outline_modulate = Color(0.004, 0.006, 0.015, 0.96)
		progress_label.position = Vector3(0, 2.4, 0)
		progress_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		progress_label.visible = false
		area.add_child(progress_label)

	area.body_entered.connect(_on_hold_zone_body_entered.bind(encounter_id))
	area.body_exited.connect(_on_hold_zone_body_exited.bind(encounter_id))
	root.add_child(area)
	_hold_zones[encounter_id] = area
	_hold_zone_occupied[encounter_id] = false
	_hold_zone_progress[encounter_id] = 0.0
	_hold_zone_stable[encounter_id] = false


func _on_hold_zone_body_entered(body: Node3D, encounter_id: StringName) -> void:
	if body is NeonPlayer:
		_hold_zone_occupied[encounter_id] = true


func _on_hold_zone_body_exited(body: Node3D, encounter_id: StringName) -> void:
	if body is NeonPlayer:
		_hold_zone_occupied[encounter_id] = false


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
	_add_prop(south, "TransitAntenna", "res://assets/third_party/quaternius_cyberpunk/antenna.gltf", Vector3.BACK, 10.5, 7.0, 0.0, 1.35, 20.0)
	_add_prop(south, "TransitFence", "res://assets/third_party/quaternius_cyberpunk/fence.gltf", Vector3.BACK, -10.0, 6.3, 0.0, 1.5, 90.0)

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
	_add_face_trim(lane, "DataSpine", down, 8.0, 8.0, 0.08, Vector3(0.08, 0.035, 13.0), CYAN)
	_add_face_trim(lane, "RelayDivider", down, 8.0, 8.0, 0.085, Vector3(15.5, 0.035, 0.08), VIOLET)
	_add_face_light(lane, "DataLightA", down, 4.0, 6.0, 4.0, CYAN, 1.15, 7.5)
	_add_face_light(lane, "DataLightB", down, 12.0, 10.0, 4.0, VIOLET, 1.25, 7.5)
	_add_objective_node(lane, "RelayCore_A", &"data_lane", &"relay_a", down, 3.0, 8.0, 90.0, CYAN)
	_add_objective_node(lane, "RelayCore_B", &"data_lane", &"relay_b", down, 13.0, 9.5, 90.0, MAGENTA)
	_add_prop(lane, "RelayConsole_A", "res://assets/third_party/quaternius_cyberpunk/computer.gltf", down, 1.2, 2.5, 0.0, 1.25, 90.0)
	_add_prop(lane, "RelayConsole_B", "res://assets/third_party/quaternius_cyberpunk/computer.gltf", down, 14.2, 12.5, 0.0, 1.25, -90.0)
	_add_prop(lane, "RelayAntenna", "res://assets/third_party/quaternius_cyberpunk/antenna.gltf", down, 13.5, 2.5, 0.0, 1.5, 0.0)

	var gate := _section(root, "WardenGate")
	_add_face_box(gate, "GateLeft", down, -4.5, 14.0, 0.0, Vector3(0.45, 4.6, 0.55), WALL, VIOLET, true)
	_add_face_box(gate, "GateRight", down, 4.5, 14.0, 0.0, Vector3(0.45, 4.6, 0.55), WALL, VIOLET, true)
	_add_face_box(gate, "GateHeader", down, 0.0, 14.0, 4.25, Vector3(9.4, 0.35, 0.55), WALL, MAGENTA, true)
	_add_face_label(gate, "GateLabel", down, 0.0, 13.7, 3.3, "NULL WARDEN ACCESS", MAGENTA)
	if DisplayServer.get_name() != "headless":
		var gate_status := Label3D.new()
		gate_status.name = "GateStatus"
		gate_status.text = "ACCESS LOCKED"
		gate_status.font_size = 26
		gate_status.outline_size = 6
		gate_status.modulate = Color(1.0, 0.26, 0.34)
		gate_status.outline_modulate = Color(0.004, 0.006, 0.015, 0.96)
		gate_status.position = _face_point(down, 0.0, 13.55, 2.55)
		gate_status.basis = CubeGravity.tangent_basis(down)
		gate_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		gate.add_child(gate_status)
	_add_prop(gate, "WardenAccessDoor", "res://assets/third_party/quaternius_cyberpunk/door.gltf", down, 0.0, 13.8, 0.0, 1.75, 180.0)


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
	if DisplayServer.get_name() != "headless":
		var phase_status := Label3D.new()
		phase_status.name = "BossPhaseStatus"
		phase_status.text = "WARDEN // PHASE 1"
		phase_status.font_size = 30
		phase_status.outline_size = 7
		phase_status.modulate = VIOLET
		phase_status.outline_modulate = Color(0.004, 0.006, 0.015, 0.96)
		phase_status.position = _face_point(down, 0.0, 5.8, 4.6)
		phase_status.basis = CubeGravity.tangent_basis(down)
		phase_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		arena.add_child(phase_status)
	_add_face_light(arena, "BossLightA", down, -6.0, -4.0, 4.8, VIOLET, 1.35, 9.0)
	_add_face_light(arena, "BossLightB", down, 6.0, -4.0, 4.8, MAGENTA, 1.25, 9.0)
	_add_prop(arena, "BossGateDoor", "res://assets/third_party/quaternius_cyberpunk/door.gltf", down, 0.0, 8.2, 0.0, 1.9, 180.0)
	_add_prop(arena, "BossRelayA", "res://assets/third_party/quaternius_cyberpunk/antenna.gltf", down, -8.8, -1.5, 0.0, 1.6, 15.0)
	_add_prop(arena, "BossRelayB", "res://assets/third_party/quaternius_cyberpunk/antenna.gltf", down, 8.8, -1.5, 0.0, 1.6, -15.0)


func _build_boss_hazards() -> void:
	var root := _section(_geometry_root, "BossHazards")
	var down := Vector3.BACK
	var specs := [
		[-6.4, -4.0, VIOLET],
		[6.4, -4.0, MAGENTA],
		[0.0, -10.2, CYAN],
		[0.0, 2.2, AMBER],
	]
	for i in range(specs.size()):
		var spec: Array = specs[i]
		var area := Area3D.new()
		area.name = "BossHazard_%02d" % i
		area.position = _face_point(down, float(spec[0]), float(spec[1]), 0.04)
		area.basis = CubeGravity.tangent_basis(down)
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 1
		area.add_to_group("boss_hazard")

		var collision := CollisionShape3D.new()
		collision.position = Vector3(0, 1.2, 0)
		var shape := CylinderShape3D.new()
		shape.radius = 2.25
		shape.height = 2.4
		collision.shape = shape
		area.add_child(collision)

		if DisplayServer.get_name() != "headless":
			var visual := MeshInstance3D.new()
			visual.name = "HazardVisual"
			var mesh := CylinderMesh.new()
			mesh.top_radius = 2.25
			mesh.bottom_radius = 2.25
			mesh.height = 0.07
			mesh.radial_segments = 48
			visual.mesh = mesh
			var accent: Color = spec[2]
			visual.material_override = _material(accent * 0.08, accent, 7.0)
			visual.visible = false
			area.add_child(visual)

		root.add_child(area)
		_boss_hazards.append(area)
		_boss_hazard_active.append(false)




func _build_extraction() -> void:
	var root := _region("Extraction")
	var down := Vector3.DOWN

	var yard := _section(root, "ExtractionYard")
	_add_face_box(yard, "YardDeck", down, -12.0, -12.0, 0.02, Vector3(15.0, 0.05, 14.0), Color(0.025, 0.045, 0.055), AMBER, false)
	_add_face_box(yard, "YardBarricadeA", down, -17.0, -12.0, 0.0, Vector3(3.2, 1.0, 0.9), COVER, AMBER, true, &"combat_cover")
	_add_face_box(yard, "YardBarricadeB", down, -10.0, -8.5, 0.0, Vector3(3.2, 1.0, 0.9), COVER, CYAN, true, &"combat_cover")
	_add_face_box(yard, "YardBarricadeC", down, -7.0, -15.0, 0.0, Vector3(3.2, 1.0, 0.9), COVER, MAGENTA, true, &"combat_cover")
	_add_prop(yard, "ExtractionLight_A", "res://assets/third_party/quaternius_cyberpunk/street_light.gltf", down, -18.0, -17.0, 0.0, 1.25, 0.0)
	_add_prop(yard, "ExtractionLight_B", "res://assets/third_party/quaternius_cyberpunk/street_light.gltf", down, -6.0, -8.0, 0.0, 1.25, 180.0)
	_add_prop(yard, "ExtractionFence", "res://assets/third_party/quaternius_cyberpunk/fence.gltf", down, -16.5, -7.5, 0.0, 1.5, 90.0)

	var route := _section(root, "ExtractionRoute")
	_add_face_box(route, "ExtractionLane", down, -5.0, -20.0, 0.02, Vector3(14.0, 0.05, 10.0), DARK, AMBER, false)
	_add_face_box(route, "RouteRail", down, -11.5, -20.0, 0.0, Vector3(0.3, 0.75, 10.0), WALL, AMBER, true, &"combat_cover")
	_add_face_trim(route, "ExtractionGuide", down, -5.0, -20.0, 0.08, Vector3(0.08, 0.035, 9.0), AMBER)
	_add_face_light(route, "ExtractionRouteLight", down, -5.0, -20.0, 3.6, AMBER, 1.25, 8.0)

	var zone_container := _section(root, "ExtractionBeacon")
	_add_ring_visual(zone_container, "ExtractionRing", down, 0.0, -25.0, 0.05, 3.4, Color(0.03, 0.06, 0.055), AMBER)
	if DisplayServer.get_name() != "headless":
		_extraction_progress_core = MeshInstance3D.new()
		_extraction_progress_core.name = "ExtractionProgressCore"
		var progress_mesh := CylinderMesh.new()
		progress_mesh.top_radius = 0.34
		progress_mesh.bottom_radius = 0.52
		progress_mesh.height = 2.7
		progress_mesh.radial_segments = 36
		_extraction_progress_core.mesh = progress_mesh
		_extraction_progress_core.position = _face_point(down, 0.0, -25.0, 0.0)
		_extraction_progress_core.basis = CubeGravity.tangent_basis(down)
		_extraction_progress_core.scale.y = 0.03
		_extraction_progress_core.material_override = _material(AMBER * 0.08, AMBER, 3.0)
		_extraction_progress_core.visible = false
		zone_container.add_child(_extraction_progress_core)
	_add_prop(zone_container, "ExtractionBeaconAntenna", "res://assets/third_party/quaternius_cyberpunk/antenna.gltf", down, 2.7, -25.0, 0.0, 1.75, 0.0)
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
	_extraction_zone.body_exited.connect(_on_extraction_body_exited)
	zone_container.add_child(_extraction_zone)

	if DisplayServer.get_name() != "headless":
		_extraction_label = Label3D.new()
		_extraction_label.name = "ExtractionStatus"
		_extraction_label.text = "EXTRACTION // HOLD POSITION"
		_extraction_label.font_size = 44
		_extraction_label.outline_size = 8
		_extraction_label.modulate = AMBER
		_extraction_label.outline_modulate = Color(0.01, 0.015, 0.02, 0.95)
		_extraction_label.position = _face_point(down, 0.0, -25.0, 3.5)
		_extraction_label.basis = CubeGravity.tangent_basis(down)
		_extraction_label.visible = false
		zone_container.add_child(_extraction_label)


func _build_combat_lockdown_gates() -> void:
	var root := _section(_geometry_root, "CombatLockdownGates")
	var specs := [
		[&"market_crossfire", "MarketEntry", Vector3.DOWN, 11.8, -3.05, Vector3(6.4, 3.6, 0.34), CYAN],
		[&"market_crossfire", "MarketExit", Vector3.DOWN, 21.0, 8.0, Vector3(5.4, 3.6, 0.34), MAGENTA],
		[&"gravity_breach", "BreachExit", Vector3.RIGHT, 3.0, -4.0, Vector3(5.4, 3.6, 0.34), AMBER],
		[&"data_lane", "DataExit", Vector3.LEFT, 0.0, 14.0, Vector3(8.0, 4.2, 0.34), VIOLET],
		[&"null_warden", "WardenEntry", Vector3.BACK, 0.0, 8.3, Vector3(11.0, 4.6, 0.34), MAGENTA],
		[&"extraction", "ExtractionRear", Vector3.DOWN, -4.5, -20.0, Vector3(8.0, 3.6, 0.34), AMBER],
	]

	for spec in specs:
		var encounter_id: StringName = spec[0]
		var gate_id: String = spec[1]
		var down: Vector3 = spec[2]
		var u: float = float(spec[3])
		var v: float = float(spec[4])
		var size: Vector3 = spec[5]
		var accent: Color = spec[6]

		var body := StaticBody3D.new()
		body.name = "%sLockdown" % gate_id
		body.position = _face_point(down, u, v, size.y * 0.5)
		body.basis = CubeGravity.tangent_basis(down)
		body.add_to_group("mission_geometry")
		body.add_to_group("combat_lockdown_gate")

		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		collision.disabled = true
		body.add_child(collision)

		var visual: MeshInstance3D = null
		if DisplayServer.get_name() != "headless":
			visual = MeshInstance3D.new()
			visual.name = "EnergyBarrier"
			var mesh := BoxMesh.new()
			mesh.size = size
			visual.mesh = mesh
			visual.material_override = _material(accent * 0.08, accent, 7.5)
			visual.visible = false
			body.add_child(visual)

		root.add_child(body)

		if not _combat_gates.has(encounter_id):
			_combat_gates[encounter_id] = []
		var gates: Array = _combat_gates[encounter_id]
		gates.append({
			"body": body,
			"collision": collision,
			"visual": visual,
			"gate_id": gate_id,
		})
		_combat_gates[encounter_id] = gates
		_lockdown_state[encounter_id] = false


func _build_encounter_activation_zones() -> void:
	var root := _section(_geometry_root, "EncounterActivationZones")
	var specs := [
		[&"market_crossfire", Vector3.DOWN, 12.0, 4.0, Vector3(7.0, 3.0, 7.0)],
		[&"gravity_breach", Vector3.RIGHT, -8.0, -12.0, Vector3(8.0, 3.0, 8.0)],
		[&"data_lane", Vector3.LEFT, 8.0, 8.0, Vector3(8.0, 3.0, 8.0)],
		[&"null_warden", Vector3.BACK, 0.0, -4.0, Vector3(9.0, 3.0, 9.0)],
		[&"extraction", Vector3.DOWN, -12.0, -12.0, Vector3(8.0, 3.0, 8.0)],
	]
	for spec in specs:
		var encounter_id: StringName = spec[0]
		var down: Vector3 = spec[1]
		var u: float = float(spec[2])
		var v: float = float(spec[3])
		var size: Vector3 = spec[4]
		var area := Area3D.new()
		area.name = "%sActivation" % String(encounter_id).to_pascal_case()
		area.position = _face_point(down, u, v, size.y * 0.5)
		area.basis = CubeGravity.tangent_basis(down)
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 1
		area.add_to_group("encounter_activation_zone")
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		area.add_child(collision)
		area.body_entered.connect(_on_encounter_zone_body_entered.bind(encounter_id))
		root.add_child(area)
		_encounter_zones[encounter_id] = area
		var beacon := Node3D.new()
		beacon.name = "%sBeacon" % String(encounter_id).to_pascal_case()
		beacon.position = _face_point(down, u, v, 0.05)
		beacon.basis = CubeGravity.tangent_basis(down)
		beacon.visible = false
		beacon.add_to_group("navigation_beacon")
		if DisplayServer.get_name() != "headless":
			var beam := MeshInstance3D.new()
			beam.name = "Beam"
			var beam_mesh := CylinderMesh.new()
			beam_mesh.top_radius = 0.18
			beam_mesh.bottom_radius = 0.34
			beam_mesh.height = 4.2
			beam_mesh.radial_segments = 24
			beam.mesh = beam_mesh
			beam.position = Vector3(0, 2.1, 0)
			beam.material_override = _material(CYAN * 0.08, CYAN, 8.0)
			beacon.add_child(beam)

			var label := Label3D.new()
			label.name = "Label"
			label.text = "OBJECTIVE // %s" % String(encounter_id).replace("_", " ").to_upper()
			label.font_size = 28
			label.outline_size = 6
			label.modulate = CYAN
			label.outline_modulate = Color(0.005, 0.01, 0.02, 0.95)
			label.position = Vector3(0, 4.6, 0)
			beacon.add_child(label)
		root.add_child(beacon)
		_navigation_beacons[encounter_id] = beacon



func _on_encounter_zone_body_entered(body: Node3D, encounter_id: StringName) -> void:
	if body is NeonPlayer:
		for key in _encounter_zones:
			var zone: Area3D = _encounter_zones[key]
			zone.set_deferred("monitoring", false)
		encounter_zone_entered.emit(encounter_id)


func _on_extraction_body_entered(body: Node3D) -> void:
	if _extraction_armed and body is NeonPlayer:
		_extraction_occupied = true


func _on_extraction_body_exited(body: Node3D) -> void:
	if body is NeonPlayer:
		_extraction_occupied = false


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


func _add_objective_node(
	parent: Node3D,
	name: String,
	encounter_id: StringName,
	objective_id: StringName,
	down: Vector3,
	u: float,
	v: float,
	health: float,
	accent: Color
) -> void:
	var node := MissionObjectiveNode.new()
	node.name = name
	node.position = _face_point(down, u, v, 1.0)
	node.basis = CubeGravity.tangent_basis(down)
	node.add_to_group("mission_objective_node")

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.25, 2.0, 1.25)
	collision.shape = shape
	node.add_child(collision)

	if DisplayServer.get_name() != "headless":
		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.25, 2.0, 1.25)
		visual.mesh = mesh
		visual.material_override = _material(accent * 0.08, accent, 5.5)
		node.add_child(visual)

		var base_ring := MeshInstance3D.new()
		base_ring.name = "BaseRing"
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 1.05
		ring_mesh.bottom_radius = 1.05
		ring_mesh.height = 0.055
		ring_mesh.radial_segments = 40
		base_ring.mesh = ring_mesh
		base_ring.position = Vector3(0, -0.96, 0)
		base_ring.material_override = _material(accent * 0.06, accent, 3.2)
		node.add_child(base_ring)

		var status := Label3D.new()
		status.name = "StatusLabel"
		status.text = "RELAY // LOCKED"
		status.font_size = 26
		status.outline_size = 6
		status.modulate = Color(0.45, 0.55, 0.70)
		status.outline_modulate = Color(0.004, 0.006, 0.015, 0.96)
		status.position = Vector3(0, 1.55, 0)
		status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node.add_child(status)

		var wreck := Node3D.new()
		wreck.name = "DestroyedVisual"
		wreck.visible = false
		node.add_child(wreck)

		var shard_specs := [
			[Vector3(-0.34, -0.55, 0.05), Vector3(0.42, 0.72, 0.46), Vector3(0, 0, 18)],
			[Vector3(0.30, -0.62, -0.10), Vector3(0.38, 0.58, 0.42), Vector3(0, 0, -24)],
			[Vector3(0.02, -0.86, 0.25), Vector3(0.52, 0.24, 0.34), Vector3(16, 8, 6)],
		]
		for spec in shard_specs:
			var shard := MeshInstance3D.new()
			var shard_mesh := BoxMesh.new()
			shard_mesh.size = spec[1]
			shard.mesh = shard_mesh
			shard.position = spec[0]
			shard.rotation_degrees = spec[2]
			shard.material_override = _material(Color(0.055, 0.045, 0.055), Color(0.55, 0.06, 0.08), 0.18)
			wreck.add_child(shard)

		var dead_core := MeshInstance3D.new()
		dead_core.name = "OfflineCore"
		var dead_mesh := SphereMesh.new()
		dead_mesh.radius = 0.16
		dead_mesh.height = 0.32
		dead_core.mesh = dead_mesh
		dead_core.position = Vector3(0, -0.42, -0.34)
		dead_core.material_override = _material(Color(0.08, 0.01, 0.015), Color(1.0, 0.08, 0.08), 2.2)
		wreck.add_child(dead_core)

	node.configure(encounter_id, objective_id, health)
	node.destroyed.connect(_on_objective_node_destroyed)
	parent.add_child(node)

	if not _objective_nodes.has(encounter_id):
		_objective_nodes[encounter_id] = []
	var nodes: Array = _objective_nodes[encounter_id]
	nodes.append(node)
	_objective_nodes[encounter_id] = nodes


func _on_objective_node_destroyed(node: MissionObjectiveNode) -> void:
	if node == null:
		return
	var down := CubeGravity.nearest_down(node.global_position, cube_half_extent)
	_spawn_event_pulse(node.global_position, down, Color(1.0, 0.20, 0.10), 2.4, 0.42)
	_spawn_event_sparks(node.global_position, down, Color(1.0, 0.38, 0.12), 8)
	var remaining := objective_nodes_remaining(node.encounter_id)
	objective_node_destroyed.emit(node.encounter_id, node.objective_id, remaining)


func _spawn_event_pulse(
	world_position: Vector3,
	down: Vector3,
	accent: Color,
	end_scale: float,
	lifetime: float
) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(_geometry_root):
		return

	var pulse := MeshInstance3D.new()
	pulse.name = "MissionEventPulse"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.72
	mesh.height = 0.045
	mesh.radial_segments = 48
	pulse.mesh = mesh
	pulse.global_position = world_position + down.normalized() * 0.92
	pulse.basis = CubeGravity.tangent_basis(down)
	pulse.scale = Vector3(0.55, 1.0, 0.55)
	pulse.material_override = _material(accent * 0.08, accent, 7.5)
	pulse.add_to_group("mission_event_fx")
	_geometry_root.add_child(pulse)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		pulse,
		"scale",
		Vector3(end_scale, 1.0, end_scale),
		maxf(0.12, lifetime)
	)
	tween.tween_callback(pulse.queue_free)


func _spawn_event_sparks(
	world_position: Vector3,
	down: Vector3,
	accent: Color,
	count: int
) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(_geometry_root):
		return

	var root := Node3D.new()
	root.name = "MissionEventSparks"
	root.global_position = world_position + down.normalized() * 0.45
	root.basis = CubeGravity.tangent_basis(down)
	root.add_to_group("mission_event_fx")
	_geometry_root.add_child(root)

	var spark_count := maxi(1, count)
	for i in range(spark_count):
		var spark := MeshInstance3D.new()
		spark.name = "Spark_%02d" % i
		var mesh := SphereMesh.new()
		mesh.radius = 0.055
		mesh.height = 0.11
		spark.mesh = mesh
		spark.material_override = _material(accent * 0.12, accent, 8.5)
		root.add_child(spark)

		var angle := TAU * float(i) / float(spark_count)
		var planar := Vector3(cos(angle), 0.0, sin(angle))
		var target := planar * (1.0 + float(i % 3) * 0.28) + Vector3(0, 0.6 + float(i % 2) * 0.35, 0)
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "position", target, 0.34 + float(i % 2) * 0.08)

	var cleanup := create_tween()
	cleanup.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	cleanup.tween_interval(0.48)
	cleanup.tween_callback(root.queue_free)


func _add_market_string_lights(
	parent: Node3D,
	name: String,
	down: Vector3,
	u: float,
	v: float,
	height: float,
	span: float,
	accent_a: Color,
	accent_b: Color
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var root := Node3D.new()
	root.name = name
	root.position = _face_point(down, u, v, height)
	root.basis = CubeGravity.tangent_basis(down)
	root.add_to_group("market_visual")
	parent.add_child(root)

	var cable := MeshInstance3D.new()
	cable.name = "Cable"
	var cable_mesh := BoxMesh.new()
	cable_mesh.size = Vector3(span, 0.025, 0.025)
	cable.mesh = cable_mesh
	cable.material_override = _material(Color(0.025, 0.028, 0.035), Color(0.08, 0.10, 0.14), 0.10)
	root.add_child(cable)

	var bulb_count := 9
	for i in range(bulb_count):
		var t := float(i) / float(bulb_count - 1)
		var x := lerpf(-span * 0.5, span * 0.5, t)
		var bulb := MeshInstance3D.new()
		bulb.name = "Bulb_%02d" % i
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.065
		bulb_mesh.height = 0.13
		bulb.mesh = bulb_mesh
		bulb.position = Vector3(x, -0.10 - sin(t * PI) * 0.18, 0)
		var accent := accent_a if i % 2 == 0 else accent_b
		bulb.material_override = _material(accent * 0.10, accent, 5.4)
		root.add_child(bulb)


func _add_market_ceiling_strip(
	parent: Node3D,
	name: String,
	down: Vector3,
	u: float,
	v: float,
	height: float,
	length: float,
	accent: Color
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var strip := MeshInstance3D.new()
	strip.name = name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.06, 0.11)
	strip.mesh = mesh
	strip.position = _face_point(down, u, v, height)
	strip.basis = CubeGravity.tangent_basis(down)
	strip.material_override = _material(accent * 0.07, accent, 4.2)
	strip.add_to_group("market_visual")
	parent.add_child(strip)


func _add_hanging_market_panel(
	parent: Node3D,
	name: String,
	down: Vector3,
	u: float,
	v: float,
	height: float,
	text: String,
	accent: Color
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var root := Node3D.new()
	root.name = name
	root.position = _face_point(down, u, v, height)
	root.basis = CubeGravity.tangent_basis(down)
	root.add_to_group("market_visual")
	parent.add_child(root)

	for side in [-1.0, 1.0]:
		var cable := MeshInstance3D.new()
		var cable_mesh := CylinderMesh.new()
		cable_mesh.top_radius = 0.018
		cable_mesh.bottom_radius = 0.018
		cable_mesh.height = 0.62
		cable.mesh = cable_mesh
		cable.position = Vector3(0.7 * side, 0.31, 0)
		cable.material_override = _material(Color(0.025, 0.03, 0.04), accent, 0.18)
		root.add_child(cable)

	var panel := MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(1.85, 0.52, 0.08)
	panel.mesh = panel_mesh
	panel.material_override = _material(Color(0.025, 0.028, 0.04), accent, 0.45)
	root.add_child(panel)

	var label := Label3D.new()
	label.text = text
	label.font_size = 25
	label.outline_size = 5
	label.modulate = accent
	label.outline_modulate = Color(0.004, 0.006, 0.015, 0.96)
	label.position = Vector3(0, 0, -0.055)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)


func _add_market_kiosk(
	parent: Node3D,
	name: String,
	down: Vector3,
	u: float,
	v: float,
	accent: Color,
	label_text: String
) -> void:
	var root := Node3D.new()
	root.name = name
	root.position = _face_point(down, u, v, 0.0)
	root.basis = CubeGravity.tangent_basis(down)
	root.add_to_group("market_visual")
	root.add_to_group("market_kiosk")
	parent.add_child(root)

	var body := StaticBody3D.new()
	body.name = "KioskCollision"
	body.position = Vector3(0, 0.575, 0)
	body.add_to_group("mission_geometry")
	body.add_to_group("combat_cover")
	body.add_to_group("market_kiosk_collision")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.25, 1.15, 1.25)
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)

	if DisplayServer.get_name() == "headless":
		return

	var base := MeshInstance3D.new()
	base.name = "Counter"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(2.25, 1.15, 1.25)
	base.mesh = base_mesh
	base.position = Vector3(0, 0.575, 0)
	base.material_override = _material(Color(0.045, 0.05, 0.065), accent, 0.14)
	root.add_child(base)

	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	var canopy_mesh := BoxMesh.new()
	canopy_mesh.size = Vector3(2.65, 0.12, 1.55)
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0, 1.72, 0)
	canopy.material_override = _material(Color(0.055, 0.035, 0.06), accent, 0.40)
	root.add_child(canopy)

	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.07, 1.55, 0.07)
		post.mesh = post_mesh
		post.position = Vector3(1.02 * side, 0.92, -0.52)
		post.material_override = _material(Color(0.055, 0.06, 0.075), accent, 1.8)
		root.add_child(post)

	var lightbox := MeshInstance3D.new()
	lightbox.name = "Lightbox"
	var lightbox_mesh := BoxMesh.new()
	lightbox_mesh.size = Vector3(1.75, 0.38, 0.08)
	lightbox.mesh = lightbox_mesh
	lightbox.position = Vector3(0, 1.40, -0.67)
	lightbox.material_override = _material(accent * 0.10, accent, 3.8)
	root.add_child(lightbox)

	var label := Label3D.new()
	label.name = "KioskLabel"
	label.text = label_text
	label.font_size = 22
	label.outline_size = 5
	label.modulate = Color(0.94, 0.97, 1.0)
	label.outline_modulate = Color(0.005, 0.008, 0.02, 0.96)
	label.position = Vector3(0, 1.40, -0.72)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)


func _add_market_signboard(
	parent: Node3D,
	name: String,
	down: Vector3,
	u: float,
	v: float,
	height: float,
	text: String,
	accent: Color
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var root := Node3D.new()
	root.name = name
	root.position = _face_point(down, u, v, height)
	root.basis = CubeGravity.tangent_basis(down)
	root.add_to_group("market_visual")
	parent.add_child(root)

	var backing := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(5.8, 0.78, 0.12)
	backing.mesh = mesh
	backing.material_override = _material(Color(0.025, 0.03, 0.045), accent, 0.08)
	root.add_child(backing)

	for x in [-2.7, 2.7]:
		var edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(0.07, 0.66, 0.15)
		edge.mesh = edge_mesh
		edge.position = Vector3(x, 0, -0.02)
		edge.material_override = _material(accent * 0.08, accent, 4.2)
		root.add_child(edge)

	for y in [-0.34, 0.34]:
		var border := MeshInstance3D.new()
		var border_mesh := BoxMesh.new()
		border_mesh.size = Vector3(5.45, 0.055, 0.15)
		border.mesh = border_mesh
		border.position = Vector3(0, y, -0.02)
		border.material_override = _material(accent * 0.08, accent, 4.2)
		root.add_child(border)

	var label := Label3D.new()
	label.text = text
	label.font_size = 28
	label.outline_size = 6
	label.modulate = accent
	label.outline_modulate = Color(0.004, 0.006, 0.015, 0.96)
	label.position = Vector3(0, 0, -0.08)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)


func _add_face_light(
	parent: Node3D,
	name: String,
	down: Vector3,
	u: float,
	v: float,
	height: float,
	color: Color,
	energy: float,
	range: float
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var light := OmniLight3D.new()
	light.name = name
	light.position = _face_point(down, u, v, height)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = range * 0.72
	light.distance_fade_length = range * 0.28
	light.add_to_group("mission_local_light")
	parent.add_child(light)


func _add_face_trim(
	parent: Node3D,
	name: String,
	down: Vector3,
	u: float,
	v: float,
	height: float,
	size: Vector3,
	accent: Color
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var trim := MeshInstance3D.new()
	trim.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	trim.mesh = mesh
	trim.position = _face_point(down, u, v, height)
	trim.basis = CubeGravity.tangent_basis(down)
	trim.material_override = _material(accent * 0.08, accent, 4.8)
	trim.add_to_group("mission_visual_trim")
	parent.add_child(trim)


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
		visual.material_override = _material(base_color, emission_color, 0.22 if collidable else 0.10)
		node.add_child(visual)
		if group_name == &"combat_cover":
			_decorate_combat_cover(node, size, emission_color)
	return node


func _decorate_combat_cover(node: Node3D, size: Vector3, accent: Color) -> void:
	if node == null or DisplayServer.get_name() == "headless":
		return

	var face_plate := MeshInstance3D.new()
	face_plate.name = "ArmorPlate"
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(
		maxf(0.25, size.x * 0.72),
		maxf(0.16, size.y * 0.42),
		0.045
	)
	face_plate.mesh = plate_mesh
	face_plate.position = Vector3(0, -size.y * 0.08, -size.z * 0.505)
	face_plate.material_override = _material(
		Color(0.085, 0.095, 0.115),
		accent,
		0.10
	)
	node.add_child(face_plate)

	var band := MeshInstance3D.new()
	band.name = "CoverBand"
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(
		maxf(0.30, size.x * 0.82),
		0.055,
		maxf(0.08, size.z * 1.015)
	)
	band.mesh = band_mesh
	band.position = Vector3(0, size.y * 0.34, 0)
	band.material_override = _material(accent * 0.08, accent, 3.0)
	node.add_child(band)

	for side in [-1.0, 1.0]:
		var bolt := MeshInstance3D.new()
		bolt.name = "Bolt"
		var bolt_mesh := SphereMesh.new()
		bolt_mesh.radius = 0.035
		bolt_mesh.height = 0.07
		bolt.mesh = bolt_mesh
		bolt.position = Vector3(
			size.x * 0.30 * side,
			-size.y * 0.08,
			-size.z * 0.53
		)
		bolt.material_override = _material(accent * 0.12, accent, 2.2)
		node.add_child(bolt)


func _add_prop(
	parent: Node3D,
	name: String,
	scene_path: String,
	down: Vector3,
	u: float,
	v: float,
	height: float,
	uniform_scale: float = 1.0,
	yaw_degrees: float = 0.0
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not ResourceLoader.exists(scene_path):
		push_warning("Mission prop missing: %s" % scene_path)
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("Mission prop is not a PackedScene: %s" % scene_path)
		return
	var prop := packed.instantiate() as Node3D
	if prop == null:
		push_warning("Mission prop root is not Node3D: %s" % scene_path)
		return
	prop.name = name
	prop.position = _face_point(down, u, v, height)
	prop.basis = CubeGravity.tangent_basis(down)
	prop.rotate_object_local(Vector3.UP, deg_to_rad(yaw_degrees))
	prop.scale = Vector3.ONE * uniform_scale
	prop.add_to_group("mission_visual_prop")
	parent.add_child(prop)


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
	material.roughness = 0.34
	material.emission_enabled = energy > 0.0
	if energy > 0.0:
		material.emission = emission_color
		material.emission_energy_multiplier = energy
	return material
