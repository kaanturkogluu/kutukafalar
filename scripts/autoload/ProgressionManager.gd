extends Node

# --- Kutu Kafalar: Kalıcı İlerleme ve Yetenek Ağacı Yöneticisi (ProgressionManager) ---
# Oyuncunun açtığı kalıcı yetenekleri, stat çarpanlarını, ön koşulları ve sınıf soketlerini yönetir.

signal stats_recalculated
signal node_unlocked(node_id: String)
signal tree_reset

# 1. Yetenek Ağacı Düğüm Kataloğu (Node Catalog)
# id -> {title, desc, cost, category, parents, tier, stats, grid_pos}
const NODE_CATALOG: Dictionary = {
	# --- ÇEKİRDEK BAŞLANGIÇ ---
	"core_start": {
		"title": "OPERASYONEL ÇEKİRDEK",
		"desc": "Taktik operasyon merkezine bağlantı kurar. Temel yetenek dallarını etkinleştirir.",
		"cost": 0,
		"category": "core",
		"parents": [],
		"tier": 0,
		"stats": {},
		"grid_pos": Vector2(0, 0)
	},

	# --- 1. SİLAH DALI (WEAPON TREE) ---
	"wpn_crit_1": {
		"title": "HASSAS NİŞAN I",
		"desc": "Kritik vuruş şansını +%8 artırır. Zayıf noktalara odaklanmayı sağlar.",
		"cost": 1,
		"category": "weapon",
		"parents": ["core_start"],
		"tier": 1,
		"stats": {"crit_chance": 0.08, "crit_multiplier": 0.25},
		"grid_pos": Vector2(-2, 1)
	},
	"wpn_assault_1": {
		"title": "HIZLI TETİK I",
		"desc": "Tüm silahların atış hızını +%12, şarjör kapasitesini +%10 artırır.",
		"cost": 1,
		"category": "weapon",
		"parents": ["core_start"],
		"tier": 1,
		"stats": {"firerate_mult": 0.12, "ammo_cap_mult": 0.10},
		"grid_pos": Vector2(-1, 1)
	},
	"wpn_headshot_2": {
		"title": "KAFA AVCISI",
		"desc": "Kafa vuruşu (Headshot) hasar çarpanını +%35 artırır.",
		"cost": 2,
		"category": "weapon",
		"parents": ["wpn_crit_1"],
		"tier": 2,
		"stats": {"headshot_mult": 0.35},
		"grid_pos": Vector2(-2, 2)
	},
	"wpn_bullet_storm": {
		"title": "MERMİ FIRTINASI",
		"desc": "Kesintisiz ateş edildiğinde 3 saniye boyunca silah hasarını +%20 artırır.",
		"cost": 2,
		"category": "weapon",
		"parents": ["wpn_assault_1"],
		"tier": 2,
		"stats": {"bullet_storm_unlocked": true, "bullet_storm_damage": 0.20},
		"grid_pos": Vector2(-1, 2)
	},

	# --- 2. HAYATTA KALMA DALI (SURVIVAL TREE) ---
	"surv_hp_1": {
		"title": "GÜÇLENDİRİLMİŞ KORUMA I",
		"desc": "Maksimum canı +25 artırır ve alınan hasarı %6 azaltır.",
		"cost": 1,
		"category": "survival",
		"parents": ["core_start"],
		"tier": 1,
		"stats": {"bonus_max_health": 25.0, "damage_reduction": 0.06},
		"grid_pos": Vector2(1, 1)
	},
	"surv_lifesteal_2": {
		"title": "BİYOLOJİK ŞİFA",
		"desc": "Öldürülen her zombi başına anında 3 Can yeniler.",
		"cost": 2,
		"category": "survival",
		"parents": ["surv_hp_1"],
		"tier": 2,
		"stats": {"kill_heal": 3.0},
		"grid_pos": Vector2(1, 2)
	},
	"surv_last_stand": {
		"title": "SON DİRENİŞ (LAST STAND)",
		"desc": "Can %25'in altına düştüğünde 5 saniye boyunca %30 Hasar Direnci ve +%25 Silah Hasarı kazanır.",
		"cost": 3,
		"category": "survival",
		"parents": ["surv_lifesteal_2"],
		"tier": 3,
		"stats": {"last_stand_unlocked": true},
		"grid_pos": Vector2(1, 3)
	},

	# --- 3. HAREKET VE TAKTİK DALI (MOBILITY TREE) ---
	"mob_speed_1": {
		"title": "HAFİF ADIMLAR I",
		"desc": "Temel yürüme ve koşma hızını +%12 artırır.",
		"cost": 1,
		"category": "mobility",
		"parents": ["core_start"],
		"tier": 1,
		"stats": {"speed_mult": 0.12},
		"grid_pos": Vector2(2, 1)
	},
	"mob_dash": {
		"title": "TAKTIKSEL ATILMA (DASH)",
		"desc": "[Shift] veya yön tuşlarına çift basarak ileri doğru hızlı kaçınma atılması yapar (1.8s bekleme).",
		"cost": 2,
		"category": "mobility",
		"parents": ["mob_speed_1"],
		"tier": 2,
		"stats": {"dash_unlocked": true, "dash_cooldown": 1.8},
		"grid_pos": Vector2(2, 2)
	},
	"mob_momentum": {
		"title": "MOMENTUM",
		"desc": "Koşarken kazanılan hız, zombilere uygulanan tekme gücünü ve alan savurmasını +%50 artırır.",
		"cost": 2,
		"category": "mobility",
		"parents": ["mob_dash"],
		"tier": 3,
		"stats": {"kick_force_mult": 0.50},
		"grid_pos": Vector2(2, 3)
	},

	# --- 4. KAOS VE YIKIM DALI (DEMOLITION TREE) ---
	"demo_barrel_1": {
		"title": "AĞIR PATLAYICI I",
		"desc": "Varil ve roket patlama hasarını +%25, patlama menzilini +%20 artırır.",
		"cost": 1,
		"category": "demolition",
		"parents": ["core_start"],
		"tier": 1,
		"stats": {"barrel_damage_mult": 0.25, "explosion_radius_mult": 0.20},
		"grid_pos": Vector2(-3, 1)
	},
	"demo_chain": {
		"title": "ZİNCİRLEME REAKSİYON",
		"desc": "Bir varil patladığında, etki alanındaki diğer varilleri beklemeden anında tetikler.",
		"cost": 2,
		"category": "demolition",
		"parents": ["demo_barrel_1"],
		"tier": 2,
		"stats": {"chain_reaction_unlocked": true},
		"grid_pos": Vector2(-3, 2)
	},

	# --- 5. TAKTİKSEL YETENEKLER DALI (UTILITY TREE) ---
	"util_cooldown_1": {
		"title": "HIZLI DÖNGÜ I",
		"desc": "[E] Taktiksel yetenek bekleme süresini -2.5 saniye kısaltır.",
		"cost": 1,
		"category": "utility",
		"parents": ["core_start"],
		"tier": 1,
		"stats": {"tactical_cooldown_reduction": 2.5},
		"grid_pos": Vector2(3, 1)
	},
	"util_ult_efficiency": {
		"title": "AŞIRI YÜKLEME",
		"desc": "Zombi öldürmelerinden kazanılan [Q] Ulti şarjını +%30 hızlandırır.",
		"cost": 2,
		"category": "utility",
		"parents": ["util_cooldown_1"],
		"tier": 2,
		"stats": {"ult_charge_mult": 0.30},
		"grid_pos": Vector2(3, 2)
	},

	# --- 6. ÇAPRAZ DÜĞÜMLER (CROSS-NODES) ---
	"cross_run_and_gun": {
		"title": "KOŞ VE VUR (RUN & GUN)",
		"desc": "[Hassas Nişan + Hafif Adımlar] Koşarken veya Dash atarken silah dağılımını sıfırlar ve hasarı +%15 artırır.",
		"cost": 3,
		"category": "cross",
		"parents": ["wpn_crit_1", "mob_speed_1"],
		"tier": 3,
		"stats": {"run_and_gun_unlocked": true, "moving_damage_bonus": 0.15},
		"grid_pos": Vector2(0, 3)
	},
	"cross_demolitionist": {
		"title": "YIKIM UZMANI (DEMOLITIONIST)",
		"desc": "[Ağır Patlayıcı + Taktiksel Atılma] Patlama öldürmeleri %20 şansla yere anında kurulan ücretsiz bir patlayıcı varil bırakır.",
		"cost": 3,
		"category": "cross",
		"parents": ["demo_chain", "mob_dash"],
		"tier": 3,
		"stats": {"demolitionist_drop_unlocked": true},
		"grid_pos": Vector2(-2, 3)
	},
	"cross_critical_spells": {
		"title": "KRİTİK DALGA",
		"desc": "[Hassas Nişan + Hızlı Döngü] [E] Taktiksel yetenekler ve [Q] Ulti büyüleri %25 şansla kritik hasar vurabilir.",
		"cost": 3,
		"category": "cross",
		"parents": ["wpn_headshot_2", "util_cooldown_1"],
		"tier": 3,
		"stats": {"critical_spells_unlocked": true, "spell_crit_chance": 0.25},
		"grid_pos": Vector2(2, 4)
	},

	# --- 7. NİHAİ DÜĞÜMLER (MASTERY / APEX) ---
	"mast_executioner": {
		"title": "İNFAZCI (EXECUTIONER)",
		"desc": "[Nihai Silah Ustalığı] Canı %20'nin altına düşen normal zombileri tek mermiyle anında patlatır. Kritik hasarı +%50 artırır.",
		"cost": 5,
		"category": "mastery",
		"parents": ["wpn_headshot_2", "cross_run_and_gun"],
		"tier": 4,
		"stats": {"executioner_unlocked": true, "execute_threshold": 0.20, "crit_multiplier": 0.50},
		"grid_pos": Vector2(-1, 4)
	},
	"mast_apocalypse": {
		"title": "KIYAMET PROTOKOLÜ (APOCALYPSE)",
		"desc": "[Nihai Yıkım Ustalığı] Tüm patlamalar yakındaki zombileri felç eden ve alevlendiren şok dalgası saçar. Varil hasarı +%50 artar.",
		"cost": 5,
		"category": "mastery",
		"parents": ["demo_chain", "cross_demolitionist"],
		"tier": 4,
		"stats": {"apocalypse_unlocked": true, "barrel_damage_mult": 0.50},
		"grid_pos": Vector2(-3, 4)
	},
	"mast_phantom": {
		"title": "HAYALET ADIMI (PHANTOM STEP)",
		"desc": "[Nihai Hareket Ustalığı] Dash atıldığında zombilerin içinden geçilebilir ve arkasında zombileri savuran hava dalgası bırakır.",
		"cost": 5,
		"category": "mastery",
		"parents": ["mob_momentum", "cross_run_and_gun"],
		"tier": 4,
		"stats": {"phantom_dash_unlocked": true},
		"grid_pos": Vector2(1, 4)
	}
}

