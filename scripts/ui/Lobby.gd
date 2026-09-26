extends Control

# --- Ana Menü, Çok Oyunculu Bekleme Odası ve Otomatik Güncelleyici ---
const GAME_SCENE_PATH: String = "res://scenes/levels/main_level.tscn"

# 1. Aşama: Bağlantı Paneli
@onready var connect_panel: PanelContainer = %ConnectPanel
@onready var name_input: LineEdit = %NameInput
@onready var class_option: OptionButton = %ClassOption
@onready var ip_input: LineEdit = %IpInput
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel

# 2. Aşama: Bekleme Odası (Room Panel)
@onready var room_panel: PanelContainer = %RoomPanel
@onready var room_info_label: Label = %RoomInfoLabel
@onready var room_class_option: OptionButton = %RoomClassOption
@onready var player_list_box: VBoxContainer = %PlayerListBox
@onready var room_status_label: Label = %RoomStatusLabel
@onready var ready_btn: Button = %ReadyBtn
@onready var start_game_btn: Button = %StartGameBtn
@onready var leave_room_btn: Button = %LeaveRoomBtn

# Güncelleyici Arayüz Elemanları
@onready var version_label: Label = %VersionLabel
@onready var check_update_btn: Button = %CheckUpdateBtn
@onready var update_overlay: ColorRect = %UpdateOverlay
@onready var update_info_label: Label = %UpdateInfoLabel
@onready var update_notes_label: Label = %UpdateNotesLabel
@onready var update_progress_bar: ProgressBar = %UpdateProgressBar
@onready var update_progress_text: Label = %UpdateProgressText
@onready var start_update_btn: Button = %StartUpdateBtn
@onready var dismiss_update_btn: Button = %DismissUpdateBtn

# 3D Taktik Tim Arka Planı
@onready var squad_bg: SquadBackground3D = %SquadBackground3D

# Ayarlar Arayüz Elemanları
@onready var settings_overlay: ColorRect = %SettingsOverlay
@onready var open_settings_btn: Button = %OpenSettingsBtn
@onready var close_settings_btn: Button = %CloseSettingsBtn
@onready var fullscreen_quick_btn: Button = %FullscreenQuickBtn
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_box: HBoxContainer = %ResolutionBox
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckBox = %VSyncCheck
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_label: Label = %VolumeLabel
@onready var sens_slider: HSlider = %SensSlider
@onready var sens_label: Label = %SensLabel

var is_local_ready: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_connect_panel()
	
	if version_label:
		version_label.text = AutoUpdater.CURRENT_VERSION
	
	class_option.add_item("🔥 Kutu Büyücüsü (Ateş Dalgası & Meteor)", 0)
	class_option.add_item("⚙️ Mühendis (Manyetik Vortex Çekimi)", 1)
	class_option.add_item("❄️ Buz Muhafızı (Kriyojenik Dondurucu)", 2)
	class_option.add_item("💚 Sahra Sıhhiyesi (Şifa Bombası & Diriltme)", 3)
	class_option.select(0)
	class_option.item_selected.connect(_on_main_class_selected)

	room_class_option.add_item("🔥 Kutu Büyücüsü (Ateş Dalgası & Meteor)", 0)
	room_class_option.add_item("⚙️ Mühendis (Manyetik Vortex Çekimi)", 1)
	room_class_option.add_item("❄️ Buz Muhafızı (Kriyojenik Dondurucu)", 2)
	room_class_option.add_item("💚 Sahra Sıhhiyesi (Şifa Bombası & Diriltme)", 3)
	room_class_option.select(0)
	room_class_option.item_selected.connect(_on_room_class_selected)
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	ready_btn.pressed.connect(_on_ready_pressed)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	leave_room_btn.pressed.connect(_on_leave_room_pressed)
	
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.game_rejected.connect(_on_game_rejected)
	
	# Ayarlar Arayüzünü Başlat
	_setup_settings_ui()
	
	# 3D Sahnede varsayılan sınıfı seç
	if squad_bg:
		squad_bg.select_class("Pyromancer", true)
	
	# AutoUpdater bağlantıları
	if check_update_btn:
		check_update_btn.pressed.connect(_on_check_update_pressed)
	if start_update_btn:
		start_update_btn.pressed.connect(_on_start_update_pressed)
	if dismiss_update_btn:
		dismiss_update_btn.pressed.connect(func(): update_overlay.visible = false)
	
	AutoUpdater.update_available.connect(_on_update_available)
	AutoUpdater.update_not_available.connect(_on_update_not_available)
	AutoUpdater.download_progress.connect(_on_download_progress)
	AutoUpdater.download_completed.connect(_on_download_completed)
	AutoUpdater.update_failed.connect(_on_update_failed)
	
	status_label.text = "Sınıfınızı seçin, oda kurun veya arkadaşınıza bağlanın."
	
	# Açılışta sessizce güncelleme denetle
	get_tree().create_timer(0.5).timeout.connect(func(): AutoUpdater.check_for_updates())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and squad_bg:
		squad_bg.update_cursor(event.position, get_viewport_rect().size)
	if event.is_action_pressed("ui_cancel"):
		if settings_overlay and settings_overlay.visible:
			settings_overlay.visible = false
			get_viewport().set_input_as_handled()

