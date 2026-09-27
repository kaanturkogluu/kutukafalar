extends Control

# --- Kutu Kafalar: Taktiksel Horde Hayatta Kalma - Ana Menü ve Lobi Sistemi ---
const GAME_SCENE_PATH: String = "res://scenes/levels/main_level.tscn"

# 1. Ana Menü Navigasyonu
@onready var main_nav: VBoxContainer = %MainNavigation
@onready var nav_single_btn: Button = %NavSingleBtn
@onready var nav_multi_btn: Button = %NavMultiBtn
@onready var nav_settings_btn: Button = %NavSettingsBtn
@onready var nav_quit_btn: Button = %NavQuitBtn

# 2. Tek Oyuncu Paneli
@onready var single_panel: PanelContainer = %SingleplayerPanel
@onready var single_name_input: LineEdit = %SingleNameInput
@onready var single_class_option: OptionButton = %SingleClassOption
@onready var selected_map_title: Label = %SelectedMapTitle
@onready var selected_map_sector: Label = %SelectedMapSector
@onready var select_map_btn: Button = %SelectMapBtn
@onready var single_resume_btn: Button = %SingleResumeBtn
@onready var single_floor1_btn: Button = %SingleFloor1Btn
@onready var floor_progress_label: Label = %FloorProgressLabel
@onready var single_start_btn: Button = %SingleStartBtn
@onready var single_back_btn: Button = %SingleBackBtn

# 3. Çok Oyunculu Paneli
@onready var multi_panel: PanelContainer = %MultiplayerPanel
@onready var multi_name_input: LineEdit = %MultiNameInput
@onready var multi_class_option: OptionButton = %MultiClassOption
@onready var host_btn: Button = %HostBtn
@onready var tab_ip_btn: Button = %TabIpBtn
@onready var tab_code_btn: Button = %TabCodeBtn
@onready var ip_join_box: VBoxContainer = %IpJoinBox
@onready var ip_input: LineEdit = %IpInput
@onready var join_ip_btn: Button = %JoinIpBtn
@onready var code_join_box: VBoxContainer = %CodeJoinBox
@onready var code_input: LineEdit = %CodeInput
@onready var join_code_btn: Button = %JoinCodeBtn
@onready var multi_back_btn: Button = %MultiBackBtn
@onready var status_label: Label = %StatusLabel

# 4. Bekleme Odası (Room Panel)
@onready var room_panel: PanelContainer = %RoomPanel
@onready var room_info_label: Label = %RoomInfoLabel
@onready var room_class_option: OptionButton = %RoomClassOption
@onready var player_list_box: VBoxContainer = %PlayerListBox
@onready var room_status_label: Label = %RoomStatusLabel
@onready var ready_btn: Button = %ReadyBtn
@onready var start_game_btn: Button = %StartGameBtn
@onready var leave_room_btn: Button = %LeaveRoomBtn

# 5. Sürüm ve Otomatik Güncelleyici
@onready var version_label: Label = %VersionLabel
@onready var update_overlay: ColorRect = %UpdateOverlay
@onready var update_info_label: Label = %UpdateInfoLabel
@onready var update_notes_label: Label = %UpdateNotesLabel
@onready var update_progress_bar: ProgressBar = %UpdateProgressBar
@onready var update_progress_text: Label = %UpdateProgressText
@onready var start_update_btn: Button = %StartUpdateBtn
@onready var dismiss_update_btn: Button = %DismissUpdateBtn

# 6. 3D Taktik Tim Arka Planı
@onready var squad_bg: SquadBackground3D = %SquadBackground3D

# 7. Ayarlar Paneli
@onready var settings_overlay: ColorRect = %SettingsOverlay
@onready var close_settings_btn: Button = %CloseSettingsBtn
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_box: HBoxContainer = %ResolutionBox
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckBox = %VSyncCheck
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_label: Label = %VolumeLabel
@onready var sens_slider: HSlider = %SensSlider
@onready var sens_label: Label = %SensLabel

