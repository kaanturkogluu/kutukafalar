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
signal lan_lobbies_updated(lobbies: Dictionary)

const DEFAULT_PORT: int = 7000
const MAX_PLAYERS: int = 4
const LAN_DISCOVERY_PORT: int = 7001
const BASE62_CHARS: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

# Bağlı oyuncular: { peer_id: { "name": String, "class": String, "is_ready": bool, "is_host": bool } }
var players: Dictionary = {}
var local_player_info: Dictionary = {
	"name": "Kutu Asker",
	"class": "Pyromancer",
	"is_ready": false,
	"is_host": false
}
var is_game_in_progress: bool = false
var should_open_multiplayer_menu: bool = false

# --- Yerel Ağ (LAN) Keşif Değişkenleri ---
var lan_broadcaster: PacketPeerUDP = null
var lan_listener: PacketPeerUDP = null
var lan_broadcast_timer: float = 0.0
var lan_prune_timer: float = 0.0
var is_lan_broadcasting: bool = false
var is_lan_discovering: bool = false
var discovered_lobbies: Dictionary = {} # target_ip -> lobby_info Dictionary

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	if is_lan_broadcasting:
		lan_broadcast_timer += delta
		if lan_broadcast_timer >= 1.0:
			lan_broadcast_timer = 0.0
			_send_lan_broadcast()
	
	if is_lan_discovering:
		_poll_lan_listener()
		lan_prune_timer += delta
		if lan_prune_timer >= 2.0:
			lan_prune_timer = 0.0
			_prune_expired_lobbies()

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
	start_lan_broadcasting()
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
	stop_lan_broadcasting()
	stop_lan_discovery()
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
		if players.has(my_id):
			players[my_id]["is_ready"] = ready_state
			_sync_lobby.rpc(players)
	else:
		_request_set_ready.rpc_id(1, ready_state)

## Oyuncunun Sınıfını Değiştir ve Odaya Duyur
func set_local_class(new_class: String) -> void:
	local_player_info["class"] = new_class
	var my_id = multiplayer.get_unique_id()
	if multiplayer.is_server():
		if players.has(my_id):
			players[my_id]["class"] = new_class
			_sync_lobby.rpc(players)
	else:
		_request_set_class.rpc_id(1, new_class)

