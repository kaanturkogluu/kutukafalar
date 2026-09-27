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
$Version = "v1.1.6"
if (Test-Path $VersionJsonPath) {
    $vData = Get-Content $VersionJsonPath -Raw | ConvertFrom-Json
    if ($vData.version) { $Version = $vData.version }
}
$ZipOut = Join-Path $BuildsRoot "KutuKafalar-$Version-Windows.zip"
$PckOut = Join-Path $GameDir "KutuKafalar.pck"
$StandalonePck = Join-Path $BuildsRoot "KutuKafalar.pck"

if (-not (Test-Path $GodotExe)) {
    Write-Host "[HATA] Godot bulunamadı: $GodotExe" -ForegroundColor Red
    exit 1
}

Write-Host "1. Derleme klasörleri hazırlanıyor..." -ForegroundColor Yellow
if (Test-Path $GameDir) {
    try {
        Remove-Item -Path $GameDir -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host "   (Oyun açık olduğu için klasör silinmedi, mevcut klasör kullanılıyor)" -ForegroundColor DarkGray
    }
}
New-Item -ItemType Directory -Path $GameDir -Force | Out-Null

Write-Host "2. KutuKafalar.pck paketi üretiliyor..." -ForegroundColor Yellow
$proc = Start-Process -FilePath $GodotExe -ArgumentList @('--headless', '--path', $ProjectDir, '--export-pack', 'Windows', $PckOut) -Wait -PassThru

if (-not (Test-Path $PckOut)) {
    Write-Host "[HATA] PCK paketi üretilemedi!" -ForegroundColor Red
    exit 1
}

Write-Host "3. KutuKafalar.exe oluşturuluyor..." -ForegroundColor Yellow
$TargetExe = Join-Path $GameDir "KutuKafalar.exe"
try {
    Copy-Item -Path $GodotExe -Destination $TargetExe -Force -ErrorAction Stop
} catch {
    Write-Host "   (KutuKafalar.exe çalışır durumda, mevcut exe korundu)" -ForegroundColor DarkGray
}

Write-Host "4. GitHub Releases için standalone KutuKafalar.pck kopyalanıyor..." -ForegroundColor Yellow
Copy-Item -Path $PckOut -Destination $StandalonePck -Force

Write-Host "5. Arkadaşlara gönderilecek ilk kurulum ZIP arşivi hazırlanıyor..." -ForegroundColor Yellow
if (Test-Path $ZipOut) {
    Remove-Item -Path $ZipOut -Force
}
Compress-Archive -Path "$GameDir\*" -DestinationPath $ZipOut -Force

$zipItem = Get-Item $ZipOut
$pckItem = Get-Item $StandalonePck

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  TEBRİKLER! OYUN BAŞARIYLA PAKETLENDİ!                 " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Oluşturulan Dosyalar ($BuildsRoot):" -ForegroundColor White
Write-Host "1) $($zipItem.Name) - [$([math]::Round($zipItem.Length / 1MB, 2)) MB] -> Arkadaşınıza İLK KEZ göndereceğiniz tam paket." -ForegroundColor Cyan
Write-Host "2) $($pckItem.Name) - [$([math]::Round($pckItem.Length / 1KB, 1)) KB] -> GitHub Releases'a yükleyeceğiniz güncelleme dosyası." -ForegroundColor Yellow
Write-Host ""
