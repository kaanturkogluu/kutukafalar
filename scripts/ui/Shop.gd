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
var active_category: String = "weapons" # "weapons", "supplies", "perks", "upgrades"
var selected_upgrade_weapon: String = ""  # Hangi silahın yükseltmeleri gösteriliyor

# Perk ve silah yükseltme stack sayaçları (oturum bazlı)
# perk_stacks: { "armor": 2, "speed": 1 }
# weapon_upgrade_stacks: { "pistol": { "damage": 3, "firerate": 2 }, "shotgun": {...} }
var perk_stacks: Dictionary = {}
var weapon_upgrade_stacks: Dictionary = {}

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
# cost_base : taban fiyat (floor 1'de)
# cost_scale: her kat başına eklenen fiyat
# cost_stack: her alımda maliyet çarpanı
# max_stack : bu oturumda en fazla kaç kez alınabilir
const PERK_CATALOG: Array[Dictionary] = [
	{
		"id": "armor",
		"title": "KEVLAR ZIRH",
		"badge": "[HAYATTA KALMA]",
		"icon": "🛡️",
		"specs": "+40 Maksimum Can & Canı Tamamen Fuller",
		"desc": "Gövde zırhı ekleyerek azami can havuzunuzu genişletir ve tüm hasarı anında iyileştirir.",
		"cost_base": 70,
		"cost_scale": 5,
		"cost_stack": 1.4,
		"max_stack": 8,
		"cost": 70,
		"is_weapon": false
	},
	{
		"id": "speed",
		"title": "TAKTİK KUNDAK",
		"badge": "[MOBİLİTE]",
		"icon": "💨",
		"specs": "Koşma Hızı +%6 & Atış Hızı +%5 Artar",
		"desc": "Daha seri hareket kabiliyeti ve refleks atış imkânı. Azalan getirili: her alımda fiyat artar.",
		"cost_base": 65,
		"cost_scale": 6,
		"cost_stack": 1.5,
		"max_stack": 4,
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
		"cost_base": 60,
		"cost_scale": 5,
		"cost_stack": 1.3,
		"max_stack": 5,
		"cost": 60,
		"is_weapon": false
	}
]

