extends CanvasLayer

# --- Profesyonel Taktiksel Seviye Seçim Penceresi (11 Sektör & 99 Kat Desteği) ---
signal level_start_requested(target_level: int)
signal shop_requested
signal map_chosen_for_lobby(floor_num: int)

@onready var panel: Panel = $Panel
@onready var header_box: VBoxContainer = $Panel/VBoxContainer/HeaderBox
@onready var chapter_title: Label = $Panel/VBoxContainer/HeaderBox/ChapterTitle
@onready var completed_label: Label = $Panel/VBoxContainer/HeaderBox/CompletedLabel
@onready var grid_container: GridContainer = $Panel/VBoxContainer/GridContainer
@onready var detail_title: Label = $Panel/VBoxContainer/DetailCard/VBox/DetailTitle
@onready var detail_desc: Label = $Panel/VBoxContainer/DetailCard/VBox/DetailDesc
@onready var start_button: Button = $Panel/VBoxContainer/HBoxActions/StartLevelButton
@onready var shop_button: Button = $Panel/VBoxContainer/HBoxActions/ShopButton
@onready var close_button: Button = get_node_or_null("Panel/VBoxContainer/HBoxActions/CloseButton")

var is_in_lobby: bool = false
var current_completed_level: int = 1
var selected_level: int = 1
var max_unlocked_level: int = 1
var current_viewed_sector: int = 1
var level_buttons: Dictionary = {} # level_num -> Button

var sector_nav_box: HBoxContainer = null
var prev_sector_btn: Button = null
var next_sector_btn: Button = null

func _ready() -> void:
	visible = false
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if shop_button:
		shop_button.pressed.connect(_on_shop_pressed)
	if close_button:
		close_button.pressed.connect(close_level_window)
	_setup_sector_navigation()

func _setup_sector_navigation() -> void:
	if not header_box:
		return
	
	sector_nav_box = HBoxContainer.new()
	sector_nav_box.alignment = BoxContainer.ALIGNMENT_CENTER
	sector_nav_box.theme_override_constants.set("separation", 16)
	
	prev_sector_btn = Button.new()
	prev_sector_btn.text = "< ÖNCEKİ SEKTÖR"
	prev_sector_btn.custom_minimum_size = Vector2(160, 32)
	prev_sector_btn.pressed.connect(_on_prev_sector_pressed)
	
	next_sector_btn = Button.new()
	next_sector_btn.text = "SONRAKİ SEKTÖR >"
	next_sector_btn.custom_minimum_size = Vector2(160, 32)
	next_sector_btn.pressed.connect(_on_next_sector_pressed)
	
	sector_nav_box.add_child(prev_sector_btn)
	sector_nav_box.add_child(next_sector_btn)
	header_box.add_child(sector_nav_box)

func _on_prev_sector_pressed() -> void:
	if current_viewed_sector > 1:
		current_viewed_sector -= 1
		_build_level_grid()

func _on_next_sector_pressed() -> void:
	if current_viewed_sector < 11:
		current_viewed_sector += 1
		_build_level_grid()

func open_for_lobby(current_lvl: int, p_max_unlocked: int = -1) -> void:
	is_in_lobby = true
	if p_max_unlocked > 0:
		max_unlocked_level = p_max_unlocked
	else:
		max_unlocked_level = SaveManager.get_highest_unlocked_floor()
	
	selected_level = clampi(current_lvl, 1, max_unlocked_level)
	current_completed_level = max(0, max_unlocked_level - 1)
	
	var info = LevelData.get_chapter_for_level(selected_level)
	current_viewed_sector = info.get("sector", 1)
	
	if shop_button:
		shop_button.visible = false
	if close_button:
		close_button.visible = true
	
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_level_grid()
	_update_details()

func open_level_window(completed_lvl: int, p_max_unlocked: int = -1) -> void:
	is_in_lobby = false
	if shop_button:
		shop_button.visible = true
	if close_button:
		close_button.visible = false
	
	current_completed_level = completed_lvl
	if p_max_unlocked > 0:
		max_unlocked_level = p_max_unlocked
	else:
		max_unlocked_level = max(SaveManager.get_highest_unlocked_floor(), completed_lvl + 1)
	
	selected_level = clampi(completed_lvl + 1, 1, 99)
	var info = LevelData.get_chapter_for_level(selected_level)
	current_viewed_sector = info.get("sector", 1)
	
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_level_grid()
	_update_details()

