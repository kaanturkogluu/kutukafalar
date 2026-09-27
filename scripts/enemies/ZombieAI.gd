extends CharacterBody3D

# --- Beyaz Kutu Zombi Yapay Zekası ---
signal died(zombie_ref)

@export var max_health: float = 100.0
@export var speed: float = 4.4
@export var attack_damage: float = 15.0
@export var attack_rate: float = 0.8
@export var zombie_type: String = "normal"

var current_health: float
var attack_timer: float = 0.0
var target_player: Node3D = null
var is_frozen: bool = false
var stun_timer: float = 0.0
var is_stunned: bool = false
var is_dead: bool = false
var is_exploding: bool = false
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var growl_timer: float = randf_range(3.0, 7.0)

const GIBS_SCENE_PATH = "res://scenes/effects/cube_gibs.tscn"

@onready var anim_mesh: Node3D = $Visuals
@onready var hips_node: Node3D = get_node_or_null("Visuals/Hips")
@onready var torso_node: Node3D = get_node_or_null("Visuals/Hips/Torso")
@onready var head_node: Node3D = get_node_or_null("Visuals/Hips/Torso/Neck/Head")
@onready var jaw_node: Node3D = get_node_or_null("Visuals/Hips/Torso/Neck/Head/JawPivot")
@onready var arm_l_node: Node3D = get_node_or_null("Visuals/Hips/Torso/ArmL")
@onready var arm_r_node: Node3D = get_node_or_null("Visuals/Hips/Torso/ArmR")
@onready var leg_l_node: Node3D = get_node_or_null("Visuals/Hips/LegL")
@onready var leg_r_node: Node3D = get_node_or_null("Visuals/Hips/LegR")

var anim_phase: float = 0.0
var last_anim_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	last_anim_pos = global_position
	anim_phase = randf_range(0.0, TAU)
	if zombie_type != "normal" and zombie_type != "boss":
		setup_type(zombie_type)

func _process(delta: float) -> void:
	_animate_limbs(delta)

func _animate_limbs(delta: float) -> void:
	if not hips_node or is_dead:
		return
	
	var is_moving = false
	var horiz_vel = Vector2(velocity.x, velocity.z).length()
	if horiz_vel > 0.15:
		is_moving = true
	else:
		var moved_dist = Vector2(global_position.x - last_anim_pos.x, global_position.z - last_anim_pos.z).length()
		if moved_dist > 0.008:
			is_moving = true
	
	last_anim_pos = global_position
	
	if is_moving and not is_frozen:
		anim_phase += delta * (speed * 1.5)
		var swing = sin(anim_phase)
		
		# Bacak yürüyüş salınımı
		if leg_l_node:
			leg_l_node.rotation.x = 0.3 + swing * 0.45
		if leg_r_node:
			leg_r_node.rotation.x = -0.15 - swing * 0.45
		
		# Gövde ve kafa zombi sendelemesi (shamble / limp)
		if torso_node:
			torso_node.rotation.z = sin(anim_phase * 0.5) * 0.07
			torso_node.rotation.x = 0.34 + abs(swing) * 0.04
		if head_node:
			head_node.rotation.y = sin(anim_phase * 0.5) * 0.08
			head_node.rotation.x = -0.17 + cos(anim_phase) * 0.04
		
		# Kollar öne uzanmış pençelerle sendeleyerek sallanır
		if arm_l_node:
			arm_l_node.rotation.x = -0.7 + swing * 0.16
		if arm_r_node:
			arm_r_node.rotation.x = -0.74 - swing * 0.16
		
		# Ağız ürpertici şekilde açılıp seğirir
		if jaw_node:
			jaw_node.rotation.x = -0.34 + sin(anim_phase * 1.2) * 0.1
	else:
		# Boşta (Idle) - Ürpertici nefes alıp verme ve çene seğirmesi
		anim_phase += delta * 2.0
		var breath = sin(anim_phase)
		if torso_node:
			torso_node.rotation.x = 0.34 + breath * 0.03
			torso_node.rotation.z = 0.0
		if head_node:
			head_node.rotation.x = -0.17 + breath * 0.02
		if jaw_node:
			jaw_node.rotation.x = -0.34 + breath * 0.04
		if leg_l_node:
			leg_l_node.rotation.x = 0.30
		if leg_r_node:
			leg_r_node.rotation.x = -0.17

