extends Area3D

# Types: "gold", "shotgun", "uzi", "bixi", "rocket", "barrel", "health"
@export var pickup_type: String = "gold"
@export var amount: int = 15

var bob_timer: float = 0.0
var initial_y: float = 0.0
var is_collected: bool = false

func _ready() -> void:
	add_to_group("pickups")
	initial_y = position.y
	_apply_visuals()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	rotate_y(3.0 * delta)
	bob_timer += delta * 4.0
	position.y = initial_y + sin(bob_timer) * 0.15

func _apply_visuals() -> void:
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.3
	mat.emission_enabled = true
	
	var label = get_node_or_null("Label3D") as Label3D
	var mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	
	match pickup_type:
		"gold":
			mat.albedo_color = Color(1.0, 0.85, 0.1)
			mat.emission = Color(1.0, 0.75, 0.1)
			if label: label.text = "+ALTIN 🪙"
		"shotgun":
			mat.albedo_color = Color(0.9, 0.3, 0.1)
			mat.emission = Color(0.8, 0.2, 0.05)
			if label: label.text = "POMPALI 💥"
		"uzi":
			mat.albedo_color = Color(0.2, 0.8, 0.3)
			mat.emission = Color(0.1, 0.7, 0.2)
			if label: label.text = "UZI ⚡"
		"bixi":
			mat.albedo_color = Color(0.2, 0.45, 0.25)
			mat.emission = Color(0.15, 0.4, 0.2)
			if label: label.text = "BİXİ 💥"
		"rocket":
			mat.albedo_color = Color(0.9, 0.1, 0.8)
			mat.emission = Color(0.8, 0.05, 0.7)
			if label: label.text = "ROKET 🚀"
		"barrel":
			mat.albedo_color = Color(0.9, 0.1, 0.1)
			mat.emission = Color(0.8, 0.05, 0.05)
			if label: label.text = "+VARİL 📦"
		"health":
			mat.albedo_color = Color(0.1, 0.7, 1.0)
			mat.emission = Color(0.05, 0.6, 0.9)
			if label: label.text = "+CAN ❤️"
			
	mat.emission_energy_multiplier = 2.0
	if mesh:
		mesh.material_override = mat

func _on_body_entered(body: Node3D) -> void:
	if is_collected or not is_instance_valid(body):
		return
	if not body.is_in_group("players"):
		return

	if multiplayer.is_server():
		_collect_by_player(body)
	else:
		# İstemci kendi karakteriyle loot'a temas ettiğinde sunucuya toplama talebi gönderir
		if body.is_multiplayer_authority():
			_request_pickup_collect.rpc_id(1, body.name)

@rpc("any_peer", "reliable")
func _request_pickup_collect(player_node_name: String) -> void:
	if not multiplayer.is_server() or is_collected:
		return
	var main_level = get_tree().current_scene
	var p = null
	if main_level and "players_container" in main_level and is_instance_valid(main_level.players_container):
		p = main_level.players_container.get_node_or_null(player_node_name)
	if not p:
		var players = get_tree().get_nodes_in_group("players")
		for pl in players:
			if pl.name == player_node_name:
				p = pl
				break
	if p and is_instance_valid(p) and not p.get("is_dead") and p.global_position.distance_to(global_position) <= 4.0:
		_collect_by_player(p)

func _collect_by_player(body: Node3D) -> void:
	if is_collected or not multiplayer.is_server():
		return
	is_collected = true
	if body.has_method("apply_pickup"):
		body.apply_pickup.rpc(pickup_type, amount)
	_collect.rpc()

@rpc("call_local", "reliable")
func _collect() -> void:
	is_collected = true
	visible = false
	set_physics_process(false)
	collision_mask = 0
	collision_layer = 0
	queue_free()
