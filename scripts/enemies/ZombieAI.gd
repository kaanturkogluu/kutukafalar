extends CharacterBody3D

# --- Beyaz Kutu Zombi Yapay Zekası ---
signal died(zombie_ref)

@export var max_health: float = 100.0
@export var speed: float = 3.6
@export var attack_damage: float = 15.0
@export var attack_rate: float = 1.0

var current_health: float
var attack_timer: float = 0.0
var target_player: CharacterBody3D = null
var is_frozen: bool = false
var is_dead: bool = false
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

const GIBS_SCENE_PATH = "res://scenes/effects/cube_gibs.tscn"

@onready var anim_mesh: Node3D = $Visuals

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	# Yerçekimi
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Zombi yapay zekası SADECE sunucu (Host) tarafından hesaplanır
	if not multiplayer.is_server():
		move_and_slide()
		return

	if is_frozen:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	attack_timer -= delta
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_factor = 1.0

	# En yakın oyuncuyu hedef seç
	_find_closest_player()

	if target_player and is_instance_valid(target_player):
		var target_pos = target_player.global_position
		var diff = target_pos - global_position
		diff.y = 0 # Yükseklik farkını yok say
		var distance = diff.length()

		# Oyuncuya doğru dön
		if diff.length_squared() > 0.01:
			var look_target = global_position + diff
			look_at(look_target, Vector3.UP)
			rotation.x = 0
			rotation.z = 0

		# Mesafe kontrolü: Kovalama mı, Saldırı mı?
		var vert_diff = abs(global_position.y - target_player.global_position.y)
		var move_speed = speed * slow_factor
		if distance > 1.3 or vert_diff > 1.6:
			# Zombi havadaysa veya oyuncudan çok uzaktaysa yaklaşmalı
			var direction = diff.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
		else:
			# Saldırı menzilinde ve aynı seviyede
			velocity.x = 0
			velocity.z = 0
			if attack_timer <= 0:
				_attack_player(target_player)
				attack_timer = attack_rate
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)

	move_and_slide()

func _find_closest_player() -> void:
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		target_player = null
		return

	var closest_dist = INF
	var closest: CharacterBody3D = null
	for p in players:
		if is_instance_valid(p) and not p.get("is_dead"):
			var d = global_position.distance_to(p.global_position)
			if d < closest_dist:
				closest_dist = d
				closest = p
	target_player = closest

func _attack_player(player: CharacterBody3D) -> void:
	if is_dead:
		return
	if is_instance_valid(player) and player.has_method("take_damage") and not player.get("is_dead"):
		player.take_damage(attack_damage)

static var zombie_hurt_mat: StandardMaterial3D = null

static func _get_zombie_hurt_mat() -> StandardMaterial3D:
	if zombie_hurt_mat == null:
		zombie_hurt_mat = StandardMaterial3D.new()
		zombie_hurt_mat.albedo_color = Color(1.0, 0.2, 0.2, 1.0)
		zombie_hurt_mat.emission_enabled = true
		zombie_hurt_mat.emission = Color(1.0, 0.1, 0.1, 1.0)
		zombie_hurt_mat.emission_energy_multiplier = 2.5
	return zombie_hurt_mat

@rpc("call_local", "unreliable")
func _flash_hurt() -> void:
	var b_mesh = $Visuals/BodyMesh
	var h_mesh = $Visuals/HeadMesh
	if b_mesh: b_mesh.material_override = _get_zombie_hurt_mat()
	if h_mesh: h_mesh.material_override = _get_zombie_hurt_mat()
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		if b_mesh and b_mesh.material_override == _get_zombie_hurt_mat():
			b_mesh.material_override = null
		if h_mesh and h_mesh.material_override == _get_zombie_hurt_mat():
			h_mesh.material_override = null

## Hasar Alma Metodu (Mermi isabet ettiğinde çağrılır)
func take_damage(amount: float, is_headshot: bool = false, hit_point: Vector3 = Vector3.ZERO, attacker_id: int = 1) -> void:
	if is_dead:
		return
	# Hasar hesaplaması sunucuda yetkilidir
	if not multiplayer.is_server():
		_request_damage.rpc_id(1, amount, is_headshot, hit_point, attacker_id)
		return

	_apply_damage(amount, is_headshot, hit_point, attacker_id)

@rpc("any_peer", "reliable")
func _request_damage(amount: float, is_headshot: bool, hit_point: Vector3, attacker_id: int = 1) -> void:
	if multiplayer.is_server():
		take_damage(amount, is_headshot, hit_point, attacker_id)

