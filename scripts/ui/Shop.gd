extends CanvasLayer

# --- Asansör İkmal ve Geliştirme İstasyonu (Shop & Upgrades) ---
signal next_floor_requested
signal back_to_levels_requested

@onready var title_label: Label = $Panel/VBoxContainer/HeaderBox/TitleLabel
@onready var gold_label: Label = $Panel/VBoxContainer/HeaderBox/GoldLabel

@onready var card1_btn: Button = $Panel/VBoxContainer/HBoxCards/Card1/VBox/BuyButton
@onready var card1_title: Label = $Panel/VBoxContainer/HBoxCards/Card1/VBox/Title
@onready var card1_desc: Label = $Panel/VBoxContainer/HBoxCards/Card1/VBox/Desc

@onready var card2_btn: Button = $Panel/VBoxContainer/HBoxCards/Card2/VBox/BuyButton
@onready var card2_title: Label = $Panel/VBoxContainer/HBoxCards/Card2/VBox/Title
@onready var card2_desc: Label = $Panel/VBoxContainer/HBoxCards/Card2/VBox/Desc

@onready var card3_btn: Button = $Panel/VBoxContainer/HBoxCards/Card3/VBox/BuyButton
@onready var card3_title: Label = $Panel/VBoxContainer/HBoxCards/Card3/VBox/Title
@onready var card3_desc: Label = $Panel/VBoxContainer/HBoxCards/Card3/VBox/Desc

@onready var back_to_levels_btn: Button = $Panel/VBoxContainer/HBoxActions/BackToLevelsButton
@onready var next_floor_btn: Button = $Panel/VBoxContainer/HBoxActions/NextFloorButton

var local_player: CharacterBody3D
var current_floor: int = 1
var current_offers: Array[Dictionary] = []

func _ready() -> void:
	visible = false
	if card1_btn:
		card1_btn.pressed.connect(func(): _buy_card(0))
	if card2_btn:
		card2_btn.pressed.connect(func(): _buy_card(1))
	if card3_btn:
		card3_btn.pressed.connect(func(): _buy_card(2))
	if back_to_levels_btn:
		back_to_levels_btn.pressed.connect(_on_back_to_levels_pressed)
	if next_floor_btn:
		next_floor_btn.pressed.connect(_on_next_floor_pressed)

func open_shop(p_player: CharacterBody3D, floor_num: int) -> void:
	local_player = p_player
	current_floor = floor_num
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if local_player and local_player.has_method("set_in_shop"):
		local_player.set_in_shop(true)
	if title_label:
		title_label.text = "ASANSÖR İKMAL VE GELİŞTİRME İSTASYONU // KAT %02d" % current_floor
	
	if next_floor_btn:
		if multiplayer.is_server():
			next_floor_btn.text = "SONRAKİ SEVİYEYİ BAŞLAT"
			next_floor_btn.disabled = false
			next_floor_btn.tooltip_text = "Seviyeyi tüm takım için başlat"
		else:
			next_floor_btn.text = "ODA SAHİBİ BEKLENİYOR..."
			next_floor_btn.disabled = true
			next_floor_btn.tooltip_text = "Yalnızca oda sahibi sonraki seviyeyi başlatabilir"
	
	_generate_offers()
	_update_ui()

func close_shop() -> void:
	visible = false
	if local_player and local_player.has_method("set_in_shop"):
		local_player.set_in_shop(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _update_ui() -> void:
	if local_player and gold_label:
		gold_label.text = "MEVCUT KREDİ: " + str(local_player.gold)
	
	if current_offers.size() >= 3:
		_setup_card_ui(card1_title, card1_desc, card1_btn, current_offers[0])
		_setup_card_ui(card2_title, card2_desc, card2_btn, current_offers[1])
		_setup_card_ui(card3_title, card3_desc, card3_btn, current_offers[2])

func _setup_card_ui(title_node: Label, desc_node: Label, btn_node: Button, offer: Dictionary) -> void:
	if not title_node or not desc_node or not btn_node:
		return
	title_node.text = offer.title
	desc_node.text = offer.desc
	if offer.bought:
		btn_node.text = "SATIN ALINDI"
		btn_node.disabled = true
	else:
		btn_node.text = "SATIN AL (" + str(offer.cost) + " KREDİ)"
		btn_node.disabled = (local_player != null and local_player.gold < offer.cost)

func _generate_offers() -> void:
	current_offers.clear()
	var base_cost = 40 + (current_floor * 15)
	
	var pool = [
		{"type": "health", "title": "ZIRH TAKVİYESİ", "desc": "+35 Maksimum Can ve Tam Şifa", "cost": base_cost, "bought": false},
		{"type": "damage", "title": "AĞIR MÜHİMMAT", "desc": "Tüm Silah Hasarı +%25 Artar", "cost": base_cost + 20, "bought": false},
		{"type": "speed", "title": "TAKTIKSEL HIZ", "desc": "Koşma Hızı +%15 Hızlanır", "cost": base_cost - 10, "bought": false},
		{"type": "firerate", "title": "SERİ TETİK", "desc": "Silah Atış Hızı +%20 Hızlanır", "cost": base_cost + 15, "bought": false},
		{"type": "barrels", "title": "VARİL İKMALİ", "desc": "+3 Patlayıcı Varil Kapasitesi", "cost": base_cost - 15, "bought": false},
		{"type": "cooldown", "title": "BÜYÜ ODAKLANMASI", "desc": "Taktiksel Büyü Bekleme Süresi -2.5 sn", "cost": base_cost + 25, "bought": false},
		{"type": "droprate", "title": "GANİMET ŞANSI", "desc": "Zombilerden Mühimmat ve Silah Düşme Şansı +%50 Artar", "cost": base_cost + 10, "bought": false},
		{"type": "bixi", "title": "BİXİ (PKM) AĞIR MAKİNELİ", "desc": "Yüksek Mermi Kapasiteli Tam Otomatik Ağır Makineli (+120 Mermi)", "cost": base_cost + 40, "bought": false}
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

func _on_back_to_levels_pressed() -> void:
	close_shop()
	back_to_levels_requested.emit()

func _on_next_floor_pressed() -> void:
	if not multiplayer.is_server():
		return
	close_shop()
	next_floor_requested.emit()
