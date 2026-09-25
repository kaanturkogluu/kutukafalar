extends RigidBody3D

# --- Klasik Kırmızı Patlayıcı Varil (Boxhead Explosive Barrel) ---
@export var max_health: float = 30.0
@export var explosion_damage: float = 300.0
@export var explosion_radius: float = 5.5

var current_health: float
var is_exploded: bool = false

const EXPLOSION_EFFECT_PATH = "res://scenes/effects/barrel_explosion.tscn"

func _ready() -> void:
	current_health = max_health
	add_to_group("interactables")
	add_to_group("barrels")
	if not multiplayer.is_server():
		freeze = true

## Hasar alma (Mermi vurunca veya başka patlamayla)
func take_damage(amount: float, _is_headshot: bool = false, hit_point: Vector3 = Vector3.ZERO) -> void:
	if is_exploded:
		return
	
	if not multiplayer.is_server():
		_request_barrel_damage.rpc_id(1, amount, hit_point)
		return

	current_health -= amount
	if hit_point != Vector3.ZERO:
		var push = (global_position - hit_point).normalized()
		apply_central_impulse(push * 5.0)

	if current_health <= 0:
		explode()

@rpc("any_peer", "reliable")
func _request_barrel_damage(amount: float, hit_point: Vector3) -> void:
	if multiplayer.is_server():
		take_damage(amount, false, hit_point)

## Tekmeyle Savrulma (Kutu Tekmesi - F Tuşu)
func kick(kick_direction: Vector3, force: float = 18.0) -> void:
	apply_central_impulse(kick_direction * force + Vector3.UP * 3.0)
	apply_torque_impulse(Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)))

## Patlama Fonksiyonu (Host Tarafından Tetiklenir)
func explode() -> void:
	if is_exploded:
		return
	is_exploded = true
	_detonate.rpc()

@rpc("call_local", "reliable")
func _detonate() -> void:
	# Efekti oluştur
	var exp_scene = load(EXPLOSION_EFFECT_PATH)
	if exp_scene:
		var effect = exp_scene.instantiate()
		get_parent().add_child(effect)
		effect.global_position = global_position

	# Hasar ve İtme Uygulama (Sadece Sunucu)
	if multiplayer.is_server():
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = explosion_radius
		query.shape = sphere
		query.transform = global_transform
		query.collision_mask = 7 # Oyuncular, Düşmanlar, Variller

		var results = space_state.intersect_shape(query, 32)
		for res in results:
			var collider = res.collider
			if collider == self:
				continue

			var dist = global_position.distance_to(collider.global_position)
			var dist_factor = clamp(1.0 - (dist / explosion_radius), 0.2, 1.0)
			var damage_to_deal = explosion_damage * dist_factor

			# Zombi hasarı
			if collider.is_in_group("enemies") and collider.has_method("take_damage"):
				collider.take_damage(damage_to_deal, false, global_position)
			# Zincirleme Varil Patlaması!
			elif collider.is_in_group("barrels") and collider.has_method("take_damage"):
				collider.take_damage(damage_to_deal, false, global_position)

	queue_free()