# Hesaplanan nihai stat nesnesi
var calculated_stats: Dictionary = {}

func _ready() -> void:
	recalculate_stats()
	# SaveManager değişikliklerini dinle
	if SaveManager.has_signal("node_unlocked"):
		SaveManager.node_unlocked.connect(func(_id): recalculate_stats())

## Ağaçtaki tüm düğümleri döner
func get_all_nodes() -> Dictionary:
	return NODE_CATALOG

## Belirli bir düğümün detayını döner
func get_skill_node(node_id: String) -> Dictionary:
	return NODE_CATALOG.get(node_id, {})

## Düğüm açık mı?
func is_node_unlocked(node_id: String) -> bool:
	if node_id == "core_start":
		return true
	return SaveManager.is_node_unlocked(node_id)

## Düğüm açılabilir mi? (Tüm ön koşullar açık mı ve yeterli Biyo-Çekirdek var mı?)
func can_unlock_node(node_id: String) -> bool:
	if is_node_unlocked(node_id):
		return false
	var node = get_skill_node(node_id)
	if node.is_empty():
		return false
	
	# Maliyet kontrolü
	var cost = int(node.get("cost", 0))
	if SaveManager.get_bio_cores() < cost:
		return false
	
	# Ön koşul (parents) kontrolü: En az bir ebeveyn açık olmalı (Cross-node'lar için tüm ebeveynler)
	var parents = node.get("parents", [])
	if parents.is_empty():
		return true
	
	var is_cross = (node.get("category", "") == "cross")
	if is_cross:
		# Cross-node için tüm ebeveynler açık olmalıdır
		for p in parents:
			if not is_node_unlocked(p):
				return false
		return true
	else:
		# Standart dal için en az 1 ebeveynin açık olması yeterlidir
		for p in parents:
			if is_node_unlocked(p):
				return true
		return false