# 4. Silah Üzerinde Yapılan Yükseltmeler (per-weapon upgrades)
# Bu katalog, sahip olunan her silah için uygulanır.
# player.weapon_upgrades = { "pistol": {"damage": 3, "firerate": 2, "ammo": 1}, ... }
const WEAPON_UPGRADE_CATALOG: Array[Dictionary] = [
	{
		"id": "damage",
		"title": "HASAR YÜKSELTMESİ",
		"badge": "[OFANSİF]",
		"icon": "⚡",
		"specs": "Silaha Özel Hasar +%2 (Kalıcı)",
		"desc": "Bu silahın namlusunu güçlendirir. Her kademe %2 hasar arttırır. Maksimum 10 kademe.",
		"cost_base": 80,
		"cost_scale": 7,
		"cost_stack": 1.35,
		"max_stack": 10,
		"stat_key": "damage",
		"stat_value": 0.02,
		"is_weapon": false
	},
	{
		"id": "firerate",
		"title": "ATIŞ HIZI YÜKSELTMESİ",
		"badge": "[MEKANİK]",
		"icon": "🔧",
		"specs": "Silaha Özel Atış Hızı +%2 (Kalıcı)",
		"desc": "Tetiği ve mekanizmayı optimize eder. Her kademe %2 atış hızı arttırır. Maksimum 10 kademe.",
		"cost_base": 70,
		"cost_scale": 6,
		"cost_stack": 1.3,
		"max_stack": 10,
		"stat_key": "firerate",
		"stat_value": 0.02,
		"is_weapon": false
	},
	{
		"id": "ammo",
		"title": "ŞARJÖRKAPASİTESİ YÜKSELTMESİ",
		"badge": "[LOJİSTİK]",
		"icon": "📦",
		"specs": "Silaha Özel Mermi Kapasitesi +%3 (Kalıcı)",
		"desc": "Şarjörü genişletir. Her kademe %3 kapasite arttırır. Maksimum 10 kademe.",
		"cost_base": 55,
		"cost_scale": 5,
		"cost_stack": 1.25,
		"max_stack": 10,
		"stat_key": "ammo",
		"stat_value": 0.03,
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

## Kat bazlı fiyat hesapla (silah ve ikmal için)
func _scaled_cost(base_cost: int, scale_per_floor: int = 4) -> int:
	return base_cost + current_floor * scale_per_floor

## Perk fiyatı: taban + kat katkısı + alım sayısına göre katlanma
func _perk_cost(item: Dictionary) -> int:
	var base = int(item.get("cost_base", item.get("cost", 60)))
	var scale = int(item.get("cost_scale", 5))
	var stack_mult = float(item.get("cost_stack", 1.3))
	var stacks = perk_stacks.get(item.get("id", ""), 0)
	var floor_price = base + current_floor * scale
	return int(floor_price * pow(stack_mult, stacks))

## Silah yükseltme fiyatı
func _weapon_upgrade_cost(weapon_id: String, upgrade_item: Dictionary) -> int:
	var base = int(upgrade_item.get("cost_base", 80))
	var scale = int(upgrade_item.get("cost_scale", 7))
	var stack_mult = float(upgrade_item.get("cost_stack", 1.35))
	var upg_id = upgrade_item.get("id", "")
	var stacks = weapon_upgrade_stacks.get(weapon_id, {}).get(upg_id, 0)
	var floor_price = base + current_floor * scale
	return int(floor_price * pow(stack_mult, stacks))

func open_shop(p_player: CharacterBody3D, floor_num: int) -> void:
	local_player = p_player
	current_floor = floor_num
	# Yeni kat → stack sayaçlarını sıfırla
	perk_stacks.clear()
	weapon_upgrade_stacks.clear()
	if local_player:
		for w in local_player.weapon_inventory:
			weapon_upgrade_stacks[w] = {}
	selected_upgrade_weapon = ""
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
	
	if active_category == "upgrades":
		_populate_weapon_upgrades()
		return
	
	var catalog: Array[Dictionary] = []
	match active_category:
		"weapons": catalog = WEAPON_CATALOG
		"supplies": catalog = SUPPLY_CATALOG
		"perks": catalog = PERK_CATALOG
	
	for item in catalog:
		# Kat bazlı fiyatları kopyada hesapla (const orijinaline dokunma)
		var resolved = item.duplicate()
		if active_category == "weapons" or active_category == "supplies":
			resolved["cost"] = _scaled_cost(int(item.get("cost", 40)), 4)
		elif active_category == "perks":
			resolved["cost"] = _perk_cost(item)
		var card = _create_product_card(resolved)
		cards_container.add_child(card)

## Silah seçimi gösteren kılavuz kartı ve silaha özel yükseltme kartlarını oluşturur
func _populate_weapon_upgrades() -> void:
	if not local_player:
		return
	
	var owned = local_player.weapon_inventory
	const WEAPON_NAMES = {
		"pistol": "TABANCA",
		"shotgun": "POMPALI TÜFEK",
		"uzi": "MICRO UZI",
		"bixi": "M249 BİXİ",
		"rocket": "RPG-7 ROKETATAR"
	}
	const WEAPON_ICONS = {"pistol": "🔫", "shotgun": "💥", "uzi": "⚡", "bixi": "🔫", "rocket": "🚀"}
	
	if selected_upgrade_weapon.is_empty() or not owned.has(selected_upgrade_weapon):
		# İlk açılışta: sahip olunan silahlar için seçim kartları göster
		for w_id in owned:
			var sel_card = PanelContainer.new()
			sel_card.custom_minimum_size = Vector2(200, 0)
			sel_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sel_style = StyleBoxFlat.new()
			sel_style.bg_color = Color(0.06, 0.1, 0.16, 0.95)
			sel_style.border_color = Color(0.35, 0.75, 1.0, 0.8)
			sel_style.border_width_bottom = 2
			sel_style.border_width_left = 1
			sel_style.border_width_top = 1
			sel_style.border_width_right = 1
			sel_style.corner_radius_top_left = 8
			sel_style.corner_radius_top_right = 8
			sel_style.corner_radius_bottom_left = 8
			sel_style.corner_radius_bottom_right = 8
			sel_style.content_margin_left = 12
			sel_style.content_margin_top = 12
			sel_style.content_margin_right = 12
			sel_style.content_margin_bottom = 12
			sel_card.add_theme_stylebox_override("panel", sel_style)
			
			var sel_vbox = VBoxContainer.new()
			sel_vbox.add_theme_constant_override("separation", 10)
			
			var icon_lbl = Label.new()
			icon_lbl.text = WEAPON_ICONS.get(w_id, "🔫")
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_lbl.add_theme_font_size_override("font_size", 34)
			sel_vbox.add_child(icon_lbl)
			
			var name_lbl = Label.new()
			name_lbl.text = WEAPON_NAMES.get(w_id, w_id.to_upper())
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.add_theme_font_size_override("font_size", 13)
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
			sel_vbox.add_child(name_lbl)
			
			# Mevcut yükseltme seviyeleri özet
			var stacks = weapon_upgrade_stacks.get(w_id, {})
			var summary = Label.new()
			summary.text = "⚡%d 🔧%d 📦%d" % [
				stacks.get("damage", 0),
				stacks.get("firerate", 0),
				stacks.get("ammo", 0)
			]
			summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			summary.add_theme_font_size_override("font_size", 11)
			summary.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
			sel_vbox.add_child(summary)
			
			var sel_btn = Button.new()
			sel_btn.text = "🔧 YÜKSELT"
			sel_btn.custom_minimum_size = Vector2(0, 34)
			sel_btn.add_theme_font_size_override("font_size", 11)
			var cap_w_id = w_id
			sel_btn.pressed.connect(func():
				selected_upgrade_weapon = cap_w_id
				_populate_products()
			)
			sel_vbox.add_child(sel_btn)
			sel_card.add_child(sel_vbox)
			cards_container.add_child(sel_card)
		return
	
	# Seçilen silah için 3 yükseltme kartı göster + geri butonu
	# Geri butonu
	var back_card = PanelContainer.new()
	back_card.custom_minimum_size = Vector2(120, 0)
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color(0.07, 0.09, 0.14, 0.9)
	back_style.border_color = Color(0.4, 0.5, 0.6, 0.6)
	back_style.border_width_left = 1
	back_style.border_width_top = 1
	back_style.border_width_right = 1
	back_style.border_width_bottom = 1
	back_style.corner_radius_top_left = 8
	back_style.corner_radius_top_right = 8
	back_style.corner_radius_bottom_left = 8
	back_style.corner_radius_bottom_right = 8
	back_style.content_margin_left = 8
	back_style.content_margin_top = 8
	back_style.content_margin_right = 8
	back_style.content_margin_bottom = 8
	back_card.add_theme_stylebox_override("panel", back_style)
	var back_vbox = VBoxContainer.new()
	back_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var weapon_name_lbl = Label.new()
	weapon_name_lbl.text = WEAPON_ICONS.get(selected_upgrade_weapon, "🔫") + " " + WEAPON_NAMES.get(selected_upgrade_weapon, selected_upgrade_weapon.to_upper())
	weapon_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_name_lbl.add_theme_font_size_override("font_size", 12)
	weapon_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	back_vbox.add_child(weapon_name_lbl)
	var back_btn = Button.new()
	back_btn.text = "← Silah Seç"
	back_btn.custom_minimum_size = Vector2(0, 34)
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.pressed.connect(func():
		selected_upgrade_weapon = ""
		_populate_products()
	)
	back_vbox.add_child(back_btn)
	back_card.add_child(back_vbox)
	cards_container.add_child(back_card)
	
	# 3 yükseltme kartı
	for upgrade_item in WEAPON_UPGRADE_CATALOG:
		var stacks_dict = weapon_upgrade_stacks.get(selected_upgrade_weapon, {})
		var upg_id = upgrade_item.get("id", "")
		var cur_stack = stacks_dict.get(upg_id, 0)
		var max_stack = int(upgrade_item.get("max_stack", 10))
		var cost = _weapon_upgrade_cost(selected_upgrade_weapon, upgrade_item)
		var stack_maxed = (cur_stack >= max_stack)
		
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(200, 0)
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.055, 0.07, 0.1, 0.95)
		card_style.border_color = Color(0.4, 0.7, 0.3, 0.7) if not stack_maxed else Color(0.5, 0.2, 0.2, 0.6)
		card_style.border_width_bottom = 2
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
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
		vbox.add_theme_constant_override("separation", 8)
		
		var badge_lbl = Label.new()
		badge_lbl.text = upgrade_item.get("badge", "[YÜKSELTME]")
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.add_theme_font_size_override("font_size", 10)
		badge_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		vbox.add_child(badge_lbl)
		
		var icon_lbl = Label.new()
		icon_lbl.text = upgrade_item.get("icon", "🔧")
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 34)
		vbox.add_child(icon_lbl)
		
		var title_lbl = Label.new()
		title_lbl.text = upgrade_item.get("title", "")
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 12)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		vbox.add_child(title_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = upgrade_item.get("desc", "")
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)
		
		var price_lbl = Label.new()
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.add_theme_font_size_override("font_size", 13)
		if stack_maxed:
			price_lbl.text = "⛔ MAK SİMUM (%d/%d)" % [cur_stack, max_stack]
			price_lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
		else:
			price_lbl.text = "FİYAT: %d 💰  [%d/%d]" % [cost, cur_stack, max_stack]
			price_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
		vbox.add_child(price_lbl)
		
		var buy_btn = Button.new()
		buy_btn.custom_minimum_size = Vector2(0, 34)
		buy_btn.add_theme_font_size_override("font_size", 11)
		if stack_maxed:
			buy_btn.text = "⛔ DOLU"
			buy_btn.disabled = true
		else:
			var player_gold = local_player.gold if local_player else 0
			buy_btn.text = "🔧 YÜKSELT (%d 💰)" % cost
			buy_btn.disabled = (player_gold < cost)
			var cap_wid = selected_upgrade_weapon
			var cap_item = upgrade_item
			buy_btn.pressed.connect(func(): _buy_weapon_upgrade(cap_wid, cap_item))
		vbox.add_child(buy_btn)
		card.add_child(vbox)
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
	vbox.add_theme_constant_override("separation", 8)
	
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
	var item_id = item.get("id", "")
	var max_stack = int(item.get("max_stack", 0))  # 0 = sınırsız (ikmal)
	var cur_stack = perk_stacks.get(item_id, 0)
	var stack_maxed = (max_stack > 0 and cur_stack >= max_stack)
	
	var price_lbl = Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 13)
	if is_unlocked:
		price_lbl.text = "✓ KİLİT AÇILDI"
		price_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	elif stack_maxed:
		price_lbl.text = "⛔ MAKSİMUM (%d/%d)" % [cur_stack, max_stack]
		price_lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	else:
		var price_text = "FİYAT: %d 💰" % cost
		if max_stack > 0:
			price_text += "  [%d/%d]" % [cur_stack, max_stack]
		price_lbl.text = price_text
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
			var current_ammo = local_player.weapon_ammo_dict.get(item_id, 0) if (local_player and "weapon_ammo_dict" in local_player) else 0
			var max_ammo = 100
			if local_player and "WEAPON_MAX_AMMO" in local_player:
				max_ammo = local_player.WEAPON_MAX_AMMO.get(item_id, 100)
			var ammo_cost = _scaled_cost(35, 2)
			if current_ammo < max_ammo:
				buy_btn.text = "📦 CEPHANE AL (%d 💰)" % ammo_cost
				buy_btn.disabled = (player_gold < ammo_cost)
				buy_btn.pressed.connect(func(): _buy_ammo(item_id, item.get("ammo_reward", 12), ammo_cost))
			else:
				buy_btn.text = "✓ AÇIK (DROPLANIR)"
				buy_btn.disabled = true
		else:
			buy_btn.text = "🛒 KİLİDİ AÇ (%d 💰)" % cost
			buy_btn.disabled = (player_gold < cost)
			buy_btn.pressed.connect(func(): _unlock_weapon(item))
	elif stack_maxed:
		buy_btn.text = "⛔ DOLU"
		buy_btn.disabled = true
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
	var item_id = item.get("id", "")
	var max_stack = int(item.get("max_stack", 0))
	var cur_stack = perk_stacks.get(item_id, 0)
	if max_stack > 0 and cur_stack >= max_stack:
		SoundManager.play_sfx("empty")
		return
	
	# Güncel fiyatı tekrar hesapla (buton basılırken)
	var cost: int
	if max_stack > 0:  # perk
		cost = _perk_cost(item)
	else:  # ikmal
		cost = _scaled_cost(int(item.get("cost", 40)), 4)
	
	if local_player.gold < cost:
		SoundManager.play_sfx("empty")
		return
	
	local_player.gold -= cost
	SoundManager.play_sfx("pickup")
	
	# Stack artır (perk ise)
	if max_stack > 0:
		perk_stacks[item_id] = cur_stack + 1
	
	match item_id:
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
			local_player._show_weapon_notice("🛡️ +40 AZAMİ CAN VE TAM ŞİFA! [%d/%d]" % [perk_stacks.get(item_id, 1), max_stack])
		"speed":
			# Her alımda +%6 hız, +%5 atış hızı (max 4 alım → +%24 hız)
			local_player.speed *= 1.06
			local_player.sprint_speed *= 1.06
			local_player.stat_firerate_mult += 0.05
			local_player._show_weapon_notice("💨 HAREKET +%%6 & ATIŞ HIZI +%%5! [%d/%d]" % [perk_stacks.get(item_id, 1), max_stack])
		"droprate":
			local_player.stat_drop_luck += 0.50
			local_player._show_weapon_notice("📡 GANİMET DÜŞME ŞANSI +%%50! [%d/%d]" % [perk_stacks.get(item_id, 1), max_stack])
	
	if local_player.has_method("sync_player_stats"):
		local_player.sync_player_stats.rpc(local_player.gold)
	local_player._update_hud()
	
	_update_wallet()
	_populate_products()

