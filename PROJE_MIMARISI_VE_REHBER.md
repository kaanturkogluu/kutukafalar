# 🏗️ KUTU KAFALAR FPS - PROJE MİMARİSİ VE ÇALIŞMA REHBERİ

Bu rehber, projenin **klasör yapısını**, **kod mimarisini** ve **token tasarruflu geliştirme sürecini** netleştirmek için hazırlanmıştır. Projeyi geliştirirken kaybolmamak, her dosyanın yerini bilmek ve yapay zeka ile çalışırken gereksiz token tüketiminin önüne geçmek için bu standartları uygulayacağız.

---

## 1. Klasör ve Dosya Hiyerarşisi

Godot 4 projemizde her şey derli toplu ve modüler olacak:

```
c:/Users/Crawl/Documents/kutukafalar/
│
├── 📂 assets/                     # Görsel ve İşitsel Kaynaklar
│   ├── audio/                     # Mermi, zombi inleme, patlama ve retro sesler
│   ├── materials/                 # Kutu zombi ve oyuncu renkleri/materyalleri
│   └── models/                    # Küp modelleri ve silah tasarımları
│
├── 📂 scenes/                     # Godot Sahneleri (.tscn)
│   ├── ui/                        # Ana Lobi, HUD (Can barı, Kombo sayacı), Skor ekranı
│   ├── player/                    # Oyuncu sahnesi (Kamera, Kollar, Kutu Kafa modeli)
│   ├── enemies/                   # Zombi çeşitleri (Beyaz Zombi, Kırmızı Şeytan)
│   ├── interactables/             # Kırmızı/Mavi/Yeşil variller, barikatlar, taretler
│   ├── levels/                    # Kat haritaları ve Asansör sahnesi
│   └── weapons/                   # Mermiler, roketler, patlama efektleri
│
├── 📂 scripts/                    # GDScript Kodları (.gd)
│   ├── autoload/                  # Tekil Yöneticiler (Singletons)
│   │   ├── NetworkManager.gd      # Lobi kurma, katılma, IP ve P2P yönetimi
│   │   ├── GameManager.gd         # Oyunun durumu (Dalga, kat sayısı, skor)
│   │   └── SteamManager.gd        # İleride Steamworks Leaderboard bağlantısı
│   ├── player/                    # FPSController.gd, PlayerHealth.gd, SpellManager.gd
│   ├── enemies/                   # ZombieAI.gd, DevilAI.gd
│   ├── combat/                    # Damageable.gd, Hitbox.gd, Projectile.gd
│   └── world/                     # Elevator.gd, Spawner.gd, FloorGenerator.gd
│
├── 📄 OYUN_TASARIM_VE_PLANLAMA.md # Oyunun detaylı tasarım belgesi (GDD)
└── 📄 PROJE_MIMARISI_VE_REHBER.md # Bu rehber dosyası
```

---

## 2. Sistemlerin Çalışma Mantığı (Nasıl İnşa Edeceğiz?)

### A) Çok Oyunculu (Multiplayer) İskeleti
* **`NetworkManager.gd` (Autoload):**
  * Oyun başlar başlamaz hafızada durur.
  * "Oda Kur" (Host) denildiğinde bir sunucu açar.
  * "Katıl" (Join) denildiğinde hedef IP'ye (veya ileride Steam lobisine) bağlanır.
* **Oyuncu Doğurma (`MultiplayerSpawner`):**
  * Yeni bir oyuncu bağlandığında, sunucu otomatik olarak `player.tscn` örneğini sahnede oluşturur ve diğer tüm oyunculara bu karakteri kopyalar.
* **Pozisyon Eşitleme (`MultiplayerSynchronizer`):**
  * Oyuncunun yürümesi, zıplaması ve kafasını çevirmesi bu bileşenle anlık olarak diğer oyuncuların ekranına yansıtılır.

### B) Zombi ve Düşman Yapay Zekası
* **Sıfır İnternet Kasmaları (Host-Authoritative):**
  * Zombileri sadece **Host (Oda Kurucusu)** hesaplar ve yönetir.
  * Diğer oyuncuların bilgisayarı zombi yapay zekasıyla yorulmaz; sadece sunucudan gelen zombi pozisyonlarını çizer.

### C) Büyü ve Skill Sistemi
* Her oyuncunun üzerinde bir `SpellManager.gd` bileşeni bulunur:
  * `E` tuşuna basıldığında taktiksel büyü çalışır (Bekleme süresi başlar).
  * Zombi kestikçe veya kombo çarpanı arttıkça bekleme süreleri azalır.

---

## 3. Token Tasarrufu ve Verimli İlerleme Kuralları

Projeyi geliştirirken token tüketimini minimumda tutmak ve hızlı ilerlemek için uygulayacağımız çalışma disiplini:

