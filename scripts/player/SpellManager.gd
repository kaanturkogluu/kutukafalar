extends Node

# --- Gelişmiş Büyü ve 4 Sınıf Yöneticisi (SpellManager) ---
signal spell_updated(tactical_percent: float, ult_percent: float)

@export var tactical_cooldown: float = 14.0 # 14 saniye bekleme süresi (Kıymetli ve stratejik!)
var tactical_timer: float = 0.0
var ultimate_charge: float = 0.0 # Başlangıç %0
const MAX_ULTIMATE: float = 100.0

var player_class: String = "Pyromancer"
var player: CharacterBody3D

# Büyü Sahneleri
const FIRE_WAVE_PATH = "res://scenes/spells/fire_wave.tscn"
const METEOR_PATH = "res://scenes/spells/meteor.tscn"
const THROWN_VORTEX_PATH = "res://scenes/spells/thrown_vortex.tscn"
const THROWN_FROST_PATH = "res://scenes/spells/thrown_frost.tscn"
const THROWN_HEAL_PATH = "res://scenes/spells/thrown_heal.tscn"

func setup(p_player: CharacterBody3D, p_class: String = "Pyromancer") -> void:
	player = p_player
	player_class = p_class
	ultimate_charge = 0.0 # Sıfırdan başlar, hak edilmesi gerekir!
	if player_class == "Engineer":
		tactical_cooldown = 25.0
	else:
		tactical_cooldown = 14.0

func _process(delta: float) -> void:
	if not player or not player.is_multiplayer_authority():
		return
	if player.get("is_dead") or player.get("is_in_shop") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if tactical_timer > 0:
		tactical_timer -= delta

	if Input.is_action_just_pressed("spell_tactical"):
		if player and player.has_method("is_targeting_downed_teammate") and player.is_targeting_downed_teammate():
			pass
		elif player_class == "Builder":
			if player and player.has_method("try_place_wall"):
				player.try_place_wall()
		elif player_class == "Engineer":
			cast_engineer_turret()
		else:
			cast_tactical()

	if Input.is_action_just_pressed("spell_ultimate"):
		cast_ultimate()

	var tac_pct = clamp(1.0 - (tactical_timer / tactical_cooldown), 0.0, 1.0)
	spell_updated.emit(tac_pct, ultimate_charge)

## Düşman öldüğünde Ulti şarjını dengeli artır (~40 kill ile 1 ulti açılır)
func add_ultimate_charge(amount: float = 2.5) -> void:
	var mult = ProgressionManager.get_stat("ult_charge_mult", 1.0)
	ultimate_charge = clamp(ultimate_charge + (amount * mult), 0.0, MAX_ULTIMATE)

## Mühendis: Otomatik Taret Yerleştirme (25 sn Cooldown, Sadece Düz Zemin)
func cast_engineer_turret() -> void:
	if tactical_timer > 0:
		return
	if not player or not is_instance_valid(player):
		return
	
	# Zemin Kontrolü (Sadece düz zemine yerleşir!)
	var space = player.get_world_3d().direct_space_state
	var cam = player.get_node_or_null("Head/Camera3D")
	var cam_forward = -cam.global_transform.basis.z if cam else -player.transform.basis.z
	
	# Kameradan ileri ve aşağıya doğru raycast
	var from_pos = cam.global_position if cam else (player.global_position + Vector3.UP * 1.5)
	var to_pos = from_pos + cam_forward * 6.0
	
	var ray = PhysicsRayQueryParameters3D.create(from_pos, to_pos, 1)
	var hit = space.intersect_ray(ray)
	
	var valid_floor_point: Vector3 = Vector3.ZERO
	var has_valid_ground: bool = false
	
	if hit and hit.collider:
		if hit.normal.dot(Vector3.UP) >= 0.70:
			valid_floor_point = hit.position
			has_valid_ground = true
	
	# Eğer kamera doğrudan zemine çarpmadıysa, oyuncunun 2.2m önüne aşağı doğru bak
	if not has_valid_ground:
		var check_pos = player.global_position - player.transform.basis.z * 2.2 + Vector3.UP * 0.5
		var down_ray = PhysicsRayQueryParameters3D.create(check_pos, check_pos + Vector3.DOWN * 2.5, 1)
		var down_hit = space.intersect_ray(down_ray)
		if down_hit and down_hit.collider and down_hit.normal.dot(Vector3.UP) >= 0.70:
			valid_floor_point = down_hit.position
			has_valid_ground = true

	if not has_valid_ground:
		SoundManager.play_sfx("empty")
		if player.has_method("_show_weapon_notice"):
			player._show_weapon_notice("⚠️ TARET SADECE DÜZ ZEMİNE YERLEŞTİRİLEBİLİR!")
		return
	
	# Cooldown başlat (25 sn)
	var cd_red = ProgressionManager.get_stat("tactical_cooldown_reduction", 0.0)
	tactical_timer = max(6.0, tactical_cooldown - cd_red)
	
	SoundManager.play_sfx("switch")
	if player.has_method("_show_weapon_notice"):
		player._show_weapon_notice("🎯 OTOMATİK TARET KURULDU! (25 sn)")
	
	# Sunucuda taret oluştur
	_request_spawn_turret.rpc_id(1, valid_floor_point, player.rotation.y)