## Silaha Özel Yükseltme Satın Alma
func _buy_weapon_upgrade(weapon_id: String, upgrade_item: Dictionary) -> void:
	if not local_player:
		return
	var upg_id = upgrade_item.get("id", "")
	var max_stack = int(upgrade_item.get("max_stack", 10))
	if not weapon_upgrade_stacks.has(weapon_id):
		weapon_upgrade_stacks[weapon_id] = {}
	var cur_stack = weapon_upgrade_stacks[weapon_id].get(upg_id, 0)
	if cur_stack >= max_stack:
		SoundManager.play_sfx("empty")
		return
	
	var cost = _weapon_upgrade_cost(weapon_id, upgrade_item)
	if local_player.gold < cost:
		SoundManager.play_sfx("empty")
		return
	
	local_player.gold -= cost
	SoundManager.play_sfx("pickup")
	weapon_upgrade_stacks[weapon_id][upg_id] = cur_stack + 1
	
	var new_stack = cur_stack + 1
	var stat_val = float(upgrade_item.get("stat_value", 0.02))
	
	match upg_id:
		"damage":
			# Silaha özel hasar çarpanını weapon_damage_mults dict'inde sakla
			if not "weapon_damage_mults" in local_player:
				local_player.set("weapon_damage_mults", {})
			var mults = local_player.get("weapon_damage_mults") as Dictionary
			if mults != null:
				mults[weapon_id] = 1.0 + (new_stack * stat_val)
			local_player._show_weapon_notice("⚡ [%s] HASAR +%%%.0f [%d/10]" % [weapon_id.to_upper(), new_stack * stat_val * 100, new_stack])
		"firerate":
			if not "weapon_firerate_mults" in local_player:
				local_player.set("weapon_firerate_mults", {})
			var mults = local_player.get("weapon_firerate_mults") as Dictionary
			if mults != null:
				mults[weapon_id] = 1.0 + (new_stack * stat_val)
			local_player._show_weapon_notice("🔧 [%s] ATIŞ HIZI +%%%.0f [%d/10]" % [weapon_id.to_upper(), new_stack * stat_val * 100, new_stack])
		"ammo":
			# Kapasite: o silahın mevcut max ammo'sunu artır
			if "WEAPON_MAX_AMMO" in local_player and weapon_id != "pistol":
				var base_max = local_player.WEAPON_MAX_AMMO.get(weapon_id, 100)
				# weapon_ammo_cap_overrides ile override takibi
				if not "weapon_ammo_cap_overrides" in local_player:
					local_player.set("weapon_ammo_cap_overrides", {})
				var caps = local_player.get("weapon_ammo_cap_overrides") as Dictionary
				if caps != null:
					var current_cap = caps.get(weapon_id, base_max)
					caps[weapon_id] = int(current_cap * (1.0 + stat_val))
				local_player._show_weapon_notice("📦 [%s] KAPATİE +%%3 [%d/10]" % [weapon_id.to_upper(), new_stack])
	
	if local_player.has_method("sync_player_stats"):
		local_player.sync_player_stats.rpc(local_player.gold)
	local_player._update_hud()
	_update_wallet()
	_populate_products()

## Tab sekme butonu - Yükseltmeler sekmesi bağlantısı
func switch_to_upgrades() -> void:
	_switch_category("upgrades")

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
