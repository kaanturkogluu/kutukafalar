extends Node

# --- Kutu Kafalar Ayarlar Yöneticisi (SettingsManager) ---
# Ekran modları (Tam Ekran, Pencereli, Kenarlıksız), Çözünürlük, Ses ve Fare hassasiyeti ayarları

signal settings_changed

const SETTINGS_FILE_PATH: String = "user://settings.cfg"

# Ekran Modları
enum WindowMode {
	WINDOWED = 0,
	BORDERLESS = 1,
	FULLSCREEN = 2
}

var current_window_mode: int = WindowMode.FULLSCREEN
var current_resolution: Vector2i = Vector2i(1920, 1080)
var vsync_enabled: bool = true
var master_volume: float = 0.85
var mouse_sensitivity: float = 0.0025
var fov_val: float = 85.0

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

func _ready() -> void:
	load_settings()
	apply_all_settings()

func apply_all_settings() -> void:
	set_window_mode(current_window_mode, false)
	set_vsync(vsync_enabled, false)
	set_master_volume(master_volume, false)
	settings_changed.emit()

func set_window_mode(mode: int, auto_save: bool = true) -> void:
	current_window_mode = mode
	match mode:
		WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			# Pencereli modda varsayılan ekran ortalama
			if current_resolution.x > 0 and current_resolution.y > 0:
				DisplayServer.window_set_size(current_resolution)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen_size = DisplayServer.screen_get_size()
			DisplayServer.window_set_size(screen_size)
			DisplayServer.window_set_position(Vector2i.ZERO)
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	if auto_save:
		save_settings()
		settings_changed.emit()

func set_resolution(res: Vector2i, auto_save: bool = true) -> void:
	current_resolution = res
	if current_window_mode == WindowMode.WINDOWED:
		DisplayServer.window_set_size(res)
		# Ekranı ortala
		var screen_size = DisplayServer.screen_get_size()
		var pos = (screen_size - res) / 2
		DisplayServer.window_set_position(pos)
	if auto_save:
		save_settings()
		settings_changed.emit()

func set_vsync(enabled: bool, auto_save: bool = true) -> void:
	vsync_enabled = enabled
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if auto_save:
		save_settings()
		settings_changed.emit()

func set_master_volume(vol: float, auto_save: bool = true) -> void:
	master_volume = clamp(vol, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if master_volume <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))
	if auto_save:
		save_settings()
		settings_changed.emit()

func set_mouse_sensitivity(sens: float, auto_save: bool = true) -> void:
	mouse_sensitivity = clamp(sens, 0.0005, 0.0080)
	if auto_save:
		save_settings()
		settings_changed.emit()

func set_fov(fov: float, auto_save: bool = true) -> void:
	fov_val = clamp(fov, 65.0, 110.0)
	if auto_save:
		save_settings()
		settings_changed.emit()

func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("video", "window_mode", current_window_mode)
	cfg.set_value("video", "resolution_w", current_resolution.x)
	cfg.set_value("video", "resolution_h", current_resolution.y)
	cfg.set_value("video", "vsync", vsync_enabled)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "fov", fov_val)
	cfg.save(SETTINGS_FILE_PATH)

func load_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_FILE_PATH)
	if err != OK:
		# İlk kez açılıyorsa varsayılan tam ekran başla
		current_window_mode = WindowMode.FULLSCREEN
		return
	
	current_window_mode = cfg.get_value("video", "window_mode", WindowMode.FULLSCREEN)
	var rw = cfg.get_value("video", "resolution_w", 1920)
	var rh = cfg.get_value("video", "resolution_h", 1080)
	current_resolution = Vector2i(rw, rh)
	vsync_enabled = cfg.get_value("video", "vsync", true)
	master_volume = cfg.get_value("audio", "master_volume", 0.85)
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", 0.0025)
	fov_val = cfg.get_value("video", "fov", 85.0)
