class_name NeonPickup
extends Area3D

signal collected(pickup_id: StringName)

@export_enum("health", "ammo", "shield") var pickup_type := "health"
@export var amount := 25.0
var pickup_id: StringName = &""

func configure(kind: String, value: float, authored_id: StringName = &"") -> void:
	pickup_type = kind
	amount = value
	pickup_id = authored_id

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	_build_visual()

func _process(delta: float) -> void:
	if DisplayServer.get_name() != "headless":
		rotate_y(delta * 1.8)

func _on_body_entered(body: Node3D) -> void:
	if not body is NeonPlayer: return
	var player: NeonPlayer = body as NeonPlayer
	if pickup_type == "health":
		player.heal(amount)
	elif pickup_type == "shield":
		player.grant_shield(amount)
	else:
		player.grant_ammo(int(amount))
	var audio: Node = get_tree().get_first_node_in_group("neon_audio")
	if audio != null and audio.has_method("play_pickup"): audio.call("play_pickup")
	if pickup_id != &"":
		collected.emit(pickup_id)
	queue_free()

func _build_visual() -> void:
	if DisplayServer.get_name() == "headless": return
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.28
	mesh.height = 0.55
	mesh_instance.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var color := Color(0.15, 1.0, 0.45)
	if pickup_type == "ammo":
		color = Color(1.0, 0.2, 0.85)
	elif pickup_type == "shield":
		color = Color(0.2, 0.55, 1.0)
	mat.albedo_color = color * 0.25
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mesh_instance.material_override = mat
	add_child(mesh_instance)
