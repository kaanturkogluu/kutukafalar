extends StaticBody3D

# --- Patlayabilir Hurda Araç (Explodable Car Wreck) ---
# Siper olarak kullanılabilir, mermi/patlama aldığında alev alıp büyük alan hasarıyla patlar.
# Patladıktan sonra yanmış iskelet olarak siper görevini sürdürür.

signal car_exploded(car_ref)

@export var max_health: float = 150.0
@export var explosion_damage: float = 350.0
@export var explosion_radius: float = 7.5
@export var car_type: String = "sedan" # "sedan", "van", "taxi"
@export var car_color: Color = Color(0.25, 0.45, 0.75, 1.0)

var current_health: float
var is_critical: bool = false
var is_exploded: bool = false
var countdown_timer: float = 0.0

const EXPLOSION_EFFECT_PATH = "res://scenes/effects/barrel_explosion.tscn"
const GIBS_EFFECT_PATH = "res://scenes/effects/cube_gibs.tscn"

@onready var body_mesh: MeshInstance3D = get_node_or_null("Visuals/Body")
@onready var cabin_mesh: MeshInstance3D = get_node_or_null("Visuals/Cabin")
@onready var warning_light: OmniLight3D = get_node_or_null("WarningLight")

var original_body_mat: StandardMaterial3D = null
static var hurt_mat: StandardMaterial3D = null
static var burnt_mat: StandardMaterial3D = null

func _ready() -> void:
	current_health = max_health
	add_to_group("interactables")
	add_to_group("barrels") # Mermiler ve varil zincirleme hasarları otomatik etkileşir
	add_to_group("destructibles")
	
	if warning_light:
		warning_light.visible = false
	
	_setup_materials()

func _setup_materials() -> void:
	if body_mesh:
		original_body_mat = StandardMaterial3D.new()
		original_body_mat.albedo_color = car_color
		original_body_mat.metallic = 0.5
		original_body_mat.roughness = 0.45
		body_mesh.material_override = original_body_mat
	
	if hurt_mat == null:
		hurt_mat = StandardMaterial3D.new()
		hurt_mat.albedo_color = Color(1.0, 0.3, 0.2, 1.0)
		hurt_mat.emission_enabled = true
		hurt_mat.emission = Color(1.0, 0.2, 0.1, 1.0)
		hurt_mat.emission_energy_multiplier = 2.0

	if burnt_mat == null:
		burnt_mat = StandardMaterial3D.new()
		burnt_mat.albedo_color = Color(0.12, 0.12, 0.14, 1.0)
		burnt_mat.roughness = 0.95
		burnt_mat.metallic = 0.1

func _process(delta: float) -> void:
	# Kritik patlama geri sayımı (hızlı yanıp sönen kırmızı ışık)
	if is_critical and not is_exploded:
		countdown_timer -= delta
		if warning_light:
			warning_light.visible = fmod(countdown_timer, 0.16) < 0.08
		
		if multiplayer.is_server() and countdown_timer <= 0:
			_explode()

## Hasar Alma Metodu (Mermi veya yakındaki patlamalar)
func take_damage(amount: float, _is_headshot: bool = false, hit_point: Vector3 = Vector3.ZERO, attacker_id: int = 1) -> void:
	if is_exploded or is_critical:
		return

	if not multiplayer.is_server():
		_request_car_damage.rpc_id(1, amount, hit_point, attacker_id)
		return

	current_health -= amount
	_flash_hit.rpc()

	if current_health <= 0:
		_start_critical_countdown.rpc()

@rpc("any_peer", "reliable")
func _request_car_damage(amount: float, hit_point: Vector3, attacker_id: int) -> void:
	if multiplayer.is_server():
		take_damage(amount, false, hit_point, attacker_id)

@rpc("call_local", "unreliable")
func _flash_hit() -> void:
	if is_exploded or not body_mesh:
		return
	body_mesh.material_override = hurt_mat
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self) and not is_exploded and body_mesh:
		body_mesh.material_override = original_body_mat

@rpc("call_local", "reliable")
func _start_critical_countdown() -> void:
	if is_critical or is_exploded:
		return
	is_critical = true
	countdown_timer = 1.2
	if warning_light:
		warning_light.visible = true
		warning_light.light_color = Color(1.0, 0.1, 0.1, 1.0)
		warning_light.light_energy = 5.0

func _explode() -> void:
	if is_exploded:
		return
	is_exploded = true
	is_critical = false
	_detonate.rpc()

@rpc("call_local", "reliable")
func _detonate() -> void:
	is_exploded = true
	is_critical = false
	if warning_light:
		warning_light.visible = false

	# Patlama Ses Efekti
	if SoundManager:
		SoundManager.play_3d_sfx("rocket", global_position)

	# Patlama Görsel Efekti
	var exp_scene = load(EXPLOSION_EFFECT_PATH)
	if exp_scene:
		var effect = exp_scene.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position + Vector3(0, 0.8, 0)

	# Voxel Parçalanma Gibs
	var gibs_scene = load(GIBS_EFFECT_PATH)
	if gibs_scene:
		var gibs = gibs_scene.instantiate()
		get_tree().current_scene.add_child(gibs)
		gibs.global_position = global_position + Vector3(0, 1.0, 0)

	# Aracı yanmış siyah iskelete çevir
	if body_mesh:
		body_mesh.material_override = burnt_mat
	if cabin_mesh:
		cabin_mesh.material_override = burnt_mat

	# Sunucu Hasar Hesabı (Geniş Alan Hasarı)
	if multiplayer.is_server():
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = explosion_radius
		query.shape = sphere
		query.transform = global_transform
		query.collision_mask = 7 # Oyuncular, Düşmanlar, Variller

		var results = space_state.intersect_shape(query, 48)
		for res in results:
			var collider = res.collider
			if collider == self:
				continue

			var dist = global_position.distance_to(collider.global_position)
			var dist_factor = clamp(1.0 - (dist / explosion_radius), 0.25, 1.0)
			var damage_to_deal = explosion_damage * dist_factor

			if collider.is_in_group("enemies") and collider.has_method("take_damage"):
				collider.take_damage(damage_to_deal, false, global_position)
			elif collider.is_in_group("barrels") and collider.has_method("take_damage"):
				collider.take_damage(damage_to_deal, false, global_position)
			elif collider.is_in_group("players") and collider.has_method("take_damage"):
				collider.take_damage(damage_to_deal * 0.4) # Dost hasarı azaltılmış

		car_exploded.emit(self)