func _physics_process(delta: float) -> void:
	# Yerçekimi
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Zombi yapay zekası SADECE sunucu (Host) tarafından hesaplanır
	if not multiplayer.is_server():
		move_and_slide()
		return

	if is_frozen or stun_timer > 0:
		if stun_timer > 0:
			stun_timer -= delta
			if stun_timer <= 0:
				is_stunned = false
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
		move_and_slide()
		return

	attack_timer -= delta
	growl_timer -= delta
	if growl_timer <= 0:
		growl_timer = randf_range(7.0, 16.0)
		if target_player and is_instance_valid(target_player) and global_position.distance_to(target_player.global_position) < 22.0:
			SoundManager.play_3d_sfx("zombie_growl", global_position, 0.18, -6.0)

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

		# Patlayıcı Zombi (Boomer): Oyuncunun dibine ulaştığında kendini patlatır!
		if zombie_type == "boomer" and distance <= 2.2:
			_detonate_boomer()
			return

		if distance > 1.7 or vert_diff > 1.9:
			# Zombi havadaysa veya oyuncudan çok uzaktaysa yaklaşmalı
			var direction = diff.normalized()
			
			# Barikat Duvarı Kontrolü (Zombiler duvara vurup kırabilir)
			var blocking_wall = _check_blocking_wall(direction)
			if blocking_wall and is_instance_valid(blocking_wall):
				velocity.x = 0
				velocity.z = 0
				if attack_timer <= 0:
					_attack_wall(blocking_wall)
					attack_timer = attack_rate
				move_and_slide()
				return

			# Engel ve kaldırım tırmanma (Kaldırımlardan ve alçak engellerden zıplama)
			if is_on_floor() and is_on_wall() and (target_player.global_position.y >= global_position.y - 0.2):
				velocity.y = 3.4

			# Duvarlara ve ev köşelerine takılmayı engelleme (Wall Slide & Obstacle Deflection)
			if is_on_wall():
				var wall_n = get_wall_normal()
				var slide_dir = direction.slide(wall_n).normalized()
				if slide_dir.length_squared() > 0.05:
					direction = slide_dir
				else:
					var to_center = (Vector3.ZERO - global_position).normalized()
					to_center.y = 0
					var side_vec = Vector3(-wall_n.z, 0, wall_n.x)
					if side_vec.dot(to_center) < 0:
						side_vec = -side_vec
					direction = (to_center * 0.6 + side_vec * 0.8).normalized()

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
	var potential_targets: Array[Node3D] = []
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and not p.get("is_dead"):
			potential_targets.append(p)
	var turrets = get_tree().get_nodes_in_group("turrets")
	for t in turrets:
		if is_instance_valid(t) and not t.get("is_destroyed"):
			potential_targets.append(t)

	if potential_targets.is_empty():
		target_player = null
		return

	var closest_dist = INF
	var closest: Node3D = null
	for t in potential_targets:
		var d = global_position.distance_to(t.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = t
	target_player = closest

func _attack_player(target: Node3D) -> void:
	if is_dead:
		return
	if is_instance_valid(target) and target.has_method("take_damage") and not target.get("is_dead"):
		target.take_damage(attack_damage)
		_trigger_attack_anim.rpc()

func _check_blocking_wall(dir: Vector3) -> Node:
	if is_on_wall():
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var collider = col.get_collider()
			if collider and collider.is_in_group("walls") and not collider.get("is_destroyed"):
				return collider
	var space = get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.7, global_position + Vector3.UP * 0.7 + dir * 1.4, 1)
	var res = space.intersect_ray(ray)
	if res and res.collider and res.collider.is_in_group("walls") and not res.collider.get("is_destroyed"):
		return res.collider
	return null

func _attack_wall(wall: Node) -> void:
	if is_dead:
		return
	if is_instance_valid(wall) and wall.has_method("take_damage"):
		wall.take_damage(attack_damage)
		_trigger_attack_anim.rpc()

