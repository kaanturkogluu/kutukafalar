extends CanvasLayer

# --- Profesyonel Taktiksel Seviye Seçim Penceresi (No Icons, Sleek Modern Grid) ---
signal level_start_requested(target_level: int)
signal shop_requested

@onready var panel: Panel = $Panel
@onready var chapter_title: Label = $Panel/VBoxContainer/HeaderBox/ChapterTitle
@onready var completed_label: Label = $Panel/VBoxContainer/HeaderBox/CompletedLabel
@onready var grid_container: GridContainer = $Panel/VBoxContainer/GridContainer
@onready var detail_title: Label = $Panel/VBoxContainer/DetailCard/VBox/DetailTitle
@onready var detail_desc: Label = $Panel/VBoxContainer/DetailCard/VBox/DetailDesc
@onready var start_button: Button = $Panel/VBoxContainer/HBoxActions/StartLevelButton
@onready var shop_button: Button = $Panel/VBoxContainer/HBoxActions/ShopButton

var current_completed_level: int = 1
var selected_level: int = 2
var max_unlocked_level: int = 2
var level_buttons: Dictionary = {} # level_num -> Button

# Seviye isimleri (Profesyonel taktiksel başlıklar - Emojisiz)
const LEVEL_SUBTITLES: Dictionary = {
	1: "SOKAK GİRİŞİ",
	2: "KAVŞAK DEVRİYESİ",
	3: "PARK ALANI",
	4: "KUZEY ÇIKMAZI",
	5: "BARİKAT HATTI",
	6: "EVLER BÖLGESİ",
	7: "BAKKAL VİTRİNİ",
	8: "DAR GEÇİTLER",
	9: "MAHALLE ŞEFİ [BOSS]"
}

# Taktiksel İstihbarat ve Görev Detayları
const LEVEL_DESCRIPTIONS: Dictionary = {
	1: "Mahallenin girişindeki ilk zombi dalgalarını temizleyin. Temel hareket ve nişan alma becerilerini test edin.",
	2: "Dört yol ağzında devriye görevi. Zombiler her iki caddeden aynı anda yaklaşacak. Çapraz ateşe dikkat edin.",
	3: "Geniş park alanında çatışma. Açık alanda hareketli kalarak zombi sürüsünü arkanızda toplayın.",
	4: "Kuzey çıkmazı barikatları. Dar koridorda patlayıcı varilleri kullanarak kalabalık grupları yok edin.",
	5: "Savunma hattı testi. Hızlı zombi koşucuları ön saflarda hücuma kalkacak. Mesafenizi koruyun.",
	6: "Terk edilmiş evler arası devriye. Binaların arasından çıkan pusulara karşı arkanızı kollayın.",
	7: "Yağmalanmış bakkal etrafında çatışma. Hurda araçları ve siperleri kullanarak zombi akınını kırın.",
	8: "Bölüm Şefi öncesi son dar geçitler. Yoğun zombi hücumu bekleniyor, mühimmatı tasarruflu harcayın.",
	9: "Mahalle Şefi sahneye iniyor! Yüksek can ve ezici saldırı gücüne sahip. Varilleri stratejik patlatın."
}

func _ready() -> void:
	visible = false
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if shop_button:
		shop_button.pressed.connect(_on_shop_pressed)

func open_level_window(completed_lvl: int, p_max_unlocked: int = -1) -> void:
	current_completed_level = completed_lvl
	if p_max_unlocked > 0:
		max_unlocked_level = p_max_unlocked
	else:
		max_unlocked_level = max(max_unlocked_level, completed_lvl + 1)
	
	selected_level = clamp(completed_lvl + 1, 1, 9)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_level_grid()
	_update_details()

func close_level_window() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_level_grid() -> void:
	if not grid_container:
		return
	
	# Eski butonları temizle
	for child in grid_container.get_children():
		child.queue_free()
	level_buttons.clear()
	
	var info = LevelData.get_chapter_for_level(selected_level)
	if chapter_title:
		chapter_title.text = "BÖLÜM %d: %s" % [info.get("chapter", 1), str(info.get("theme", "BÖLGE")).to_upper()]
	if completed_label:
		completed_label.text = "SON GÖREV: SEVİYE %d TAMAMLANDI" % current_completed_level

	# 1'den 9'a kadar seviye grid kartları oluştur (3x3 Yan Yana Grid)
	for lvl in range(1, 10):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(236, 72)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var is_locked = lvl > max_unlocked_level
		btn.disabled = is_locked
		
		# Buton tıklandığında seviyeyi seç
		btn.pressed.connect(func(): _select_level(lvl))
		
		grid_container.add_child(btn)
		level_buttons[lvl] = btn
		_style_button(btn, lvl)

func _select_level(lvl: int) -> void:
	if lvl > max_unlocked_level:
		return
	selected_level = lvl
	_update_details()
	# Tüm butonların stillerini ve seçili durum metinlerini güncelle
	for l in level_buttons.keys():
		_style_button(level_buttons[l], l)