# 8. Sınıf Taktik Yetenek Kartı (Glassmorphism & HUD - 2 Ayrı Kutucuk)
@onready var class_skills_container: VBoxContainer = %ClassSkillsContainer
@onready var skill_class_title: Label = %SkillClassTitle
@onready var skill_role_desc: Label = %SkillRoleDesc
@onready var tactical_skill_box: PanelContainer = %TacticalSkillBox
@onready var skill_tactical_title: Label = %SkillTacticalTitle
@onready var skill_tactical_desc: Label = %SkillTacticalDesc
@onready var ult_skill_box: PanelContainer = %UltSkillBox
@onready var skill_ult_title: Label = %SkillUltTitle
@onready var skill_ult_desc: Label = %SkillUltDesc

# 9. Seviye / Harita Seçim Arayüzü
@onready var level_select_ui: CanvasLayer = %LevelSelectUI

const CLASS_SKILLS: Dictionary = {
	"Pyromancer": {
		"title": "ATEŞ UZMANI",
		"role": "[SALDIRI / ALAN HASARI]",
		"tactical_title": "[E] TAKTİK: ALEV DALGASI (14s Bekleme)",
		"tactical_desc": "İleriye doğru yayılan yakıcı alev dalgası savurur. Sürüleri ateşe verir ve yüksek hasar uygular.",
		"ult_title": "[Q] NİHAİ: KIYAMET METEORU",
		"ult_desc": "Hedef noktaya gökyüzünden alevli meteor düşürür. Etki alanındaki tüm zombileri anında yok eder.",
		"ult_color": Color(1.0, 0.45, 0.35)
	},
	"Engineer": {
		"title": "DUVARCI (MÜHENDİS)",
		"role": "[SAVUNMA / ALAN KONTROLÜ]",
		"tactical_title": "[E] TAKTİK: BARİKAT & VORTEX (14s Bekleme)",
		"tactical_desc": "Zombi geçişlerini kesen taktik barikat kurar veya manyetik vortex bombasıyla düşmanları toplar.",
		"ult_title": "[Q] NİHAİ: GRAVİTON EMP PATLAMASI",
		"ult_desc": "Yerçekimsel şok dalgası yayarak hedef bölgedeki tüm zombi sürülerini ezer ve savurur.",
		"ult_color": Color(0.35, 0.85, 1.0)
	},
	"Cryomancer": {
		"title": "BUZ MUHAFIZI",
		"role": "[KONTROL / DONDURMA]",
		"tactical_title": "[E] TAKTİK: KRİYOJENİK BUZ BOMBASI (14s Bekleme)",
		"tactical_desc": "Çarptığı bölgedeki zombileri anında dondurarak hareket kabiliyetlerini felç eder.",
		"ult_title": "[Q] NİHAİ: BUZ FIRTINASI (GLACIAL BLAST)",
		"ult_desc": "Geniş bir alana devasa buz sarkıtları yağdırarak zombi sürülerini dondurup parçalar.",
		"ult_color": Color(0.45, 0.9, 1.0)
	},
	"Medic": {
		"title": "SIHHİYE (DOKTOR)",
		"role": "[DESTEK / TAKIM HAYATTA KALMA]",
		"tactical_title": "[E] TAKTİK: ŞİFA ŞİŞESİ (14s Bekleme)",
		"tactical_desc": "Patladığı alana taktik şifa sisi yayar. Alandaki tüm dost personelin canını hızla yeniler.",
		"ult_title": "[Q] NİHAİ: AŞIRI YÜKLEME (MEDIC OVERDRIVE)",
		"ult_desc": "Tüm ekibin canını anında %100'e çıkarır ve yere düşmüş takım arkadaşlarını kaldırır.",
		"ult_color": Color(0.35, 1.0, 0.55)
	}
}