## Düğümü satın al ve kilidini aç
func unlock_node(node_id: String) -> bool:
	if not can_unlock_node(node_id):
		return false
	var node = get_skill_node(node_id)
	var cost = int(node.get("cost", 0))
	var success = SaveManager.unlock_node(node_id, cost)
	if success:
		recalculate_stats()
		node_unlocked.emit(node_id)
		print("[ProgressionManager] Düğüm açıldı: ", node.get("title", node_id))
	return success

## Tüm yetenekleri sıfırla ve harcanan Biyo-Çekirdekleri %100 iade et (Respec)
func respec() -> void:
	var total_refund = 0
	for node_id in SaveManager.get_unlocked_nodes():
		var node = get_skill_node(node_id)
		if not node.is_empty():
			total_refund += int(node.get("cost", 0))
	
	SaveManager.refund_all_nodes(total_refund)
	recalculate_stats()
	tree_reset.emit()
	print("[ProgressionManager] Yetenekler sıfırlandı. İade edilen Biyo-Çekirdek: ", total_refund)

## Aktif açılmış düğümlere göre nihai stat çarpanlarını hesaplar
func recalculate_stats() -> void:
	calculated_stats = {
		# Silah statları
		"crit_chance": 0.05,        # Temel %5 kritik şansı
		"crit_multiplier": 1.5,     # Temel 1.5x kritik hasar
		"firerate_mult": 1.0,       # Temel atış hızı çarpanı
		"ammo_cap_mult": 1.0,       # Temel mermi kapasitesi
		"headshot_mult": 1.5,       # Temel 1.5x kafa hasarı
		"bullet_storm_unlocked": false,
		"bullet_storm_damage": 0.0,
		# Hayatta kalma statları
		"bonus_max_health": 0.0,
		"damage_reduction": 0.0,
		"kill_heal": 0.0,
		"last_stand_unlocked": false,
		# Hareket statları
		"speed_mult": 1.0,
		"dash_unlocked": false,
		"dash_cooldown": 2.0,
		"kick_force_mult": 1.0,
		# Kaos ve Varil statları
		"barrel_damage_mult": 1.0,
		"explosion_radius_mult": 1.0,
		"chain_reaction_unlocked": false,
		# Taktiksel Yetenek statları
		"tactical_cooldown_reduction": 0.0,
		"ult_charge_mult": 1.0,
		# Çapraz ve Nihai perkler
		"run_and_gun_unlocked": false,
		"moving_damage_bonus": 0.0,
		"demolitionist_drop_unlocked": false,
		"critical_spells_unlocked": false,
		"spell_crit_chance": 0.0,
		"executioner_unlocked": false,
		"execute_threshold": 0.0,
		"apocalypse_unlocked": false,
		"phantom_dash_unlocked": false
	}
	
	for node_id in SaveManager.get_unlocked_nodes():
		var node = get_skill_node(node_id)
		if node.is_empty():
			continue
		var stats = node.get("stats", {})
		for key in stats:
			var val = stats[key]
			if typeof(val) == TYPE_BOOL:
				calculated_stats[key] = val
			elif typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
				if key == "firerate_mult" or key == "ammo_cap_mult" or key == "speed_mult" or key == "barrel_damage_mult" or key == "explosion_radius_mult" or key == "ult_charge_mult":
					calculated_stats[key] = float(calculated_stats.get(key, 1.0)) + float(val)
				elif key == "crit_multiplier" or key == "headshot_mult":
					calculated_stats[key] = float(calculated_stats.get(key, 1.5)) + float(val)
				elif key == "dash_cooldown":
					calculated_stats[key] = float(val) # En güncel bekleme süresi
				else:
					calculated_stats[key] = float(calculated_stats.get(key, 0.0)) + float(val)
	
	stats_recalculated.emit()