func _apply_damage(amount: float, is_headshot: bool, hit_point: Vector3, attacker_id: int = 1) -> void:
	if is_dead:
		return
	var final_damage = amount * 2.5 if is_headshot else amount
	current_health -= final_damage
	
	_flash_hurt.rpc()
	
	# Hafif geriye savrulma (knockback) - Sadece belirgin hasarlarda ve neredeyse tamamen yatay
	if amount >= 12.0 and hit_point != Vector3.ZERO:
		var push_dir = (global_position - hit_point).normalized()
		push_dir.y = 0.04
		velocity += push_dir * min(amount * 0.08, 2.8)

	if current_health <= 0:
		is_dead = true
		_die.rpc(is_headshot, attacker_id)

const PICKUP_SCENE_PATH = "res://scenes/interactables/pickup.tscn"

@rpc("call_local", "reliable")
func _die(is_headshot: bool, attacker_id: int = 1) -> void:
	if is_dead and not multiplayer.is_server() and not visible:
		return
	is_dead = true
	died.emit(self)
	
	# Skoru vuran oyuncuya yaz
	var killer = get_tree().current_scene.find_child(str(attacker_id), true, false)
	if killer and killer.has_method("record_kill"):
		killer.record_kill(is_headshot)
	
	# Küp parçalanma efektini doğur
	var gibs_scene = load(GIBS_SCENE_PATH)
	if gibs_scene:
		var gibs = gibs_scene.instantiate()
		gibs.position = global_position
		get_tree().current_scene.add_child(gibs)

	# Eşya Düşürme (Sadece Sunucu)
	if multiplayer.is_server():
		# Altın Düşüşü
		_spawn_pickup("gold", randi_range(6, 14), global_position)
		
		# Takımın en yüksek ganimet şansını hesapla
		var luck_bonus = 0.0
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if is_instance_valid(p):
				var p_luck = p.get("stat_drop_luck")
				if p_luck != null:
					luck_bonus = max(luck_bonus, float(p_luck))
		
		# Dengeli Düşüş Oranları (Taban ~%15, Şans Kartı ile artar)
		var base_chance = 0.15 * (1.0 + luck_bonus)
		var roll = randf()
		if roll < base_chance:
			var w_roll = randf()
			if w_roll < 0.35:
				_spawn_pickup("shotgun", 12, global_position + Vector3(0.4, 0, 0.4))
			elif w_roll < 0.65:
				_spawn_pickup("uzi", 60, global_position + Vector3(0.4, 0, 0.4))
			elif w_roll < 0.90:
				_spawn_pickup("bixi", 80, global_position + Vector3(0.4, 0, 0.4))
			else:
				_spawn_pickup("rocket", 3, global_position + Vector3(0.4, 0, 0.4))
		elif roll < base_chance + 0.05:
			_spawn_pickup("barrel", 1, global_position + Vector3(-0.4, 0, 0.4))
		elif roll < base_chance + 0.10:
			_spawn_pickup("health", 25, global_position + Vector3(0.4, 0, -0.4))
		
		queue_free()
	else:
		visible = false
		collision_layer = 0

func _spawn_pickup(p_type: String, p_amount: int, pos: Vector3) -> void:
	var scene = load(PICKUP_SCENE_PATH)
	if scene:
		var item = scene.instantiate()
		item.pickup_type = p_type
		item.amount = p_amount
		item.position = pos
		get_tree().current_scene.add_child(item, true)

static var freeze_mat: StandardMaterial3D = null

static func _get_freeze_mat() -> StandardMaterial3D:
	if freeze_mat == null:
		freeze_mat = StandardMaterial3D.new()
		freeze_mat.albedo_color = Color(0.35, 0.75, 1.0, 1.0)
		freeze_mat.emission_enabled = true
		freeze_mat.emission = Color(0.2, 0.5, 0.9, 1.0)
		freeze_mat.emission_energy_multiplier = 1.0
	return freeze_mat

## Dondurma Fonksiyonu (Paladin Buz Kristali Büyüsü)
func freeze(duration: float = 4.0) -> void:
	if not multiplayer.is_server():
		return
	_apply_freeze.rpc(duration)

@rpc("call_local", "reliable")
func _apply_freeze(duration: float) -> void:
	is_frozen = true
	var b_mesh = $Visuals/BodyMesh
	if b_mesh: b_mesh.material_override = _get_freeze_mat()
	await get_tree().create_timer(duration).timeout
	is_frozen = false
	if is_instance_valid(self):
		if b_mesh and b_mesh.material_override == _get_freeze_mat():
			b_mesh.material_override = null

## Yavaşlatma Fonksiyonu (Buz Muhafızı Kriyojenik Zemin)
func apply_slow(factor: float = 0.4, duration: float = 1.0) -> void:
	slow_factor = min(slow_factor, factor)
	slow_timer = max(slow_timer, duration)