var is_local_ready: bool = false
var active_join_mode: String = "ip" # "ip" veya "code"

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if version_label:
		var v_str = AutoUpdater.get_current_version()
		if not v_str.begins_with("v"):
			v_str = "v" + v_str
		version_label.text = v_str
		version_label.mouse_filter = Control.MOUSE_FILTER_STOP
		version_label.tooltip_text = "Güncellemeleri denetlemek için tıklayın"
		version_label.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				version_label.text = v_str + " (Denetleniyor...)"
				AutoUpdater.check_for_updates()
		)
	
	# Sınıf Açılır Menülerini Doldur (İkonsuz / Ciddi Taktiksel İsimler)
	_setup_class_options()
	
	# Ana Navigasyon Bağlantıları
	nav_single_btn.pressed.connect(_on_nav_single_pressed)
	nav_multi_btn.pressed.connect(_on_nav_multi_pressed)
	nav_settings_btn.pressed.connect(_on_nav_settings_pressed)
	nav_quit_btn.pressed.connect(_on_nav_quit_pressed)
	
	# Tek Oyunculu Butonları
	single_start_btn.pressed.connect(_on_single_start_pressed)
	single_back_btn.pressed.connect(_show_main_nav)
	if select_map_btn:
		select_map_btn.pressed.connect(_on_select_map_pressed)
	if single_resume_btn:
		single_resume_btn.pressed.connect(_on_single_resume_pressed)
	if single_floor1_btn:
		single_floor1_btn.pressed.connect(_on_single_floor1_pressed)
	if level_select_ui:
		level_select_ui.map_chosen_for_lobby.connect(_on_map_chosen_from_level_select)
	
	# Çok Oyunculu Butonları
	host_btn.pressed.connect(_on_host_pressed)
	multi_back_btn.pressed.connect(_show_main_nav)
	tab_ip_btn.pressed.connect(func(): _set_join_mode("ip"))
	tab_code_btn.pressed.connect(func(): _set_join_mode("code"))
	join_ip_btn.pressed.connect(_on_join_ip_pressed)
	join_code_btn.pressed.connect(_on_join_code_pressed)
	
	# Oda Butonları
	ready_btn.pressed.connect(_on_ready_pressed)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	leave_room_btn.pressed.connect(_on_leave_room_pressed)
	
	# Ağ Yöneticisi Sinyalleri
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.game_rejected.connect(_on_game_rejected)
	
	# Ayarlar Paneli
	_setup_settings_ui()
	
	# Otomatik Güncelleyici Sinyalleri
	_setup_autoupdater()
	
	# Varsayılan panel görünümü
	_show_main_nav()
	_set_join_mode("ip")
	
	# 3D Sahneyi varsayılan sınıfla başlat ve yetenek kartını senkronize et
	var default_class = NetworkManager.local_player_class if NetworkManager.local_player_class != "" else "Pyromancer"
	if squad_bg:
		squad_bg.select_class(default_class, true)
	_update_class_skill_card(default_class)
	
	# Açılışta sessizce güncelleme kontrolü
	get_tree().create_timer(0.6).timeout.connect(func(): AutoUpdater.check_for_updates())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and squad_bg:
		squad_bg.update_cursor(event.position, get_viewport_rect().size)
		# 3D karakterin üzerinde miyiz kontrolü
		if event.position.x > 468 and (single_panel.visible or multi_panel.visible or room_panel.visible):
			var hover_char = squad_bg.get_character_under_mouse(event.position, get_viewport_rect().size)
			if hover_char != "":
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if squad_bg and event.position.x > 468 and (single_panel.visible or multi_panel.visible or room_panel.visible):
			var clicked_class = squad_bg.get_character_under_mouse(event.position, get_viewport_rect().size)
			if clicked_class != "":
				var idx = _get_index_from_class_code(clicked_class)
				_on_class_selected(idx)
		
	if event.is_action_pressed("ui_cancel"):
		if settings_overlay and settings_overlay.visible:
			settings_overlay.visible = false
			get_viewport().set_input_as_handled()
		elif room_panel.visible:
			pass # Odadan yanlışlıkla çıkmayı önlemek için ESC ile çıkış yapmıyoruz
		elif single_panel.visible or multi_panel.visible:
			_show_main_nav()
			get_viewport().set_input_as_handled()

# --- Sınıf Seçimleri ---