func _setup_settings_ui() -> void:
	if open_settings_btn:
		open_settings_btn.pressed.connect(func():
			if settings_overlay:
				settings_overlay.visible = true
				_sync_settings_to_ui()
		)
	if close_settings_btn:
		close_settings_btn.pressed.connect(func():
			if settings_overlay:
				settings_overlay.visible = false
		)
	if fullscreen_quick_btn:
		fullscreen_quick_btn.pressed.connect(_on_fullscreen_quick_toggle)
		_update_fullscreen_btn_text()

	if window_mode_option:
		window_mode_option.clear()
		window_mode_option.add_item("🪟 Pencereli (Windowed)", 0)
		window_mode_option.add_item("🔲 Kenarlıksız (Borderless)", 1)
		window_mode_option.add_item("🖥️ Tam Ekran (Fullscreen)", 2)
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
				volume_label.text = "🔊 Ana Ses: %" + str(int(val * 100))
		)

	if sens_slider:
		sens_slider.value_changed.connect(func(val: float):
			SettingsManager.set_mouse_sensitivity(val)
			if sens_label:
				sens_label.text = "🖱️ Fare Hassasiyeti: " + str(snapped(val * 1000.0, 0.1))
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
			volume_label.text = "🔊 Ana Ses: %" + str(int(SettingsManager.master_volume * 100))
	if sens_slider:
		sens_slider.value = SettingsManager.mouse_sensitivity
		if sens_label:
			sens_label.text = "🖱️ Fare Hassasiyeti: " + str(snapped(SettingsManager.mouse_sensitivity * 1000.0, 0.1))
	_update_fullscreen_btn_text()

func _on_window_mode_selected(idx: int) -> void:
	SettingsManager.set_window_mode(idx)
	if resolution_box:
		resolution_box.visible = (idx == SettingsManager.WindowMode.WINDOWED)
	_update_fullscreen_btn_text()

func _on_resolution_selected(idx: int) -> void:
	if idx >= 0 and idx < SettingsManager.RESOLUTION_PRESETS.size():
		SettingsManager.set_resolution(SettingsManager.RESOLUTION_PRESETS[idx])

func _on_fullscreen_quick_toggle() -> void:
	if SettingsManager.current_window_mode == SettingsManager.WindowMode.FULLSCREEN:
		SettingsManager.set_window_mode(SettingsManager.WindowMode.WINDOWED)
	else:
		SettingsManager.set_window_mode(SettingsManager.WindowMode.FULLSCREEN)
	_sync_settings_to_ui()

func _update_fullscreen_btn_text() -> void:
	if not fullscreen_quick_btn:
		return
	if SettingsManager.current_window_mode == SettingsManager.WindowMode.FULLSCREEN:
		fullscreen_quick_btn.text = "🪟 Pencereli Yap"
	else:
		fullscreen_quick_btn.text = "⛶ Tam Ekran"

func _get_class_code_from_index(index: int) -> String:
	match index:
		0: return "Pyromancer"
		1: return "Engineer"
		2: return "Cryomancer"
		3: return "Medic"
	return "Pyromancer"

func _on_main_class_selected(index: int) -> void:
	var selected_class = _get_class_code_from_index(index)
	NetworkManager.set_local_class(selected_class)
	if room_class_option:
		room_class_option.select(index)
	if squad_bg:
		squad_bg.select_class(selected_class)
	print("[Lobi] Sınıf seçildi: ", selected_class)

func _on_room_class_selected(index: int) -> void:
	var selected_class = _get_class_code_from_index(index)
	NetworkManager.set_local_class(selected_class)
	if class_option:
		class_option.select(index)
	if squad_bg:
		squad_bg.select_class(selected_class)
	print("[Lobi Odası] Sınıf değiştirildi: ", selected_class)

func _show_connect_panel() -> void:
	connect_panel.visible = true
	room_panel.visible = false
	host_button.disabled = false
	join_button.disabled = false

func _show_room_panel() -> void:
	connect_panel.visible = false
	room_panel.visible = true
	is_local_ready = false
	if room_class_option and class_option:
		room_class_option.select(class_option.selected)
	_update_room_buttons()

func _get_player_name() -> String:
	var player_name = name_input.text.strip_edges()
	if player_name.is_empty():
		return "Kutu Kafa " + str(randi_range(10, 99))
	return player_name

func _apply_selected_class() -> void:
	var selected_class = "Pyromancer"
	match class_option.selected:
		0: selected_class = "Pyromancer"
		1: selected_class = "Engineer"
		2: selected_class = "Cryomancer"
		3: selected_class = "Medic"
	NetworkManager.local_player_info["class"] = selected_class
	print("[Lobi] Seçilen Sınıf: ", selected_class)

func _get_class_display_title(class_code: String) -> String:
	match class_code:
		"Pyromancer": return "🔥 Büyücü"
		"Engineer": return "⚙️ Mühendis"
		"Cryomancer": return "❄️ Buz Muhafızı"
		"Medic": return "💚 Sıhhiye"
		_: return class_code

# --- Buton Aksiyonları ---

func _on_host_pressed() -> void:
	_apply_selected_class()
	var player_name = _get_player_name()
	var error = NetworkManager.create_game(player_name)
	if error == OK:
		_show_room_panel()
		room_info_label.text = "👑 Oda Kuruldu (Host: " + player_name + ") | Port: 7000"
		_refresh_player_list()
	else:
		status_label.text = "Hata: Oda kurulamadı! (Port meşgul olabilir)"

func _on_join_pressed() -> void:
	_apply_selected_class()
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	
	var player_name = _get_player_name()
	status_label.text = "Sunucuya bağlanılıyor: " + ip + "..."
	host_button.disabled = true
	join_button.disabled = true
	
	var error = NetworkManager.join_game(ip, player_name)
	if error != OK:
		status_label.text = "Hata: Bağlantı başlatılamadı!"
		host_button.disabled = false
		join_button.disabled = false

func _on_ready_pressed() -> void:
	is_local_ready = not is_local_ready
	NetworkManager.set_local_ready(is_local_ready)
	_update_room_buttons()

func _on_start_game_pressed() -> void:
	if multiplayer.is_server():
		start_game_btn.disabled = true
		room_status_label.text = "🚀 Oyun başlatılıyor! Sahne yükleniyor..."
		NetworkManager.start_game()

func _on_leave_room_pressed() -> void:
	NetworkManager.disconnect_game()
	_show_connect_panel()
	status_label.text = "Odadan ayrıldınız."

# --- Ağ Geri Bildirimleri ---

func _on_connection_succeeded() -> void:
	_show_room_panel()
	room_info_label.text = "🔗 Odaya Katılınıldı! Sunucu: " + ip_input.text.strip_edges()
	_update_room_buttons()

func _on_connection_failed() -> void:
	_show_connect_panel()
	status_label.text = "Bağlantı başarısız! IP adresini ve sunucunun açık olduğunu kontrol edin."

func _on_server_disconnected() -> void:
	_show_connect_panel()
	status_label.text = "Sunucu bağlantısı koptu veya oda kapatıldı."

func _on_game_rejected(reason: String) -> void:
	_show_connect_panel()
	status_label.text = "Bağlantı Reddedildi: " + reason

func _on_lobby_updated(_players_dict: Dictionary) -> void:
	_refresh_player_list()
	_update_room_buttons()

func _refresh_player_list() -> void:
	for child in player_list_box.get_children():
		child.queue_free()
	
	var all_ready = true
	var player_count = NetworkManager.players.size()
	
	for id in NetworkManager.players.keys():
		var p_info = NetworkManager.players[id]
		var p_name = p_info.get("name", "Bilinmeyen")
		var p_class = p_info.get("class", "Pyromancer")
		var is_ready = p_info.get("is_ready", false)
		var is_host = (id == 1)
		
		if not is_ready and not is_host:
			all_ready = false
		
		# Oyuncu kartı satırı
		var row = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 8)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		
		# İsim ve rol
		var name_lbl = Label.new()
		name_lbl.text = ("👑 " if is_host else "👤 ") + p_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if is_host else Color.WHITE)
		hbox.add_child(name_lbl)
		
		# Sınıf
		var class_lbl = Label.new()
		class_lbl.text = _get_class_display_title(p_class)
		class_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		hbox.add_child(class_lbl)
		
		# Hazır Durumu
		var status_badge = Label.new()
		if is_host:
			status_badge.text = "[ODA SAHİBİ]"
			status_badge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		elif is_ready:
			status_badge.text = "✅ HAZIR"
			status_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		else:
			status_badge.text = "⏳ BEKLİYOR"
			status_badge.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		hbox.add_child(status_badge)
		
		margin.add_child(hbox)
		row.add_child(margin)
		player_list_box.add_child(row)
	
	room_info_label.text = "Katılımcılar: (" + str(player_count) + "/4)"
	
	if multiplayer.is_server():
		if player_count <= 1:
			room_status_label.text = "Arkadaşınızın odaya katılması bekleniyor..."
			start_game_btn.disabled = false # Tek başına test edebilsin
		elif all_ready:
			room_status_label.text = "🎉 Tüm oyuncular hazır! Oyunu başlatabilirsiniz."
			room_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			start_game_btn.disabled = false
		else:
			room_status_label.text = "Diğer oyuncuların hazır olması bekleniyor..."
			room_status_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
			start_game_btn.disabled = false # Host dilerse yine de başlatabilir

