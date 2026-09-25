extends Node

# --- GitHub Otomatik Güncelleyici (AutoUpdater) ---
# GitHub Releases API üzerinden yeni .pck dosyalarını denetler, indirir ve uygular.

signal update_check_started
signal update_available(version_tag: String, changelog: String, pck_url: String, pck_size: int)
signal update_not_available(current_version: String)
signal download_progress(percent: float, downloaded_bytes: int, total_bytes: int)
signal download_completed
signal update_failed(reason: String)

const REPO_OWNER: String = "kaanturkogluu"
const REPO_NAME: String = "kutukafalar"
const CURRENT_VERSION: String = "v1.0.0"
const GITHUB_API_URL: String = "https://api.github.com/repos/kaanturkogluu/kutukafalar/releases/latest"

var check_http: HTTPRequest = null
var download_http: HTTPRequest = null

var is_checking: bool = false
var is_downloading: bool = false
var latest_pck_url: String = ""
var target_pck_path: String = ""
var temp_pck_path: String = ""

func _ready() -> void:
	check_http = HTTPRequest.new()
	add_child(check_http)
	check_http.request_completed.connect(_on_check_request_completed)
	
	download_http = HTTPRequest.new()
	add_child(download_http)
	download_http.request_completed.connect(_on_download_request_completed)
	
	_determine_paths()

func _determine_paths() -> void:
	var base_dir: String
	if OS.has_feature("editor"):
		base_dir = ProjectSettings.globalize_path("res://builds")
	else:
		base_dir = OS.get_executable_path().get_base_dir()
	
	target_pck_path = base_dir.path_join("KutuKafalar.pck")
	temp_pck_path = base_dir.path_join("KutuKafalar.pck.new")

func _process(_delta: float) -> void:
	if is_downloading and download_http:
		var downloaded = download_http.get_downloaded_bytes()
		var total = download_http.get_body_size()
		if total > 0:
			var pct = clamp(float(downloaded) / float(total) * 100.0, 0.0, 100.0)
			download_progress.emit(pct, downloaded, total)

## GitHub'dan en son sürümü sorgula
func check_for_updates() -> void:
	if is_checking or is_downloading:
		return
	is_checking = true
	update_check_started.emit()
	
	var headers = [
		"User-Agent: KutuKafalar-AutoUpdater",
		"Accept: application/vnd.github.v3+json"
	]
	
	print("[AutoUpdater] Güncellemeler denetleniyor: ", GITHUB_API_URL)
	var err = check_http.request(GITHUB_API_URL, headers, HTTPClient.METHOD_GET)
	if err != OK:
		is_checking = false
		update_failed.emit("Ağ isteği başlatılamadı (Hata: " + str(err) + ")")

func _on_check_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_checking = false
	
	if response_code == 404:
		print("[AutoUpdater] GitHub'da henüz yayınlanmış bir Release bulunamadı.")
		update_not_available.emit(CURRENT_VERSION)
		return
	
	if response_code != 200:
		print("[AutoUpdater] GitHub API yanıt vermedi, kod: ", response_code)
		update_failed.emit("Sunucu yanıt kodu: " + str(response_code))
		return
	
	var json_str = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK:
		update_failed.emit("GitHub yanıtı ayrıştırılamadı.")
		return
	
	var data = json.get_data()
	if not data is Dictionary:
		update_failed.emit("Geçersiz API verisi.")
		return
	
	var tag_name: String = data.get("tag_name", "")
	var changelog: String = data.get("body", "Yama detayları belirtilmedi.")
	var assets: Array = data.get("assets", [])
	
	print("[AutoUpdater] Mevcut sürüm: ", CURRENT_VERSION, " | En son GitHub sürümü: ", tag_name)
	
	# Sürüm karşılaştırması
	if tag_name.is_empty() or tag_name == CURRENT_VERSION:
		update_not_available.emit(CURRENT_VERSION)
		return
	
	# Assets içinden KutuKafalar.pck dosyasını ara
	var found_pck_url = ""
	var pck_size = 0
	for asset in assets:
		var asset_name = asset.get("name", "")
		if asset_name == "KutuKafalar.pck":
			found_pck_url = asset.get("browser_download_url", "")
			pck_size = int(asset.get("size", 0))
			break
	
	if found_pck_url.is_empty():
		print("[AutoUpdater] Sürüm bulundu ancak KutuKafalar.pck eklenmemiş.")
		update_not_available.emit(CURRENT_VERSION)
		return
	
	latest_pck_url = found_pck_url
	update_available.emit(tag_name, changelog, found_pck_url, pck_size)

## Yeni PCK dosyasını indir
func start_download(pck_url: String = "") -> void:
	if is_downloading:
		return
	
	if pck_url.is_empty():
		pck_url = latest_pck_url
	if pck_url.is_empty():
		update_failed.emit("İndirilecek dosya bağlantısı bulunamadı.")
		return
	
	is_downloading = true
	download_http.download_file = temp_pck_path
	
	var headers = [
		"User-Agent: KutuKafalar-AutoUpdater"
	]
	
	print("[AutoUpdater] İndirme başlatılıyor: ", pck_url, " -> ", temp_pck_path)
	var err = download_http.request(pck_url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		is_downloading = false
		update_failed.emit("İndirme isteği başlatılamadı: " + str(err))

func _on_download_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	is_downloading = false
	
	if response_code != 200:
		print("[AutoUpdater] İndirme başarısız oldu! Kod: ", response_code)
		update_failed.emit("Dosya indirilemedi (Kod: " + str(response_code) + ")")
		return
	
	print("[AutoUpdater] İndirme tamamlandı!")
	download_completed.emit()

## Güncellemeyi uygula ve oyunu 1 saniyede yeniden başlat
func apply_update_and_restart() -> void:
	if not FileAccess.file_exists(temp_pck_path):
		update_failed.emit("İndirilen yama dosyası bulunamadı!")
		return
	
	var base_dir = OS.get_executable_path().get_base_dir()
	var exe_name = OS.get_executable_path().get_file()
	
	# Windows için otomatik değiştirici ve yeniden başlatıcı bat dosyası
	var bat_path = base_dir.path_join("apply_update.bat")
	var bat_content = """@echo off
timeout /t 1 /nobreak >nul
if exist "%~dp0KutuKafalar.pck.new" (
    move /y "%~dp0KutuKafalar.pck.new" "%~dp0KutuKafalar.pck" >nul
)
start "" "%~dp0{EXE_NAME}"
del "%~f0"
""".replace("{EXE_NAME}", exe_name)
	
	var bat_file = FileAccess.open(bat_path, FileAccess.WRITE)
	if bat_file:
		bat_file.store_string(bat_content)
		bat_file.close()
		print("[AutoUpdater] apply_update.bat oluşturuldu, yeniden başlatılıyor...")
		OS.create_process("cmd.exe", ["/c", bat_path])
		get_tree().quit(0)
	else:
		# Eğer bat yazılamazsa (örn. editördeyken), dinamik olarak paketi hafızaya yükle
		print("[AutoUpdater] Bat yazılamadı, runtime pack yükleniyor...")
		ProjectSettings.load_resource_pack(temp_pck_path, true)
		get_tree().reload_current_scene()