func _setup_class_options() -> void:
	var classes = [
		{"name": "Ateş Uzmanı (Pyromancer)", "code": "Pyromancer", "id": 0},
		{"name": "Duvarcı (Taktiksel Barikat)", "code": "Engineer", "id": 1},
		{"name": "Buz Muhafızı (Kriyojenik)", "code": "Cryomancer", "id": 2},
		{"name": "Sıhhiye (Şifa & Destek)", "code": "Medic", "id": 3}
	]
	
	for opt in [single_class_option, multi_class_option, room_class_option]:
		if opt:
			opt.clear()
			for c in classes:
				opt.add_item(c["name"], c["id"])
			opt.select(0)
	
	single_class_option.item_selected.connect(_on_class_selected)
	multi_class_option.item_selected.connect(_on_class_selected)
	room_class_option.item_selected.connect(_on_class_selected)

func _on_class_selected(index: int) -> void:
	var class_code = _get_class_code_from_index(index)
	NetworkManager.set_local_class(class_code)
	
	# Tüm menülerdeki seçimi senkronize et
	if single_class_option: single_class_option.select(index)
	if multi_class_option: multi_class_option.select(index)
	if room_class_option: room_class_option.select(index)
	
	# 3D karakteri öne getir ve vurgula
	if squad_bg:
		squad_bg.select_class(class_code)
	
	# Sağ alt köşedeki taktiksel yetenek kartını güncelle
	_update_class_skill_card(class_code)

func _get_class_code_from_index(index: int) -> String:
	match index:
		0: return "Pyromancer"
		1: return "Engineer"
		2: return "Cryomancer"
		3: return "Medic"
	return "Pyromancer"

func _get_index_from_class_code(code: String) -> int:
	match code:
		"Pyromancer": return 0
		"Engineer": return 1
		"Cryomancer": return 2
		"Medic": return 3
	return 0

func _get_class_display_title(class_code: String) -> String:
	match class_code:
		"Pyromancer": return "ATEŞ UZMANI"
		"Engineer": return "DUVARCI"
		"Cryomancer": return "BUZ MUHAFIZI"
		"Medic": return "SIHHİYE"
		_: return class_code.to_upper()

func _update_class_skill_card(class_code: String) -> void:
	if not class_skills_container:
		return
	
	var data = CLASS_SKILLS.get(class_code, CLASS_SKILLS["Pyromancer"])
	if skill_class_title:
		skill_class_title.text = data["title"]
		var title_color = Color(1.0, 0.85, 0.35)
		match class_code:
			"Pyromancer": title_color = Color(1.0, 0.82, 0.30)
			"Engineer": title_color = Color(1.0, 0.95, 0.25)
			"Cryomancer": title_color = Color(0.40, 0.95, 1.0)
			"Medic": title_color = Color(0.35, 1.0, 0.65)
		skill_class_title.add_theme_color_override("font_color", title_color)
	if skill_role_desc:
		skill_role_desc.text = data["role"]
	if skill_tactical_title:
		skill_tactical_title.text = data["tactical_title"]
	if skill_tactical_desc:
		skill_tactical_desc.text = data["tactical_desc"]
	if skill_ult_title:
		skill_ult_title.text = data["ult_title"]
		skill_ult_title.add_theme_color_override("font_color", data.get("ult_color", Color(1.0, 0.45, 0.35)))
	if skill_ult_desc:
		skill_ult_desc.text = data["ult_desc"]

# --- Panel Geçişleri ---

func _show_main_nav() -> void:
	main_nav.visible = true
	single_panel.visible = false
	multi_panel.visible = false
	room_panel.visible = false
	if class_skills_container:
		class_skills_container.visible = false

func _show_single_panel() -> void:
	main_nav.visible = false
	single_panel.visible = true
	multi_panel.visible = false
	room_panel.visible = false
	if class_skills_container:
		class_skills_container.visible = true
	_update_selected_map_display()

func _show_multi_panel() -> void:
	main_nav.visible = false
	single_panel.visible = false
	multi_panel.visible = true
	room_panel.visible = false
	if class_skills_container:
		class_skills_container.visible = true
	status_label.text = ""

