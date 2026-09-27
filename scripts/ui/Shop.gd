extends CanvasLayer

# --- Kutu Kafalar: Taktiksel E-Ticaret Askeri Karaborsa (Shop & Weapon Fabricator) ---
signal next_floor_requested
signal back_to_levels_requested

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var gold_label: Label = %GoldLabel
@onready var bio_cores_label: Label = %BioCoresLabel

@onready var tab_weapons_btn: Button = %TabWeaponsBtn
@onready var tab_supplies_btn: Button = %TabSuppliesBtn
@onready var tab_perks_btn: Button = %TabPerksBtn

@onready var cards_container: HBoxContainer = %CardsContainer

@onready var back_to_levels_btn: Button = %BackToLevelsButton
@onready var skill_tree_btn: Button = %SkillTreeButton
@onready var next_floor_btn: Button = %NextFloorButton

var local_player: CharacterBody3D = null
var current_floor: int = 1
var active_category: String = "weapons" # "weapons", "supplies", "perks"

# 1. Silah Kataloğu (Yalnızca buradan açılan silahlar sahada zombilerden düşer!)
const WEAPON_CATALOG: Array[Dictionary] = [
	{
		"id": "shotgun",
		"title": "POMPALI TÜFEK",
		"badge": "[AĞIR SİLAH]",
		"icon": "💥",
		"specs": "Hasar: 18x8 | Saçılma: Yüksek | Kapasite: 12",
		"desc": "Zombi sürülerini ve dar koridorları tek atışta temizleyen taktiksel pompalı tüfek. Kilidi açıldıktan sonra oyundaki zombilerden de düşmeye başlar.",
		"cost": 140,
		"ammo_reward": 16,
		"is_weapon": true
	},
	{
		"id": "uzi",
		"title": "MICRO UZI",
		"badge": "[SERİ ATEŞ]",
		"icon": "⚡",
		"specs": "Hasar: 14 | Atış Hızı: +%200 | Kapasite: 60",
		"desc": "Ultra yüksek atış hızıyla hızlı koşan zombileri anında biçer. Kilidi açıldıktan sonra oyundaki zombilerden de düşmeye başlar.",
		"cost": 190,
		"ammo_reward": 80,
		"is_weapon": true
	},
	{
		"id": "bixi",
		"title": "M249 BİXİ",
		"badge": "[AĞIR MAKİNELİ]",
		"icon": "🔫",
		"specs": "Hasar: 22 | Kapasite: 80 | Delip Geçme",
		"desc": "Yüksek şarjör kapasiteli manga destek makineli tüfeği. Kesintisiz kurşun yağmuru. Kilidi açıldıktan sonra oyundaki zombilerden de düşmeye başlar.",
		"cost": 260,
		"ammo_reward": 100,
		"is_weapon": true
	},
	{
		"id": "rocket",
		"title": "RPG-7 ROKETATAR",
		"badge": "[ALAN YIKIMI]",
		"icon": "🚀",
		"specs": "Hasar: 250 | Patlama Çapı: 6m | Kapasite: 3",
		"desc": "Büyük zombi kalabalıklarını ve mutant canavarları tek atışta havaya uçurur. Kilidi açıldıktan sonra oyundaki zombilerden de düşmeye başlar.",
		"cost": 320,
		"ammo_reward": 4,
		"is_weapon": true
	}
]

# 2. Mühimmat & İkmal Kataloğu
const SUPPLY_CATALOG: Array[Dictionary] = [
	{
		"id": "full_ammo",
		"title": "TAM MÜHİMMAT",
		"badge": "[LOJİSTİK]",
		"icon": "📦",
		"specs": "Tüm silahların mermisini tamamen doldurur",
		"desc": "Operasyon sırasında mermisiz kalmayın. Taşıdığınız tüm silahların cephanesini maksimum seviyeye çıkarır.",
		"cost": 45,
		"is_weapon": false
	},
	{
		"id": "medkit",
		"title": "ASKERİ MEDKİT",
		"badge": "[SAĞLIK]",
		"icon": "💉",
		"specs": "+60 Can Yeniler ve Yaralanmaları İyileştirir",
		"desc": "Kritik can seviyelerinde anında acil durum tedavisi uygulayarak personeli ayakta tutar.",
		"cost": 40,
		"is_weapon": false
	},
	{
		"id": "barrels",
		"title": "VARİL PAKETİ",
		"badge": "[TAKTİK TUZAK]",
		"icon": "💣",
		"specs": "+3 Adet Taktik Patlayıcı Varil [G]",
		"desc": "Zeminlere yerleştirip vurarak zombileri toplu halde havaya uçurabileceğiniz taktik variller.",
		"cost": 35,
		"is_weapon": false
	},
	{
		"id": "wall_boost",
		"title": "BARİKAT KİTİ",
		"badge": "[İSTİHKAM]",
		"icon": "🧱",
		"specs": "+5 Maksimum Duvar ve Anında Tam Dolum",
		"desc": "Duvarcı personelin barikat kurma kapasitesini artırır ve anında tüm duvarları yeniler.",
		"cost": 40,
		"is_weapon": false
	}
]

