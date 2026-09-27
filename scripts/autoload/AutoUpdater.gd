extends Node

# ==============================================================================
# KUTU KAFALAR - TEMİZ OTOMATİK GÜNCELLEYİCİ (AutoUpdater)
# ==============================================================================
# - Sürüm doğruluğu için tek kaynak (Single Source of Truth): res://version.json
# - Semantik sürüm karşılaştırması (Semantic Versioning: Major.Minor.Patch)
# - CDN önbelleğini engelleyen dinamik sorgulama (?t=timestamp)
# - Windows süreç (PID) takipli, kilitlenmeyen ve güvenli dosya değiştirici
# ==============================================================================

signal update_check_started
signal update_available(version_tag: String, changelog: String, pck_url: String, pck_size: int)
signal update_not_available(current_version: String)
signal download_progress(percent: float, downloaded_bytes: int, total_bytes: int)
signal download_completed
signal update_failed(reason: String)

const VERSION_FILE_PATH: String = "res://version.json"
const FALLBACK_VERSION: String = "v1.3.0"
const RAW_VERSION_URL: String = "https://raw.githubusercontent.com/kaanturkogluu/kutukafalar/main/version.json"

var current_version: String = FALLBACK_VERSION
var CURRENT_VERSION: String:
	get:
		return current_version

var latest_version_info: Dictionary = {}
var is_checking: bool = false
var is_downloading: bool = false

var temp_download_path: String = ""
var target_pck_path: String = ""
var exe_path: String = ""

var check_http: HTTPRequest = null
var download_http: HTTPRequest = null

func _ready() -> void:
	_load_local_version()
	_setup_paths()
	_cleanup_residual_downloads()
	_setup_http_nodes()