func _show_room_panel() -> void:
	main_nav.visible = false
	single_panel.visible = false
	multi_panel.visible = false
	room_panel.visible = true
	if class_skills_container:
		class_skills_container.visible = true
	is_local_ready = false
	_update_room_buttons()

func _set_join_mode(mode: String) -> void:
	active_join_mode = mode
	if mode == "ip":
		ip_join_box.visible = true
		code_join_box.visible = false
		tab_ip_btn.modulate = Color(1.0, 1.0, 1.0)
		tab_code_btn.modulate = Color(0.65, 0.65, 0.7)
	else:
		ip_join_box.visible = false
		code_join_box.visible = true
		tab_ip_btn.modulate = Color(0.65, 0.65, 0.7)
		tab_code_btn.modulate = Color(1.0, 1.0, 1.0)

# --- Navigasyon Buton Aksiyonları ---

func _on_nav_single_pressed() -> void:
	_show_single_panel()

func _on_nav_multi_pressed() -> void:
	_show_multi_panel()

func _on_nav_settings_pressed() -> void:
	if settings_overlay:
		settings_overlay.visible = true
		_sync_settings_to_ui()

func _on_nav_quit_pressed() -> void:
	get_tree().quit()

# --- Tek Oyunculu Başlatma ve Kat Seçimi ---

func _update_selected_map_display() -> void:
	var starting_floor = SaveManager.get_starting_floor()
	var max_unlocked = SaveManager.get_highest_unlocked_floor()
	var last_played = SaveManager.get_last_played_floor()
	
	if starting_floor > max_unlocked:
		starting_floor = max_unlocked
		SaveManager.set_starting_floor(starting_floor)
	
	var fname = LevelData.FLOOR_NAMES.get(starting_floor, "Kat " + str(starting_floor))
	var is_boss = LevelData.is_boss_level(starting_floor)
	var ch = LevelData.get_chapter_for_level(starting_floor)
	
	if selected_map_title:
		selected_map_title.text = "KAT %02d: %s%s" % [starting_floor, fname.to_upper(), " [BOSS TEHLİKESİ]" if is_boss else ""]
		if is_boss:
			selected_map_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		else:
			selected_map_title.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))
			
	if selected_map_sector:
		selected_map_sector.text = "SEKTÖR %d // %s" % [ch.get("sector", 1), str(ch.get("theme", "")).to_upper()]
	
	if single_resume_btn:
		single_resume_btn.text = "[SON KALINAN: KAT %02d]" % last_played
	
	if floor_progress_label:
		floor_progress_label.text = "EN YÜKSEK AÇIK SEVİYE: KAT %02d / 99" % max_unlocked

func _on_select_map_pressed() -> void:
	if level_select_ui:
		var current_start = SaveManager.get_starting_floor()
		var max_unlocked = SaveManager.get_highest_unlocked_floor()
		level_select_ui.open_for_lobby(current_start, max_unlocked)

func _on_map_chosen_from_level_select(floor_num: int) -> void:
	SaveManager.set_starting_floor(floor_num)
	_update_selected_map_display()

func _on_single_resume_pressed() -> void:
	var last_floor = SaveManager.get_last_played_floor()
	SaveManager.set_starting_floor(last_floor)
	_update_selected_map_display()

func _on_single_floor1_pressed() -> void:
	SaveManager.set_starting_floor(1)
	_update_selected_map_display()

func _on_single_start_pressed() -> void:
	var player_name = single_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Kutu Asker"
	
	var chosen_class = _get_class_code_from_index(single_class_option.selected)
	NetworkManager.local_player_info["class"] = chosen_class
	
	var chosen_floor = SaveManager.get_starting_floor()
	single_start_btn.disabled = true
	single_start_btn.text = "KAT %02d BAŞLATILIYOR..." % chosen_floor
	
	# Tek oyuncu için yerel host başlatılır ve doğrudan sahne açılır
	var err = NetworkManager.create_game(player_name, 7000)
	if err == OK:
		NetworkManager.start_game()
	else:
		single_start_btn.disabled = false
		single_start_btn.text = "OYUNA BAŞLA"

# --- Çok Oyunculu Oda Kurma ve Katılma ---

