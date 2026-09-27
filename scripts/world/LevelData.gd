class_name LevelData
extends RefCounted

# --- "99" KUTU KAFALAR: 11 SEKTÖR & 99 KAT VERİ TABANI ---
# leveller dosyasındaki kule tırmanışı şemasına tam uyumlu

const SECTORS: Array[Dictionary] = [
	{
		"chapter": 1,
		"min_level": 1,
		"max_level": 9,
		"theme": "Giriş Lobisi & Zemin Katlar",
		"icon": "🏚️",
		"description": "Sokak çıkmazından plazanın mermer giriş lobisine doğru sızış.",
		"boss_name": "Mahalle Şefi (Brute Crusher)"
	},
	{
		"chapter": 2,
		"min_level": 10,
		"max_level": 18,
		"theme": "Yeraltı Otoparkı & Kazan Dairesi",
		"icon": "🚇",
		"description": "Zifiri karanlık, beton sütunlar, buhar boruları ve fener ışıkları.",
		"boss_name": "Hurdalık Canavarı (Scrap Goliath)"
	},
	{
		"chapter": 3,
		"min_level": 19,
		"max_level": 27,
		"theme": "AVM & Ticari Bölge",
		"icon": "🏪",
		"description": "Yağmalanmış mağazalar, yemek katı, vitrinler ve dar reyonlar.",
		"boss_name": "Zombi Kasap (The Butcher)"
	},
	{
		"chapter": 4,
		"min_level": 28,
		"max_level": 36,
		"theme": "Kurumsal Plaza Ofisleri",
		"icon": "🏢",
		"description": "Bölmeli çalışma masaları, fotokopi odaları ve cam toplantı salonları.",
		"boss_name": "Şirket CEO'su Kutu (The Overlord)"
	},
	{
		"chapter": 5,
		"min_level": 37,
		"max_level": 45,
		"theme": "Veri Merkezi & Sunucu Odaları",
		"icon": "💻",
		"description": "Mavi neonlar, soğutma fanları, sunucu kabinleri ve elektrik tuzakları.",
		"boss_name": "Kısa Devre Titan (Volt Titan)"
	},
	{
		"chapter": 6,
		"min_level": 46,
		"max_level": 54,
		"theme": "Karantina & Sahra Hastanesi",
		"icon": "🏥",
		"description": "Tıbbi sedyeler, yeşil zehirli duman, radyoloji ve ameliyathaneler.",
		"boss_name": "Doktor Veba (Dr. Plague)"
	},
	{
		"chapter": 7,
		"min_level": 55,
		"max_level": 63,
		"theme": "Lüks Casino & Eğlence",
		"icon": "🎰",
		"description": "Kırmızı peluş halılar, slot makineleri, rulet masaları ve dev avizeler.",
		"boss_name": "Kumarhane Baronu (Gold Craver)"
	},
	{
		"chapter": 8,
		"min_level": 64,
		"max_level": 72,
		"theme": "Botanik Park & Kapalı Sera",
		"icon": "🌴",
		"description": "Kule içi yapay orman, dev sarmaşıklar, yapay şelale ve kırık cam tavan.",
		"boss_name": "Biyo-Mutant Kök (The Abomination)"
	},
	{
		"chapter": 9,
		"min_level": 73,
		"max_level": 81,
		"theme": "Gizli Virüs Laboratuvarı",
		"icon": "🧪",
		"description": "Virüsün doğduğu yer. Klonlama tüpleri, kimyasal asit havuzları.",
		"boss_name": "Denek Sıfır (Subject Zero)"
	},
	{
		"chapter": 10,
		"min_level": 82,
		"max_level": 90,
		"theme": "Askeri Savunma & Cephanelik",
		"icon": "🎖️",
		"description": "Kum torbaları, cephane sandıkları, taret yuvaları ve zırhlı sığınaklar.",
		"boss_name": "Zırhlı General Kutu (General Dread)"
	},
	{
		"chapter": 11,
		"min_level": 91,
		"max_level": 99,
		"theme": "Penthouse & Helikopter Pisti",
		"icon": "🚁",
		"description": "Zirveye tırmanış! Şiddetli fırtına, şimşekler ve nihai helikopter tahliyesi.",
		"boss_name": "KUTU ŞAH (THE APOCALYPSE KING)"
	}
]