1. **Modüler Parçalar (Küçük Dosyalar):**
   * Tek bir dosyaya 500 satır kod yazmak yerine, işlevleri 40-80 satırlık küçük scriptlere böleceğiz. Bu sayede bir değişiklik yaparken devasa kod bloklarını tekrar tekrar okumak/yazmak zorunda kalmayacağız.
2. **Adım Adım (Faz Bazlı) Onay:**
   * Her adımda tek bir somut hedefi tamamlayacağız (Örn: *Adım 1: Sadece Lobi ve 2 Oyuncunun bağlanması*).
   * Çalıştığını test edip onayladıktan sonra bir sonraki adıma (Zombilere) geçeceğiz.
3. **Tekrar Eden Kodları Önleme:**
   * Godot'nun yerleşik bileşenlerini (`RayCast3D`, `NavigationAgent3D`, `GPUParticles3D`) hazır kullanarak sıfırdan tekerleği yeniden icat etmeyeceğiz.

---

## 4. Tamamlanan Sistemler ve Mevcut Durum

* [x] **Faz 1: Çok Oyunculu Altyapı ve Lobi:**
  * Host-Client bağlantısı (`NetworkManager.gd`), oyuncu senkronizasyonu (`MultiplayerSynchronizer` ve `MultiplayerSpawner`).
* [x] **Faz 2: Düşman Yapay Zekası ve Dalga Döngüsü:**
  * Host-authoritative zombi kovalama ve saldırı sistemi (`ZombieAI.gd`), kat ve dalga yöneticisi (`MainLevel.gd`), kat asansörü (`Elevator.gd`).
* [x] **Faz 3: Çoklu Silahlar, Büyüler ve Ekonomi:**
  * Tabanca, Uzi, Pompalı, Roketatar, Kutu Tekmesi, 4 sınıfın taktik ve ulti büyüleri (`SpellManager.gd`), Asansör Mağazası (`Shop.gd`).
* [x] **Faz 4: Vuruş Hissi, Hasar Geri Bildirimi ve Ölüm/Canlanma Döngüsü:**
  * **Hasar Efektleri:** Ekran radyal kan/vignette kaplaması (`GradientTexture2D`), ani kırmızı hasar flaşı, kamera travma sarsıntısı/açısal tepme, 3D model kırmızı parlaması (`material_override`).
  * **Kritik Can Bildirimi:** Can <%30 altına indiğinde nabız/kalp atışı ritmiyle atan kenar kan efekti.
  * **Ölüm Mekaniği:** `is_dead` durumuyla tüm kontrollerin ve çarpışmanın kapanması, karakterin yere devrilmesi, 3D küp parçalanması (`cube_gibs.tscn`), kamera yere yatışı, `DeathScreen` arayüzü ve `[R]` tuşuyla hızlı yeniden başlama desteği.
* [x] **Faz 5: Silah Sesleri, Dinamik Envanter ve Mermi Tüketim Mekaniği:**
  * **Prosedürel Retro Ses Sistemi (`SoundManager.gd`):** Harici ses dosyasına ihtiyaç duymadan GDScript matematiksel dalga fonksiyonlarıyla (`AudioStreamWAV` 16-bit PCM) sıfır gecikmeli retro arcade silah sesleri (`pistol`, `shotgun`, `uzi`, `rocket`, `switch`, `empty`, `pickup`) oluşturuldu. Hem 2D arayüz hem de çok oyunculu 3D uzamsal ses desteği sağlandı.
  * **Toplanabilir Silah Envanteri:** Oyuncu başlangıçta sınırsız mermili tabanca ile başlar. Zombilerden düşen veya kutulardan çıkan silahlar (`shotgun`, `uzi`, `rocket`) alındığında dinamik olarak envantere eklenir, mermiler üst üste birikir ve yeni toplanan silah otomatik donatılır.
  * **Fare Tekerleği (Scroll) ve Slot Geçişi:** `Fare Tekerleği Yukarı/Aşağı` (`WHEEL_UP` / `WHEEL_DOWN`) ile mevcut toplanmış tüm silahlar arasında akıcı geçiş ve `1, 2, 3, 4` sayı tuşlarıyla doğrudan silah seçimi eklendi. Silah değişiminde hafif eğilme animasyonu ve mekanik değiştirme tıkırtısı oynatılır.
  * **Mermisi Biten Silahın Kullanımdan Kalkması:** Pompalı, Uzi veya Roketatarın mermisi bittiğinde silah otomatik olarak envanterden silinir, boş mermi klik sesi (`empty`) çalar, arayüzde bildirim çıkar ve oyuncu otomatik olarak bir önceki silaha veya tabancaya geçirilir.
  * **Gelişmiş Silah HUD'ı:** Aktif silah adı, mermi sayısı, sahip olunan silahların slot listesi (`▶ [1: Tabanca (∞)] [2: Pompalı (16)]`) ve geçici bildirimler gerçek zamanlı olarak HUD'da gösterilir.
  * **Asansör Mağaza Tıklama Yalıtımı:** Mağaza açıkken veya fare görünür moddayken (`is_in_shop` / `MOUSE_MODE_VISIBLE`) tüm silah ateşleme, tekme, büyü atma ve tekerlek geçişleri kilitlendi; satın alma butonlarına tıklandığında karakterin ateş etmesi ve mermi harcaması tamamen önlendi. Kart alımlarına `pickup` ve `empty` ses efektleri eklendi.
