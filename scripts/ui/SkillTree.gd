extends CanvasLayer
class_name SkillTreeUI

# --- Kutu Kafalar: Kalıcı Taktiksel Yetenek Ağacı (SkillTreeUI) ---
# Referans formata göre başlıklara (dallara) ayrılmış dikey hiyerarşik ağaç arayüzü.

signal closed

@onready var modal_backdrop: ColorRect = $ModalBackdrop
@onready var close_btn: Button = %CloseBtn
@onready var respec_btn: Button = %RespecBtn
@onready var bio_cores_label: Label = %BioCoresLabel
@onready var unlocked_count_label: Label = %UnlockedCountLabel

# Ağaç & Çizgi Alanı
@onready var core_module_btn: Button = %CoreModuleBtn
@onready var columns_container: HBoxContainer = %ColumnsContainer
@onready var lines_overlay: Control = %LinesOverlay

# Detay Kartı
@onready var detail_card: PanelContainer = %DetailCard
@onready var detail_category: Label = %DetailCategory
@onready var detail_icon: Label = %DetailIcon
@onready var detail_title: Label = %DetailTitle
@onready var detail_desc: Label = %DetailDesc
@onready var detail_reqs: Label = %DetailReqs
@onready var detail_cost: Label = %DetailCost
@onready var unlock_btn: Button = %UnlockBtn

var selected_node_id: String = "wpn_crit_1"
var node_buttons: Dictionary = {} # node_id -> Button
var current_player: CharacterBody3D = null

const BRANCHES: Array[Dictionary] = [
	{
		"id": "weapon",
		"title": "SİLAH UZMANLIĞI",
		"short_title": "SİLAH",
		"icon": "⚔️",
		"color": Color(1.0, 0.45, 0.25),
		"nodes": ["wpn_crit_1", "wpn_assault_1", "wpn_headshot_2", "wpn_bullet_storm", "mast_executioner"]
	},
	{
		"id": "survival",
		"title": "HAYATTA KALMA",
		"short_title": "HAYAT",
		"icon": "🛡️",
		"color": Color(0.3, 0.95, 0.55),
		"nodes": ["surv_hp_1", "surv_lifesteal_2", "surv_last_stand"]
	},
	{
		"id": "mobility",
		"title": "HAREKET & DASH",
		"short_title": "HAREKET",
		"icon": "💨",
		"color": Color(0.35, 0.85, 1.0),
		"nodes": ["mob_speed_1", "mob_dash", "mob_momentum", "mast_phantom"]
	},
	{
		"id": "demolition",
		"title": "KAOS & VARİL",
		"short_title": "KAOS",
		"icon": "💣",
		"color": Color(1.0, 0.78, 0.2),
		"nodes": ["demo_barrel_1", "demo_chain", "mast_apocalypse"]
	},
	{
		"id": "utility",
		"title": "TAKTİK & ÇAPRAZ",
		"short_title": "TAKTİK",
		"icon": "🔮",
		"color": Color(0.85, 0.5, 1.0),
		"nodes": ["util_cooldown_1", "util_ult_efficiency", "cross_run_and_gun", "cross_demolitionist", "cross_critical_spells"]
	}
]

const NODE_ICONS: Dictionary = {
	"core_start": "❖",
	"wpn_crit_1": "🎯",
	"wpn_assault_1": "⚡",
	"wpn_headshot_2": "💀",
	"wpn_bullet_storm": "🌪️",
	"surv_hp_1": "🛡️",
	"surv_lifesteal_2": "💉",
	"surv_last_stand": "🩸",
	"mob_speed_1": "👟",
	"mob_dash": "💨",
	"mob_momentum": "💥",
	"demo_barrel_1": "💣",
	"demo_chain": "⛓️",
	"util_cooldown_1": "⏱️",
	"util_ult_efficiency": "🔋",
	"cross_run_and_gun": "🏃",
	"cross_demolitionist": "🧨",
	"cross_critical_spells": "✨",
	"mast_executioner": "👑",
	"mast_apocalypse": "🌋",
	"mast_phantom": "👻"
}