func _on_host_pressed() -> void:
	var player_name = multi_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Kutu Komutan"
	
	var chosen_class = _get_class_code_from_index(multi_class_option.selected)
	NetworkManager.local_player_info["class"] = chosen_class
	
	host_btn.disabled = true
	status_label.text = "Lobi oluşturuluyor..."
	
	var error = NetworkManager.create_game(player_name, 7000)
	host_btn.disabled = false
	if error == OK:
		_show_room_panel()
		var local_ip = _get_local_ip()
		var room_code = _ip_to_code(local_ip)
		room_info_label.text = "Oda Kodu: " + room_code + "  |  Yerel IP: " + local_ip
		_refresh_player_list()
	else:
		status_label.text = "Hata: Oda oluşturulamadı! (Port 7000 meşgul olabilir)"

func _on_join_ip_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	_attempt_join(ip)

func _on_join_code_pressed() -> void:
	var raw_code = code_input.text.strip_edges()
	if raw_code.is_empty():
		status_label.text = "Lütfen 8 haneli oda kodunu girin."
		return
	
	var target_ip = _code_to_ip(raw_code)
	_attempt_join(target_ip)

func _attempt_join(target_ip: String) -> void:
	var player_name = multi_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Kutu Asker " + str(randi_range(10, 99))
	
	var chosen_class = _get_class_code_from_index(multi_class_option.selected)
	NetworkManager.local_player_info["class"] = chosen_class
	
	status_label.text = "Bağlanılıyor: " + target_ip + "..."
	join_ip_btn.disabled = true
	join_code_btn.disabled = true
	
	var error = NetworkManager.join_game(target_ip, player_name, 7000)
	if error != OK:
		status_label.text = "Hata: Bağlantı başlatılamadı!"
		join_ip_btn.disabled = false
		join_code_btn.disabled = false

# --- IP ve Oda Kodu Çevrim Fonksiyonları ---

func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			return ip
	return "127.0.0.1"

func _ip_to_code(ip_str: String) -> String:
	var parts = ip_str.split(".")
	if parts.size() != 4:
		return ip_str
	var code = ""
	for p in parts:
		code += "%02X" % clampi(p.to_int(), 0, 255)
	return code

func _code_to_ip(code_str: String) -> String:
	var s = code_str.strip_edges().to_upper()
	if s.contains("."):
		return s
	if s.length() == 8:
		var parts: Array[String] = []
		for i in range(4):
			var sub = s.substr(i * 2, 2)
			var b = sub.hex_to_int()
			parts.append(str(b))
		return ".".join(parts)
	return code_str

# --- Bekleme Odası Yönetimi ---

func _on_ready_pressed() -> void:
	is_local_ready = not is_local_ready
	NetworkManager.set_local_ready(is_local_ready)
	_update_room_buttons()

func _on_start_game_pressed() -> void:
	if multiplayer.is_server():
		start_game_btn.disabled = true
		room_status_label.text = "Oyun başlatılıyor... Bölge yükleniyor."
		NetworkManager.start_game()

func _on_leave_room_pressed() -> void:
	NetworkManager.disconnect_game()
	_show_main_nav()

func _update_room_buttons() -> void:
	if multiplayer.is_server():
		ready_btn.visible = false
		start_game_btn.visible = true
	else:
		ready_btn.visible = true
		start_game_btn.visible = false
		if is_local_ready:
			ready_btn.text = "HAZIR DEĞİL"
			ready_btn.modulate = Color(1.0, 0.45, 0.45)
		else:
			ready_btn.text = "HAZIR"
			ready_btn.modulate = Color(0.4, 0.9, 0.5)

