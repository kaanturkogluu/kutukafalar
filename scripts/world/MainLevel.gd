extends Node3D

# --- Ana Oyun Seviyesi, Çok Oyunculu Doğurma, Asansör ve Kat İlerlemesi ---
const PLAYER_SCENE_PATH: String = "res://scenes/player/player.tscn"
const ZOMBIE_SCENE_PATH: String = "res://scenes/enemies/zombie.tscn"
const BARREL_SCENE_PATH: String = "res://scenes/interactables/barrel_red.tscn"
const PICKUP_SCENE_PATH: String = "res://scenes/interactables/pickup.tscn"

@onready var players_container: Node3D = $Players
@onready var enemies_container: Node3D = $Enemies
@onready var barrels_container: Node3D = $Barrels
@onready var elevator: Node3D = $Elevator
@onready var shop_ui: CanvasLayer = $ShopUI
@onready var default_camera: Camera3D = $DefaultCamera

@onready var spawn_points: Array[Node] = $SpawnPoints.get_children()
@onready var zombie_spawn_points: Array[Node] = $ZombieSpawnPoints.get_children()

# Kat ve Dalga Değişkenleri
var current_floor: int = 1
var current_wave: int = 1
const WAVES_PER_FLOOR: int = 3

var zombies_remaining_to_spawn: int = 0
var active_zombie_count: int = 0
var zombie_id_counter: int = 0
var barrel_id_counter: int = 0
var wave_loop_token: int = 0
var initial_barrels_spawned: bool = false
var peers_ready: Dictionary = {}
var is_wave_in_progress: bool = false

@onready var floor_label: Label = $WaveUI/WaveInfo/FloorLabel
@onready var wave_label: Label = $WaveUI/WaveInfo/WaveLabel
@onready var enemies_label: Label = $WaveUI/WaveInfo/EnemiesLabel

