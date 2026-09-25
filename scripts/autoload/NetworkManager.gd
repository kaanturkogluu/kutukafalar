extends Node

# --- Ağ ve Lobi Yöneticisi (NetworkManager) ---
signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_disconnected
signal connection_failed
signal connection_succeeded
signal lobby_updated(players_dict: Dictionary)
signal game_started
signal game_rejected(reason: String)

const DEFAULT_PORT: int = 7000
const MAX_PLAYERS: int = 4

# Bağlı oyuncular: { peer_id: { "name": String, "class": String, "is_ready": bool, "is_host": bool } }
var players: Dictionary = {}
var local_player_info: Dictionary = {
	"name": "Kutu Asker",
	"class": "Pyromancer",
	"is_ready": false,
	"is_host": false
}
var is_game_in_progress: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## Sunucu (Host) Başlat
func create_game(player_name: String = "Host", port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		print("[NetworkManager] Sunucu başlatılamadı! Hata: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	is_game_in_progress = false
	
	local_player_info["name"] = player_name
	local_player_info["is_ready"] = true
	local_player_info["is_host"] = true
	players[1] = local_player_info.duplicate(true)
	
	print("[NetworkManager] Sunucu (Host) başlatıldı. Port: ", port)
	player_connected.emit(1, local_player_info)
	lobby_updated.emit(players)
	return OK

## İstemci (Client) Olarak Bağlan
func join_game(address: String = "127.0.0.1", player_name: String = "İstemci", port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		print("[NetworkManager] Bağlantı kurulamadı! Hata: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	is_game_in_progress = false
	
	local_player_info["name"] = player_name
	local_player_info["is_ready"] = false
	local_player_info["is_host"] = false
	print("[NetworkManager] Sunucuya bağlanılıyor: ", address, ":", port)
	return OK

## Bağlantıyı Kes / Odadan Ayrıl
func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	is_game_in_progress = false
	print("[NetworkManager] Bağlantı sonlandırıldı.")

## İstemci Hazır Durumunu Değiştir
func set_local_ready(ready_state: bool) -> void:
	local_player_info["is_ready"] = ready_state
	var my_id = multiplayer.get_unique_id()
	if multiplayer.is_server():
		players[my_id]["is_ready"] = ready_state
		_sync_lobby.rpc(players)
	else:
		_request_set_ready.rpc_id(1, ready_state)

## Host İçin Oyunu Başlat
func start_game() -> void:
	if not multiplayer.is_server():
		return
	is_game_in_progress = true
	_start_game_rpc.rpc()

# --- Ağ Sinyal Yakalayıcıları ---

func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Yeni peer bağlandı, ID: ", id)
	# Eğer sunucuysak ve oyun zaten başlamışsa geç katılımı engelle
	if multiplayer.is_server():
		if is_game_in_progress:
			print("[NetworkManager] Oyun devam ettiği için gelen bağlantı reddedildi: ", id)
			_reject_connection.rpc_id(id, "Oyun şu anda devam ediyor! Lütfen bitmesini bekleyin.")
			return
	
	# Bilgilerimizi yeni bağlanan sunucuya/oyuncuya tanıtıyoruz
	_register_player.rpc_id(id, local_player_info)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Oyuncu ayrıldı, ID: ", id)
	if players.has(id):
		players.erase(id)
		player_disconnected.emit(id)
		if multiplayer.is_server():
			_sync_lobby.rpc(players)

func _on_connected_to_server() -> void:
	var my_id = multiplayer.get_unique_id()
	print("[NetworkManager] Sunucuya başarıyla bağlanıldı! Benim ID: ", my_id)
	players[my_id] = local_player_info.duplicate(true)
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("[NetworkManager] Sunucuya bağlantı başarısız!")
	disconnect_game()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Sunucu kapandı veya bağlantı koptu!")
	disconnect_game()
	server_disconnected.emit()

# --- RPC Fonksiyonları ---

@rpc("any_peer", "reliable")
func _register_player(info: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	players[sender_id] = info
	print("[NetworkManager] Oyuncu kaydı: ", info.get("name", "Bilinmeyen"), " (ID: ", sender_id, ")")
	player_connected.emit(sender_id, info)
	
	# Sunucu güncel oyuncu listesini tüm odadakilere senkronize eder
	if multiplayer.is_server():
		_sync_lobby.rpc(players)

@rpc("any_peer", "reliable")
func _request_set_ready(ready_state: bool) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and players.has(sender_id):
		players[sender_id]["is_ready"] = ready_state
		_sync_lobby.rpc(players)

@rpc("call_local", "reliable")
func _sync_lobby(p_dict: Dictionary) -> void:
	players = p_dict
	lobby_updated.emit(players)

@rpc("call_local", "reliable")
func _start_game_rpc() -> void:
	is_game_in_progress = true
	game_started.emit()
	get_tree().change_scene_to_file("res://scenes/levels/main_level.tscn")

@rpc("reliable")
func _reject_connection(reason: String) -> void:
	print("[NetworkManager] Bağlantı reddedildi: ", reason)
	game_rejected.emit(reason)
	disconnect_game()
