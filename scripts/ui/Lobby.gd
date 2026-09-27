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

var is_local_ready: bool = false
var active_join_mode: String = "ip" # "ip" veya "code"

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if version_label:
		version_label.text = "v" + AutoUpdater.CURRENT_VERSION
	
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
	
	# 3D Sahneyi varsayılan sınıfla başlat
	if squad_bg:
		squad_bg.select_class("Pyromancer", true)
	
	# Açılışta sessizce güncelleme kontrolü
	get_tree().create_timer(0.6).timeout.connect(func(): AutoUpdater.check_for_updates())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and squad_bg:
		squad_bg.update_cursor(event.position, get_viewport_rect().size)
		
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
		{"name": "Mühendis (Vortex Alanı)", "code": "Engineer", "id": 1},
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

func _get_class_code_from_index(index: int) -> String:
	match index:
		0: return "Pyromancer"
		1: return "Engineer"
		2: return "Cryomancer"
		3: return "Medic"
	return "Pyromancer"

func _get_class_display_title(class_code: String) -> String:
	match class_code:
		"Pyromancer": return "ATEŞ UZMANI"
		"Engineer": return "MÜHENDİS"
		"Cryomancer": return "BUZ MUHAFIZI"
		"Medic": return "SIHHİYE"
		_: return class_code.to_upper()

# --- Panel Geçişleri ---

func _show_main_nav() -> void:
	main_nav.visible = true
	single_panel.visible = false
	multi_panel.visible = false
	room_panel.visible = false

func _show_single_panel() -> void:
	main_nav.visible = false
	single_panel.visible = true
	multi_panel.visible = false
	room_panel.visible = false

func _show_multi_panel() -> void:
	main_nav.visible = false
	single_panel.visible = false
	multi_panel.visible = true
	room_panel.visible = false
	status_label.text = ""

func _show_room_panel() -> void:
	main_nav.visible = false
	single_panel.visible = false
	multi_panel.visible = false
	room_panel.visible = true
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

# --- Tek Oyunculu Başlatma ---

func _on_single_start_pressed() -> void:
	var player_name = single_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Kutu Asker"
	
	var chosen_class = _get_class_code_from_index(single_class_option.selected)
	NetworkManager.local_player_info["class"] = chosen_class
	
	single_start_btn.disabled = true
	single_start_btn.text = "BAŞLATILIYOR..."
	
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
	# Sessiz kontrol, kullanıcıyı rahatsız etmiyoruz
	pass

func _on_start_update_pressed() -> void:
	start_update_btn.disabled = true
	dismiss_update_btn.disabled = true
	update_progress_bar.visible = true
	update_progress_bar.value = 0
	update_progress_text.visible = true
	update_progress_text.text = "İndiriliyor... %0"
	AutoUpdater.start_download()

func _on_download_progress(percent: float, _downloaded: int, _total: int) -> void:
	update_progress_bar.value = percent
	update_progress_text.text = "İndiriliyor... %" + str(int(percent))

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
