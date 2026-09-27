extends Node3D

# --- Kat Asansörü ve Geçiş Kapısı (Elevator) ---
signal players_entered_elevator

@export var is_open: bool = false
var players_inside: Array[CharacterBody3D] = []
var has_triggered_transition: bool = false

@onready var light: OmniLight3D = $BeaconLight
@onready var sign_label: Label3D = $SignLabel
@onready var left_door: Node3D = $LeftDoor
@onready var right_door: Node3D = $RightDoor

func _ready() -> void:
	set_elevator_state(false)
	$TriggerArea.body_entered.connect(_on_body_entered)
	$TriggerArea.body_exited.connect(_on_body_exited)

## Asansörün Açılması (Kat Temizlendiğinde Tüm Ekranlarda Senkronize)
@rpc("call_local", "reliable")
func set_elevator_state(open: bool) -> void:
	is_open = open
	if is_open:
		has_triggered_transition = false
		light.light_color = Color(0.1, 1.0, 0.3) # Yeşil
		sign_label.text = "🛗 ASANSÖR HAZIR!\n(İÇERİ GİRİN)"
		sign_label.modulate = Color(0.2, 1.0, 0.4)
		_open_doors()
	else:
		players_inside.clear()
		light.light_color = Color(1.0, 0.2, 0.1) # Kırmızı
		sign_label.text = "🔒 ASANSÖR KİLİTLİ\n(KAT TEMİZLİĞİ BEKLENİYOR)"
		sign_label.modulate = Color(1.0, 0.4, 0.3)
		_close_doors()

@rpc("call_local", "reliable")
func reset_elevator() -> void:
	players_inside.clear()
	has_triggered_transition = false

func _open_doors() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(left_door, "position:x", -2.0, 0.8)
	tween.tween_property(right_door, "position:x", 2.0, 0.8)

func _close_doors() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(left_door, "position:x", -0.7, 0.8)
	tween.tween_property(right_door, "position:x", 0.7, 0.8)

func _on_body_entered(body: Node3D) -> void:
	if not is_open:
		return
	if body.is_in_group("players"):
		if not players_inside.has(body):
			players_inside.append(body)
		if not multiplayer.is_server() and body.is_multiplayer_authority():
			_notify_server_player_entered.rpc_id(1, body.name.to_int())
		if multiplayer.is_server():
			_check_all_players_inside()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		if players_inside.has(body):
			players_inside.erase(body)
		if not multiplayer.is_server() and body.is_multiplayer_authority():
			_notify_server_player_exited.rpc_id(1, body.name.to_int())
		if multiplayer.is_server():
			_check_all_players_inside()

@rpc("any_peer", "reliable")
func _notify_server_player_entered(p_id: int) -> void:
	if not multiplayer.is_server():
		return
	var p = get_tree().current_scene.find_child(str(p_id), true, false)
	if p and not players_inside.has(p):
		players_inside.append(p)
	_check_all_players_inside()

@rpc("any_peer", "reliable")
func _notify_server_player_exited(p_id: int) -> void:
	if not multiplayer.is_server():
		return
	var p = get_tree().current_scene.find_child(str(p_id), true, false)
	if p and players_inside.has(p):
		players_inside.erase(p)
	_check_all_players_inside()

func _check_all_players_inside() -> void:
	if not multiplayer.is_server() or not is_open or has_triggered_transition:
		return
	
	var all_players = get_tree().get_nodes_in_group("players")
	var living_players = 0
	for p in all_players:
		if is_instance_valid(p) and not p.get("is_dead") and p.current_health > 0:
			living_players += 1
	
	# Eğer yaşayan en az 1 oyuncu varsa ve tüm yaşayanlar asansördeyse geçiş başlar
	var living_inside = 0
	for p in players_inside:
		if is_instance_valid(p) and not p.get("is_dead") and p.current_health > 0:
			living_inside += 1

	if living_inside >= living_players and living_players > 0:
		has_triggered_transition = true
		print("[Asansör] Tüm yaşayan oyuncular (", living_inside, "/", living_players, ") bindi! Sonraki kata geçiliyor...")
		players_entered_elevator.emit()