func _ready() -> void:
	add_to_group("skill_tree_ui")
	visible = false
	
	if close_btn:
		close_btn.pressed.connect(close)
	if respec_btn:
		respec_btn.pressed.connect(_on_respec_pressed)
	if unlock_btn:
		unlock_btn.pressed.connect(_on_unlock_pressed)
	if core_module_btn:
		core_module_btn.pressed.connect(func(): _select_node("core_start"))

	if lines_overlay:
		lines_overlay.draw.connect(_on_draw_tree_lines)

	if SaveManager:
		SaveManager.bio_cores_changed.connect(func(_amt): _update_header())
	if ProgressionManager:
		ProgressionManager.node_unlocked.connect(func(_id): _refresh_tree())
		ProgressionManager.tree_reset.connect(_refresh_tree)

## Arayüzü belirli bir oyuncu için aç (oyun içi)
func open_for_player(p_player: CharacterBody3D = null) -> void:
	current_player = p_player
	if current_player and is_instance_valid(current_player) and current_player.has_method("set_in_skill_tree"):
		current_player.set_in_skill_tree(true)
	open()

## Arayüzü aç
func open() -> void:
	visible = true
	_update_header()
	_populate_tree()
	_select_node(selected_node_id)
	# Çizgilerin doğru hizalanması için iki kare sonra yeniden çizim iste
	get_tree().create_timer(0.05).timeout.connect(func():
		if lines_overlay: lines_overlay.queue_redraw()
	)

## Arayüzü kapat
func close() -> void:
	visible = false
	if current_player and is_instance_valid(current_player):
		if current_player.has_method("set_in_skill_tree"):
			current_player.set_in_skill_tree(false)
		ProgressionManager.apply_to_player(current_player)
		current_player = null
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_K:
			close()
			get_viewport().set_input_as_handled()

func _update_header() -> void:
	if bio_cores_label:
		bio_cores_label.text = "BİYO-ÇEKİRDEK: %d" % SaveManager.get_bio_cores()
	
	if unlocked_count_label:
		var total = ProgressionManager.get_all_nodes().size() - 1 # core_start hariç
		var unlocked = SaveManager.get_unlocked_nodes().size()
		unlocked_count_label.text = "AÇILAN: %d / %d" % [unlocked, total]

## Sütunları ve düğümleri görsel ağaç formatında oluştur
func _populate_tree() -> void:
	if not columns_container:
		return
	
	for child in columns_container.get_children():
		child.queue_free()
	node_buttons.clear()

	# 5 Sütunu (Dalları) oluştur
	for branch in BRANCHES:
		var col_vbox = VBoxContainer.new()
		col_vbox.custom_minimum_size = Vector2(148, 0)
		col_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_vbox.theme_override_constants.set("separation", 14)
		col_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		
		# Sütun Başlık Kartı
		var header_panel = PanelContainer.new()
		var h_style = StyleBoxFlat.new()
		h_style.bg_color = Color(0.05, 0.07, 0.11, 0.9)
		h_style.border_color = branch["color"]
		h_style.border_width_bottom = 2
		h_style.border_width_left = 1
		h_style.border_width_top = 1
		h_style.border_width_right = 1
		h_style.corner_radius_top_left = 6
		h_style.corner_radius_top_right = 6
		h_style.corner_radius_bottom_left = 6
		h_style.corner_radius_bottom_right = 6
		h_style.content_margin_top = 6
		h_style.content_margin_bottom = 6
		h_style.content_margin_left = 8
		h_style.content_margin_right = 8
		header_panel.add_theme_stylebox_override("panel", h_style)
		
		var header_label = Label.new()
		header_label.text = branch["icon"] + " " + branch["short_title"]
		header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_label.add_theme_color_override("font_color", branch["color"])
		header_label.add_theme_font_size_override("font_size", 12)
		header_panel.add_child(header_label)
		col_vbox.add_child(header_panel)
		
		# Sütundaki Düğümler
		var nodes_list_vbox = VBoxContainer.new()
		nodes_list_vbox.theme_override_constants.set("separation", 16)
		nodes_list_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		for node_id in branch["nodes"]:
			var node_data = ProgressionManager.get_skill_node(node_id)
			if node_data.is_empty():
				continue
			
			var btn = _create_node_button(node_id, node_data, branch["color"])
			nodes_list_vbox.add_child(btn)
			node_buttons[node_id] = btn
		
		col_vbox.add_child(nodes_list_vbox)
		columns_container.add_child(col_vbox)
	
	if lines_overlay:
		lines_overlay.queue_redraw()