# 3. Zırh & Güçlendirme Kataloğu
const PERK_CATALOG: Array[Dictionary] = [
	{
		"id": "armor",
		"title": "KEVLAR ZIRH",
		"badge": "[HAYATTA KALMA]",
		"icon": "🛡️",
		"specs": "+40 Maksimum Can & Canı Tamamen Fuller",
		"desc": "Gövde zırhı ekleyerek azami can havuzunuzu genişletir ve tüm hasarı anında iyileştirir.",
		"cost": 70,
		"is_weapon": false
	},
	{
		"id": "damage",
		"title": "DELİCİ ÇEKİRDEK",
		"badge": "[OFANSİF]",
		"icon": "⚡",
		"specs": "Tüm Silah Hasarları Kalıcı Olarak +%25 Artar",
		"desc": "Ağır kalibre mermiler zombilerin gövdesini parçalar ve tüm silahların öldürücülüğünü yükseltir.",
		"cost": 85,
		"is_weapon": false
	},
	{
		"id": "speed",
		"title": "TAKTİK KUNDAK",
		"badge": "[MOBİLİTE]",
		"icon": "💨",
		"specs": "Koşma Hızı +%18 & Atış Hızı +%15 Artar",
		"desc": "Daha seri hareket kabiliyeti ve refleks atış imkânı sunar.",
		"cost": 65,
		"is_weapon": false
	},
	{
		"id": "droprate",
		"title": "GANİMET RADARI",
		"badge": "[ŞANS / EKONOMİ]",
		"icon": "📡",
		"specs": "Zombilerden Altın ve Eşya Düşme Şansı +%50 Artar",
		"desc": "Zombilerin taşıdığı ikmal malzemelerini tespit ederek sahada daha fazla cephane ve altın bulunmasını sağlar.",
		"cost": 60,
		"is_weapon": false
	}
]

func _ready() -> void:
	visible = false
	
	if tab_weapons_btn:
		tab_weapons_btn.pressed.connect(func(): _switch_category("weapons"))
	if tab_supplies_btn:
		tab_supplies_btn.pressed.connect(func(): _switch_category("supplies"))
	if tab_perks_btn:
		tab_perks_btn.pressed.connect(func(): _switch_category("perks"))
	
	if back_to_levels_btn:
		back_to_levels_btn.pressed.connect(_on_back_to_levels_pressed)
	if skill_tree_btn:
		skill_tree_btn.pressed.connect(_on_skill_tree_pressed)
	if next_floor_btn:
		next_floor_btn.pressed.connect(_on_next_floor_pressed)
	
	if SaveManager:
		SaveManager.bio_cores_changed.connect(func(_amt): _update_wallet())

func open_shop(p_player: CharacterBody3D, floor_num: int) -> void:
	local_player = p_player
	current_floor = floor_num
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if local_player and local_player.has_method("set_in_shop"):
		local_player.set_in_shop(true)
	
	if title_label:
		title_label.text = "🛒 TAKTİKSEL KARABORSA // KAT %02d OPERASYON İKMALİ" % current_floor
	
	if next_floor_btn:
		if multiplayer.is_server():
			next_floor_btn.text = "🚀 SONRAKİ SEVİYEYİ BAŞLAT"
			next_floor_btn.disabled = false
			next_floor_btn.tooltip_text = "Seviyeyi tüm takım için başlat"
		else:
			next_floor_btn.text = "ODA SAHİBİ BEKLENİYOR..."
			next_floor_btn.disabled = true
			next_floor_btn.tooltip_text = "Yalnızca oda sahibi sonraki seviyeyi başlatabilir"
	
	_switch_category("weapons")