func _refresh_player_list() -> void:
	for child in player_list_box.get_children():
		child.queue_free()
	
	var all_ready = true
	var player_count = NetworkManager.players.size()
	
	for id in NetworkManager.players.keys():
		var p_info = NetworkManager.players[id]
		var p_name = p_info.get("name", "Bilinmeyen Asker")
		var p_class = p_info.get("class", "Pyromancer")
		var is_ready = p_info.get("is_ready", false)
		var is_host = (id == 1)
		
		if not is_ready and not is_host:
			all_ready = false
		
		# Oyuncu Listesi Kartı
		var row = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 8)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		
		# İsim ve rol
		var name_lbl = Label.new()
		name_lbl.text = ("[LİDER] " if is_host else "") + p_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if is_host else Color(0.9, 0.92, 0.96))
		hbox.add_child(name_lbl)
		
		# Sınıf
		var class_lbl = Label.new()
		class_lbl.text = _get_class_display_title(p_class)
		class_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 0.92))
		hbox.add_child(class_lbl)
		
		# Hazır Durumu
		var status_badge = Label.new()
		if is_host:
			status_badge.text = "[ODA KURUCU]"
			status_badge.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		elif is_ready:
			status_badge.text = "[HAZIR]"
			status_badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		else:
			status_badge.text = "[BEKLİYOR]"
			status_badge.add_theme_color_override("font_color", Color(0.85, 0.45, 0.35))
		hbox.add_child(status_badge)
		
		margin.add_child(hbox)
		row.add_child(margin)
		player_list_box.add_child(row)
	
	if multiplayer.is_server():
		if player_count <= 1:
			room_status_label.text = "Diğer oyuncuların katılması bekleniyor..."
			start_game_btn.disabled = false
		elif all_ready:
			room_status_label.text = "Tüm ekip hazır! Operasyonu başlatabilirsiniz."
			room_status_label.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45))
			start_game_btn.disabled = false
		else:
			room_status_label.text = "Diğer personelin hazır olması bekleniyor..."
			room_status_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.35))
			start_game_btn.disabled = false

# --- Ağ Geri Bildirimleri ---

func _on_connection_succeeded() -> void:
	join_ip_btn.disabled = false
	join_code_btn.disabled = false
	_show_room_panel()
	var entered_target = ip_input.text.strip_edges() if active_join_mode == "ip" else code_input.text.strip_edges()
	room_info_label.text = "Bağlanıldı: " + entered_target
	_update_room_buttons()

func _on_connection_failed() -> void:
	join_ip_btn.disabled = false
	join_code_btn.disabled = false
	_show_multi_panel()
	status_label.text = "Bağlantı kurulamadı. Sunucu açık mı ve IP/Kod doğru mu?"

func _on_server_disconnected() -> void:
	join_ip_btn.disabled = false
	join_code_btn.disabled = false
	_show_main_nav()

func _on_game_rejected(reason: String) -> void:
	join_ip_btn.disabled = false
	join_code_btn.disabled = false
	_show_multi_panel()
	status_label.text = "Bağlantı reddedildi: " + reason

func _on_lobby_updated(_players_dict: Dictionary) -> void:
	_refresh_player_list()
	_update_room_buttons()

# --- Ayarlar Paneli ---

func _setup_settings_ui() -> void:
	if close_settings_btn:
		close_settings_btn.pressed.connect(func():
			if settings_overlay:
				settings_overlay.visible = false
		)

	if window_mode_option:
		window_mode_option.clear()
		window_mode_option.add_item("Pencereli (Windowed)", 0)
		window_mode_option.add_item("Kenarlıksız (Borderless)", 1)
		window_mode_option.add_item("Tam Ekran (Fullscreen)", 2)
		window_mode_option.item_selected.connect(_on_window_mode_selected)

	if resolution_option:
		resolution_option.clear()
		for i in range(SettingsManager.RESOLUTION_PRESETS.size()):
			var res = SettingsManager.RESOLUTION_PRESETS[i]
			resolution_option.add_item(str(res.x) + " x " + str(res.y), i)
		resolution_option.item_selected.connect(_on_resolution_selected)

	if vsync_check:
		vsync_check.toggled.connect(func(enabled: bool):
			SettingsManager.set_vsync(enabled)
		)

	if volume_slider:
		volume_slider.value_changed.connect(func(val: float):
			SettingsManager.set_master_volume(val)
			if volume_label:
				volume_label.text = "ANA SES: %" + str(int(val * 100))
		)

	if sens_slider:
		sens_slider.value_changed.connect(func(val: float):
			SettingsManager.set_mouse_sensitivity(val)
			if sens_label:
				sens_label.text = "FARE HASSASİYETİ: " + str(snapped(val * 1000.0, 0.1))
		)

	_sync_settings_to_ui()

