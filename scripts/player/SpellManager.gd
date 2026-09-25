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

func _process(delta: float) -> void:
	if not player or not player.is_multiplayer_authority():
		return
	if player.get("is_dead") or player.get("is_in_shop") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if tactical_timer > 0:
		tactical_timer -= delta

	if Input.is_action_just_pressed("spell_tactical"):
		cast_tactical()

	if Input.is_action_just_pressed("spell_ultimate"):
		cast_ultimate()

	var tac_pct = clamp(1.0 - (tactical_timer / tactical_cooldown), 0.0, 1.0)
	spell_updated.emit(tac_pct, ultimate_charge)

## Düşman öldüğünde Ulti şarjını dengeli artır (~40 kill ile 1 ulti açılır)
func add_ultimate_charge(amount: float = 2.5) -> void:
	ultimate_charge = clamp(ultimate_charge + amount, 0.0, MAX_ULTIMATE)

## [E] Taktiksel Büyü (Fırlatılabilir Proje Mekaniği)
func cast_tactical() -> void:
	if tactical_timer > 0:
		return
	tactical_timer = tactical_cooldown

	var cam = player.get_node_or_null("Head/Camera3D")
	var forward = -player.transform.basis.z
	if cam:
		forward = -cam.global_transform.basis.z
	
	var throw_start = player.global_position + Vector3.UP * 1.4 + forward * 0.8

	match player_class:
		"Pyromancer":
			# Büyücü: İleriye doğru genişleyen alev dalgası
			_request_cast_spell.rpc_id(1, "fire_wave", throw_start, forward)
		"Engineer":
			# Mühendis: Fırlatılan Manyetik Vortex Bombası
			_request_cast_spell.rpc_id(1, "thrown_vortex", throw_start, forward)
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
		"Medic":
			# Adrenalin ve Toplu Şifa: Tüm takımı %100 cana getirir
			_request_cast_spell.rpc_id(1, "medic_overdrive", player.global_position, Vector3.ZERO)
		"Cryomancer":
			# Küresel Buzul Fırtınası: Haritadaki tüm zombileri dondurur
			_request_cast_spell.rpc_id(1, "blizzard", player.global_position, Vector3.ZERO)
		"Engineer":
			# İkiz Manyetik Vortex Alanı
			_request_cast_spell.rpc_id(1, "thrown_vortex", target_pos, Vector3.ZERO)
		_:
			var meteor_start = target_pos + Vector3.UP * 22.0
			_request_cast_spell.rpc_id(1, "meteor", meteor_start, Vector3.DOWN, target_pos.y)

@rpc("any_peer", "call_local", "reliable")
func _request_cast_spell(spell_type: String, pos: Vector3, dir: Vector3, extra_y: float = 0.0) -> void:
	if not multiplayer.is_server():
		return

	var current_scene = player.get_tree().current_scene
	var spell_instance = null

	match spell_type:
		"fire_wave":
			var scene = load(FIRE_WAVE_PATH)
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
				spell_instance.direction = dir
				spell_instance.look_at(pos + dir, Vector3.UP)
		"thrown_vortex":
			var scene = load(THROWN_VORTEX_PATH)
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
				spell_instance.setup(dir)
		"thrown_frost":
			var scene = load(THROWN_FROST_PATH)
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
				spell_instance.setup(dir)
		"thrown_heal":
			var scene = load(THROWN_HEAL_PATH)
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
				spell_instance.setup(dir)
		"meteor":
			var scene = load(METEOR_PATH)
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
				spell_instance.target_y = extra_y
		"medic_overdrive":
			# Tüm oyuncuların canını yenile
			var players = player.get_tree().get_nodes_in_group("players")
			for p in players:
				if p.has_method("take_damage"):
					p.current_health = p.max_health
					p._update_hud()
			print("[Sıhhiye Ulti] Tüm takımın canı tamamen dolduruldu!")
		"blizzard":
			# Tüm zombileri 6 saniyeliğine dondur
			var enemies = player.get_tree().get_nodes_in_group("enemies")
			for e in enemies:
				if e.has_method("freeze"):
					e.freeze(6.0)
			print("[Buz Muhafızı Ulti] Tüm haritadaki zombiler donduruldu!")

	if spell_instance:
		current_scene.add_child(spell_instance, true)
