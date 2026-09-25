@echo off
echo ==============================================
echo   KUTU KAFALAR FPS - CIFT PENCERE TESTI
echo ==============================================
echo 1. Pencere (Host / Sunucu) baslatiliyor...
start "" "C:\Users\Crawl\Downloads\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --resolution 960x540 --position 50,100

timeout /t 2 /nobreak >nul

echo 2. Pencere (Client / Istemci) baslatiliyor...
start "" "C:\Users\Crawl\Downloads\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --resolution 960x540 --position 1020,100

echo.
echo Test pencereleri acildi!
echo - 1. Ekranda 'ODA KUR (HOST)' butonuna basin.
echo - 2. Ekranda 'ODAYA KATIL (JOIN)' butonuna basin.
