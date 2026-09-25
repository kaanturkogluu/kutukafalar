extends Node3D

# --- Ana Oyun Seviyesi, Çok Oyunculu Doğurma, Asansör ve Kat İlerlemesi ---
const PLAYER_SCENE_PATH: String = "res://scenes/player/player.tscn"
const ZOMBIE_SCENE_PATH: String = "res://scenes/enemies/zombie.tscn"
const BARREL_SCENE_PATH: String = "res://scenes/interactables/barrel_red.tscn"
const PICKUP_SCENE_PATH: String = "res://scenes/interactables/pickup.tscn"

@onready var players_container: Node3D = $Players
@onready var enemies_container: Node3D = $Enemies
@onready var barrels_container: Node3D = $Barrels
@onready var player_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var enemy_spawner: MultiplayerSpawner = $EnemySpawner
@onready var barrel_spawner: MultiplayerSpawner = $BarrelSpawner
@onready var elevator: Node3D = $Elevator
@onready var shop_ui: CanvasLayer = $ShopUI

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

@onready var floor_label: Label = $WaveUI/WaveInfo/FloorLabel
@onready var wave_label: Label = $WaveUI/WaveInfo/WaveLabel
@onready var enemies_label: Label = $WaveUI/WaveInfo/EnemiesLabel

func _ready() -> void:
	player_spawner.spawn_path = players_container.get_path()
	player_spawner.add_spawnable_scene(PLAYER_SCENE_PATH)

	enemy_spawner.spawn_path = enemies_container.get_path()
	enemy_spawner.add_spawnable_scene(ZOMBIE_SCENE_PATH)

	barrel_spawner.spawn_path = barrels_container.get_path()
	barrel_spawner.add_spawnable_scene(BARREL_SCENE_PATH)
	
	if elevator:
		elevator.players_entered_elevator.connect(_on_players_entered_elevator)
	if shop_ui:
		shop_ui.next_floor_requested.connect(_on_next_floor_requested)
	
	player_spawner.spawned.connect(func(node):
		if node is CharacterBody3D and node.has_signal("player_died"):
			if not node.player_died.is_connected(_on_player_died):
				node.player_died.connect(_on_player_died.bind(node))
	)

	if multiplayer.is_server():
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		
		# Host oyuncuyu doğur
		spawn_player(1)
		
		for id in NetworkManager.players.keys():
			if id != 1:
				spawn_player(id)

		# Başlangıç varillerini doğur
		_spawn_initial_barrels()

		# 2 saniye sonra 1. Dalgayı Başlat
		await get_tree().create_timer(2.0).timeout
		_start_next_wave()

func spawn_player(id: int) -> void:
	if players_container.has_node(str(id)):
		return
	
	var player_scene = load(PLAYER_SCENE_PATH)
	var player = player_scene.instantiate()
	player.name = str(id)
	
	if spawn_points.size() > 0:
		var index = id % spawn_points.size()
		player.position = spawn_points[index].global_position
	else:
		player.position = Vector3(0, 1.5, 0)
	
	player.player_died.connect(_on_player_died.bind(player))
	players_container.add_child(player, true)

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

