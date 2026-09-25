extends Node

# --- Ağ ve Lobi Yöneticisi (NetworkManager) ---
signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_disconnected
signal connection_failed
signal connection_succeeded

const DEFAULT_PORT: int = 7000
const MAX_PLAYERS: int = 4

# Bağlı oyuncular: { peer_id: { "name": String, "score": int, "class": String } }
var players: Dictionary = {}
var local_player_info: Dictionary = {
	"name": "Kutu Kafa",
	"class": "Pyromancer"
}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## Sunucu (Host) Başlat
func create_game(player_name: String = "Host", port: int = DEFAULT_PORT) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		print("[NetworkManager] Sunucu başlatılamadı! Hata: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	local_player_info["name"] = player_name
	players[1] = local_player_info
	print("[NetworkManager] Sunucu (Host) başlatıldı. Port: ", port)
	player_connected.emit(1, local_player_info)
	return OK

## İstemci (Client) Olarak Bağlan
func join_game(address: String = "127.0.0.1", player_name: String = "İstemci", port: int = DEFAULT_PORT) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		print("[NetworkManager] Bağlantı kurulamadı! Hata: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	local_player_info["name"] = player_name
	print("[NetworkManager] Sunucuya bağlanılıyor: ", address, ":", port)
	return OK

## Bağlantıyı Kes
func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	print("[NetworkManager] Bağlantı sonlandırıldı.")

# --- Ağ Sinyal Yakalayıcıları ---

func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Yeni oyuncu bağlandı, ID: ", id)
	# Sunucuya kendi bilgilerimizi gönderiyoruz
	_register_player.rpc_id(id, local_player_info)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Oyuncu ayrıldı, ID: ", id)
	if players.has(id):
		players.erase(id)
		player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	var my_id = multiplayer.get_unique_id()
	print("[NetworkManager] Sunucuya başarıyla bağlanıldı! Benim ID: ", my_id)
	players[my_id] = local_player_info
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("[NetworkManager] Sunucuya bağlantı başarısız!")
	disconnect_game()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Sunucu kapandı veya bağlantı koptu!")
	disconnect_game()
	server_disconnected.emit()

# --- RPC Bilgi Senkronizasyonu ---

@rpc("any_peer", "reliable")
func _register_player(info: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	players[sender_id] = info
	player_connected.emit(sender_id, info)
	print("[NetworkManager] Oyuncu kaydı alındı: ", info.get("name", "Bilinmeyen"), " (ID: ", sender_id, ")")
