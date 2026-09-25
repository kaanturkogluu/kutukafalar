# 📦 KUTU KAFALAR FPS (BOXHEAD: CO-OP REBORN)
## Oyun Tasarım ve Planlama Dokümanı (Game Design Document)

---

## 1. Proje Özeti ve Vizyon
* **Tür:** 1. Şahıs Nişancı (FPS) / Co-Op Horde Survival / Hafif Roguelite-RPG
* **İlham Kaynakları:** *Boxhead: 2Play Rooms*, *Killing Floor*, *Gunfire Reborn*, *Risk of Rain 2*, *Roboquest*
* **Oyun Motoru:** Godot 4.x (Jolt Physics, Forward+)
* **Hedef Platform:** PC (Steam)
* **Oyuncu Sayısı:** 1 - 4 Kişi (Online Co-Op)
* **Görsel Stil:** Voxel / Low-Poly Retro Kutu Estetiği (Küp karakterler, etrafa saçılan küp parçalanma fiziği - Gibs/Gore)

---

## 2. Temel Oynanış Döngüsü (Core Gameplay Loop)

```
[Kat Başlangıcı] ➔ [Zombi Dalgasını Savuştur] ➔ [Kombo & Büyü Sinerjisi] 
       ➔ [Asansöre Ulaş] ➔ [Skill / Yükseltme Seç] ➔ [Bir Alt Kata İn]
```

1. **Akıcı FPS Hareketi:** Hızlı koşma, zıplama, taktiksel pozisyon alma.
2. **Kutu Fiziği ve Vuruş Hissi:** Zombileri vurduğunda kafaların/kolların fırlaması; roket veya patlayan varille vurulduklarında onlarca küçük küpe ayrılarak parçalanması.
3. **Boxhead Kombo (Multiplier) Sistemi:** 
   * Seri zombi öldürdükçe ekrandaki çarpan ($x1 \rightarrow x2 \rightarrow x5 \rightarrow x10$) artar.
   * Çarpan yüksek tutuldukça büyülerin bekleme süreleri (cooldown) çok daha hızlı dolar veya anında sıfırlanır, hareket hızı artar.
4. **İnşaat ve Elementel Taktik Savunma (Variller):**
   * 🔴 **Kırmızı Varil (Ateş / Patlama):** Klasik devasa alan hasarı ve yakıcı patlama.
   * 🔵 **Mavi Varil (Kriyojenik / Buz):** Hasar vermez, 5 metre içindeki tüm zombileri buz heykeline çevirir (Tekmeyle veya pompalıyla parçalama fırsatı).
   * 🟢 **Yeşil Varil (Asit / Biyolojik Tehlike):** Yere asit birikintisi saçar, üzerinden geçen zombilerin bacaklarını eritip sürünmelerine neden olur.
   * 🟡 **Sarı Varil (Şok / Overcharge):** Patladığında elektrik arkı yayar, yakındaki taretleri geçici olarak 2 kat hızlı ateşletir.
   * **Barikatlar & Taretler:** Zombileri dar koridorlara yönlendirir ve otomatik koruma sağlar.
5. **Kutu Tekmesi ve Yakın Dövüş (`F` Tuşu):**
   * Mermi bittiğinde veya sıkışıldığında zombilere sert bir tekme atarak onları geriye savurma.
   * Zombileri kırmızı patlayıcı varillerin üzerine tekmeleyip tek mermiyle havaya uçurma taktiği!
   * **Doom Tarzı Mühimmat Düşürme:** Tekmeyle veya varil patlamasıyla ölen zombilerden parlayan renkli mermi küpleri saçılır; oyuncu sürekli hücumda kalır.
