class_name NeonPickup
extends Area3D

@export_enum("health", "ammo") var pickup_type := "health"
@export var amount := 25.0

var _base_y := 0.0

func configure(kind: String, value: float) -> void:
	pickup_type = kind
	amount = value

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	_build_visual()

func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	rotate_y(delta * 1.8)

func _on_body_entered(body: Node3D) -> void:
	if not body is NeonPlayer:
		return
	var player: NeonPlayer = body as NeonPlayer
	if pickup_type == "health":
		player.heal(amount)
	else:
		player.grant_ammo(int(amount))
	var audio: Node = get_tree().get_first_node_in_group("neon_audio")
	if audio != null and audio.has_method("play_pickup"):
		audio.call("play_pickup")
	queue_free()

func _build_visual() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.28
	mesh.height = 0.55
	mesh_instance.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var color: Color = Color(0.15, 1.0, 0.45) if pickup_type == "health" else Color(1.0, 0.2, 0.85)
	mat.albedo_color = color * 0.25
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mesh_instance.material_override = mat
	add_child(mesh_instance)