## Tekil yetenek kart butonu oluşturur (Referans resimdeki kare formata uygun)
func _create_node_button(node_id: String, node_data: Dictionary, branch_color: Color) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(76, 76)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.clip_contents = true
	
	var is_unlocked = ProgressionManager.is_node_unlocked(node_id)
	var can_unlock = ProgressionManager.can_unlock_node(node_id)
	var is_selected = (node_id == selected_node_id)
	
	# Stil Kutusu
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	var icon_text = NODE_ICONS.get(node_id, "◆")
	var cost = int(node_data.get("cost", 1))
	
	if is_selected:
		# Seçili Düğüm: Parlak elektrik mavisi neon çerçeve (Referans görseldeki gibi)
		style.bg_color = Color(0.1, 0.18, 0.28, 0.95)
		style.border_color = Color(0.2, 0.9, 1.0, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.shadow_color = Color(0.2, 0.8, 1.0, 0.6)
		style.shadow_size = 8
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	elif is_unlocked:
		# Açılmış Düğüm: Açık gümüş/beyaz arka plan ve koyu simge (Referans görseldeki üst düğümler)
		style.bg_color = Color(0.85, 0.90, 0.95, 0.95)
		style.border_color = Color(0.4, 0.95, 0.65, 0.8)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		btn.add_theme_color_override("font_color", Color(0.08, 0.12, 0.18, 1.0))
	elif can_unlock:
		# Açılabilir Düğüm: Koyu arka plan, altın/kehribar parlak çerçeve
		style.bg_color = Color(0.12, 0.15, 0.22, 0.9)
		style.border_color = Color(1.0, 0.8, 0.25, 0.9)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	else:
		# Kilitli Düğüm: Koyu mat arka plan, kilit simgesi
		style.bg_color = Color(0.06, 0.08, 0.12, 0.8)
		style.border_color = Color(0.22, 0.26, 0.34, 0.45)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		icon_text = "🔒"
		btn.add_theme_color_override("font_color", Color(0.45, 0.5, 0.58, 0.6))
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	# Buton İçeriği (İkon ve Maliyet Etiketi)
	var content_box = VBoxContainer.new()
	content_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var icon_lbl = Label.new()
	icon_lbl.text = icon_text
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 24)
	if is_unlocked and not is_selected:
		icon_lbl.add_theme_color_override("font_color", Color(0.08, 0.12, 0.18, 1.0))
	elif can_unlock and not is_selected:
		icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25, 1.0))
	elif is_selected:
		icon_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0, 1.0))
	else:
		icon_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62, 0.6))
	content_box.add_child(icon_lbl)
	
	var cost_lbl = Label.new()
	cost_lbl.text = "Lv.%d" % cost if is_unlocked else "%d●" % cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 10)
	if is_unlocked and not is_selected:
		cost_lbl.add_theme_color_override("font_color", Color(0.15, 0.2, 0.25, 0.8))
	else:
		cost_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82, 0.8))
	content_box.add_child(cost_lbl)
	
	btn.add_child(content_box)
	btn.pressed.connect(func(): _select_node(node_id))
	return btn