6. **Ölüm, Yerde Kalan Ceset ve Canlanma Döngüsü (Revive & Spectator):**
   * **Yerde Kalan Ceset (Downed Body):** Canı sıfırlanan oyuncu ölür ve kutu modeli yere devrilmiş (85 derece yatık) şekilde haritada kalır. Başının üstünde `💀 [Oyuncu] \n[E] Canlandır (10 sn)` rozeti belirir.
   * **10 Saniyelik [E] ile Canlandırma:** Hayattaki takım arkadaşı yerdeki cesedin 3.2m yakınına gelip baktığında ekranda canlandırma arayüzü çıkar. `[E]` tuşuna 10 saniye basılı tutarak takım arkadaşını bulunduğu noktada 50 Canla ayağa kaldırabilir. Canlandırma esnasında ölü oyuncunun ekranında arkadaşının kurtarma ilerlemesi anlık yüzde olarak gösterilir.
   * **İzleyici Modu & Gizlenebilir Arayüz (Spectator Mode & [H] Toggle):** Ölen oyuncu hemen 3. şahıs izleyici moduna geçer; kamera hayattaki arkadaşını arkadan takip eder. `[Sol Tık]` / `[Sağ Tık]` ile oyuncular arasında geçiş yapılır. `[H]` tuşu veya butona basılarak ekrandaki tüm yazılar gizlenip temiz görüntü alınabilir.
   * **Asansörde Yeniden Doğma (Elevator Respawn):** Kat temizlenip hayattaki tüm oyuncular asansöre bindiğinde, ölen oyuncular sonraki katta otomatik olarak canlandırılır.
   * **Tüm Takım Elenme (Game Over):** Yalnızca tüm takım arkadaşları öldüğünde oyun biter ve lobi sahibine `[R]` tuşuyla sıfırdan başlatma yetkisi verilir. Hayatta oyuncu varken kazara oyun sıfırlanamaz.
7. **Dost Ateşi ve Kaos Fiziği (Friendly Fire - Lobi Tercihine Bağlı):**
   * Lobi kurucusu dost ateşini açıp kapatabilir.
   * Kapalıyken bile varil patlamaları arkadaşları komik bir şekilde havaya fırlatır (Ragdoll/İtişme fiziği - hasar almazlar ama kaos ve eğlence korunur).
8. **Dinamik Müzik (Adaptive Soundtrack):**
   * Kombo çarpanı arttıkça müzik katmanlaşır (x1'de hafif bas $\rightarrow$ x10'da çılgın synth-metal elektro gitarlar devreye girer).

---

## 3. Büyü ve Yetenek (Spell / Skill) Sistemi [Hafif RPG]

Silah kullanımını zenginleştiren, takım oyununu ve sınıf rollerini belirleyen aktif büyü sistemi.

### A) Kontrol Şeması ve Dengeleme
* **`E` Tuşu - Taktiksel Büyü (Tactical Spell):** 14 saniye bekleme süreli, stratejik ve fırlatılabilir yetenekler.
* **`Q` Tuşu - Ultimate Büyü (Büyük Büyü):** %0'dan başlayan, ~40 zombi kestikçe veya yüksek kombo yaptıkça dolan kıymetli kurtarıcı güçler.

### B) 4 Kutu Kafa Sınıfı (Classes & Spells)

#### 1. Kutu Büyücüsü (Pyromancer)
* **[E] Ateş Dalgası:** Önündeki alana doğru genişleyen ve zombileri yakıp savuran alev hattı fırlatır.
* **[Q - Ulti] Kutu Kıyameti (Meteor):** Nişan alınan yere gökyüzünden alevli devasa bir küp indirir; 9 metrelik alandaki tüm zombileri havaya uçurur.

#### 2. Teknisyen / Mühendis (Engineer)
* **[E] Fırlatılan Manyetik Vortex Bombası:** Bomba gibi fırlatılır; çarptığı yerde dev bir kütleçekim girdabı açar ve 9 metredeki tüm zombileri merkezine çeker (Zombileri tek noktaya toplar, tam varillik tuzak!).
* **[Q - Ulti] İkiz Manyetik Vortex Alanı:** Geniş alanda zombileri sıkıştırıp felç eder.

#### 3. Buz Muhafızı (Cryomancer)
* **[E] Fırlatılan Kriyojenik Buz Bombası:** Fırlatılan buz kristali çarptığı anda parçalanır ve alandaki tüm zombileri 4.5 saniyeliğine buzdan heykellere çevirir!
* **[Q - Ulti] Buzul Fırtınası (Blizzard):** Haritadaki tüm zombileri 6 saniyeliğine anında dondurur.