@rpc("call_local", "unreliable")
func _trigger_attack_anim() -> void:
	SoundManager.play_3d_sfx("zombie_attack", global_position, 0.1, -1.0)
	if torso_node:
		var tw = create_tween()
		tw.tween_property(torso_node, "rotation:x", 0.52, 0.08)
		if jaw_node:
			tw.parallel().tween_property(jaw_node, "rotation:x", -0.55, 0.08)
		tw.tween_property(torso_node, "rotation:x", 0.34, 0.16)
		if jaw_node:
			tw.parallel().tween_property(jaw_node, "rotation:x", -0.34, 0.16)

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
	SoundManager.play_3d_sfx("zombie_hurt", global_position, 0.12, -3.5)
	var meshes = find_children("*", "MeshInstance3D")
	var h_mat = _get_zombie_hurt_mat()
	for m in meshes:
		m.material_override = h_mat
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self):
		for m in meshes:
			if is_instance_valid(m) and m.material_override == h_mat:
				m.material_override = null

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
	SoundManager.play_3d_sfx("zombie_die", global_position, 0.12, -2.0)
	if is_dead and not multiplayer.is_server() and not visible:
		return
	is_dead = true
	died.emit(self)

	# Zombi Türü Özel Efektleri
	if zombie_type == "toxic":
		_toxic_burst()
	elif zombie_type == "boomer" and not is_exploding:
		_trigger_boomer_explosion.rpc()
	
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
			# Yalnızca mağazadan Altın ile kilidi açılmış silahlar düşer
			var unlocked_pool: Array[String] = []
			for w in SaveManager.get_unlocked_weapons():
				if w != "pistol":
					unlocked_pool.append(w)
			
			if not unlocked_pool.is_empty():
				var chosen_w = unlocked_pool.pick_random()
				match chosen_w:
					"shotgun":
						_spawn_pickup("shotgun", 12, global_position + Vector3(0.4, 0, 0.4))
					"uzi":
						_spawn_pickup("uzi", 60, global_position + Vector3(0.4, 0, 0.4))
					"bixi":
						_spawn_pickup("bixi", 80, global_position + Vector3(0.4, 0, 0.4))
					"rocket":
						_spawn_pickup("rocket", 3, global_position + Vector3(0.4, 0, 0.4))
			else:
				# Henüz mağazadan özel silah kilidi açılmadıysa ekstra altın bırakır
				_spawn_pickup("gold", randi_range(10, 20), global_position + Vector3(0.4, 0, 0.4))
		elif roll < base_chance + 0.05:
			_spawn_pickup("barrel", 1, global_position + Vector3(-0.4, 0, 0.4))
		elif roll < base_chance + 0.10:
			_spawn_pickup("health", 25, global_position + Vector3(0.4, 0, -0.4))
		
		queue_free()
	else:
		visible = false
		collision_layer = 0

func _spawn_pickup(p_type: String, p_amount: int, pos: Vector3) -> void:
	var main_level = get_tree().get_first_node_in_group("main_level")
	if not main_level:
		main_level = get_tree().current_scene
	if main_level and main_level.has_method("spawn_pickup"):
		main_level.spawn_pickup(p_type, p_amount, pos)
	else:
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
	var meshes = find_children("*", "MeshInstance3D")
	var f_mat = _get_freeze_mat()
	for m in meshes:
		m.material_override = f_mat
	await get_tree().create_timer(duration).timeout
	is_frozen = false
	if is_instance_valid(self):
		for m in meshes:
			if is_instance_valid(m) and m.material_override == f_mat:
				m.material_override = null

## Yavaşlatma Fonksiyonu (Buz Muhafızı Kriyojenik Zemin)
func apply_slow(factor: float = 0.4, duration: float = 1.0) -> void:
	slow_factor = min(slow_factor, factor)
	slow_timer = max(slow_timer, duration)

static var stun_mat: StandardMaterial3D = null

static func _get_stun_mat() -> StandardMaterial3D:
	if stun_mat == null:
		stun_mat = StandardMaterial3D.new()
		stun_mat.albedo_color = Color(1.0, 0.9, 0.25, 1.0)
		stun_mat.emission_enabled = true
		stun_mat.emission = Color(1.0, 0.85, 0.1, 1.0)
		stun_mat.emission_energy_multiplier = 1.8
	return stun_mat

## Sersemletme Fonksiyonu (Mühendis Şok Dalgası: 1.2 sn Stun)
func stun(duration: float = 1.2) -> void:
	if not multiplayer.is_server():
		return
	_apply_stun.rpc(duration)

@rpc("call_local", "reliable")
func _apply_stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)
	is_stunned = true
	var meshes = find_children("*", "MeshInstance3D")
	var s_mat = _get_stun_mat()
	for m in meshes:
		m.material_override = s_mat
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		if stun_timer <= 0.05:
			is_stunned = false
			for m in meshes:
				if is_instance_valid(m) and m.material_override == s_mat:
					m.material_override = null