func _update_room_buttons() -> void:
	if multiplayer.is_server():
		ready_btn.visible = false
		start_game_btn.visible = true
	else:
		ready_btn.visible = true
		start_game_btn.visible = false
		if is_local_ready:
			ready_btn.text = "❌ HAZIR DEĞİLİM"
			ready_btn.modulate = Color(1.0, 0.5, 0.5)
		else:
			ready_btn.text = "✅ HAZIR OL"
			ready_btn.modulate = Color(0.5, 1.0, 0.5)

# --- AutoUpdater Geri Bildirimleri ---

func _on_check_update_pressed() -> void:
	status_label.text = "Güncellemeler denetleniyor..."
	AutoUpdater.check_for_updates()

func _on_update_available(version_tag: String, changelog: String, _url: String, pck_size: int) -> void:
	update_info_label.text = "Yeni Sürüm: " + version_tag + " (Boyut: ~" + str(max(1, int(pck_size / 1024))) + " KB)"
	update_notes_label.text = changelog
	update_progress_bar.visible = false
	update_progress_text.visible = false
	start_update_btn.disabled = false
	dismiss_update_btn.disabled = false
	update_overlay.visible = true

func _on_update_not_available(ver: String) -> void:
	status_label.text = "Oyununuz güncel (" + ver + ")"

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
	update_progress_text.text = "İndirme tamamlandı! Oyun yeniden başlatılıyor..."
	await get_tree().create_timer(1.0).timeout
	AutoUpdater.apply_update_and_restart()

func _on_update_failed(reason: String) -> void:
	status_label.text = "Güncelleme uyarısı: " + reason
	if update_overlay.visible:
		update_progress_text.text = "Hata: " + reason
		start_update_btn.disabled = false
		dismiss_update_btn.disabled = false