func close_shop() -> void:
	visible = false
	if local_player and local_player.has_method("set_in_shop"):
		local_player.set_in_shop(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _switch_category(cat: String) -> void:
	active_category = cat
	_update_tab_styles()
	_update_wallet()
	_populate_products()

func _update_tab_styles() -> void:
	var tabs = {
		"weapons": tab_weapons_btn,
		"supplies": tab_supplies_btn,
		"perks": tab_perks_btn
	}
	
	for key in tabs:
		var btn = tabs[key]
		if btn:
			if key == active_category:
				btn.modulate = Color(1.0, 1.0, 1.0)
			else:
				btn.modulate = Color(0.65, 0.7, 0.8)

func _update_wallet() -> void:
	if local_player and gold_label:
		gold_label.text = "💰 KREDİ: " + str(local_player.gold)
	if bio_cores_label and SaveManager:
		bio_cores_label.text = "🧬 BİYO-ÇEKİRDEK: " + str(SaveManager.get_bio_cores())

func _populate_products() -> void:
	if not cards_container:
		return
	
	for child in cards_container.get_children():
		child.queue_free()
	
	var catalog: Array[Dictionary] = []
	match active_category:
		"weapons": catalog = WEAPON_CATALOG
		"supplies": catalog = SUPPLY_CATALOG
		"perks": catalog = PERK_CATALOG
	
	for item in catalog:
		var card = _create_product_card(item)
		cards_container.add_child(card)

## E-Ticaret Ürün Kartı Arayüz Elemanı
func _create_product_card(item: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(230, 0)
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.055, 0.07, 0.1, 0.95)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.2, 0.32, 0.46, 0.7)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.content_margin_left = 12
	card_style.content_margin_top = 12
	card_style.content_margin_right = 12
	card_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_style)
	
	var vbox = VBoxContainer.new()
	vbox.theme_override_constants.set("separation", 8)
	
	# 1. Kategori / Özellik Rozeti
	var badge_lbl = Label.new()
	badge_lbl.text = item.get("badge", "[ÜRÜN]")
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 10)
	badge_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vbox.add_child(badge_lbl)
	
	# 2. İkon
	var icon_lbl = Label.new()
	icon_lbl.text = item.get("icon", "📦")
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 34)
	vbox.add_child(icon_lbl)
	
	# 3. Başlık
	var title_lbl = Label.new()
	title_lbl.text = item.get("title", "")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox.add_child(title_lbl)
	
	# 4. Özellikler
	var specs_lbl = Label.new()
	specs_lbl.text = item.get("specs", "")
	specs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	specs_lbl.add_theme_font_size_override("font_size", 10)
	specs_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	specs_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(specs_lbl)
	
	# 5. Açıklama
	var desc_lbl = Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)
	
	# 6. Fiyat Etiketi
	var cost = int(item.get("cost", 50))
	var is_weapon = bool(item.get("is_weapon", false))
	var is_unlocked = is_weapon and SaveManager.is_weapon_unlocked(item.get("id", ""))
	
	var price_lbl = Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 13)
	if is_unlocked:
		price_lbl.text = "✓ KİLİT AÇILDI"
		price_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		price_lbl.text = "FİYAT: %d KREDİ" % cost
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	vbox.add_child(price_lbl)
	
	# 7. Satın Alma / Unlock Butonu
	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(0, 36)
	buy_btn.add_theme_font_size_override("font_size", 11)
	
	var player_gold = local_player.gold if local_player else 0
	
	if is_weapon:
		if is_unlocked:
			# Silah zaten açık; mermisi azalmışsa mermi alma fırsatı sun
			var current_ammo = local_player.weapon_ammo_dict.get(item.get("id"), 0) if local_player else 0
			var max_ammo = local_player.WEAPON_MAX_AMMO.get(item.get("id"), 100) if local_player else 100
			if current_ammo < max_ammo:
				buy_btn.text = "📦 CEPHANE AL (35 💰)"
				buy_btn.disabled = (player_gold < 35)
				buy_btn.pressed.connect(func(): _buy_ammo(item.get("id"), item.get("ammo_reward", 12), 35))
			else:
				buy_btn.text = "✓ AÇIK (DROPLANIR)"
				buy_btn.disabled = true
		else:
			buy_btn.text = "🛒 KİLİDİ AÇ (%d 💰)" % cost
			buy_btn.disabled = (player_gold < cost)
			buy_btn.pressed.connect(func(): _unlock_weapon(item))
	else:
		buy_btn.text = "🛒 SATIN AL (%d 💰)" % cost
		buy_btn.disabled = (player_gold < cost)
		buy_btn.pressed.connect(func(): _buy_supply_or_perk(item))
	
	vbox.add_child(buy_btn)
	card.add_child(vbox)
	return card