func _ready() -> void:
	if elevator:
		elevator.players_entered_elevator.connect(_on_players_entered_elevator)
	if shop_ui:
		shop_ui.next_floor_requested.connect(_on_next_floor_requested)

	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	if multiplayer.is_server():
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)

	# Seviye yüklendiğinde sunucuya hazır olduğumuzu bildir (Host ve tüm Client'lar)
	_notify_peer_level_ready.rpc_id(1, multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func _notify_peer_level_ready(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[MainLevel] Seviyeye giriş yapan oyuncu hazır: ", peer_id)
	peers_ready[peer_id] = true
	
	# 1) Bu oyuncuya sahnede zaten mevcut olan TÜM oyuncuları doğurt:
	for existing_player in players_container.get_children():
		var p_id = existing_player.name.to_int()
		sync_spawn_player.rpc_id(peer_id, p_id, existing_player.position)
	
	# 2) Bu yeni oyuncunun kendi karakterini doğur ve HERKESE bildir:
	if not players_container.has_node(str(peer_id)):
		var spawn_pos = _get_spawn_position(peer_id)
		sync_spawn_player.rpc(peer_id, spawn_pos)
	
	# 3) Sahnede zaten mevcut olan varilleri bu oyuncuya doğurt:
	for existing_barrel in barrels_container.get_children():
		sync_spawn_barrel.rpc_id(peer_id, existing_barrel.name, existing_barrel.position)
		
	# 4) Sahnede zaten mevcut olan zombileri bu oyuncuya doğurt:
	for existing_zombie in enemies_container.get_children():
		var speed_val: float = 3.6
		if "speed" in existing_zombie and existing_zombie.speed != null:
			speed_val = float(existing_zombie.speed)
		var hp_val: float = 100.0
		if "current_health" in existing_zombie and existing_zombie.current_health != null:
			hp_val = float(existing_zombie.current_health)
		sync_spawn_zombie.rpc_id(peer_id, existing_zombie.name, existing_zombie.global_position, speed_val, hp_val)
	
	# 5) Güncel dalga/kat durumunu bildir:
	_sync_floor_ui.rpc_id(peer_id, current_floor, current_wave, active_zombie_count + zombies_remaining_to_spawn)
	
	# Eğer host hazırsa ve başlangıç varilleri konmadıysa koy:
	if peer_id == 1 and not initial_barrels_spawned:
		initial_barrels_spawned = true
		_spawn_initial_barrels()
		
		# 2 saniye sonra 1. Dalgayı Başlat
		get_tree().create_timer(2.0).timeout.connect(func():
			if current_wave == 1 and current_floor == 1 and not is_wave_in_progress:
				_start_next_wave()
		)

func _get_spawn_position(peer_id: int) -> Vector3:
	if spawn_points.size() > 0:
		var idx = 0
		if peer_id != 1:
			idx = peer_id % spawn_points.size()
		return spawn_points[idx % spawn_points.size()].global_position
	return Vector3(0, 1.5, 0)

@rpc("call_local", "reliable")
func sync_spawn_player(id: int, spawn_pos: Vector3) -> void:
	if players_container.has_node(str(id)):
		return
	
	var player_scene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		return
	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = spawn_pos
	player.player_died.connect(_on_player_died.bind(player))
	players_container.add_child(player, true)
	print("[MainLevel] Oyuncu doğuruldu: ", id, " (Yerel mi: ", id == multiplayer.get_unique_id(), ")")

func spawn_player(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players_container.has_node(str(id)):
		return
	var spawn_pos = _get_spawn_position(id)
	sync_spawn_player.rpc(id, spawn_pos)

func _spawn_initial_barrels() -> void:
	var initial_positions = [
		Vector3(-6, 0.5, -6),
		Vector3(6, 0.5, -6),
		Vector3(-6, 0.5, 6),
		Vector3(6, 0.5, 6),
		Vector3(0, 0.5, 0)
	]
	for pos in initial_positions:
		spawn_barrel(pos)

@rpc("call_local", "reliable")
func sync_spawn_barrel(b_name: String, pos: Vector3) -> void:
	if barrels_container.has_node(b_name):
		return
	var barrel_scene = load(BARREL_SCENE_PATH)
	if barrel_scene:
		var barrel = barrel_scene.instantiate()
		barrel.name = b_name
		barrel.position = pos
		barrels_container.add_child(barrel, true)

func spawn_barrel(pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	barrel_id_counter += 1
	var b_name = "Barrel_" + str(barrel_id_counter)
	sync_spawn_barrel.rpc(b_name, pos)

func _on_player_connected(id: int, _info: Dictionary) -> void:
	if multiplayer.is_server():
		spawn_player(id)
		_sync_floor_ui.rpc(current_floor, current_wave, active_zombie_count + zombies_remaining_to_spawn)

func _on_player_disconnected(id: int) -> void:
	if multiplayer.is_server():
		sync_despawn_node.rpc("Players", str(id))
		get_tree().create_timer(0.1).timeout.connect(_check_all_players_dead)

func _on_server_disconnected() -> void:
	print("[MainLevel] Sunucu kapandı, ana menüye dönülüyor...")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")

# --- Zombi Dalga Mantığı ---

func _start_next_wave() -> void:
	if not multiplayer.is_server():
		return

	is_wave_in_progress = true
	wave_loop_token += 1
	var current_token = wave_loop_token
	zombies_remaining_to_spawn = 4 + (current_floor * 2) + (current_wave * 2)
	active_zombie_count = 0
	_sync_floor_ui.rpc(current_floor, current_wave, zombies_remaining_to_spawn)
	_spawn_zombie_loop(current_token)

func _spawn_zombie_loop(token: int) -> void:
	while zombies_remaining_to_spawn > 0:
		if not is_instance_valid(self) or token != wave_loop_token:
			return
		
		var spawn_delay = max(0.5, 1.2 - (current_floor * 0.08))
		await get_tree().create_timer(spawn_delay).timeout
		if token != wave_loop_token:
			return
		
		_spawn_single_zombie()
		zombies_remaining_to_spawn -= 1
		active_zombie_count += 1
		_sync_floor_ui.rpc(current_floor, current_wave, active_zombie_count + zombies_remaining_to_spawn)

@rpc("call_local", "reliable")
func sync_spawn_zombie(z_name: String, pos: Vector3, speed_val: float, hp_val: float) -> void:
	if enemies_container.has_node(z_name):
		return
	var zombie_scene = load(ZOMBIE_SCENE_PATH)
	if zombie_scene:
		var zombie = zombie_scene.instantiate()
		zombie.name = z_name
		zombie.position = pos
		zombie.speed = speed_val
		zombie.max_health = hp_val
		zombie.current_health = hp_val
		zombie.died.connect(_on_zombie_died)
		enemies_container.add_child(zombie, true)

func _spawn_single_zombie() -> void:
	zombie_id_counter += 1
	var z_name = "Zombie_" + str(zombie_id_counter)
	var speed_val = 3.6 + (current_floor * 0.2)
	var hp_val = 100.0 + (current_floor * 15.0)

	var spawn_pos = Vector3(randf_range(-10, 10), 1.5, randf_range(-10, 10))
	if zombie_spawn_points.size() > 0:
		spawn_pos = zombie_spawn_points.pick_random().global_position
	
	sync_spawn_zombie.rpc(z_name, spawn_pos, speed_val, hp_val)

@rpc("call_local", "reliable")
func sync_despawn_node(container_name: String, node_name: String) -> void:
	var container = get_node_or_null(container_name)
	if container:
		var n = container.get_node_or_null(node_name)
		if n and is_instance_valid(n):
			n.queue_free()

func _on_zombie_died(zombie_ref = null, _extra = null) -> void:
	if not multiplayer.is_server():
		return

	if zombie_ref and is_instance_valid(zombie_ref):
		sync_despawn_node.rpc("Enemies", zombie_ref.name)

	active_zombie_count = max(0, active_zombie_count - 1)
	_sync_floor_ui.rpc(current_floor, current_wave, active_zombie_count + zombies_remaining_to_spawn)

	if zombies_remaining_to_spawn <= 0 and active_zombie_count <= 0:
		is_wave_in_progress = false
		var token = wave_loop_token
		if current_wave < WAVES_PER_FLOOR:
			# Kat içindeki bir sonraki dalga
			current_wave += 1
			_announce_wave_cleared.rpc()
			await get_tree().create_timer(3.0).timeout
			if token == wave_loop_token:
				_start_next_wave()
		else:
			# KAT TAMAMEN TEMİZLENDİ! ASANSÖR AÇILIR!
			_on_floor_cleared()

func _on_floor_cleared() -> void:
	print("[Kat Tamamlandı] Kat ", current_floor, " temizlendi! Asansör kapıları açılıyor...")
	_announce_floor_cleared.rpc()
	elevator.set_elevator_state(true)

func _on_players_entered_elevator() -> void:
	if not multiplayer.is_server():
		return

	# Ölen oyuncuları asansörde yarım canla yeniden canlandır
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p.get("is_dead") or p.current_health <= 0:
			if p.has_method("revive"):
				p.revive.rpc(p.max_health * 0.5, elevator.global_position)
			print("[Asansör] Oyuncu yeniden canlandırıldı: ", p.name)

	# Mağazayı tüm oyunculara aç
	_open_shop_ui.rpc(current_floor)

@rpc("call_local", "reliable")
func _open_shop_ui(floor_num: int) -> void:
	# Yerel oyuncuyu bul
	var local_id = multiplayer.get_unique_id()
	var local_player = players_container.get_node_or_null(str(local_id))
	if local_player and shop_ui:
		shop_ui.open_shop(local_player, floor_num)

@rpc("call_local", "reliable")
func _close_shop_ui() -> void:
	if shop_ui:
		shop_ui.close_shop()

func _on_next_floor_requested() -> void:
	_request_next_floor.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _request_next_floor() -> void:
	if not multiplayer.is_server():
		return

	_close_shop_ui.rpc()

	current_floor += 1
	current_wave = 1
	elevator.set_elevator_state(false)

	# Oyuncuları asansörden doğuş noktalarına geri taşı
	var players = get_tree().get_nodes_in_group("players")
	for i in range(players.size()):
		var spawn_pt = spawn_points[i % spawn_points.size()]
		players[i].position = spawn_pt.global_position

	_sync_floor_ui.rpc(current_floor, current_wave, 0)
	print("[Yeni Kat] Kat ", current_floor, " başladı!")
	await get_tree().create_timer(3.0).timeout
	_start_next_wave()

@rpc("call_local", "reliable")
func _sync_floor_ui(floor_num: int, wave_num: int, remaining: int) -> void:
	if floor_label:
		floor_label.text = "🏢 KAT: " + str(floor_num)
	if wave_label:
		wave_label.text = "DALGA: " + str(wave_num) + " / " + str(WAVES_PER_FLOOR)
	if enemies_label:
		enemies_label.text = "KALAN DÜŞMAN: " + str(remaining)

@rpc("call_local", "reliable")
func _announce_wave_cleared() -> void:
	if enemies_label:
		enemies_label.text = "🎉 DALGA TEMİZLENDİ! HAZIRLANIN..."

@rpc("call_local", "reliable")
func _announce_floor_cleared() -> void:
	if enemies_label:
		enemies_label.text = "🏆 KAT TEMİZLENDİ! ASANSÖRE BİNİN! 🛗"

func _on_player_died(_player_node: Node) -> void:
	if not multiplayer.is_server():
		return
	_check_all_players_dead()

func _check_all_players_dead() -> void:
	if not multiplayer.is_server():
		return
	
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	
	var all_dead = true
	for p in players:
		if not p.get("is_dead"):
			all_dead = false
			break
	
	if all_dead:
		print("[MainLevel] Tüm takım elendi! Oyun Bitti.")
		_announce_game_over.rpc()

@rpc("call_local", "reliable")
func _announce_game_over() -> void:
	if enemies_label:
		enemies_label.text = "💀 OYUN BİTTİ! TÜM TAKIM ELENDİ 💀"
	
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p.has_method("set_all_players_dead"):
			p.set_all_players_dead()

func request_restart() -> void:
	if not multiplayer.is_server():
		_request_server_restart.rpc_id(1)
		return
	_restart_game()

@rpc("any_peer", "reliable")
func _request_server_restart() -> void:
	if multiplayer.is_server():
		_restart_game()

func _restart_game() -> void:
	print("[MainLevel] Oyun sıfırlanıyor ve baştan başlatılıyor...")
	wave_loop_token += 1
	current_floor = 1
	current_wave = 1
	active_zombie_count = 0
	zombies_remaining_to_spawn = 0
	
	_close_shop_ui.rpc()
	sync_clear_all_entities.rpc()
	
	# Başlangıç varillerini yeniden doğur
	_spawn_initial_barrels()
	
	# Tüm oyuncuları doğuş noktalarında canlandır ve envanterlerini sıfırla
	var players = get_tree().get_nodes_in_group("players")
	for i in range(players.size()):
		var p = players[i]
		var spawn_pos = spawn_points[i % spawn_points.size()].global_position if spawn_points.size() > 0 else Vector3(0, 1.5, 0)
		if p.has_method("reset_to_default_loadout"):
			p.reset_to_default_loadout.rpc(spawn_pos)
		elif p.has_method("revive"):
			p.revive.rpc(p.max_health, spawn_pos)
	
	elevator.set_elevator_state(false)
	_sync_floor_ui.rpc(current_floor, current_wave, 0)
	await get_tree().create_timer(1.8).timeout
	_start_next_wave()

@rpc("call_local", "reliable")
func sync_clear_all_entities() -> void:
	for child in enemies_container.get_children():
		child.queue_free()
	for child in barrels_container.get_children():
		child.queue_free()
	var pickups = get_tree().get_nodes_in_group("pickups")
	for p in pickups:
		p.queue_free()

## Çok Oyunculu Senkronize Büyü Oluşturma (Tüm ekranlarda görünür!)
@rpc("call_local", "reliable")
func sync_spawn_spell(spell_type: String, pos: Vector3, dir: Vector3, extra_y: float = 0.0) -> void:
	var spell_instance = null
	match spell_type:
		"fire_wave":
			var scene = load("res://scenes/spells/fire_wave.tscn")
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
				spell_instance.direction = dir
				spell_instance.look_at_from_position(pos, pos + dir, Vector3.UP)
		"thrown_vortex":
			var scene = load("res://scenes/spells/thrown_vortex.tscn")
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
				spell_instance.setup(dir)
		"thrown_frost":
			var scene = load("res://scenes/spells/thrown_frost.tscn")
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
				spell_instance.setup(dir)
		"thrown_heal":
			var scene = load("res://scenes/spells/thrown_heal.tscn")
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
				spell_instance.setup(dir)
		"meteor":
			var scene = load("res://scenes/spells/meteor.tscn")
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
				spell_instance.target_y = extra_y
		"emp_blast":
			var scene = load("res://scenes/spells/vortex.tscn")
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
		"frost_storm":
			var scene = load("res://scenes/spells/frost_nova.tscn")
			if scene:
				spell_instance = scene.instantiate()
				spell_instance.position = pos
	
	if spell_instance:
		add_child(spell_instance, false)
