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

# --- Kalıcı Yetenek Ağacı ve Meta Para Birimi ---
var bio_cores: int = 0
var unlocked_nodes: Array[String] = []
var unlocked_weapons: Array[String] = ["pistol"]

signal progress_saved
signal floor_unlocked(new_floor: int)
signal bio_cores_changed(new_amount: int)
signal node_unlocked(node_id: String)
signal weapon_unlocked(weapon_name: String)

func _ready() -> void:
	load_game()

## Oyunu diske kaydeder (user://save_data.json)
func save_game() -> void:
	var data = {
		"version": "1.3.16",
		"highest_unlocked_floor": highest_unlocked_floor,
		"last_played_floor": last_played_floor,
		"selected_start_floor": selected_start_floor,
		"total_kills": total_kills,
		"total_boss_kills": total_boss_kills,
		"total_gold_earned": total_gold_earned,
		"total_floors_cleared": total_floors_cleared,
		"total_runs": total_runs,
		"bio_cores": bio_cores,
		"unlocked_nodes": unlocked_nodes,
		"unlocked_weapons": unlocked_weapons,
		"saved_at": Time.get_datetime_string_from_system()
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(data, "\t")
		file.store_string(json_str)
		file.close()
		progress_saved.emit()
		print("[SaveManager] İlerleme kaydedildi: En Yüksek Kat ", highest_unlocked_floor, ", Biyo-Çekirdek: ", bio_cores, ", Silahlar: ", unlocked_weapons)
	else:
		push_error("[SaveManager] Kayıt dosyası açılamadı: " + str(FileAccess.get_open_error()))

## Oyunu diskten yükler
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[SaveManager] Kayıt dosyası henüz yok, yeni profil başlatıldı (Kat 1).")
		highest_unlocked_floor = 1
		last_played_floor = 1
		selected_start_floor = 1
		unlocked_weapons = ["pistol"]
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
		unlocked_weapons = ["pistol"]
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
		bio_cores = int(data.get("bio_cores", 0))
		
		var loaded_nodes = data.get("unlocked_nodes", [])
		unlocked_nodes.clear()
		if typeof(loaded_nodes) == TYPE_ARRAY:
			for n in loaded_nodes:
				unlocked_nodes.append(str(n))
		
		var loaded_weapons = data.get("unlocked_weapons", ["pistol"])
		unlocked_weapons.clear()
		if typeof(loaded_weapons) == TYPE_ARRAY:
			for w in loaded_weapons:
				unlocked_weapons.append(str(w))
		if not unlocked_weapons.has("pistol"):
			unlocked_weapons.insert(0, "pistol")
		
		# Retroaktif Biyo-Çekirdek düzeltmesi: Eğer oyuncu seviye geçmiş ama puanı 0 görünüyorsa hak ettiği puanları yükle
		if bio_cores <= 0 and unlocked_nodes.is_empty() and (highest_unlocked_floor > 1 or total_floors_cleared > 0):
			var retroactive = 0
			for f in range(2, highest_unlocked_floor + 1):
				retroactive += (3 if f % 9 == 0 else 1)
			if total_floors_cleared > 0:
				retroactive += maxi(1, int(total_floors_cleared / 2))
			bio_cores = maxi(retroactive, 8)
			print("[SaveManager] Retroaktif Biyo-Çekirdek hesaplandı ve eklendi: +", bio_cores)
			save_game()

		print("[SaveManager] Kayıt yüklendi! En Yüksek Kat: ", highest_unlocked_floor, " | Biyo-Çekirdek: ", bio_cores, " | Yetenekler: ", unlocked_nodes.size(), " | Silahlar: ", unlocked_weapons)

## Yeni kat kilidini açar (Kat temizlendiğinde çağrılır)
func unlock_floor(target_floor: int) -> bool:
	var clamped_target = clampi(target_floor, 1, 99)
	var newly_unlocked = false
	if clamped_target > highest_unlocked_floor:
		highest_unlocked_floor = clamped_target
		newly_unlocked = true
		floor_unlocked.emit(highest_unlocked_floor)
		# Yeni kat açma ödülü: +1 Biyo-Çekirdek (Her 9. katta +3 Biyo-Çekirdek)
		var reward = 3 if (clamped_target % 9 == 0) else 1
		add_bio_cores(reward)
		print("[SaveManager] YENİ KAT KİLİDİ AÇILDI: Kat ", highest_unlocked_floor, " (Ödül: +", reward, " Biyo-Çekirdek)")
	
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
		# Boss öldürme ödülü: +5 Biyo-Çekirdek!
		add_bio_cores(5)
		print("[SaveManager] SEKTÖR BOSS'U ELENDİ! (+5 Biyo-Çekirdek)")

func record_gold(amount: int) -> void:
	if amount > 0:
		total_gold_earned += amount

func record_floor_cleared() -> void:
	total_floors_cleared += 1
	save_game()

func record_run_started() -> void:
	total_runs += 1
	save_game()

# --- Yetenek Ağacı (Skill Tree) Yönetimi ---

func get_bio_cores() -> int:
	return bio_cores

func add_bio_cores(amount: int) -> void:
	if amount > 0:
		bio_cores += amount
		bio_cores_changed.emit(bio_cores)
		save_game()

func spend_bio_cores(amount: int) -> bool:
	if amount <= 0:
		return true
	if bio_cores >= amount:
		bio_cores -= amount
		bio_cores_changed.emit(bio_cores)
		save_game()
		return true
	return false

func get_unlocked_nodes() -> Array[String]:
	return unlocked_nodes

func is_node_unlocked(node_id: String) -> bool:
	return unlocked_nodes.has(node_id)

func unlock_node(node_id: String, cost: int) -> bool:
	if is_node_unlocked(node_id):
		return true
	if spend_bio_cores(cost):
		unlocked_nodes.append(node_id)
		node_unlocked.emit(node_id)
		save_game()
		return true
	return false

func refund_all_nodes(refund_amount: int) -> void:
	unlocked_nodes.clear()
	bio_cores += refund_amount
	bio_cores_changed.emit(bio_cores)
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
	bio_cores = 0
	unlocked_nodes.clear()
	unlocked_weapons = ["pistol"]
	save_game()
	print("[SaveManager] İlerleme sıfırlandı.")

# --- Silah Kilit Açma (Weapon Unlock) Yönetimi ---

func get_unlocked_weapons() -> Array[String]:
	if not unlocked_weapons.has("pistol"):
		unlocked_weapons.insert(0, "pistol")
	return unlocked_weapons

func is_weapon_unlocked(w_name: String) -> bool:
	if w_name == "pistol":
		return true
	return unlocked_weapons.has(w_name)

func unlock_weapon(w_name: String) -> bool:
	if not unlocked_weapons.has(w_name):
		unlocked_weapons.append(w_name)
		weapon_unlocked.emit(w_name)
		save_game()
		print("[SaveManager] Yeni silah kilidi açıldı: ", w_name)
		return true
	return false
