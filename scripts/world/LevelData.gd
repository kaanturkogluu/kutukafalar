class_name LevelData
extends RefCounted

# --- Kutu Kafalar Bölüm & Seviye Veri Sistemi ---
# leveller dosyasına göre 11 bölüm ve 99 seviye şeması

const CHAPTERS: Array[Dictionary] = [
	{
		"chapter": 1,
		"min_level": 1,
		"max_level": 9,
		"theme": "Terk Edilmiş Mahalle",
		"icon": "🏚️",
		"description": "Sessiz banliyö çıkmazı ve harabe sokaklar zombi ordularıyla dolup taşıyor.",
		"boss_name": "Mahalle Şefi (Brute Crusher)"
	},
	{
		"chapter": 2,
		"min_level": 10,
		"max_level": 18,
		"theme": "Şehir Merkezi",
		"icon": "🏙️",
		"description": "Gökdelenlerin ve neon tabelaların gölgesinde hayatta kal.",
		"boss_name": "Şehir Celladı (City Slayer)"
	},
	{
		"chapter": 3,
		"min_level": 19,
		"max_level": 27,
		"theme": "Market & Ticari Bölge",
		"icon": "🏪",
		"description": "Yağmalanmış süpermarketler ve dar alışveriş sokakları.",
		"boss_name": "Kasap Zombi (The Butcher)"
	},
	{
		"chapter": 4,
		"min_level": 28,
		"max_level": 36,
		"theme": "Apartmanlar",
		"icon": "🏢",
		"description": "Dar koridorlar, kilitli kapılar ve basık merdivenler.",
		"boss_name": "Bina Yöneticisi (Overlord)"
	},
	{
		"chapter": 5,
		"min_level": 37,
		"max_level": 45,
		"theme": "Otopark & Metro",
		"icon": "🚇",
		"description": "Karanlık tüneller, terk edilmiş vagonlar ve raylar.",
		"boss_name": "Metro Canavarı (Tunnel Stalker)"
	},
	{
		"chapter": 6,
		"min_level": 46,
		"max_level": 54,
		"theme": "Hastane",
		"icon": "🏥",
		"description": "Karantina koğuşları ve mutasyona uğramış hastalar.",
		"boss_name": "Başhekim Kutu (Dr. Plague)"
	},
	{
		"chapter": 7,
		"min_level": 55,
		"max_level": 63,
		"theme": "Fabrika",
		"icon": "🏭",
		"description": "Dönen dişliler, erimiş maden kazanları ve montaj hatları.",
		"boss_name": "Demir Ezici (Steel Golem)"
	},
	{
		"chapter": 8,
		"min_level": 64,
		"max_level": 72,
		"theme": "Kanalizasyon",
		"icon": "🕳️",
		"description": "Zehirli yeşil asit atıkları ve karanlık su dehlizleri.",
		"boss_name": "Asit Yutan (Toxic Abomination)"
	},
	{
		"chapter": 9,
		"min_level": 73,
		"max_level": 81,
		"theme": "Askeri Tesis",
		"icon": "🎖️",
		"description": "Ağır barikatlar, taret yuvaları ve zırhlı sığınaklar.",
		"boss_name": "Zırhlı Komutan (General Dread)"
	},
	{
		"chapter": 10,
		"min_level": 82,
		"max_level": 90,
		"theme": "Kutu Kafalar Laboratuvarı",
		"icon": "🧪",
		"description": "Virüsün başladığı gizli genetik klonlama tesisi.",
		"boss_name": "Denek-0 (Subject Zero)"
	},
	{
		"chapter": 11,
		"min_level": 91,
		"max_level": 99,
		"theme": "Ana Tesis / Final",
		"icon": "☢️",
		"description": "Kıyametin merkez üssü ve nihai hayatta kalma savaşı.",
		"boss_name": "Nihai Kutu Kafa (Apex Destroyer)"
	}
]

## Seviye numarasına göre bölüm bilgilerini döner
static func get_chapter_for_level(level: int) -> Dictionary:
	var clamped_lvl = clampi(level, 1, 99)
	for ch in CHAPTERS:
		if clamped_lvl >= ch["min_level"] and clamped_lvl <= ch["max_level"]:
			var progress_in_chapter = clamped_lvl - ch["min_level"] + 1
			var total_in_chapter = ch["max_level"] - ch["min_level"] + 1
			var is_boss = (clamped_lvl == ch["max_level"])
			return {
				"chapter": ch["chapter"],
				"theme": ch["theme"],
				"icon": ch["icon"],
				"description": ch["description"],
				"boss_name": ch["boss_name"],
				"level": clamped_lvl,
				"level_in_chapter": progress_in_chapter,
				"max_in_chapter": total_in_chapter,
				"is_boss_level": is_boss
			}
	return CHAPTERS[0]

## Belirtilen seviye bir Bölüm Sonu Boss seviyesi mi?
static func is_boss_level(level: int) -> bool:
	var info = get_chapter_for_level(level)
	return info.get("is_boss_level", false)
