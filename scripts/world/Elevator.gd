extends Node3D

# --- Kat Asansörü ve Geçiş Kapısı (Elevator) ---
signal players_entered_elevator

@export var is_open: bool = false
var players_inside: Array[CharacterBody3D] = []

@onready var light: OmniLight3D = $BeaconLight
@onready var sign_label: Label3D = $SignLabel
@onready var left_door: Node3D = $LeftDoor
@onready var right_door: Node3D = $RightDoor

func _ready() -> void:
	set_elevator_state(false)
	$TriggerArea.body_entered.connect(_on_body_entered)
	$TriggerArea.body_exited.connect(_on_body_exited)

## Asansörün Açılması (Kat Temizlendiğinde)
func set_elevator_state(open: bool) -> void:
	is_open = open
	if is_open:
		light.light_color = Color(0.1, 1.0, 0.3) # Yeşil
		sign_label.text = "🛗 ASANSÖR HAZIR!\n(İÇERİ GİRİN)"
		sign_label.modulate = Color(0.2, 1.0, 0.4)
		_open_doors()
	else:
		light.light_color = Color(1.0, 0.2, 0.1) # Kırmızı
		sign_label.text = "🔒 ASANSÖR KİLİTLİ\n(KAT TEMİZLİĞİ BEKLENİYOR)"
		sign_label.modulate = Color(1.0, 0.4, 0.3)
		_close_doors()

func _open_doors() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(left_door, "position:x", -1.8, 1.0)
	tween.tween_property(right_door, "position:x", 1.8, 1.0)

func _close_doors() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(left_door, "position:x", -0.7, 1.0)
	tween.tween_property(right_door, "position:x", 0.7, 1.0)

func _on_body_entered(body: Node3D) -> void:
	if not is_open:
		return
	if body.is_in_group("players") and not players_inside.has(body):
		players_inside.append(body)
		_check_all_players_inside()

func _on_body_exited(body: Node3D) -> void:
	if players_inside.has(body):
		players_inside.erase(body)

func _check_all_players_inside() -> void:
	if not multiplayer.is_server():
		return
	
	var all_players = get_tree().get_nodes_in_group("players")
	var living_players = 0
	for p in all_players:
		if p.current_health > 0:
			living_players += 1
	
	# Eğer tüm yaşayan oyuncular asansördeyse geçiş başlar
	if players_inside.size() >= living_players and living_players > 0:
		print("[Asansör] Tüm oyuncular bindi! Sonraki kata geçiliyor...")
		players_entered_elevator.emit()
