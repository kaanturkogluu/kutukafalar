extends CanvasLayer

# --- Asansör Mağazası ve Yükseltme Kartları (Shop & Upgrades) ---
signal next_floor_requested

@onready var gold_label: Label = $Panel/VBoxContainer/GoldLabel
@onready var card1_btn: Button = $Panel/VBoxContainer/HBoxCards/Card1/VBox/BuyButton
@onready var card1_title: Label = $Panel/VBoxContainer/HBoxCards/Card1/VBox/Title
@onready var card1_desc: Label = $Panel/VBoxContainer/HBoxCards/Card1/VBox/Desc

@onready var card2_btn: Button = $Panel/VBoxContainer/HBoxCards/Card2/VBox/BuyButton
@onready var card2_title: Label = $Panel/VBoxContainer/HBoxCards/Card2/VBox/Title
@onready var card2_desc: Label = $Panel/VBoxContainer/HBoxCards/Card2/VBox/Desc

@onready var card3_btn: Button = $Panel/VBoxContainer/HBoxCards/Card3/VBox/BuyButton
@onready var card3_title: Label = $Panel/VBoxContainer/HBoxCards/Card3/VBox/Title
@onready var card3_desc: Label = $Panel/VBoxContainer/HBoxCards/Card3/VBox/Desc

@onready var next_floor_btn: Button = $Panel/VBoxContainer/NextFloorButton

var local_player: CharacterBody3D
var current_floor: int = 1
var current_offers: Array[Dictionary] = []

func _ready() -> void:
	visible = false
	card1_btn.pressed.connect(func(): _buy_card(0))
	card2_btn.pressed.connect(func(): _buy_card(1))
	card3_btn.pressed.connect(func(): _buy_card(2))
	next_floor_btn.pressed.connect(_on_next_floor_pressed)

func open_shop(p_player: CharacterBody3D, floor_num: int) -> void:
	local_player = p_player
	current_floor = floor_num
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if local_player and local_player.has_method("set_in_shop"):
		local_player.set_in_shop(true)
	_generate_offers()
	_update_ui()

func close_shop() -> void:
	visible = false
	if local_player and local_player.has_method("set_in_shop"):
		local_player.set_in_shop(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _update_ui() -> void:
	if local_player:
		gold_label.text = "🪙 MEVCUT ALTININIZ: " + str(local_player.gold)
	
	if current_offers.size() >= 3:
		card1_title.text = current_offers[0].title
		card1_desc.text = current_offers[0].desc
		card1_btn.text = "SATIN AL (" + str(current_offers[0].cost) + " 🪙)"
		card1_btn.disabled = current_offers[0].bought or (local_player and local_player.gold < current_offers[0].cost)

		card2_title.text = current_offers[1].title
		card2_desc.text = current_offers[1].desc
		card2_btn.text = "SATIN AL (" + str(current_offers[1].cost) + " 🪙)"
		card2_btn.disabled = current_offers[1].bought or (local_player and local_player.gold < current_offers[1].cost)

		card3_title.text = current_offers[2].title
		card3_desc.text = current_offers[2].desc
		card3_btn.text = "SATIN AL (" + str(current_offers[2].cost) + " 🪙)"
		card3_btn.disabled = current_offers[2].bought or (local_player and local_player.gold < current_offers[2].cost)

func _generate_offers() -> void:
	current_offers.clear()
	var base_cost = 40 + (current_floor * 15)
	
	var pool = [
		{"type": "health", "title": "🛡️ Zırh Takviyesi", "desc": "+35 Maksimum Can ve Tam Şifa", "cost": base_cost, "bought": false},
		{"type": "damage", "title": "💥 Ağır Mühimmat", "desc": "Tüm Silah Hasarı +%25 Artar", "cost": base_cost + 20, "bought": false},
		{"type": "speed", "title": "🏃 Kutu Çevikliği", "desc": "Koşma Hızı +%15 Hızlanır", "cost": base_cost - 10, "bought": false},
		{"type": "firerate", "title": "⚡ Seri Tetik", "desc": "Silah Atış Hızı +%20 Hızlanır", "cost": base_cost + 15, "bought": false},
		{"type": "barrels", "title": "📦 Varil İkmali", "desc": "+3 Patlayıcı Varil Kapasitesi", "cost": base_cost - 15, "bought": false},
		{"type": "cooldown", "title": "🔮 Büyü Odaklanması", "desc": "Taktiksel Büyü Bekleme Süresi -2.5 sn", "cost": base_cost + 25, "bought": false},
		{"type": "droprate", "title": "🍀 Ganimet Şansı", "desc": "Zombilerden Eşya ve Silah Düşme Şansı +%50 Artar", "cost": base_cost + 10, "bought": false},
		{"type": "bixi", "title": "🔥 Bixi (PKM) Ağır Makineli", "desc": "Yüksek Mermi Kapasiteli Tam Otomatik Ağır Makineli (+120 Mermi)", "cost": base_cost + 40, "bought": false}
	]
	pool.shuffle()
	current_offers = [pool[0], pool[1], pool[2]]

func _buy_card(index: int) -> void:
	if not local_player or index >= current_offers.size():
		return
	var offer = current_offers[index]
	if offer.bought or local_player.gold < offer.cost:
		SoundManager.play_sfx("empty")
		return
	
	local_player.gold -= offer.cost
	offer.bought = true
	SoundManager.play_sfx("pickup")
	
	# Yükseltmeyi oyuncuya uygula
	match offer.type:
		"health":
			local_player.max_health += 35.0
			local_player.current_health = local_player.max_health
		"damage":
			local_player.stat_damage_mult += 0.25
		"speed":
			local_player.speed *= 1.15
			local_player.sprint_speed *= 1.15
		"firerate":
			local_player.stat_firerate_mult += 0.20
		"barrels":
			local_player.barrel_count += 3
		"cooldown":
			if local_player.spell_manager:
				local_player.spell_manager.tactical_cooldown = max(5.0, local_player.spell_manager.tactical_cooldown - 2.5)
		"droprate":
			local_player.stat_drop_luck += 0.50
		"bixi":
			local_player.apply_pickup("bixi", 120)

	if local_player.has_method("sync_player_stats"):
		local_player.sync_player_stats.rpc(local_player.gold)
	local_player._update_hud()
	_update_ui()
	print("[Mağaza] Satın alındı: ", offer.title)

func _on_next_floor_pressed() -> void:
	close_shop()
	next_floor_requested.emit()