## Bağlantı çizgilerini (devre hatlarını) çizen fonksiyon
func _on_draw_tree_lines() -> void:
	if not lines_overlay or not core_module_btn or node_buttons.is_empty():
		return
	
	var overlay_global_pos = lines_overlay.global_position
	var core_rect = core_module_btn.get_global_rect()
	var core_bottom = Vector2(core_rect.position.x + core_rect.size.x * 0.5, core_rect.position.y + core_rect.size.y) - overlay_global_pos
	
	# 1. Ana çekirdekten her sütunun en üst düğümüne dağıtım hattı
	var bus_y = core_bottom.y + 12.0
	lines_overlay.draw_line(core_bottom, Vector2(core_bottom.x, bus_y), Color(0.4, 0.85, 1.0, 0.8), 2.5)
	
	var col_x_positions: Array[float] = []
	for branch in BRANCHES:
		var first_node_id = branch["nodes"][0]
		if node_buttons.has(first_node_id):
			var b_btn = node_buttons[first_node_id]
			var b_rect = b_btn.get_global_rect()
			var b_top = Vector2(b_rect.position.x + b_rect.size.x * 0.5, b_rect.position.y) - overlay_global_pos
			col_x_positions.append(b_top.x)
			
			# Yatay hattan sütun üstüne iniş
			var is_unlocked = ProgressionManager.is_node_unlocked(first_node_id)
			var can_unlock = ProgressionManager.can_unlock_node(first_node_id)
			var line_col = Color(0.85, 0.95, 1.0, 0.9) if is_unlocked else (Color(1.0, 0.8, 0.25, 0.75) if can_unlock else Color(0.25, 0.30, 0.40, 0.45))
			var line_width = 2.5 if is_unlocked else 1.8
			
			lines_overlay.draw_line(Vector2(b_top.x, bus_y), b_top, line_col, line_width)
	
	# Yatay dağıtım barı (en soldaki sütundan en sağdaki sütuna)
	if col_x_positions.size() > 1:
		col_x_positions.sort()
		lines_overlay.draw_line(Vector2(col_x_positions[0], bus_y), Vector2(col_x_positions[-1], bus_y), Color(0.4, 0.85, 1.0, 0.8), 2.5)
	
	# 2. Düğümler arası dikey bağlantı hatları
	for node_id in node_buttons:
		var node_data = ProgressionManager.get_skill_node(node_id)
		var parents = node_data.get("parents", [])
		var child_btn = node_buttons[node_id]
		var child_rect = child_btn.get_global_rect()
		var child_top = Vector2(child_rect.position.x + child_rect.size.x * 0.5, child_rect.position.y) - overlay_global_pos
		
		for p_id in parents:
			if p_id == "core_start":
				continue
			if node_buttons.has(p_id):
				var p_btn = node_buttons[p_id]
				var p_rect = p_btn.get_global_rect()
				var p_bottom = Vector2(p_rect.position.x + p_rect.size.x * 0.5, p_rect.position.y + p_rect.size.y) - overlay_global_pos
				
				var is_child_unlocked = ProgressionManager.is_node_unlocked(node_id)
				var is_parent_unlocked = ProgressionManager.is_node_unlocked(p_id)
				var can_unlock_child = ProgressionManager.can_unlock_node(node_id)
				
				var line_col = Color(0.35, 0.95, 0.7, 0.9) if is_child_unlocked else (Color(1.0, 0.8, 0.25, 0.8) if can_unlock_child else Color(0.22, 0.26, 0.36, 0.45))
				var line_width = 3.0 if is_child_unlocked else (2.0 if can_unlock_child else 1.5)
				
				if abs(p_bottom.x - child_top.x) < 4.0:
					# Aynı sütunda düz dikey hat
					lines_overlay.draw_line(p_bottom, child_top, line_col, line_width)
				else:
					# Çapraz/Farklı sütunlar arası basamaklı ortogonal hat
					var mid_y = (p_bottom.y + child_top.y) * 0.5
					lines_overlay.draw_line(p_bottom, Vector2(p_bottom.x, mid_y), line_col, line_width)
					lines_overlay.draw_line(Vector2(p_bottom.x, mid_y), Vector2(child_top.x, mid_y), line_col, line_width)
					lines_overlay.draw_line(Vector2(child_top.x, mid_y), child_top, line_col, line_width)