## Yerel sürüm bilgisini res://version.json dosyasından oku
func _load_local_version() -> void:
	if FileAccess.file_exists(VERSION_FILE_PATH):
		var file = FileAccess.open(VERSION_FILE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(content) == OK:
				var data = json.get_data()
				if data is Dictionary and data.has("version"):
					current_version = str(data["version"]).strip_edges()
					print("[AutoUpdater] Yüklü oyun sürümü doğrulandı: ", current_version)
					return
	current_version = FALLBACK_VERSION
	print("[AutoUpdater] Sürüm dosyası bulunamadı, varsayılan sürüm kullanılıyor: ", current_version)

## Çalışma yollarını belirle (user:// ve exe dizini)
func _setup_paths() -> void:
	exe_path = OS.get_executable_path()
	var base_dir = exe_path.get_base_dir()
	
	# Hedef PCK her zaman çalıştırılan exe'nin yanındaki .pck dosyasıdır
	var pck_name = exe_path.get_file().get_basename() + ".pck"
	target_pck_path = base_dir.path_join(pck_name)
	
	if not FileAccess.file_exists(target_pck_path):
		var fallback_pck = base_dir.path_join("KutuKafalar.pck")
		if FileAccess.file_exists(fallback_pck):
			target_pck_path = fallback_pck
	
	print("[AutoUpdater] Hedef PCK yolu: ", target_pck_path)
	# İndirilen dosya her zaman izin garantili user:// dizinine yazılır
	temp_download_path = ProjectSettings.globalize_path("user://update_download.pck")

## Eski yarım kalmış veya artık indirmeleri temizle
func _cleanup_residual_downloads() -> void:
	if FileAccess.file_exists(temp_download_path):
		DirAccess.remove_absolute(temp_download_path)
	var cmd_path = ProjectSettings.globalize_path("user://apply_update.cmd")
	if FileAccess.file_exists(cmd_path):
		DirAccess.remove_absolute(cmd_path)

## HTTP istemci düğümlerini hazırla
func _setup_http_nodes() -> void:
	check_http = HTTPRequest.new()
	check_http.name = "CheckHTTPRequest"
	check_http.timeout = 15.0
	check_http.max_redirects = 8
	check_http.use_threads = true  # Ana thread'i bloklamaz
	add_child(check_http)
	check_http.request_completed.connect(_on_check_completed)
	
	download_http = HTTPRequest.new()
	download_http.name = "DownloadHTTPRequest"
	download_http.timeout = 120.0
	download_http.max_redirects = 8
	download_http.use_threads = true  # İndirme ana thread'i bloklamaz
	add_child(download_http)
	download_http.request_completed.connect(_on_download_completed)

## HTTP result kod açıklaması (tanı için)
static func _get_result_name(result: int) -> String:
	match result:
		0: return "OK"
		1: return "CHUNKED_BODY_SIZE_MISMATCH"
		2: return "CANT_CONNECT"
		3: return "CANT_RESOLVE"
		4: return "CONNECTION_ERROR"
		5: return "TLS_HANDSHAKE_ERROR"
		6: return "NO_RESPONSE"
		7: return "BODY_SIZE_LIMIT_EXCEEDED"
		8: return "BODY_DECOMPRESS_FAILED"
		9: return "REQUEST_FAILED"
		10: return "DOWNLOAD_FILE_CANT_OPEN"
		11: return "DOWNLOAD_FILE_WRITE_ERROR"
		12: return "REDIRECT_LIMIT_REACHED"
		13: return "TIMEOUT"
		_: return "UNKNOWN(%d)" % result

## Sürüm metnini [Major, Minor, Patch] sayı dizisine çevirir
static func parse_semver(ver: String) -> Array[int]:
	var clean = ver.strip_edges().to_lower().trim_prefix("v")
	var parts = clean.split(".")
	var res: Array[int] = [0, 0, 0]
	for i in range(mini(parts.size(), 3)):
		res[i] = int(parts[i])
	return res

## Uzak sürüm yerel sürümden daha yeni mi denetle
static func is_newer_version(remote: String, local: String) -> bool:
	var r = parse_semver(remote)
	var l = parse_semver(local)
	for i in range(3):
		if r[i] > l[i]:
			return true
		elif r[i] < l[i]:
			return false
	return false

## Mevcut sürümü döndür
func get_current_version() -> String:
	return current_version

## Güncellemeleri denetle
func check_for_updates() -> void:
	if is_checking or is_downloading:
		return
	is_checking = true
	update_check_started.emit()
	
	# GitHub CDN önbellek atlatıcı (cache-busting)
	var cache_buster = str(int(Time.get_unix_time_from_system()))
	var check_url = RAW_VERSION_URL + "?t=" + cache_buster
	
	var headers = [
		"User-Agent: KutuKafalar-AutoUpdater",
		"Accept: application/json",
		"Cache-Control: no-cache, no-store, must-revalidate",
		"Pragma: no-cache"
	]
	
	print("[AutoUpdater] Güncellemeler sorgulanıyor: ", check_url)
	var err = check_http.request(check_url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		is_checking = false
		update_failed.emit("Güncelleme sunucusuna bağlanılamadı (Hata: %d)" % err)

func _on_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_checking = false
	
	var result_name = _get_result_name(result)
	print("[AutoUpdater] Sunucu yanıtı: result=%s code=%d body_size=%d" % [result_name, response_code, body.size()])
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# TLS hatası: bazı PC'lerde SSL sertifikası sorunu (en yaygın neden)
		if result == 5:  # TLS_HANDSHAKE_ERROR
			var msg = "Güncelleme sunucusu SSL bağlantı hatası. İnternet bağlantınızı kontrol edin."
			print("[AutoUpdater] ", msg)
			update_failed.emit(msg)
		elif result == 13:  # TIMEOUT
			var msg = "Güncelleme sunucusu zaman aşımına uğradi. İnternet bağlantınızı kontrol edin."
			print("[AutoUpdater] ", msg)
			update_failed.emit(msg)
		elif result == 2 or result == 3 or result == 4:  # CANT_CONNECT / CANT_RESOLVE / CONNECTION_ERROR
			var msg = "Sunucuya ulaşılamıyor (%s). İnternet bağlantınızı kontrol edin." % result_name
			print("[AutoUpdater] ", msg)
			update_failed.emit(msg)
		elif response_code == 404:
			print("[AutoUpdater] Sürüm dosyası bulunamadı (404).")
			update_not_available.emit(current_version)
		else:
			var msg = "Güncelleme sunucusundan yanıt alınamadı (%s / HTTP %d)" % [result_name, response_code]
			print("[AutoUpdater] ", msg)
			update_failed.emit(msg)
		return
	
	var json_str = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(json_str) != OK:
		update_failed.emit("Sürüm bilgisi okunamadı.")
		return
	
	var data = json.get_data()
	if not data is Dictionary:
		update_failed.emit("Geçersiz sürüm yanıtı.")
		return
	
	latest_version_info = data
	var remote_ver = str(data.get("version", data.get("tag_name", ""))).strip_edges()
	var changelog = str(data.get("changelog", data.get("body", "Yama detayları belirtilmedi.")))
	var pck_url = str(data.get("download_url", ""))
	var pck_size = int(data.get("pck_size", 0))
	
	# Eğer download_url boşsa GitHub Releases varlıklarından ara
	if pck_url.is_empty():
		var assets: Array = data.get("assets", [])
		for a in assets:
			if str(a.get("name", "")).to_lower().ends_with(".pck"):
				pck_url = str(a.get("browser_download_url", ""))
				pck_size = int(a.get("size", 0))
				break
	
	print("[AutoUpdater] Mevcut: %s | Sunucu: %s" % [current_version, remote_ver])
	
	if remote_ver.is_empty() or not is_newer_version(remote_ver, current_version):
		print("[AutoUpdater] Oyun zaten en güncel sürümde.")
		update_not_available.emit(current_version)
		return
	
	if pck_url.is_empty():
		print("[AutoUpdater] Yeni sürüm var fakat indirme bağlantısı tanımlanmamış.")
		update_not_available.emit(current_version)
		return
	
	print("[AutoUpdater] Yeni sürüm tespit edildi: ", remote_ver, " Boyut: ", pck_size)
	update_available.emit(remote_ver, changelog, pck_url, pck_size)

## İndirme işlemini başlat
func start_download(pck_url: String = "") -> void:
	if is_downloading:
		return
	
	if pck_url.is_empty():
		pck_url = str(latest_version_info.get("download_url", ""))
	
	if pck_url.is_empty():
		update_failed.emit("İndirilecek yama bağlantısı bulunamadı.")
		return
	
	_cleanup_residual_downloads()
	
	is_downloading = true
	download_http.download_file = temp_download_path
	
	var headers = [
		"User-Agent: KutuKafalar-AutoUpdater"
	]
	
	print("[AutoUpdater] İndirme başlıyor: ", pck_url, " -> ", temp_download_path)
	var err = download_http.request(pck_url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		is_downloading = false
		update_failed.emit("İndirme isteği başlatılamadı (Hata: %d)" % err)

func _process(_delta: float) -> void:
	if is_downloading and download_http:
		var downloaded = download_http.get_downloaded_bytes()
		var total = download_http.get_body_size()
		if total > 0:
			var pct = clamp(float(downloaded) / float(total) * 100.0, 0.0, 100.0)
			download_progress.emit(pct, downloaded, total)

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	is_downloading = false
	download_http.download_file = "" # Dosya kilidini serbest bırak
	
	var result_name = _get_result_name(result)
	print("[AutoUpdater] İndirme tamamlandı: result=%s code=%d" % [result_name, response_code])
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var detail = "%s / HTTP %d" % [result_name, response_code]
		if result == 5:
			detail = "SSL/TLS sertifika hatası"
		elif result == 13:
			detail = "Zaman aşımı - indirme yavaş bağlantıda tamamlanamadı"
		print("[AutoUpdater] İndirme başarısız: ", detail)
		update_failed.emit("Dosya indirilemedi (%s)" % detail)
		return
	
	if not FileAccess.file_exists(temp_download_path):
		update_failed.emit("İndirilen yama dosyası oluşturulamadı.")
		return
	
	var file_size = FileAccess.get_file_as_bytes(temp_download_path).size()
	if file_size < 1024:
		DirAccess.remove_absolute(temp_download_path)
		update_failed.emit("İndirilen dosya geçersiz veya bozuk.")
		return
	
	print("[AutoUpdater] İndirme başarıyla tamamlandı. Dosya boyutu: ", file_size, " bayt.")
	download_completed.emit()

## Güncellemeyi uygula ve oyunu yeniden başlat
func apply_update_and_restart() -> void:
	if not FileAccess.file_exists(temp_download_path):
		update_failed.emit("Uygulanacak güncelleme dosyası bulunamadı.")
		return
	
	# Eğer hedef PCK diski bulunamazsa (sadece Godot editör geliştirme ortamında çalışırken)
	if not FileAccess.file_exists(target_pck_path):
		print("[AutoUpdater] Hedef PCK bulunamadı (Editör geliştirme ortamı). Runtime pack yükleniyor...")
		ProjectSettings.load_resource_pack(temp_download_path, true)
		_load_local_version()
		get_tree().reload_current_scene()
		return
	
	# Windows bağımsız çalıştırıcı (Standalone)
	var updater_cmd_path = ProjectSettings.globalize_path("user://apply_update.cmd")
	var pid = OS.get_process_id()
	var src = temp_download_path.replace("/", "\\")
	var dst = target_pck_path.replace("/", "\\")
	var exe = exe_path.replace("/", "\\")
	
	# Güvenilir Windows CMD betiği:
	# 1. tasklist ile oyun PID'sinin tamamen kapanmasını bekler (dosya kilitlerini çözer)
	# 2. ping 127.0.0.1 ile güvenli bekleme yapar (timeout gibi stdin yönlendirmelerinde çökmez)
	# 3. Dosyayı hedefe kopyalar, başarılı olunca geçici dosyayı ve betiği temizleyip oyunu açar
	var script_content = """@echo off
chcp 65001 >nul
title Kutu Kafalar - Guncelleme Uygulaniyor

set "PID=%s"
set "SRC=%s"
set "DST=%s"
set "EXE=%s"

:wait_game
tasklist /fi "PID eq %%PID%%" 2>nul | find "%%PID%%" >nul
if not errorlevel 1 (
    ping 127.0.0.1 -n 2 >nul
    goto wait_game
)

:: Dosya kilitlerinin tamamen serbest kalmasi icin kisa bekleme
ping 127.0.0.1 -n 2 >nul

set /a tries=0
:copy_loop
copy /y "%%SRC%%" "%%DST%%" >nul 2>&1
if not errorlevel 1 goto copy_success
set /a tries+=1
if %%tries%% geq 20 goto copy_failed
ping 127.0.0.1 -n 2 >nul
goto copy_loop

:copy_success
del /f /q "%%SRC%%" >nul 2>&1
start "" "%%EXE%%"
del "%%~f0" >nul 2>&1
exit /b 0

:copy_failed
start "" "%%EXE%%"
del "%%~f0" >nul 2>&1
exit /b 1
""" % [str(pid), src, dst, exe]
	
	var file = FileAccess.open(updater_cmd_path, FileAccess.WRITE)
	if not file:
		print("[AutoUpdater] Betik oluşturulamadı, direkt pack yükleniyor...")
		ProjectSettings.load_resource_pack(temp_download_path, true)
		_load_local_version()
		get_tree().reload_current_scene()
		return
	
	file.store_string(script_content)
	file.close()
	
	print("[AutoUpdater] apply_update.cmd başlatılıyor, oyun kapatılıyor...")
	OS.create_process("cmd.exe", ["/c", updater_cmd_path])
	get_tree().quit(0)