* [x] **Faz 6: Bağımsız EXE Derleme, Paketleme ve GitHub Otomatik Güncelleyici:**
  * **GitHub Releases Entegrasyonu (`AutoUpdater.gd`):** Oyun açıldığında `https://api.github.com/repos/kaanturkogluu/kutukafalar/releases/latest` adresini sorgular. Yeni bir sürüm (`tag_name`) varsa lobide indirme çubuğuyla birlikte güncelleme modalı açılır.
  * **Hafif Paket Dağıtımı (`.pck`):** Tüm oyunu baştan indirmek yerine yalnızca **220 KB** boyutundaki `KutuKafalar.pck` dosyası 1 saniyede indirilir ve oyun otomatik olarak yeniden başlatılarak güncellenir.
  * **Tek Tık Derleme Aracı (`build_release.bat` / `build_release.ps1`):** Projeyi doğrudan `builds/` klasörüne bağımsız Windows `.exe`, `.pck` ve arkadaşlara gönderilecek ilk kurulum `KutuKafalar-v1.0.0-Windows.zip` olarak paketler.
* [x] **Faz 7: İki Aşamalı Bekleme Odası (Lobi), Hazır Sistemi, İzleyici Modu ve Geç Katılım Koruması:**
  * **İki Aşamalı Lobi & Bekleme Odası (`Lobby.gd` & `scenes/ui/lobby.tscn`):**
    * 1. Aşama (`ConnectPanel`): İsim, Sınıf ve IP girilerek "Oda Kur" veya "Odaya Katıl" denir.
    * 2. Aşama (`RoomPanel` - Bekleme Odası): Tüm bağlı oyuncular bir arada listelenir. Sınıfları, isimleri, `👑 [ODA SAHİBİ]`, `✅ HAZIR` veya `⏳ BEKLİYOR` durum rozetleri canlı olarak senkronize edilir.
    * İstemciler `✅ HAZIR OL` / `❌ HAZIR DEĞİLİM` butonlarıyla hazır durumunu değiştirir.
    * Oda Sahibi (Host), herkes hazır olduğunda veya istediği anda `🚀 OYUNU BAŞLAT` butonuna basarak tüm oyuncuları aynı anda `main_level.tscn` sahnesine taşır.
    * Oyuncular dilediklerinde `🚪 ODADAN AYRIL` butonuyla odayı terk edip ana menüye dönebilir.
  * **Geç Katılım ve Oyun Bozulması Koruması (`NetworkManager.gd`):**
    * Oyun başladıktan sonra (`is_game_in_progress = true`) gelen tüm geç bağlantılar otomatik olarak reddedilir (`_reject_connection`) ve kullanıcıya "Oyun şu anda devam ediyor!" uyarısı verilerek bağlantı temiz şekilde kapatılır; böylece dalga ve kat akışı bozulmaz.
    * Host oyunu kapattığında veya ayrıldığında tüm istemciler donup kalmak yerine güvenle lobi ekranına yönlendirilir.
  * **Ölüm Senkronizasyonu & Çok Oyunculu İzleyici Modu (Spectator Mode - `FPSController.gd`):**
    * Çok oyunculu modda bir oyuncu öldüğünde tek bir oyuncunun `[R]` / `Space` / `Yeniden Başlat` tuşuna basarak oyunu erken sıfırlaması engellendi (`all_players_dead` kilidi).
    * Ölen oyuncu hemen 3. şahıs **İzleyici Moduna (Spectator)** geçer; kamera pürüzsüz biçimde hayatta kalan takım arkadaşının arkasına geçer ve onu takip eder.
    * `[Sol Tık]` veya `[Boşluk]` tuşuna basarak hayattaki diğer takım arkadaşları arasında geçiş yapılabilir.
    * Takım arkadaşları katı temizleyip asansöre ulaştığında ölen oyuncular asansörde otomatik olarak canlanır.
    * Ancak **tüm takım elendiğinde** Oyun Bitti (Game Over) ekranı gelir ve `[R]` tuşuyla 1. Kattan baştan başlatmaya izin verilir.