@rpc("any_peer", "call_local", "reliable")
func _request_spawn_turret(pos: Vector3, rot_y: float) -> void:
	if multiplayer.is_server():
		var main_level = player.get_tree().current_scene
		if main_level and main_level.has_method("spawn_turret"):
			main_level.spawn_turret(pos, rot_y)

## [E] Taktiksel Büyü (Fırlatılabilir Proje Mekaniği)
func cast_tactical() -> void:
	if tactical_timer > 0:
		return
	var cd_red = ProgressionManager.get_stat("tactical_cooldown_reduction", 0.0)
	tactical_timer = max(4.0, tactical_cooldown - cd_red)

	var cam = player.get_node_or_null("Head/Camera3D")
	var forward = -player.transform.basis.z
	if cam:
		forward = -cam.global_transform.basis.z
	
	var throw_start = player.global_position + Vector3.UP * 1.4 + forward * 0.8

	match player_class:
		"Pyromancer":
			# Büyücü: İleriye doğru genişleyen alev dalgası
			_request_cast_spell.rpc_id(1, "fire_wave", throw_start, forward)
		"Cryomancer":
			# Buz Muhafızı: Fırlatılan Kriyojenik Dondurucu Bomba
			_request_cast_spell.rpc_id(1, "thrown_frost", throw_start, forward)
		"Medic":
			# Sıhhiye / Doktor: Fırlatılan İyileştirici Şifa Şişesi
			_request_cast_spell.rpc_id(1, "thrown_heal", throw_start, forward)
		_:
			_request_cast_spell.rpc_id(1, "fire_wave", throw_start, forward)

## [Q] Ultimate Büyü (Büyük Kurtarıcı Güçler)
func cast_ultimate() -> void:
	if ultimate_charge < MAX_ULTIMATE:
		return
	ultimate_charge = 0.0

	var shoot_ray = player.get_node_or_null("Head/Camera3D/ShootRay")
	var target_pos = player.global_position - player.transform.basis.z * 12.0
	if shoot_ray and shoot_ray.is_colliding():
		target_pos = shoot_ray.get_collision_point()

	match player_class:
		"Pyromancer":
			# Meteor: Hedefin gökyüzünden dev alevli küp düşer
			var meteor_start = target_pos + Vector3.UP * 22.0
			_request_cast_spell.rpc_id(1, "meteor", meteor_start, Vector3.DOWN, target_pos.y)
		"Builder":
			# Graviton EMP / Manyetik Vortex Blast: Hedef alandaki zombileri çeker ve patlatır
			_request_cast_spell.rpc_id(1, "emp_blast", target_pos, Vector3.ZERO)
		"Medic":
			# Adrenalin ve Toplu Şifa: Tüm takımı %100 cana getirir
			_request_cast_spell.rpc_id(1, "medic_overdrive", player.global_position, Vector3.ZERO)
		"Cryomancer":
			# Buz Fırtınası / Glacial Blast: Hedef alana devasa buz sarkıtları patlatır
			_request_cast_spell.rpc_id(1, "frost_storm", target_pos, Vector3.ZERO)
		"Engineer":
			# Elektriksel Şok Dalgası: Zombileri fırlatır ve 1.2 sn sersemletir
			_request_cast_spell.rpc_id(1, "shockwave", player.global_position, Vector3.ZERO)
		_:
			var meteor_start = target_pos + Vector3.UP * 22.0
			_request_cast_spell.rpc_id(1, "meteor", meteor_start, Vector3.DOWN, target_pos.y)

@rpc("any_peer", "call_local", "reliable")
func _request_cast_spell(spell_type: String, pos: Vector3, dir: Vector3, extra_y: float = 0.0) -> void:
	if not multiplayer.is_server():
		return

	var current_scene = player.get_tree().current_scene
	if current_scene and current_scene.has_method("sync_spawn_spell"):
		current_scene.sync_spawn_spell.rpc(spell_type, pos, dir, extra_y)
	
	if spell_type == "medic_overdrive":
		var players = player.get_tree().get_nodes_in_group("players")
		var p_container = player.get_tree().current_scene.find_child("Players", true, false)
		if p_container:
			for c in p_container.get_children():
				if c is CharacterBody3D and not players.has(c):
					players.append(c)

		var revived_count = 0
		for p in players:
			if is_instance_valid(p):
				if p.get("is_dead"):
					p.revive.rpc(p.max_health, p.global_position)
					revived_count += 1
				elif p.has_method("heal"):
					p.heal(p.max_health)
				elif p.has_method("take_damage"):
					p.current_health = p.max_health
					p._update_hud()
		print("[Sıhhiye Ulti] Tüm takımın canı yenilendi! Canlandırılan ölü takım arkadaşı sayısı: ", revived_count)
