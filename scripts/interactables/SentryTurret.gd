extends StaticBody3D

# --- Mühendis Taktiksel Otomatik Tareti (Sentry Turret) ---
signal destroyed

@export var max_health: float = 220.0
var current_health: float = 220.0
var is_destroyed: bool = false

@export var attack_range: float = 16.0
@export var fire_rate: float = 0.32
@export var damage_per_bullet: float = 16.0

var fire_timer: float = 0.0
var current_target: Node3D = null

@onready var head_node: Node3D = get_node_or_null("Head")
@onready var muzzle_node: Node3D = get_node_or_null("Head/Muzzle")
@onready var sensor_mesh: MeshInstance3D = get_node_or_null("Head/Sensor")
@onready var muzzle_flash: Node3D = get_node_or_null("Head/Muzzle/Flash")

static var turret_hurt_mat: StandardMaterial3D = null
static var sensor_idle_mat: StandardMaterial3D = null
static var sensor_active_mat: StandardMaterial3D = null

const GIBS_SCENE_PATH = "res://scenes/effects/cube_gibs.tscn"

func _ready() -> void:
	current_health = max_health
	add_to_group("turrets")
	add_to_group("destructibles")
	add_to_group("interactables")
	
	_setup_materials()
	
	if sensor_mesh and sensor_idle_mat:
		sensor_mesh.material_override = sensor_idle_mat

func _setup_materials() -> void:
	if turret_hurt_mat == null:
		turret_hurt_mat = StandardMaterial3D.new()
		turret_hurt_mat.albedo_color = Color(1.0, 0.25, 0.25, 1.0)
		turret_hurt_mat.emission_enabled = true
		turret_hurt_mat.emission = Color(1.0, 0.15, 0.15, 1.0)
		turret_hurt_mat.emission_energy_multiplier = 2.0
	
	if sensor_idle_mat == null:
		sensor_idle_mat = StandardMaterial3D.new()
		sensor_idle_mat.albedo_color = Color(0.2, 0.9, 0.4, 1.0)
		sensor_idle_mat.emission_enabled = true
		sensor_idle_mat.emission = Color(0.1, 0.9, 0.3, 1.0)
		sensor_idle_mat.emission_energy_multiplier = 2.0

	if sensor_active_mat == null:
		sensor_active_mat = StandardMaterial3D.new()
		sensor_active_mat.albedo_color = Color(1.0, 0.2, 0.2, 1.0)
		sensor_active_mat.emission_enabled = true
		sensor_active_mat.emission = Color(1.0, 0.1, 0.1, 1.0)
		sensor_active_mat.emission_energy_multiplier = 2.5

func _physics_process(delta: float) -> void:
	if is_destroyed:
		return

	if fire_timer > 0:
		fire_timer -= delta

	# Hedefleme ve atış kararı SADECE sunucuda (Host) verilir
	if multiplayer.is_server():
		_find_best_target()
		if current_target and is_instance_valid(current_target) and not current_target.get("is_dead"):
			var target_pos = current_target.global_position + Vector3.UP * 0.8
			_aim_at.rpc(target_pos)
			
			if fire_timer <= 0:
				fire_timer = fire_rate
				_shoot_at_target(target_pos, current_target)
		else:
			_aim_idle.rpc()

func _find_best_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_dist = attack_range
	var best: Node3D = null
	var space = get_world_3d().direct_space_state
	var muzzle_pos = muzzle_node.global_position if muzzle_node else (global_position + Vector3.UP * 0.8)
	
	for e in enemies:
		if is_instance_valid(e) and not e.get("is_dead") and not e.is_in_group("players"):
			var e_pos = e.global_position + Vector3.UP * 0.8
			var d = muzzle_pos.distance_to(e_pos)
			if d < closest_dist:
				# Görüş Hattı (Line of Sight) Kontrolü - Duvar ve takım arkadaşlarının arkasına ateş etmez
				if space:
					var ray = PhysicsRayQueryParameters3D.create(muzzle_pos, e_pos, 7)
					ray.exclude = [self.get_rid()]
					var hit = space.intersect_ray(ray)
					if hit and hit.collider:
						# Eğer araya bir oyuncu girmişse dost ateşini önlemek için hedef alma
						if hit.collider.is_in_group("players"):
							continue
						# Eğer araya düşman dışında başka bir engel (duvar vb.) girmişse hedef alma
						if hit.collider != e and not hit.collider.is_in_group("enemies"):
							continue
				closest_dist = d
				best = e
	
	current_target = best