#### 4. Sahra Sıhhiyesi / Doktor (Combat Medic)
* **[E] Fırlatılan Şifa Bombası:** Fırlatıldığı yerde 5 saniye süren zümrüt yeşili bir alan açar; içindeki oyuncuların canını saniyede 15 yeniler, giren zombilere asit hasarı verir.
* **[Q - Ulti] Adrenalin Dalgası (Team Overdrive):** Tüm takım arkadaşlarının canını tek tuşla anında %100'e doldurur ve hayatta tutar.

### C) Takım Büyü Komboları (Team Synergies)
* **Vortex + Meteor:** Mühendis zombileri tek noktaya toplar, Büyücü tam ortalarına devasa meteor indirir.
* **Buz + Roketatar:** Şifacı odayı dondurur, takım arkadaşı tek bir roketle donmuş zombileri cam gibi kırar.

---

## 4. Bölüm Yapısı: "Sonsuz Tesis" (The Infinite Complex)

Oyunun 2-3 aşamada bitmemesini sağlayan asansör ve kat döngüsü.

```
Kat 1-4 (Temizleme & Isınma) 
   ➔ Asansör (Skill Seçimi)
Kat 5 (BOSS KAT 1) 
   ➔ Tahliye mi? / Devam mı? (Risk vs Reward)
Kat 6-9 (Zorlaşan Katlar, Çevre Tuzakları)
   ➔ Asansör (Gelişmiş Skill Seçimi)
Kat 10 (BOSS KAT 2 - Mega Devil) 
   ➔ Çevre Tehlikeleri Başlar (Karanlık, Gaz vb.)
... (Kat Sayısı Sınırsız İlerler)
```

1. **Katlar (Floors):** Her kat rastgele üretilen bir odadır (Depo, Laboratuvar, Dar Tüneller, Reaktör Çekirdeği).
2. **Asansör (Yükseltme Molası):** Kat temizlendiğinde asansöre binilir ve her oyuncu 3 rastgele karttan bir skill güçlendirmesi seçer:
   * *Örn: "Vortex içine çekilen zombileri patlatır."*
   * *Örn: "Ateş Duvarı düşman mermilerini yok eder."*
3. **Her 5 Katta Bir: BOSS SAVAŞI:**
   * Kat 5: Zırhlı Kutu Ezici (Armored Boxhead Crusher).
   * Kat 10: Çift Kırmızı Şeytan Boss (Twin Devils).
4. **Tahliye mi, Kumar mı? (Risk vs. Reward):**
   * Her 5. kattan sonra oyunculara iki kapı açılır:
     * **Yeşil Kapı (Tahliye - Escape):** Güvenle oyunu bitir, kazanılan XP ve skorları kaydet.
     * **Kırmızı Kapı (Daha Derine İn):** Skoru **2x Çarpan** ile katla ama takım silinirse toplam skorun yarısı kaybolur!

---

## 5. Global Skor Tablosu (Leaderboard) ve Rekabet

Takımların aylarca yarışmasını sağlayacak küresel sıralama sistemi:

### A) Skor Hesaplama Formülü
$$\text{Toplam Skor} = (\text{Ulaşılan Kat} \times 10.000) + (\text{Öldürülen Zombi} \times 100) + (\text{En Yüksek Kombo Rekoru} \times 500) + (\text{Kalan Can/Süre Bonusu})$$

### B) Sıralama Tabloları (Steam Leaderboards)
* **Haftalık Liderler:** Her pazartesi sıfırlanır; haftanın ilk 3 takımına oyun içi özel kozmetik unvan ve altın kutu kafalar verilir.
* **Tüm Zamanların Rekoru:** Dünyanın en uzağa giden (örn. 52. Kat) efsanevi takımları.
* **Kategori Ayrımı:** 1 Kişi (Solo), 2 Kişi (Duo) ve 4 Kişi (Squad) liderlik tabloları ayrı tutulur.

---

## 6. Ağ ve Çok Oyunculu (Multiplayer) Altyapısı

