extends Node

# --- Kutu Kafalar: 99 Kat Kalıcı Kayıt Sistemi (SaveManager) ---
# Oyuncunun ulaştığı en yüksek katı, kaldığı yeri ve istatistiklerini user://save_data.json içinde saklar.

const SAVE_FILE_PATH: String = "user://save_data.json"

var highest_unlocked_floor: int = 1
var last_played_floor: int = 1
var selected_start_floor: int = 1
var total_kills: int = 0
var total_boss_kills: int = 0
var total_gold_earned: int = 0
var total_floors_cleared: int = 0
var total_runs: int = 0

signal progress_saved
signal floor_unlocked(new_floor: int)

func _ready() -> void:
	load_game()

## Oyunu diske kaydeder (user://save_data.json)
func save_game() -> void:
	var data = {
		"version": "1.3.11",
		"highest_unlocked_floor": highest_unlocked_floor,
		"last_played_floor": last_played_floor,
		"selected_start_floor": selected_start_floor,
		"total_kills": total_kills,
		"total_boss_kills": total_boss_kills,
		"total_gold_earned": total_gold_earned,
		"total_floors_cleared": total_floors_cleared,
		"total_runs": total_runs,
		"saved_at": Time.get_datetime_string_from_system()
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(data, "\t")
		file.store_string(json_str)
		file.close()
		progress_saved.emit()
		print("[SaveManager] İlerleme kaydedildi: En Yüksek Kat ", highest_unlocked_floor, ", Son Kat: ", last_played_floor)
	else:
		push_error("[SaveManager] Kayıt dosyası açılamadı: " + str(FileAccess.get_open_error()))

## Oyunu diskten yükler
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[SaveManager] Kayıt dosyası henüz yok, yeni profil başlatıldı (Kat 1).")
		highest_unlocked_floor = 1
		last_played_floor = 1
		selected_start_floor = 1
		save_game()
		return

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Kayıt dosyası okunamadı!")
		return

	var content = file.get_as_text()
	file.close()

	var test_json_conv = JSON.new()
	var error = test_json_conv.parse(content)
	if error != OK:
		push_warning("[SaveManager] Kayıt JSON ayrıştırma hatası! Dosya bozulmuş olabilir.")
		highest_unlocked_floor = 1
		last_played_floor = 1
		selected_start_floor = 1
		return

	var data = test_json_conv.data
	if typeof(data) == TYPE_DICTIONARY:
		highest_unlocked_floor = clampi(int(data.get("highest_unlocked_floor", 1)), 1, 99)
		last_played_floor = clampi(int(data.get("last_played_floor", 1)), 1, highest_unlocked_floor)
		selected_start_floor = clampi(int(data.get("selected_start_floor", last_played_floor)), 1, highest_unlocked_floor)
		total_kills = int(data.get("total_kills", 0))
		total_boss_kills = int(data.get("total_boss_kills", 0))
		total_gold_earned = int(data.get("total_gold_earned", 0))
		total_floors_cleared = int(data.get("total_floors_cleared", 0))
		total_runs = int(data.get("total_runs", 0))
		print("[SaveManager] Kayıt yüklendi! En Yüksek Kat: ", highest_unlocked_floor, " | Son Kalınan Kat: ", last_played_floor)

## Yeni kat kilidini açar (Kat temizlendiğinde çağrılır)
func unlock_floor(target_floor: int) -> bool:
	var clamped_target = clampi(target_floor, 1, 99)
	var newly_unlocked = false
	if clamped_target > highest_unlocked_floor:
		highest_unlocked_floor = clamped_target
		newly_unlocked = true
		floor_unlocked.emit(highest_unlocked_floor)
		print("[SaveManager] YENİ KAT KİLİDİ AÇILDI: Kat ", highest_unlocked_floor)
	
	last_played_floor = clamped_target
	selected_start_floor = clamped_target
	save_game()
	return newly_unlocked

func set_starting_floor(floor_num: int) -> void:
	selected_start_floor = clampi(floor_num, 1, highest_unlocked_floor)
	save_game()

func get_starting_floor() -> int:
	return clampi(selected_start_floor, 1, highest_unlocked_floor)

func set_last_played_floor(floor_num: int) -> void:
	last_played_floor = clampi(floor_num, 1, 99)
	save_game()

func get_last_played_floor() -> int:
	return clampi(last_played_floor, 1, highest_unlocked_floor)

func get_highest_unlocked_floor() -> int:
	return highest_unlocked_floor

func record_kill(is_boss: bool = false) -> void:
	total_kills += 1
	if is_boss:
		total_boss_kills += 1

func record_gold(amount: int) -> void:
	if amount > 0:
		total_gold_earned += amount

func record_floor_cleared() -> void:
	total_floors_cleared += 1
	save_game()

func record_run_started() -> void:
	total_runs += 1
	save_game()

## Kaydı sıfırlama (İsteğe bağlı test/ayarlar için)
func reset_progress() -> void:
	highest_unlocked_floor = 1
	last_played_floor = 1
	selected_start_floor = 1
	total_kills = 0
	total_boss_kills = 0
	total_gold_earned = 0
	total_floors_cleared = 0
	save_game()
	print("[SaveManager] İlerleme sıfırlandı.")