## Bir perk açık mı? (Hızlı kontrol)
func has_perk(perk_name: String) -> bool:
	return calculated_stats.get(perk_name, false) == true

## Sayısal stat değerini oku
func get_stat(stat_name: String, default_val: float = 0.0) -> float:
	return float(calculated_stats.get(stat_name, default_val))

## Oyuncu doğduğunda veya perk güncellendiğinde tüm kalıcı çarpanları uygular
func apply_to_player(player: CharacterBody3D) -> void:
	if not player:
		return
	
	# 1. Can çarpanı
	var bonus_hp = get_stat("bonus_max_health", 0.0)
	var new_max = 100.0 + bonus_hp
	var old_max = player.max_health if player.get("max_health") != null else 100.0
	player.max_health = new_max
	if new_max > old_max:
		player.current_health = clamp(player.current_health + (new_max - old_max), 0.0, player.max_health)
	else:
		player.current_health = clamp(player.current_health, 0.0, player.max_health)
	if player.has_signal("health_changed"):
		player.health_changed.emit(player.current_health)
	
	# 2. Hız çarpanı
	var spd_mult = get_stat("speed_mult", 1.0)
	player.speed = 7.0 * spd_mult
	player.sprint_speed = 11.0 * spd_mult
	
	# 3. Silah atış hızı çarpanı
	var fr_mult = get_stat("firerate_mult", 1.0)
	player.stat_firerate_mult = fr_mult
	
	# 4. Dash yeteneği
	if player.has_method("set_dash_enabled"):
		player.set_dash_enabled(has_perk("dash_unlocked"), get_stat("dash_cooldown", 1.8))
	
	print("[ProgressionManager] İlerleme çarpanları uygulandı. HP: ", player.max_health, " | Hız: ", player.speed, " | Dash: ", has_perk("dash_unlocked"))