* **Mimari:** Listen Server / Host-Client P2P (Aylık sunucu faturası: **0 TL**).
* **Geliştirme Aşamasında:** Godot 4 `ENetMultiplayerPeer` (Localhost ve Sanal LAN ile hızlı test).
* **Yayın Aşaması (Steam):** `GodotSteam` Steamworks P2P Relay (Port açmaya gerek kalmadan davetle bağlanma + Steam Leaderboard).
* **Senkronizasyon:** `MultiplayerSynchronizer` (Oyuncu pozisyonları, can değerleri, büyü durumları) + `MultiplayerSpawner` (Zombi sürüsü ve variller).
* **Host-Authoritative Zombi Optimizasyonu:**
  * 100+ zombinin yapay zekası ve yol bulması (NavMesh) SADECE Host bilgisayarında hesaplanır.
  * İstemcilere (Client) sadece hafif yön/pozisyon verisi gönderilir, istemci tarafında hareket yumuşatması (interpolation) yapılır. Bu sayede internet trafiği şişmez, sıfır lag sağlanır.
* **Mekansal Ses ve Yakınlık Telsizi (Proximity Voice Chat):**
  * Oyuncuların birbirinden uzaklaştıkça seslerinin azalması, arka odada canavar kovalarken atılan çığlıkların yankılanması (Lethal Company/Content Warning etkisi).
* **Özel Kutu Kafa Editörü (Custom Skin Maker & Topluluk):**
  * Basit 6 yüzeyli küp kafa boyama editörü (Piksel/Minecraft tarzı). Oyuncular kendi komik ifadelerini çizip oyunda takabilir.

---

## 7. Geliştirme Yol Haritası (Fazlar)

* [x] **Faz 1: Ağ ve Temel Karakter (Multiplayer Sandbox)**
  * Godot 4 Host-Client bağlantısı.
  * 1. Şahıs kamera, hareket ve diğer oyuncunun modelini görme/senkronize etme.
* [x] **Faz 2: Kutu Zombiler, Hasar Efektleri & Vuruş Hissi**
  * Basit NavMesh ile oyuncuları kovalayan beyaz kutu zombi.
  * Mermi atışı, kafadan vuruş (headshot) ve küp parçalanma (gib) efekti.
  * Tam ekran radyal kan vignette kaplaması, kamera travması ve 3D gövde vuruş parlaması.
* [x] **Faz 3: Taktiksel Araçlar & Kombo Sayacı**
  * Kırmızı patlayıcı varillerin yerleştirilmesi ve patlatılması.
  * Ekran üstü çarpan (multiplier) barı.
* [x] **Faz 4: Sınıf & Büyü (Spell) Mekanikleri**
  * `E` ve `Q` yetenek altyapısı, sınıfların kodlanması.
* [x] **Faz 5: Kat, Çatışma İçi Canlandırma ve Asansör Senkronizasyonu (Floor & Revive)**
  * Kat temizleme $\rightarrow$ Asansör kapılarının tüm istemcilerde senkronize açılması (`set_elevator_state.rpc`) $\rightarrow$ Kart seçme $\rightarrow$ Yeni kat akışı.
  * Yerde kalan ceset, 10 saniye boyunca `[E]` basılı tutarak takım arkadaşını ayağa kaldırma (`_handle_revive_interaction`).
  * 3. Şahıs takip kamerasıyla izleyici modu, `[H]` tuşuyla açılıp kapanabilen temiz izleme arayüzü.
  * Yaşayan tüm oyuncular asansöre bindiğinde sonraki kata geçiş ve ölü oyuncuların asansörde otomatik dirilmesi.
* [x] **Faz 6: Bağımsız EXE, GitHub Güncelleyici ve Kesintisiz Lobi Deneyimi**
  * Tek tık derleyici scripti (`build_release.ps1`) ile Windows standalone exe ve pck üretimi.
  * Oyun içi GitHub Releases otomatik güncelleyicisi (`AutoUpdater.gd`) ve Windows dosya kilitleme engelleme döngüsü.
  * İki aşamalı lobi, hazır olma durumu, geç katılım reddi ve yetkisiz yeniden başlatma kilidi.
* [ ] **Faz 7: Bosslar, Steam Entegrasyonu & Skor Tablosu**
  * Kırmızı Şeytanlar ve Boss yapay zekası.
  * Steam Leaderboard bağlantısı ve ses/görsel cilalama (Polish).