## Silah Kilidini Açma ve Envantere Ekleme (Gold İle)
func _unlock_weapon(item: Dictionary) -> void:
	if not local_player:
		return
	var cost = int(item.get("cost", 100))
	if local_player.gold < cost:
		SoundManager.play_sfx("empty")
		return
	
	local_player.gold -= cost
	var w_id = str(item.get("id", ""))
	var ammo_rew = int(item.get("ammo_reward", 12))
	
	# 1. Kalıcı kayıt ve oturuma ekle
	SaveManager.unlock_weapon(w_id)
	
	# 2. Çok oyunculuda sunucuya bildir ki zombiler bu silahı düşürmeye başlasın
	var main_level = get_tree().get_first_node_in_group("main_level")
	if main_level and main_level.has_method("sync_unlock_weapon"):
		main_level.sync_unlock_weapon.rpc(w_id)
	
	# 3. Oyuncuya anında silahı ver ve donat
	local_player.apply_pickup(w_id, ammo_rew)
	if local_player.has_method("sync_player_stats"):
		local_player.sync_player_stats.rpc(local_player.gold)
	
	SoundManager.play_sfx("pickup")
	if local_player.has_method("_show_weapon_notice"):
		local_player._show_weapon_notice("🎉 " + item.get("title", "").to_upper() + " AÇILDI! ARTIK SAHADA DÜŞEBİLİR!")
	
	_update_wallet()
	_populate_products()

## Açılmış Silaha Ek Mermi Satın Alma
func _buy_ammo(w_id: String, ammo_amount: int, cost: int) -> void:
	if not local_player or local_player.gold < cost:
		SoundManager.play_sfx("empty")
		return
	local_player.gold -= cost
	local_player.apply_pickup(w_id, ammo_amount)
	if local_player.has_method("sync_player_stats"):
		local_player.sync_player_stats.rpc(local_player.gold)
	SoundManager.play_sfx("pickup")
	_update_wallet()
	_populate_products()

## İkmal ve Güçlendirme Satın Alma
func _buy_supply_or_perk(item: Dictionary) -> void:
	if not local_player:
		return
	var cost = int(item.get("cost", 40))
	if local_player.gold < cost:
		SoundManager.play_sfx("empty")
		return
	
	local_player.gold -= cost
	SoundManager.play_sfx("pickup")
	
	match item.get("id", ""):
		"full_ammo":
			for w in local_player.weapon_inventory:
				if local_player.weapon_ammo_dict.has(w):
					var max_c = local_player.WEAPON_MAX_AMMO.get(w, 200)
					local_player.weapon_ammo_dict[w] = max_c
			local_player._show_weapon_notice("📦 TÜM CEPHANELER TAMAMEN DOLDURULDU!")
		"medkit":
			local_player.current_health = min(local_player.max_health, local_player.current_health + 60.0)
			local_player._show_weapon_notice("💉 +60 CAN İYİLEŞTİRİLDİ!")
		"barrels":
			local_player.barrel_count += 3
			local_player._show_weapon_notice("💣 +3 TAKTİK PATLAYICI VARİL EKLENDİ!")
		"wall_boost":
			if local_player.get("max_wall_count") != null:
				local_player.max_wall_count += 5
				local_player.wall_count = local_player.max_wall_count
				if local_player.has_method("_update_wall_hud"):
					local_player._update_wall_hud()
			local_player._show_weapon_notice("🧱 +5 MAKSİMUM BARİKAT KAPASİTESİ!")
		"armor":
			local_player.max_health += 40.0
			local_player.current_health = local_player.max_health
			local_player._show_weapon_notice("🛡️ +40 AZAMİ CAN VE TAM ŞİFA!")
		"damage":
			local_player.stat_damage_mult += 0.25
			local_player._show_weapon_notice("⚡ SİLAH HASARI +%25 ARTIRILDI!")
		"speed":
			local_player.speed *= 1.18
			local_player.sprint_speed *= 1.18
			local_player.stat_firerate_mult += 0.15
			local_player._show_weapon_notice("💨 HAREKET +%18 & ATIŞ HIZI +%15 ARTIRILDI!")
		"droprate":
			local_player.stat_drop_luck += 0.50
			local_player._show_weapon_notice("📡 GANİMET DÜŞME ŞANSI +%50 ARTIRILDI!")
	
	if local_player.has_method("sync_player_stats"):
		local_player.sync_player_stats.rpc(local_player.gold)
	local_player._update_hud()
	
	_update_wallet()
	_populate_products()

func _on_skill_tree_pressed() -> void:
	var main_level = get_tree().get_first_node_in_group("main_level")
	if main_level and main_level.has_method("open_skill_tree_for_local_player"):
		main_level.open_skill_tree_for_local_player()
	else:
		var st = get_tree().get_first_node_in_group("skill_tree_ui")
		if st:
			st.open_for_player(local_player)

func _on_back_to_levels_pressed() -> void:
	close_shop()
	back_to_levels_requested.emit()

func _on_next_floor_pressed() -> void:
	if not multiplayer.is_server():
		return
	close_shop()
	next_floor_requested.emit()