## Düğüm seçimi ve detay paneli güncellemesi
func _select_node(node_id: String) -> void:
	selected_node_id = node_id
	var node = ProgressionManager.get_skill_node(node_id)
	if node.is_empty():
		return
	
	if detail_icon:
		detail_icon.text = NODE_ICONS.get(node_id, "◆")
	
	if detail_title:
		detail_title.text = node.get("title", "")
	
	if detail_category:
		var cat_name = node.get("category", "").to_upper()
		match node.get("category", ""):
			"core": cat_name = "[ MERKEZİ ÇEKİRDEK ]"
			"weapon": cat_name = "[ SİLAH UZMANLIĞI ]"
			"survival": cat_name = "[ HAYATTA KALMA ]"
			"mobility": cat_name = "[ HAREKET & TAKTİK ]"
			"demolition": cat_name = "[ KAOS & YIKIM ]"
			"utility": cat_name = "[ TAKTİKSEL BECERİ ]"
			"cross": cat_name = "[ ÇAPRAZ UZMANLIK ]"
			"mastery": cat_name = "[ NİHAİ USTALIK ]"
		detail_category.text = cat_name
	
	if detail_desc:
		detail_desc.text = node.get("desc", "")
	
	if detail_reqs:
		var parents = node.get("parents", [])
		var reqs_text = "ÖN KOŞULLAR:\n"
		if parents.is_empty() or parents == ["core_start"]:
			reqs_text += "• Başlangıç Seviyesi (Açık ✅)"
		else:
			for p_id in parents:
				var p_node = ProgressionManager.get_skill_node(p_id)
				var is_p_unlocked = ProgressionManager.is_node_unlocked(p_id)
				var mark = " ✅" if is_p_unlocked else " ❌"
				reqs_text += "• " + p_node.get("title", p_id) + mark + "\n"
		detail_reqs.text = reqs_text
	
	var cost = int(node.get("cost", 0))
	if detail_cost:
		detail_cost.text = "MALİYET: %d BİYO-ÇEKİRDEK" % cost
	
	var is_unlocked = ProgressionManager.is_node_unlocked(node_id)
	var can_unlock = ProgressionManager.can_unlock_node(node_id)
	
	if unlock_btn:
		if node_id == "core_start" or is_unlocked:
			unlock_btn.text = "AÇILDI"
			unlock_btn.disabled = true
		elif can_unlock:
			unlock_btn.text = "KİLİDİ AÇ (%d ÇEKİRDEK)" % cost
			unlock_btn.disabled = false
		else:
			unlock_btn.text = "KİLİTLİ"
			unlock_btn.disabled = true
	
	_populate_tree()

func _on_unlock_pressed() -> void:
	if selected_node_id.is_empty():
		return
	var success = ProgressionManager.unlock_node(selected_node_id)
	if success:
		SoundManager.play_sfx("pickup")
		_refresh_tree()
		_select_node(selected_node_id)
		if current_player and is_instance_valid(current_player):
			ProgressionManager.apply_to_player(current_player)
	else:
		SoundManager.play_sfx("empty")

func _on_respec_pressed() -> void:
	ProgressionManager.respec()
	SoundManager.play_sfx("switch")
	_refresh_tree()
	if not selected_node_id.is_empty():
		_select_node(selected_node_id)
	if current_player and is_instance_valid(current_player):
		ProgressionManager.apply_to_player(current_player)

func _refresh_tree() -> void:
	_update_header()
	_populate_tree()