func _style_button(btn: Button, lvl: int) -> void:
	var is_completed = lvl <= current_completed_level
	var is_locked = lvl > max_unlocked_level
	var is_boss = (lvl == 9)
	var subtitle = LEVEL_SUBTITLES.get(lvl, "SEVİYE " + str(lvl))
	
	var status_text = "AÇIK"
	if lvl == selected_level:
		status_text = "SEÇİLİ"
	elif is_completed:
		status_text = "TAMAMLANDI"
	elif lvl == current_completed_level + 1:
		status_text = "SIRADAKİ GÖREV"
	elif is_locked:
		status_text = "KİLİTLİ"
	
	if is_boss and not is_completed and lvl != selected_level:
		status_text = "BOSS TEHLİKESİ"

	btn.text = "SEVİYE %02d: %s\n[ %s ]" % [lvl, subtitle, status_text]
	
	# Temel Normal Stil
	var normal_sb = StyleBoxFlat.new()
	normal_sb.corner_radius_top_left = 6
	normal_sb.corner_radius_top_right = 6
	normal_sb.corner_radius_bottom_right = 6
	normal_sb.corner_radius_bottom_left = 6
	normal_sb.content_margin_top = 8
	normal_sb.content_margin_bottom = 8
	normal_sb.content_margin_left = 10
	normal_sb.content_margin_right = 10
	
	# Hover Stili
	var hover_sb = normal_sb.duplicate() as StyleBoxFlat

	if lvl == selected_level:
		# Aktif Seçili Kart: Kehribar (Amber) Taktiksel Çerçeve
		normal_sb.bg_color = Color(0.13, 0.10, 0.05, 0.95)
		normal_sb.border_color = Color(0.95, 0.68, 0.18, 1.0)
		normal_sb.border_width_left = 3
		normal_sb.border_width_top = 1
		normal_sb.border_width_right = 1
		normal_sb.border_width_bottom = 1
		
		hover_sb.bg_color = Color(0.18, 0.14, 0.07, 1.0)
		hover_sb.border_color = Color(1.0, 0.82, 0.35, 1.0)
		hover_sb.border_width_left = 4
		hover_sb.border_width_top = 1
		hover_sb.border_width_right = 1
		hover_sb.border_width_bottom = 1
		
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	elif is_completed:
		# Tamamlanmış Görev: Koyu Taktiksel Zümrüt Yeşili
		normal_sb.bg_color = Color(0.06, 0.11, 0.08, 0.9)
		normal_sb.border_color = Color(0.2, 0.48, 0.3, 0.9)
		normal_sb.border_width_left = 2
		normal_sb.border_width_top = 1
		normal_sb.border_width_right = 1
		normal_sb.border_width_bottom = 1
		
		hover_sb.bg_color = Color(0.09, 0.16, 0.12, 1.0)
		hover_sb.border_color = Color(0.3, 0.72, 0.45, 1.0)
		hover_sb.border_width_left = 3
		hover_sb.border_width_top = 1
		hover_sb.border_width_right = 1
		hover_sb.border_width_bottom = 1
		
		btn.add_theme_color_override("font_color", Color(0.7, 0.92, 0.76))
		btn.add_theme_color_override("font_hover_color", Color(0.9, 1.0, 0.94))
	elif is_locked:
		# Kilitli Görev: Sönük Grafit Gri
		normal_sb.bg_color = Color(0.05, 0.06, 0.08, 0.6)
		normal_sb.border_color = Color(0.16, 0.18, 0.22, 0.4)
		normal_sb.border_width_left = 1
		normal_sb.border_width_top = 1
		normal_sb.border_width_right = 1
		normal_sb.border_width_bottom = 1
		hover_sb = normal_sb
		btn.add_theme_color_override("font_disabled_color", Color(0.36, 0.4, 0.46))
	else:
		# Açık Görev (Sıradaki veya Oynanabilir)
		if is_boss:
			normal_sb.bg_color = Color(0.18, 0.07, 0.08, 0.95)
			normal_sb.border_color = Color(0.75, 0.22, 0.25, 0.9)
			hover_sb.bg_color = Color(0.25, 0.09, 0.11, 1.0)
			hover_sb.border_color = Color(0.95, 0.35, 0.4, 1.0)
			btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.9))
		else:
			normal_sb.bg_color = Color(0.08, 0.11, 0.15, 0.9)
			normal_sb.border_color = Color(0.22, 0.32, 0.45, 0.8)
			hover_sb.bg_color = Color(0.13, 0.18, 0.24, 0.95)
			hover_sb.border_color = Color(0.95, 0.68, 0.18, 0.9)
			btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.96))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		normal_sb.border_width_left = 1
		normal_sb.border_width_top = 1
		normal_sb.border_width_right = 1
		normal_sb.border_width_bottom = 1
		hover_sb.border_width_left = 3
		hover_sb.border_width_top = 1
		hover_sb.border_width_right = 1
		hover_sb.border_width_bottom = 1

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", hover_sb)
	btn.add_theme_stylebox_override("disabled", normal_sb)
	if not is_locked:
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _update_details() -> void:
	var info = LevelData.get_chapter_for_level(selected_level)
	var subtitle = LEVEL_SUBTITLES.get(selected_level, "SEVİYE " + str(selected_level))
	var desc = LEVEL_DESCRIPTIONS.get(selected_level, "Zombi sürüleri açık sokak aralıklarından hücum edecek.")
	
	if detail_title:
		if info.get("is_boss_level", false):
			detail_title.text = "GÖREV DOSYASI // SEVİYE %02d: %s [BOSS TEHLİKESİ]" % [selected_level, subtitle]
			detail_title.modulate = Color(1.0, 0.35, 0.35)
		else:
			detail_title.text = "GÖREV DOSYASI // SEVİYE %02d: %s" % [selected_level, subtitle]
			detail_title.modulate = Color(0.35, 0.85, 1.0)
	
	if detail_desc:
		detail_desc.text = desc
	
	if start_button:
		if multiplayer.is_server():
			start_button.text = "SEVİYE %02d BAŞLAT" % selected_level
			start_button.disabled = false
		else:
			start_button.text = "ODA SAHİBİNİN SEVİYEYİ SEÇMESİ BEKLENİYOR..."
			start_button.disabled = true

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		level_start_requested.emit(selected_level)

func _on_shop_pressed() -> void:
	shop_requested.emit()