func spawn_barrel(pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var barrel_scene = load(BARREL_SCENE_PATH)
	if barrel_scene:
		var barrel = barrel_scene.instantiate()
		barrel_id_counter += 1
		barrel.name = "Barrel_" + str(barrel_id_counter)
		barrel.position = pos
		barrels_container.add_child(barrel, true)

func _on_player_connected(id: int, _info: Dictionary) -> void:
	if multiplayer.is_server():
		spawn_player(id)
		_sync_floor_ui.rpc(current_floor, current_wave, active_zombie_count + zombies_remaining_to_spawn)

func _on_player_disconnected(id: int) -> void:
	if multiplayer.is_server():
		var player_node = players_container.get_node_or_null(str(id))
		if player_node:
			player_node.queue_free()

# --- Zombi Dalga Mantığı ---

func _start_next_wave() -> void:
	if not multiplayer.is_server():
		return

	# Kat ve Dalga çarpanına göre zombi sayısı
	zombies_remaining_to_spawn = 4 + (current_floor * 2) + (current_wave * 2)
	active_zombie_count = 0
	_sync_floor_ui.rpc(current_floor, current_wave, zombies_remaining_to_spawn)
	_spawn_zombie_loop()

func _spawn_zombie_loop() -> void:
	while zombies_remaining_to_spawn > 0:
		if not is_instance_valid(self):
			return
		
		var spawn_delay = max(0.6, 1.3 - (current_floor * 0.1))
		await get_tree().create_timer(spawn_delay).timeout
		_spawn_single_zombie()
		zombies_remaining_to_spawn -= 1
		active_zombie_count += 1
		_sync_floor_ui.rpc(current_floor, current_wave, active_zombie_count + zombies_remaining_to_spawn)

func _spawn_single_zombie() -> void:
	var zombie_scene = load(ZOMBIE_SCENE_PATH)
	var zombie = zombie_scene.instantiate()
	
	zombie_id_counter += 1
	zombie.name = "Zombie_" + str(zombie_id_counter)
	
	# Kat ilerledikçe zombiler hafif hızlanır ve güçlenir
	zombie.speed = 3.6 + (current_floor * 0.2)
	zombie.max_health = 100.0 + (current_floor * 15.0)

	if zombie_spawn_points.size() > 0:
		var spawn_point = zombie_spawn_points.pick_random()
		zombie.position = spawn_point.global_position
	else:
		zombie.position = Vector3(randf_range(-10, 10), 1.5, randf_range(-10, 10))
	
	zombie.died.connect(_on_zombie_died)
	enemies_container.add_child(zombie, true)

func _on_zombie_died(_zombie_ref) -> void:
	if not multiplayer.is_server():
		return

	active_zombie_count = max(0, active_zombie_count - 1)
	_sync_floor_ui.rpc(current_floor, current_wave, active_zombie_count + zombies_remaining_to_spawn)

	if zombies_remaining_to_spawn == 0 and active_zombie_count == 0:
		if current_wave < WAVES_PER_FLOOR:
			# Kat içindeki bir sonraki dalga
			current_wave += 1
			_announce_wave_cleared.rpc()
			await get_tree().create_timer(3.5).timeout
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
	
	var local_id = multiplayer.get_unique_id()
	var local_player = players_container.get_node_or_null(str(local_id))
	if local_player and local_player.death_screen:
		local_player.death_screen.visible = true
		if local_player.death_title_label:
			local_player.death_title_label.text = "💀 OYUN BİTTİ 💀"
		if local_player.death_reason_label:
			local_player.death_reason_label.text = "Tüm takım zombiler tarafından alt edildi!"
		if local_player.death_info_label:
			local_player.death_info_label.text = "[R] tuşuna veya butona basarak baştan başlayın."
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
	print("[MainLevel] Oyun yeniden başlatılıyor...")
	current_floor = 1
	current_wave = 1
	active_zombie_count = 0
	zombies_remaining_to_spawn = 0
	
	# Sahnedeki tüm düşmanları temizle
	for child in enemies_container.get_children():
		child.queue_free()
	
	# Tüm oyuncuları doğuş noktalarında canlandır
	var players = get_tree().get_nodes_in_group("players")
	for i in range(players.size()):
		var p = players[i]
		var spawn_pos = spawn_points[i % spawn_points.size()].global_position if spawn_points.size() > 0 else Vector3(0, 1.5, 0)
		if p.has_method("revive"):
			p.revive.rpc(p.max_health, spawn_pos)
	
	elevator.set_elevator_state(false)
	_sync_floor_ui.rpc(current_floor, current_wave, 0)
	await get_tree().create_timer(1.5).timeout
	_start_next_wave()
