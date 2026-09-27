extends StaticBody3D

# --- Duvarcı Sınıfı Taktiksel Barikat Duvarı (Boxhead Brick Wall) ---
@export var max_health: float = 200.0
var current_health: float = 200.0
var is_destroyed: bool = false

const GIBS_SCENE_PATH = "res://scenes/effects/cube_gibs.tscn"

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

static var wall_hurt_mat: StandardMaterial3D = null

func _ready() -> void:
	current_health = max_health
	add_to_group("walls")
	add_to_group("interactables")
	add_to_group("destructibles")

static func _get_wall_hurt_mat() -> StandardMaterial3D:
	if wall_hurt_mat == null:
		wall_hurt_mat = StandardMaterial3D.new()
		wall_hurt_mat.albedo_color = Color(1.0, 0.3, 0.3, 1.0)
		wall_hurt_mat.emission_enabled = true
		wall_hurt_mat.emission = Color(0.9, 0.2, 0.2, 1.0)
		wall_hurt_mat.emission_energy_multiplier = 1.5
	return wall_hurt_mat

func take_damage(amount: float, _is_headshot: bool = false, _hit_point: Vector3 = Vector3.ZERO, _attacker_id: int = 1) -> void:
	if is_destroyed:
		return
	if not multiplayer.is_server():
		_request_wall_damage.rpc_id(1, amount)
		return
	_apply_damage(amount)

@rpc("any_peer", "reliable")
func _request_wall_damage(amount: float) -> void:
	if multiplayer.is_server():
		take_damage(amount)

func _apply_damage(amount: float) -> void:
	if is_destroyed:
		return
	current_health -= amount
	_flash_wall_damage.rpc()
	
	if current_health <= 0 and not is_destroyed:
		is_destroyed = true
		_destroy_wall.rpc()

@rpc("call_local", "unreliable")
func _flash_wall_damage() -> void:
	if mesh_instance:
		mesh_instance.material_override = _get_wall_hurt_mat()
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(mesh_instance) and mesh_instance.material_override == _get_wall_hurt_mat():
			mesh_instance.material_override = null

@rpc("call_local", "reliable")
func _destroy_wall() -> void:
	is_destroyed = true
	# Moloz ve taş parçalanma efekti
	var gibs_scene = load(GIBS_SCENE_PATH)
	if gibs_scene:
		var gibs = gibs_scene.instantiate()
		gibs.position = global_position + Vector3(0, 0.7, 0)
		get_tree().current_scene.add_child(gibs)
	
	SoundManager.play_3d_sfx("shotgun", global_position, 0.4, -4.0)
	queue_free()