@rpc("call_local", "unreliable")
func _aim_at(target_pos: Vector3) -> void:
	if head_node and is_instance_valid(head_node):
		head_node.look_at(target_pos, Vector3.UP)
	if sensor_mesh and sensor_active_mat:
		sensor_mesh.material_override = sensor_active_mat

@rpc("call_local", "unreliable")
func _aim_idle() -> void:
	if sensor_mesh and sensor_idle_mat:
		sensor_mesh.material_override = sensor_idle_mat

func _shoot_at_target(target_pos: Vector3, enemy_ref: Node3D) -> void:
	if not is_instance_valid(enemy_ref) or enemy_ref.is_in_group("players"):
		return
	
	_sync_fire.rpc(target_pos)
	
	# Sunucuda zombiye hasar ver (attacker_id = -1 verilerek taretin ultiyi bedava/sonsuz şarjlaması engellenir)
	if enemy_ref.has_method("take_damage"):
		enemy_ref.take_damage(damage_per_bullet, false, target_pos, -1)

@rpc("call_local", "unreliable")
func _sync_fire(target_pos: Vector3) -> void:
	SoundManager.play_3d_sfx("pistol", global_position, 0.16, 1.25)
	
	# Namlu alevi efekti
	if muzzle_flash:
		muzzle_flash.visible = true
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(muzzle_flash):
				muzzle_flash.visible = false
		)
	
	# Mermi izi (Tracer)
	var spawn_pt = muzzle_node.global_position if muzzle_node else (global_position + Vector3.UP * 0.8)
	_draw_tracer(spawn_pt, target_pos)

func _draw_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.9)
	mi.material_override = mat
	
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(from_pos)
	im.surface_add_vertex(to_pos)
	im.surface_end()
	
	get_tree().current_scene.add_child(mi)
	
	var tw = mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.07)
	tw.tween_callback(mi.queue_free)

# --- Hasar ve Kırılma Yönetimi (Destructible) ---

func take_damage(amount: float, _is_headshot: bool = false, _hit_point: Vector3 = Vector3.ZERO, _attacker_id: int = 1) -> void:
	if is_destroyed:
		return
	if not multiplayer.is_server():
		_request_damage.rpc_id(1, amount)
		return
	_apply_damage(amount)

@rpc("any_peer", "reliable")
func _request_damage(amount: float) -> void:
	if multiplayer.is_server():
		take_damage(amount)

func _apply_damage(amount: float) -> void:
	if is_destroyed:
		return
	current_health -= amount
	_flash_hurt.rpc()
	
	if current_health <= 0:
		is_destroyed = true
		_destroy_turret.rpc()

@rpc("call_local", "unreliable")
func _flash_hurt() -> void:
	var meshes = find_children("*", "MeshInstance3D")
	for m in meshes:
		if m != sensor_mesh:
			m.material_override = turret_hurt_mat
	
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self):
		for m in meshes:
			if is_instance_valid(m) and m != sensor_mesh:
				m.material_override = null

@rpc("call_local", "reliable")
func _destroy_turret() -> void:
	is_destroyed = true
	SoundManager.play_3d_sfx("barrel_explode", global_position, 0.4, 0.8)
	
	# Parçalanma efektleri
	var gibs_scene = load(GIBS_SCENE_PATH)
	if gibs_scene:
		var gibs = gibs_scene.instantiate()
		gibs.position = global_position + Vector3.UP * 0.5
		get_tree().current_scene.add_child(gibs)
	
	destroyed.emit()
	queue_free()