## Geri İtme (Knockback) Fonksiyonu (Şok Dalgası)
func apply_knockback(force: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_apply_knockback.rpc(force)

@rpc("call_local", "reliable")
func _apply_knockback(force: Vector3) -> void:
	velocity += force

# --- Zombi Türleri ve Boss Özelleştirme Mantığı ---

func setup_type(type_name: String) -> void:
	zombie_type = type_name
	match type_name:
		"runner":
			speed = speed * 1.45
			max_health = max_health * 0.72
			current_health = max_health
			attack_damage = 12.0
			scale = Vector3(0.85, 0.9, 0.85)
			_tint_zombie(Color(0.85, 0.45, 0.25), Color(1.0, 0.35, 0.05))
		"tank":
			speed = max(2.6, speed * 0.70)
			max_health = max_health * 2.6
			current_health = max_health
			attack_damage = 32.0
			scale = Vector3(1.35, 1.35, 1.35)
			_tint_zombie(Color(0.25, 0.28, 0.3), Color(0.85, 0.15, 0.15))
		"toxic":
			speed = speed * 0.95
			max_health = max_health * 1.15
			current_health = max_health
			_tint_zombie(Color(0.25, 0.65, 0.25), Color(0.2, 1.0, 0.25))
		"boomer":
			speed = speed * 1.25
			max_health = max_health * 0.65
			current_health = max_health
			_tint_zombie(Color(0.85, 0.22, 0.15), Color(1.0, 0.7, 0.1), true)

func _tint_zombie(body_color: Color, eye_color: Color, is_pulsing: bool = false) -> void:
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mat.roughness = 0.7
	if is_pulsing:
		body_mat.emission_enabled = true
		body_mat.emission = Color(1.0, 0.2, 0.1)
		body_mat.emission_energy_multiplier = 1.6

	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = eye_color
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_color
	eye_mat.emission_energy_multiplier = 4.0

	var meshes = find_children("*", "MeshInstance3D")
	for m in meshes:
		if "Pupil" in m.name or "Eye" in m.name:
			m.material_override = eye_mat
		elif "Torso" in m.name or "Head" in m.name:
			m.material_override = body_mat

func setup_boss_sector(sector_num: int) -> void:
	zombie_type = "boss"
	var boss_scale = 1.35 + (sector_num * 0.08)
	if sector_num == 11:
		boss_scale = 2.2 # Nihai Kat 99 Kutu Şah!
	scale = Vector3(boss_scale, boss_scale, boss_scale)
	
	match sector_num:
		1:
			_tint_zombie(Color(0.7, 0.15, 0.15), Color(1.0, 0.1, 0.1))
		2:
			_tint_zombie(Color(0.45, 0.35, 0.25), Color(1.0, 0.4, 0.0))
		3:
			_tint_zombie(Color(0.65, 0.1, 0.2), Color(1.0, 0.1, 0.1))
		4:
			_tint_zombie(Color(0.2, 0.22, 0.28), Color(0.3, 0.6, 1.0))
		5:
			_tint_zombie(Color(0.15, 0.25, 0.45), Color(0.1, 0.9, 1.0))
		6:
			_tint_zombie(Color(0.8, 0.85, 0.8), Color(0.2, 1.0, 0.4))
		7:
			_tint_zombie(Color(0.85, 0.72, 0.2), Color(1.0, 0.9, 0.2))
		8:
			_tint_zombie(Color(0.2, 0.45, 0.15), Color(0.4, 1.0, 0.2))
		9:
			_tint_zombie(Color(0.1, 0.5, 0.5), Color(0.1, 1.0, 0.8))
		10:
			_tint_zombie(Color(0.28, 0.34, 0.22), Color(1.0, 0.2, 0.1))
		11:
			_tint_zombie(Color(0.08, 0.08, 0.1), Color(1.0, 0.05, 0.05), true)

func _detonate_boomer() -> void:
	if is_exploding or is_dead:
		return
	is_exploding = true
	is_dead = true
	_trigger_boomer_explosion.rpc()
	
	if multiplayer.is_server():
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if is_instance_valid(p) and not p.get("is_dead"):
				var dist = global_position.distance_to(p.global_position)
				if dist < 5.5:
					var dmg = lerp(45.0, 10.0, dist / 5.5)
					p.take_damage(dmg)
		_die.rpc(false, 1)

@rpc("call_local", "unreliable")
func _trigger_boomer_explosion() -> void:
	SoundManager.play_3d_sfx("barrel_explode", global_position, 0.15, 0.0)

func _toxic_burst() -> void:
	if multiplayer.is_server():
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if is_instance_valid(p) and not p.get("is_dead"):
				if global_position.distance_to(p.global_position) < 4.0:
					p.take_damage(18.0)