func close_level_window() -> void:
	visible = false
	if not is_in_lobby:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_level_grid() -> void:
	if not grid_container:
		return
	
	for child in grid_container.get_children():
		child.queue_free()
	level_buttons.clear()
	
	current_viewed_sector = clampi(current_viewed_sector, 1, 11)
	var sector_data = LevelData.SECTORS[current_viewed_sector - 1]
	var min_lvl: int = sector_data["min_level"]
	var max_lvl: int = sector_data["max_level"]
	
	if chapter_title:
		chapter_title.text = "SEKTÖR %d / 11: %s (KAT %02d - %02d)" % [current_viewed_sector, str(sector_data.get("theme", "")).to_upper(), min_lvl, max_lvl]
	if completed_label:
		completed_label.text = "EN YÜKSEK AÇIK KAT: %02d // TAHLİYEYE KALAN: %d KAT" % [max_unlocked_level, max(0, 99 - max_unlocked_level)]
	
	if prev_sector_btn:
		prev_sector_btn.disabled = (current_viewed_sector <= 1)
	if next_sector_btn:
		next_sector_btn.disabled = (current_viewed_sector >= 11)

	# Bu sektörün 9 katlık grid kartlarını oluştur (3x3 Yan Yana Grid)
	for lvl in range(min_lvl, max_lvl + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(236, 72)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var is_locked = lvl > max_unlocked_level
		btn.disabled = is_locked
		
		var target_lvl = lvl
		btn.pressed.connect(func(): _select_level(target_lvl))
		
		grid_container.add_child(btn)
		level_buttons[lvl] = btn
		_style_button(btn, lvl)

func _select_level(lvl: int) -> void:
	if lvl > max_unlocked_level:
		return
	selected_level = lvl
	_update_details()
	for l in level_buttons.keys():
		_style_button(level_buttons[l], l)

func _style_button(btn: Button, lvl: int) -> void:
	var is_completed = lvl <= current_completed_level
	var is_locked = lvl > max_unlocked_level
	var is_boss = LevelData.is_boss_level(lvl)
	var subtitle = LevelData.FLOOR_NAMES.get(lvl, "KAT " + str(lvl)).to_upper()
	
	var status_text = "AÇIK"
	if lvl == selected_level:
		status_text = "SEÇİLİ"
	elif is_completed:
		status_text = "TAMAMLANDI"
	elif lvl == current_completed_level + 1:
		status_text = "SIRADAKİ KAT"
	elif is_locked:
		status_text = "KİLİTLİ"
	
	if is_boss and not is_completed and lvl != selected_level:
		status_text = "BOSS TEHLİKESİ"

	btn.text = "KAT %02d: %s\n[ %s ]" % [lvl, subtitle, status_text]
	
	var normal_sb = StyleBoxFlat.new()
	normal_sb.corner_radius_top_left = 6
	normal_sb.corner_radius_top_right = 6
	normal_sb.corner_radius_bottom_right = 6
	normal_sb.corner_radius_bottom_left = 6
	normal_sb.content_margin_top = 8
	normal_sb.content_margin_bottom = 8
	normal_sb.content_margin_left = 10
	normal_sb.content_margin_right = 10
	
	var hover_sb = normal_sb.duplicate() as StyleBoxFlat

	if lvl == selected_level:
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
		normal_sb.bg_color = Color(0.02, 0.025, 0.035, 0.85)
		normal_sb.border_color = Color(0.09, 0.11, 0.14, 0.45)
		normal_sb.border_width_left = 1
		normal_sb.border_width_top = 1
		normal_sb.border_width_right = 1
		normal_sb.border_width_bottom = 1
		hover_sb = normal_sb
		btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.28, 0.33))
	else:
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
	var subtitle = LevelData.FLOOR_NAMES.get(selected_level, "KAT " + str(selected_level)).to_upper()
	
	if detail_title:
		if info.get("is_boss_level", false):
			detail_title.text = "GÖREV DOSYASI // KAT %02d: %s [BOSS TEHLİKESİ]" % [selected_level, subtitle]
			detail_title.modulate = Color(1.0, 0.35, 0.35)
		else:
			detail_title.text = "GÖREV DOSYASI // KAT %02d: %s" % [selected_level, subtitle]
			detail_title.modulate = Color(0.35, 0.85, 1.0)
	
	if detail_desc:
		if info.get("is_boss_level", false):
			detail_desc.text = "UYARI: %s bu katta bekliyor! Yüksek can ve ezici saldırı gücü. Varilleri ve siperleri koordineli kullanın." % str(info.get("boss_name", "SEKTÖR BOSS'U")).to_upper()
		else:
			detail_desc.text = "Sektör %d: %s. Zombi sürüleri açık koridor ve aralıklardan hücum edecek. Hedef: Asansörü açıp bir sonraki kata tırmanın." % [info.get("sector", 1), str(info.get("theme", ""))]
	
	if start_button:
		if is_in_lobby:
			start_button.text = "BU HARİTAYI SEÇ [KAT %02d]" % selected_level
			start_button.disabled = false
		elif multiplayer.is_server():
			start_button.text = "KAT %02d BAŞLAT" % selected_level
			start_button.disabled = false
		else:
			start_button.text = "ODA SAHİBİNİN SEVİYEYİ SEÇMESİ BEKLENİYOR..."
			start_button.disabled = true

func _on_start_pressed() -> void:
	if is_in_lobby:
		map_chosen_for_lobby.emit(selected_level)
		close_level_window()
	elif multiplayer.is_server():
		level_start_requested.emit(selected_level)

func _on_shop_pressed() -> void:
	shop_requested.emit()

func _input(event: InputEvent) -> void:
	if visible and is_in_lobby and event.is_action_pressed("ui_cancel"):
		close_level_window()
		get_viewport().set_input_as_handled()