@rpc("any_peer", "reliable")
func _request_set_class(new_class: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and players.has(sender_id):
		players[sender_id]["class"] = new_class
		_sync_lobby.rpc(players)

## Host İçin Oyunu Başlat
func start_game() -> void:
	if not multiplayer.is_server():
		return
	is_game_in_progress = true
	# LAN yayınını devam ettir ki düşen oyuncular veya yeni katılacaklar odayı görüp katılabilsin
	_start_game_rpc.rpc()

# --- Ağ Sinyal Yakalayıcıları ---

func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Yeni peer bağlandı, ID: ", id)
	# Eğer sunucuysak ve oyun zaten başlamışsa oyuncuyu doğrudan oyuna alıyoruz (Ölü/İzleyici olarak doğacak)
	if multiplayer.is_server() and is_game_in_progress:
		print("[NetworkManager] Oyun devam ediyor, geç bağlanan oyuncu oyuna yönlendiriliyor: ", id)
		_start_game_rpc.rpc_id(id)
	
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

## Odaya Geri Dön (Bağlantıyı koparmadan tüm takımı lobi bekleme odasına çeker)
func return_to_lobby() -> void:
	if multiplayer.is_server():
		is_game_in_progress = false
		start_lan_broadcasting()
		_return_to_lobby_rpc.rpc()

@rpc("call_local", "reliable")
func _return_to_lobby_rpc() -> void:
	is_game_in_progress = false
	for pid in players:
		players[pid]["is_ready"] = (pid == 1)
	local_player_info["is_ready"] = (multiplayer.get_unique_id() == 1)
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")

@rpc("reliable")
func _reject_connection(reason: String) -> void:
	print("[NetworkManager] Bağlantı reddedildi: ", reason)
	game_rejected.emit(reason)
	disconnect_game()

# --- Yerel Ağ (LAN) Keşif & Yayın Fonksiyonları ---

func start_lan_broadcasting() -> void:
	is_lan_broadcasting = true
	lan_broadcast_timer = 1.0 # İlk yayını hemen gönder
	if not lan_broadcaster:
		lan_broadcaster = PacketPeerUDP.new()
		lan_broadcaster.set_broadcast_enabled(true)
	print("[NetworkManager] LAN lobi yayını devrede.")

func stop_lan_broadcasting() -> void:
	is_lan_broadcasting = false
	if lan_broadcaster:
		lan_broadcaster.close()
		lan_broadcaster = null
	print("[NetworkManager] LAN lobi yayını kapatıldı.")

func start_lan_discovery() -> void:
	is_lan_discovering = true
	discovered_lobbies.clear()
	lan_lobbies_updated.emit(discovered_lobbies)
	if not lan_listener:
		lan_listener = PacketPeerUDP.new()
		var err = lan_listener.bind(LAN_DISCOVERY_PORT)
		if err != OK:
			print("[NetworkManager] LAN dinleyici portu açılamadı (Port: %d, Hata: %d)" % [LAN_DISCOVERY_PORT, err])
		else:
			print("[NetworkManager] LAN lobi arama dinleyicisi başlatıldı (Port: %d)" % LAN_DISCOVERY_PORT)

func stop_lan_discovery() -> void:
	is_lan_discovering = false
	if lan_listener:
		lan_listener.close()
		lan_listener = null
	print("[NetworkManager] LAN lobi araması durduruldu.")

func _send_lan_broadcast() -> void:
	if not multiplayer.is_server():
		return
	if not lan_broadcaster:
		lan_broadcaster = PacketPeerUDP.new()
		lan_broadcaster.set_broadcast_enabled(true)
	
	var host_name = local_player_info.get("name", "Kutu Komutan")
	var host_class = local_player_info.get("class", "Pyromancer")
	var start_flr = SaveManager.get_starting_floor()
	var local_ip = _get_local_ip()
	var code = _calculate_room_code(local_ip)
	
	var payload = {
		"app": "kutukafalar",
		"host_name": host_name,
		"host_class": host_class,
		"ip": local_ip,
		"port": DEFAULT_PORT,
		"code": code,
		"players_count": players.size(),
		"max_players": MAX_PLAYERS,
		"floor": start_flr,
		"floor_name": LevelData.FLOOR_NAMES.get(start_flr, "Kat " + str(start_flr))
	}
	var json_bytes = JSON.stringify(payload).to_utf8_buffer()
	
	# Yerel alt ağa yayın yap (Broadcast)
	lan_broadcaster.set_dest_address("255.255.255.255", LAN_DISCOVERY_PORT)
	lan_broadcaster.put_packet(json_bytes)
	
	# Aynı bilgisayardaki diğer pencerelerin de görebilmesi için loopback'e de yolla
	lan_broadcaster.set_dest_address("127.0.0.1", LAN_DISCOVERY_PORT)
	lan_broadcaster.put_packet(json_bytes)

func _poll_lan_listener() -> void:
	if not lan_listener:
		return
	while lan_listener.get_available_packet_count() > 0:
		var pkt = lan_listener.get_packet()
		var sender_ip = lan_listener.get_packet_ip()
		var pkt_str = pkt.get_string_from_utf8()
		var parsed = JSON.parse_string(pkt_str)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.get("app") == "kutukafalar":
			# Eğer sunucu bizsek kendi kendimizi listeye eklemeyelim
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and (sender_ip == "127.0.0.1" or sender_ip == _get_local_ip()):
				continue
			var target_ip = sender_ip
			if target_ip.is_empty():
				target_ip = "127.0.0.1"
			# Eğer paketin içinde gerçek yerel IP varsa onu tercih et
			if parsed.has("ip") and str(parsed["ip"]).count(".") == 3 and not str(parsed["ip"]).begins_with("127."):
				target_ip = str(parsed["ip"])
			
			parsed["ip"] = target_ip
			parsed["last_seen"] = Time.get_ticks_msec()
			discovered_lobbies[target_ip] = parsed
			lan_lobbies_updated.emit(discovered_lobbies)

func _prune_expired_lobbies() -> void:
	var now = Time.get_ticks_msec()
	var changed = false
	var to_remove = []
	for ip_key in discovered_lobbies.keys():
		var lobby = discovered_lobbies[ip_key]
		var last_seen = lobby.get("last_seen", 0)
		if now - last_seen > 3500:
			to_remove.append(ip_key)
	for ip_key in to_remove:
		discovered_lobbies.erase(ip_key)
		changed = true
	if changed:
		lan_lobbies_updated.emit(discovered_lobbies)

func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			return ip
	return "127.0.0.1"

func _calculate_room_code(ip_str: String) -> String:
	var parts = ip_str.split(".")
	if parts.size() != 4:
		return ip_str
	var n: int = (clampi(parts[0].to_int(), 0, 255) << 24) | (clampi(parts[1].to_int(), 0, 255) << 16) | (clampi(parts[2].to_int(), 0, 255) << 8) | clampi(parts[3].to_int(), 0, 255)
	n = n & 0xFFFFFFFF
	var code = ""
	for i in range(6):
		var rem = n % 62
		code = BASE62_CHARS[rem] + code
		n = int(n / 62)
	return code