# 99 Katın Birebir Başlıkları
const FLOOR_NAMES: Dictionary = {
	1: "Sokak Giriş Meydanı",
	2: "Avlu & Güvenlik Bariyeri",
	3: "Döner Kapılar & X-Ray",
	4: "Büyük Karşılama Lobisi",
	5: "Resepsiyon & Bekleme Holü",
	6: "Güvenlik Turnikeleri",
	7: "VIP Asansör Girişi",
	8: "Lobi Kontrol Odası",
	9: "Ana Asansör Holü (Boss)",
	10: "Otopark Giriş Rampası",
	11: "Katlı Otopark A Bloğu",
	12: "Araç Bakım Atölyesi",
	13: "Otopark B Bloğu (Karanlık)",
	14: "Acil Jeneratör Odası",
	15: "Kazan Dairesi",
	16: "Havalandırma Koridorları",
	17: "Otopark Güvenlik Çıkışı",
	18: "Atık Pres Alanı (Boss)",
	19: "AVM Giriş Pasajı",
	20: "Elektronik Mağazası",
	21: "Orta Meydan & Havuz",
	22: "Süpermarket Rafları",
	23: "Yürüyen Merdiven Katı",
	24: "Yemek Katı (Food Court)",
	25: "Restoran Mutfakları",
	26: "Soğuk Hava Deposu",
	27: "Kasap Restoranı (Boss)",
	28: "Danışma & Turnike Katı",
	29: "Açık Ofis Alanı",
	30: "Cam Toplantı Odaları",
	31: "Arşiv & Evrak Deposu",
	32: "Yönetici Koridoru",
	33: "Dinlenme & Kahve Salonu",
	34: "Yangın Tahliye Boşluğu",
	35: "Finans Departmanı",
	36: "Yönetim Kurulu (Boss)",
	37: "Sunucu Giriş Koridoru",
	38: "Sunucu Kabinleri Bölgesi A",
	39: "Soğutma Fanları Dairesi",
	40: "Kablo Kanalları & Izgara",
	41: "Elektrik Dağıtım Odası",
	42: "Sunucu Kabinleri Bölgesi B",
	43: "Yedek Batarya Odası",
	44: "Ağ Operasyon Merkezi",
	45: "Ana Bilgisayar (Boss)",
	46: "Karantina Triyaj Girişi",
	47: "Acil Servis Koğuşu",
	48: "Ameliyathane Bloğu",
	49: "Eczane & İlaç Deposu",
	50: "Yoğun Bakım Ünitesi",
	51: "Biyolojik Atık Deposu",
	52: "Radyoloji & Röntgen",
	53: "Karantina Çadır Alanı",
	54: "Başhekim Laboratuvarı (Boss)",
	55: "Casino Giriş Fuayesi",
	56: "Slot Makineleri Labirenti",
	57: "Rulet & Poker Salonu",
	58: "VIP Lounge & Bar",
	59: "Kasa Dairesi Önü",
	60: "Gösteri Sahnesi",
	61: "Özel Kumar Odaları",
	62: "Güvenlik Kasası Koridoru",
	63: "Büyük Kasa Dairesi (Boss)",
	64: "Sera Giriş Tüneli",
	65: "Tropikal Palmiye Bahçesi",
	66: "Yapay Şelale & Gölet",
	67: "Bambu Labirenti",
	68: "Kaktüs & Çöl Bahçesi",
	69: "Asma Yürüyüş Köprüsü",
	70: "Tohum & Gen Bankası",
	71: "Kırık Cam Kubbe",
	72: "Ana Orman Kalbi (Boss)",
	73: "Steril Giriş Hava Kilidi",
	74: "Klonlama Tankları Odası",
	75: "Kimyasal Karışım Odası",
	76: "Genetik Test Hücreleri",
	77: "Dondurucu Kriyojenik Depo",
	78: "Santrifüj & Reaktör",
	79: "Tehlikeli Madde İzolasyon",
	80: "Klonlama Kontrol Odası",
	81: "Denek-0 Odası (Boss)",
	82: "Askeri Güvenlik Barikatı",
	83: "Ağır Cephane Deposu",
	84: "Taktik Harita Karargahı",
	85: "Zırhlı Araç Hangarı",
	86: "Barut & Patlayıcı Odası",
	87: "Makineli Tüfek Mevzisi",
	88: "Askeri Revir",
	89: "Hava Savunma Kontrolü",
	90: "Ordu Cephaneliği (Boss)",
	91: "Penthouse Giriş Holü",
	92: "Özel Sinema Salonu",
	93: "Lüks Kütüphane & Şömine",
	94: "Sanat Galerisi & Heykeller",
	95: "Kapalı Çatı Havuzu",
	96: "Büyük Balo Salonu",
	97: "Çatıya Çıkış Merdiveni",
	98: "Çatı Basınç Kapısı Önü",
	99: "AÇIK ÇATI & HELİKOPTER PİSTİ (FİNAL)"
}

## Seviye numarasına göre bölüm & kat bilgilerini döner
static func get_chapter_for_level(level: int) -> Dictionary:
	var clamped_lvl = clampi(level, 1, 99)
	for ch in SECTORS:
		if clamped_lvl >= ch["min_level"] and clamped_lvl <= ch["max_level"]:
			var progress_in_chapter = clamped_lvl - ch["min_level"] + 1
			var total_in_chapter = ch["max_level"] - ch["min_level"] + 1
			var is_boss = (clamped_lvl == ch["max_level"])
			var floor_name = FLOOR_NAMES.get(clamped_lvl, "Kat " + str(clamped_lvl))
			return {
				"chapter": ch["chapter"],
				"sector": ch["chapter"],
				"sector_name": ch["theme"],
				"theme": ch["theme"],
				"icon": ch["icon"],
				"description": ch["description"],
				"boss_name": ch["boss_name"],
				"level": clamped_lvl,
				"floor_num": clamped_lvl,
				"floor_name": floor_name,
				"level_in_chapter": progress_in_chapter,
				"max_in_chapter": total_in_chapter,
				"is_boss_level": is_boss
			}
	return SECTORS[0]

## Belirtilen seviye bir Bölüm Sonu Boss seviyesi mi?
static func is_boss_level(level: int) -> bool:
	var info = get_chapter_for_level(level)
	return info.get("is_boss_level", false)
