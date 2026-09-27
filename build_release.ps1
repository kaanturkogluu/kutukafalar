param(
    [string]$NewVersion = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  KUTU KAFALAR - OYUN DERLEME VE PAKETLEME (RELEASE)    " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

$GodotExe = "C:\Users\Crawl\Downloads\Godot_v4.7.2-stable_win64.exe"
$ProjectDir = $PSScriptRoot
$BuildsRoot = Join-Path $ProjectDir "builds"
$GameDir = Join-Path $BuildsRoot "KutuKafalar"
$VersionJsonPath = Join-Path $ProjectDir "version.json"

if (-not (Test-Path $GodotExe)) {
    Write-Host "[HATA] Godot bulunamadı: $GodotExe" -ForegroundColor Red
    exit 1
}

# 1. Sürüm bilgisini version.json üzerinden yönet (Tek Kaynak)
$Version = "v1.3.0"
$vData = $null
if (Test-Path $VersionJsonPath) {
    try {
        $rawJson = [System.IO.File]::ReadAllText($VersionJsonPath, [System.Text.Encoding]::UTF8)
        $vData = $rawJson | ConvertFrom-Json
        if ($vData.version) { $Version = $vData.version }
    } catch {
        Write-Host "[UYARI] version.json okunamadı, varsayılan sürüm kullanılacak." -ForegroundColor DarkYellow
    }
}

if ($NewVersion -ne "") {
    if (-not $NewVersion.StartsWith("v") -and -not $NewVersion.StartsWith("V")) {
        $NewVersion = "v$NewVersion"
    }
    $Version = $NewVersion
    if ($vData) {
        $vData.version = $Version
    }
}

Write-Host "Derlenecek Sürüm: $Version" -ForegroundColor Green
Write-Host ""

# 2. Derleme klasörlerini hazırla
Write-Host "1. Derleme klasörleri hazırlanıyor..." -ForegroundColor Yellow
if (-not (Test-Path $BuildsRoot)) {
    New-Item -ItemType Directory -Path $BuildsRoot -Force | Out-Null
}
if (Test-Path $GameDir) {
    try {
        Remove-Item -Path $GameDir -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host "   (Oyun veya dosya açık olduğu için klasör temizlenemedi, üzerine yazılacak)" -ForegroundColor DarkGray
    }
}
New-Item -ItemType Directory -Path $GameDir -Force | Out-Null

$PckOut = Join-Path $GameDir "KutuKafalar.pck"
$StandalonePck = Join-Path $BuildsRoot "KutuKafalar.pck"
$ZipOut = Join-Path $BuildsRoot "KutuKafalar-$Version-Windows.zip"

# *** KRİTİK: PCK derlenmesinden ÖNCE version.json'ı diske yaz ***
# Aksi hâlde Godot derleme sırasında eski version string'ini PCK'ya gömer
# ve güncelleme döngüsü oluşur (oyuncu güncelleyip yeniden başlatsa bile hep eski versiyon görünür).
if ($vData) {
    $vData.pck_size = 0  # Geçici sıfır; PCK boyutu derleme sonrası güncellenecek
    $jsonString = $vData | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($VersionJsonPath, $jsonString, [System.Text.UTF8Encoding]::new($false))
    Write-Host "1.5. version.json PCK derlemesi öncesi diske yazıldı (Sürüm: $Version)" -ForegroundColor DarkGreen
}

# 3. Godot ile KutuKafalar.pck paketini derle
Write-Host "2. KutuKafalar.pck paketi Godot ile derleniyor (version.json icinde: $Version)..." -ForegroundColor Yellow
$proc = Start-Process -FilePath $GodotExe -ArgumentList @('--headless', '--path', $ProjectDir, '--export-pack', 'Windows', $PckOut) -Wait -PassThru

if (-not (Test-Path $PckOut)) {
    Write-Host "[HATA] PCK paketi üretilemedi!" -ForegroundColor Red
    exit 1
}

$pckItem = Get-Item $PckOut
$pckSize = $pckItem.Length

# 4. version.json dosyasındaki pck_size değerini otomatik güncelle
if ($vData) {
    $vData.pck_size = [int]$pckSize
    $jsonString = $vData | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($VersionJsonPath, $jsonString, [System.Text.UTF8Encoding]::new($false))
    Write-Host "3. version.json güncellendi (PCK Boyutu: $([math]::Round($pckSize / 1KB, 1)) KB)" -ForegroundColor Yellow
}

# 5. KutuKafalar.exe oluştur
Write-Host "4. KutuKafalar.exe oluşturuluyor..." -ForegroundColor Yellow
$TargetExe = Join-Path $GameDir "KutuKafalar.exe"
try {
    Copy-Item -Path $GodotExe -Destination $TargetExe -Force -ErrorAction Stop
} catch {
    Write-Host "   (KutuKafalar.exe kullanımda, mevcut çalıştırıcı korundu)" -ForegroundColor DarkGray
}

# 6. Git için builds/KutuKafalar.pck kopyala
Write-Host "5. builds/KutuKafalar.pck güncelleniyor (Doğrudan Git otomatik güncellemesi için)..." -ForegroundColor Yellow
Copy-Item -Path $PckOut -Destination $StandalonePck -Force

# 7. İlk kurulum ZIP arşivi oluştur
Write-Host "6. Arkadaşlara ilk kez gönderilecek ZIP arşivi hazırlanıyor..." -ForegroundColor Yellow
if (Test-Path $ZipOut) {
    Remove-Item -Path $ZipOut -Force
}
Compress-Archive -Path "$GameDir\*" -DestinationPath $ZipOut -Force

$zipItem = Get-Item $ZipOut

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  TEBRİKLER! OYUN BAŞARIYLA PAKETLENDİ!                 " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Üretilen Dosyalar ($BuildsRoot):" -ForegroundColor White
Write-Host "1) $($zipItem.Name) [$([math]::Round($zipItem.Length / 1MB, 2)) MB] -> Arkadaşlarınıza ilk kez göndereceğiniz tam paket." -ForegroundColor Cyan
Write-Host "2) $($pckItem.Name) [$([math]::Round($pckSize / 1KB, 1)) KB] -> Otomatik güncelleme PCK dosyası." -ForegroundColor Yellow
Write-Host ""
Write-Host "GÜNCELLEMEYİ YAYINLAMAK İÇİN SADECE ŞUNLARI ÇALIŞTIRIN:" -ForegroundColor Magenta
Write-Host "   git add version.json builds/KutuKafalar.pck" -ForegroundColor White
Write-Host "   git commit -m `"release: $Version`"" -ForegroundColor White
Write-Host "   git push origin main" -ForegroundColor White
Write-Host ""
Write-Host "Oyuncular oyunu açtıklarında bu güncellemeyi doğrudan alacaktır!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
