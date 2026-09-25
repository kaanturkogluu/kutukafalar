extends Control

# --- Ana Menü ve Çok Oyunculu Lobi Ekranı ---
const GAME_SCENE_PATH: String = "res://scenes/levels/main_level.tscn"

@onready var name_input: LineEdit = %NameInput
@onready var class_option: OptionButton = %ClassOption
@onready var ip_input: LineEdit = %IpInput
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel

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

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if version_label:
		version_label.text = AutoUpdater.CURRENT_VERSION
	
	class_option.add_item("🔥 Kutu Büyücüsü (Ateş Dalgası & Meteor)", 0)
	class_option.add_item("⚙️ Mühendis (Manyetik Vortex Çekimi)", 1)
	class_option.add_item("❄️ Buz Muhafızı (Kriyojenik Dondurucu)", 2)
	class_option.add_item("💚 Sahra Sıhhiyesi (Şifa Bombası & Diriltme)", 3)
	class_option.select(0)
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	
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

func _on_host_pressed() -> void:
	_apply_selected_class()
	var player_name = _get_player_name()
	var error = NetworkManager.create_game(player_name)
	if error == OK:
		status_label.text = "Oda kuruldu! Oyun başlatılıyor..."
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
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

func _on_connection_succeeded() -> void:
	status_label.text = "Bağlantı başarılı! Haritaya giriliyor..."
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_connection_failed() -> void:
	status_label.text = "Bağlantı başarısız! IP adresini ve sunucunun açık olduğunu kontrol edin."
	host_button.disabled = false
	join_button.disabled = false