func _sync_settings_to_ui() -> void:
	if window_mode_option:
		window_mode_option.select(SettingsManager.current_window_mode)
	if resolution_box:
		resolution_box.visible = (SettingsManager.current_window_mode == SettingsManager.WindowMode.WINDOWED)
	if vsync_check:
		vsync_check.button_pressed = SettingsManager.vsync_enabled
	if volume_slider:
		volume_slider.value = SettingsManager.master_volume
		if volume_label:
			volume_label.text = "ANA SES: %" + str(int(SettingsManager.master_volume * 100))
	if sens_slider:
		sens_slider.value = SettingsManager.mouse_sensitivity
		if sens_label:
			sens_label.text = "FARE HASSASİYETİ: " + str(snapped(SettingsManager.mouse_sensitivity * 1000.0, 0.1))

func _on_window_mode_selected(idx: int) -> void:
	SettingsManager.set_window_mode(idx)
	if resolution_box:
		resolution_box.visible = (idx == SettingsManager.WindowMode.WINDOWED)

func _on_resolution_selected(idx: int) -> void:
	if idx >= 0 and idx < SettingsManager.RESOLUTION_PRESETS.size():
		SettingsManager.set_resolution(SettingsManager.RESOLUTION_PRESETS[idx])

# --- Otomatik Güncelleyici ---

func _setup_autoupdater() -> void:
	if start_update_btn:
		start_update_btn.pressed.connect(_on_start_update_pressed)
	if dismiss_update_btn:
		dismiss_update_btn.pressed.connect(func(): update_overlay.visible = false)
	
	AutoUpdater.update_available.connect(_on_update_available)
	AutoUpdater.update_not_available.connect(_on_update_not_available)
	AutoUpdater.download_progress.connect(_on_download_progress)
	AutoUpdater.download_completed.connect(_on_download_completed)
	AutoUpdater.update_failed.connect(_on_update_failed)

func _on_update_available(version_tag: String, changelog: String, _url: String, pck_size: int) -> void:
	update_info_label.text = "Yeni Sürüm: " + version_tag + " (" + str(maxi(1, int(pck_size / 1024))) + " KB)"
	update_notes_label.text = changelog
	update_progress_bar.visible = false
	update_progress_text.visible = false
	start_update_btn.disabled = false
	dismiss_update_btn.disabled = false
	update_overlay.visible = true

func _on_update_not_available(_ver: String) -> void:
	if version_label:
		var v_str = AutoUpdater.get_current_version()
		if not v_str.begins_with("v"):
			v_str = "v" + v_str
		version_label.text = v_str

func _on_start_update_pressed() -> void:
	start_update_btn.disabled = true
	dismiss_update_btn.disabled = true
	update_progress_bar.visible = true
	update_progress_bar.value = 0
	update_progress_text.visible = true
	update_progress_text.text = "İndiriliyor... %0"
	AutoUpdater.start_download()

func _on_download_progress(percent: float, downloaded: int, total: int) -> void:
	update_progress_bar.value = percent
	var dl_kb = maxi(0, int(downloaded / 1024))
	var tot_kb = maxi(0, int(total / 1024))
	if tot_kb > 0:
		update_progress_text.text = "İndiriliyor... %%%d (%d KB / %d KB)" % [int(percent), dl_kb, tot_kb]
	else:
		update_progress_text.text = "İndiriliyor... %%%d" % int(percent)

func _on_download_completed() -> void:
	update_progress_bar.value = 100
	update_progress_text.text = "Güncelleme hazır! Oyun yeniden başlatılıyor..."
	await get_tree().create_timer(1.0).timeout
	AutoUpdater.apply_update_and_restart()

func _on_update_failed(reason: String) -> void:
	if update_overlay.visible:
		update_progress_text.text = "Güncelleme Hatası: " + reason
		start_update_btn.disabled = false
		dismiss_update_btn.disabled = false
