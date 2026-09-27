extends CharacterBody3D

# --- 1. Şahıs Kutu Kafa Kontrolcüsü, Çoklu Silah, Ekonomi ve Kombo Sistemi ---
signal health_changed(new_health: float)
signal player_died

@export var speed: float = 7.0
@export var sprint_speed: float = 11.0
@export var jump_velocity: float = 4.4 # Zıplama dengelendi (zombilerin üzerinden rastgele uçulamaz)
var jump_cooldown_timer: float = 0.0
@export var mouse_sensitivity: float = 0.0025

# Can ve Hasar
@export var max_health: float = 100.0
var current_health: float = 100.0

# Silah ve Cephane Sistemi (Envanter & Çoklu Silah)
const WEAPON_MAX_AMMO: Dictionary = {
	"pistol": -1,   # Sonsuz mermi
	"shotgun": 64,  # Pompalı mermi sınırı
	"uzi": 120,     # Uzi mermi sınırı
	"bixi": 350,    # Bixi (PKM) Ağır makineli mermi sınırı
	"rocket": 16    # Roket mermi sınırı
}

var weapon_inventory: Array[String] = ["pistol"]
var weapon_ammo_dict: Dictionary = {
	"pistol": -1,
	"shotgun": 0,
	"uzi": 0,
	"bixi": 0,
	"rocket": 0
}
var current_weapon: String = "pistol"
var current_weapon_index: int = 0
var fire_timer: float = 0.0
var weapon_switch_cooldown: float = 0.0
var weapon_notice_tween: Tween = null

# Kalıcı Mağaza Yükseltmeleri (Stat Multipliers)
var stat_damage_mult: float = 1.0
var stat_firerate_mult: float = 1.0
var stat_drop_luck: float = 0.0 # Zombi ganimet düşürme şansı çarpanı

# Ekonomi
var gold: int = 0

# Tekme (Kick - F Tuşu)
@export var kick_cooldown: float = 0.8
var kick_timer: float = 0.0

# Kombo ve Çarpan
var combo_multiplier: int = 1
var combo_timer: float = 0.0
const COMBO_DURATION: float = 4.5
var kill_count: int = 0
var headshot_count: int = 0

# Envanter: Patlayıcı Variller (G Tuşu)
var barrel_count: int = 3

# Dash (Taktiksel Atılma Mekaniği - Progression)
var is_dash_unlocked: bool = false
var dash_cooldown: float = 1.8
var dash_timer: float = 0.0
var is_dashing: bool = false
var dash_duration_timer: float = 0.0
const DASH_SPEED: float = 22.0
const DASH_DURATION: float = 0.18
var dash_dir: Vector3 = Vector3.ZERO
var is_last_stand_active: bool = false
var last_stand_timer: float = 0.0

# Duvarcı Sınıfı Duvar Sistemi
var wall_count: int = 10
var max_wall_count: int = 10
var wall_regen_timer: float = 0.0
const WALL_REGEN_INTERVAL: float = 5.0
const BARREL_SCENE_PATH = "res://scenes/interactables/barrel_red.tscn"
const ROCKET_SCENE_PATH = "res://scenes/weapons/rocket.tscn"
const HIT_EFFECT_PATH = "res://scenes/weapons/hit_effect.tscn"
const GIBS_SCENE_PATH = "res://scenes/effects/cube_gibs.tscn"

# Durum ve Efekt Değişkenleri
var is_dead: bool = false
var is_in_shop: bool = false
var is_in_skill_tree: bool = false
var spectator_target: CharacterBody3D = null
var all_players_dead: bool = false
var camera_trauma: float = 0.0
var hurt_tween: Tween = null

# Canlandırma (Revive) Sistemi (E Tuşuna 10 saniye basılı tutarak)
const REVIVE_REQUIRED_TIME: float = 10.0
const REVIVE_MAX_DISTANCE: float = 3.2
var current_reviving_target: CharacterBody3D = null
var revive_progress_timer: float = 0.0
var revive_box: VBoxContainer = null
var revive_label: Label = null
var revive_bar: ProgressBar = null

# Ölüm / İzleyici Ekranı Gizleme / Gösterme
var is_death_ui_hidden: bool = false
var toggle_death_ui_btn: Button = null
var floating_show_ui_btn: Button = null

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var shoot_ray: RayCast3D = $Head/Camera3D/ShootRay
@onready var kick_ray: RayCast3D = $Head/Camera3D/KickRay
@onready var gun: Node3D = $Head/Camera3D/Gun
@onready var model_pistol: Node3D = $Head/Camera3D/Gun.get_node_or_null("Pistol")
@onready var model_shotgun: Node3D = $Head/Camera3D/Gun.get_node_or_null("Shotgun")
@onready var model_uzi: Node3D = $Head/Camera3D/Gun.get_node_or_null("Uzi")
@onready var model_bixi: Node3D = $Head/Camera3D/Gun.get_node_or_null("Bixi")
@onready var model_rocket: Node3D = $Head/Camera3D/Gun.get_node_or_null("Rocket")
@onready var hud: CanvasLayer = $HUD

# HUD Elemanları
@onready var health_bar: ProgressBar = $HUD/HealthContainer/HealthBar
@onready var health_label: Label = $HUD/HealthContainer/HealthLabel
@onready var multiplier_label: Label = $HUD/ComboContainer/MultiplierLabel
@onready var combo_bar: ProgressBar = $HUD/ComboContainer/ComboBar
@onready var barrel_label: Label = $HUD/BarrelContainer/BarrelLabel
@onready var weapon_label: Label = $HUD/WeaponContainer/WeaponLabel
@onready var weapon_slots_label: Label = $HUD/WeaponContainer/WeaponSlotsLabel
@onready var weapon_notice_label: Label = $HUD/WeaponContainer/WeaponNoticeLabel
@onready var gold_label: Label = $HUD/GoldContainer/GoldLabel
@onready var tactical_bar: ProgressBar = $HUD/SpellContainer/TacticalBox/TacticalBar
@onready var ult_bar: ProgressBar = $HUD/SpellContainer/UltBox/UltBar
@onready var ult_label: Label = $HUD/SpellContainer/UltBox/UltLabel
@onready var name_label: Label3D = $NameLabel
@onready var head_mesh: MeshInstance3D = $Head/HeadMesh
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var spell_manager: Node = $SpellManager

# Hasar ve Ölüm UI
@onready var damage_overlay: Control = $HUD/DamageOverlay
@onready var damage_vignette: TextureRect = $HUD/DamageOverlay/DamageVignette
@onready var damage_flash: ColorRect = $HUD/DamageOverlay/DamageFlash
@onready var death_screen: Control = $HUD/DeathScreen
@onready var death_title_label: Label = $HUD/DeathScreen/CenterContainer/VBox/DeathTitleLabel
@onready var death_reason_label: Label = $HUD/DeathScreen/CenterContainer/VBox/DeathReasonLabel
@onready var death_info_label: Label = $HUD/DeathScreen/CenterContainer/VBox/DeathInfoLabel
@onready var restart_btn: Button = $HUD/DeathScreen/CenterContainer/VBox/Buttons/RestartBtn
@onready var lobby_btn: Button = $HUD/DeathScreen/CenterContainer/VBox/Buttons/LobbyBtn

# Duraklatma Menüsü UI (ESC Menu)
@onready var pause_menu: Control = $HUD/PauseMenu
@onready var pause_nav: VBoxContainer = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseNav
@onready var pause_settings: VBoxContainer = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseSettings
@onready var pause_resume_btn: Button = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseNav/ResumeBtn
@onready var pause_skill_tree_btn: Button = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseNav/SkillTreeBtn
@onready var pause_settings_btn: Button = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseNav/SettingsBtn
@onready var pause_restart_btn: Button = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseNav/RestartBtn
@onready var pause_lobby_btn: Button = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseNav/LobbyBtn
@onready var pause_quit_btn: Button = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseNav/QuitBtn

@onready var pause_window_mode: OptionButton = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseSettings/WindowModeBox/PauseWindowMode
@onready var pause_vsync_check: CheckBox = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseSettings/VSyncBox/PauseVSyncCheck
@onready var pause_volume_slider: HSlider = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseSettings/VolumeBox/PauseVolumeSlider
@onready var pause_volume_label: Label = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseSettings/VolumeBox/PauseVolumeLabel
@onready var pause_sens_slider: HSlider = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseSettings/SensBox/PauseSensSlider
@onready var pause_sens_label: Label = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseSettings/SensBox/PauseSensLabel
@onready var back_from_settings_btn: Button = $HUD/PauseMenu/CenterContainer/Panel/Margin/PauseSettings/BackFromSettingsBtn

# Skor Tablosu UI (TAB Scoreboard)
@onready var scoreboard: Control = $HUD/Scoreboard
@onready var scoreboard_list: VBoxContainer = $HUD/Scoreboard/CenterContainer/Panel/VBox/PlayerList

var player_id: int = 1
var player_name: String = "Oyuncu"
var player_class: String = "Pyromancer"
var original_gun_pos: Vector3 = Vector3(0.24, -0.20, -0.42)
var slide_tween: Tween = null
var pump_tween: Tween = null
var uzi_tween: Tween = null
var kick_cam_tilt: float = 0.0

func _enter_tree() -> void:
	player_id = name.to_int()
	if player_id == 0:
		player_id = 1
	set_multiplayer_authority(player_id)

func _ready() -> void:
	add_to_group("players")
	current_health = max_health
	_hide_all_muzzle_flashes()
	_update_gun_visuals()
	
	if SettingsManager:
		mouse_sensitivity = SettingsManager.mouse_sensitivity
		if camera:
			camera.fov = SettingsManager.fov_val
		SettingsManager.settings_changed.connect(func():
			mouse_sensitivity = SettingsManager.mouse_sensitivity
			if camera:
				camera.fov = SettingsManager.fov_val
		)
	
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if lobby_btn:
		lobby_btn.pressed.connect(_on_lobby_pressed)
	
	if pause_resume_btn:
		pause_resume_btn.pressed.connect(_on_pause_resume_pressed)
	if pause_skill_tree_btn:
		pause_skill_tree_btn.pressed.connect(toggle_skill_tree)
	if pause_settings_btn:
		pause_settings_btn.pressed.connect(_on_pause_settings_pressed)
	if back_from_settings_btn:
		back_from_settings_btn.pressed.connect(_on_pause_back_from_settings_pressed)
	if pause_restart_btn:
		pause_restart_btn.pressed.connect(_on_restart_pressed)
	if pause_lobby_btn:
		pause_lobby_btn.pressed.connect(_on_lobby_pressed)
	if pause_quit_btn:
		pause_quit_btn.pressed.connect(_on_pause_quit_pressed)
	
	if pause_window_mode:
		pause_window_mode.clear()
		pause_window_mode.add_item("PENCERELİ", 0)
		pause_window_mode.add_item("KENARLIKSIZ", 1)
		pause_window_mode.add_item("TAM EKRAN", 2)
		pause_window_mode.item_selected.connect(_on_pause_window_mode_selected)
	if pause_vsync_check:
		pause_vsync_check.toggled.connect(_on_pause_vsync_toggled)
	if pause_volume_slider:
		pause_volume_slider.value_changed.connect(_on_pause_volume_changed)
	if pause_sens_slider:
		pause_sens_slider.value_changed.connect(_on_pause_sens_changed)
	
	if NetworkManager.players.has(player_id):
		player_name = NetworkManager.players[player_id].get("name", "Kutu Kafa")
		player_class = NetworkManager.players[player_id].get("class", "Pyromancer")
	name_label.text = player_name

	if spell_manager:
		spell_manager.setup(self, player_class)
		spell_manager.spell_updated.connect(_on_spell_updated)

	if is_multiplayer_authority():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.visible = true
		head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		# Kalıcı Yetenek Ağacı İlerlemesini Oyuncuya Uygula
		ProgressionManager.apply_to_player(self)
		_update_hud()
		
		# Canlandırma (Revive) Arayüzünü Oluştur
		revive_box = VBoxContainer.new()
		revive_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		revive_box.offset_bottom = -160.0
		revive_box.offset_left = -200.0
		revive_box.offset_right = 200.0
		revive_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		revive_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
		revive_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		revive_box.visible = false
		
		revive_label = Label.new()
		revive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		revive_label.add_theme_font_size_override("font_size", 16)
		revive_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		revive_label.text = "[E] CANLANDIRILIYOR..."
		revive_box.add_child(revive_label)
		
		revive_bar = ProgressBar.new()
		revive_bar.custom_minimum_size = Vector2(340, 16)
		revive_bar.show_percentage = true
		revive_bar.max_value = 100.0
		revive_box.add_child(revive_bar)
		
		hud.add_child(revive_box)

		# Ölüm Ekranı Gizleme / Gösterme Butonları
		if death_screen:
			death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var backdrop = death_screen.get_node_or_null("Backdrop")
			if backdrop:
				backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			var vbox = death_screen.get_node_or_null("CenterContainer/VBox")
			if vbox:
				toggle_death_ui_btn = Button.new()
				toggle_death_ui_btn.text = "Arayüzü Gizle [H]"
				toggle_death_ui_btn.add_theme_font_size_override("font_size", 14)
				toggle_death_ui_btn.custom_minimum_size = Vector2(180, 36)
				toggle_death_ui_btn.pressed.connect(toggle_death_ui)
				vbox.add_child(toggle_death_ui_btn)
			
			floating_show_ui_btn = Button.new()
			floating_show_ui_btn.text = "Arayüzü Göster [H]"
			floating_show_ui_btn.add_theme_font_size_override("font_size", 13)
			floating_show_ui_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			floating_show_ui_btn.offset_left = -180.0
			floating_show_ui_btn.offset_top = 20.0
			floating_show_ui_btn.offset_right = -20.0
			floating_show_ui_btn.offset_bottom = 56.0
			floating_show_ui_btn.visible = false
			floating_show_ui_btn.pressed.connect(toggle_death_ui)
			death_screen.add_child(floating_show_ui_btn)
	else:
		camera.current = false
		hud.visible = false

func set_in_shop(active: bool) -> void:
	is_in_shop = active
	if is_multiplayer_authority():
		if active:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			if not is_in_skill_tree and not (pause_menu and pause_menu.visible):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_in_skill_tree(active: bool) -> void:
	is_in_skill_tree = active
	if is_multiplayer_authority():
		if active:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			if not is_in_shop and not (pause_menu and pause_menu.visible):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if not active:
			ProgressionManager.apply_to_player(self)

func toggle_skill_tree() -> void:
	var st = get_tree().get_first_node_in_group("skill_tree_ui")
	if not st:
		return
	if st.visible:
		st.close()
	else:
		if pause_menu and pause_menu.visible:
			_close_pause_menu()
		st.open_for_player(self)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	# TAB TUŞU: Skor / Takım Tablosu
	if event is InputEventKey and event.keycode == KEY_TAB:
		_set_scoreboard_visible(event.pressed)
		get_viewport().set_input_as_handled()
		return

	# K TUŞU: Yetenek Ağacı Aç/Kapat (Oyun İçi Meta-Geliştirme)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		if not is_dead and not (scoreboard and scoreboard.visible):
			toggle_skill_tree()
			get_viewport().set_input_as_handled()
			return

	# ESC TUŞU: Duraklatma Menüsü Aç/Kapat
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if scoreboard and scoreboard.visible:
			_set_scoreboard_visible(false)
			get_viewport().set_input_as_handled()
			return
		
		if is_in_skill_tree:
			toggle_skill_tree()
			get_viewport().set_input_as_handled()
			return
		
		if not is_in_shop and not (death_screen and death_screen.visible):
			if pause_menu:
				if pause_menu.visible:
					_close_pause_menu()
				else:
					_open_pause_menu()
				get_viewport().set_input_as_handled()
				return
	
	if is_dead:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_H:
				toggle_death_ui()
				get_viewport().set_input_as_handled()
				return
		
		if all_players_dead:
			if event is InputEventKey and event.pressed and (event.keycode == KEY_R or event.keycode == KEY_SPACE):
				_on_restart_pressed()
		else:
			if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
				_cycle_spectator_target(1)
			elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				_cycle_spectator_target(-1)
		return
	
	# Pause menüsü, Mağaza açıkken veya fare görünürken silah ve kamera girdilerini engelle
	if (pause_menu and pause_menu.visible) or is_in_shop or is_in_skill_tree or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	# Fare Tekerleği ile Silah Geçişi (Mouse Scroll Wheel)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon(1)
	
	# Sayı Tuşları ile Silah Seçimi (1, 2, 3, 4, 5)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _select_weapon_slot(0)
			KEY_2: _select_weapon_slot(1)
			KEY_3: _select_weapon_slot(2)
			KEY_4: _select_weapon_slot(3)
			KEY_5: _select_weapon_slot(4)
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Kamera sarsıntısı ve travma sönümleme
	if is_multiplayer_authority():
		if camera_trauma > 0:
			camera_trauma = max(0.0, camera_trauma - delta * 2.5)
			var s = camera_trauma * camera_trauma
			camera.h_offset = randf_range(-0.12, 0.12) * s
			camera.v_offset = randf_range(-0.12, 0.12) * s
			camera.rotation_degrees.z = lerp(camera.rotation_degrees.z, 0.0, 10.0 * delta)
		else:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
			camera.rotation_degrees.z = lerp(camera.rotation_degrees.z, 0.0, 10.0 * delta)

		# Kritik can nabız efekti (< 30% Can)
		if not is_dead and damage_vignette:
			if current_health < 30.0:
				var pulse = (sin(Time.get_ticks_msec() * 0.007) * 0.5 + 0.5) * 0.4 + 0.15
				damage_vignette.modulate.a = max(damage_vignette.modulate.a, pulse)

	if not is_multiplayer_authority():
		move_and_slide()
		return

	if weapon_switch_cooldown > 0:
		weapon_switch_cooldown -= delta

	if is_dead:
		velocity.x = move_toward(velocity.x, 0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 15.0 * delta)
		move_and_slide()
		
		# İzleyici Kamera Takibi (Spectator Follow)
		if is_multiplayer_authority() and not all_players_dead:
			if spectator_target == null or not is_instance_valid(spectator_target) or spectator_target.get("is_dead"):
				_cycle_spectator_target(1)
			
			if spectator_target and is_instance_valid(spectator_target):
				var target_cam_pos = spectator_target.global_position + Vector3(0, 2.2, 0) - spectator_target.transform.basis.z * 3.2
				camera.global_position = camera.global_position.lerp(target_cam_pos, 10.0 * delta)
				camera.look_at(spectator_target.global_position + Vector3(0, 1.2, 0), Vector3.UP)
		return

	# Duraklatma Menüsü veya Mağazadayken hareket ve aksiyonları durdur
	if (pause_menu and pause_menu.visible) or is_in_shop or is_in_skill_tree:
		velocity.x = move_toward(velocity.x, 0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 15.0 * delta)
		move_and_slide()
		return

	fire_timer -= delta
	kick_timer -= delta
	jump_cooldown_timer = max(0.0, jump_cooldown_timer - delta)
	if dash_timer > 0:
		dash_timer -= delta
	if last_stand_timer > 0:
		last_stand_timer -= delta
		if last_stand_timer <= 0:
			is_last_stand_active = false
	
	# Kombo Sayacı
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_multiplier = 1
			_update_combo_hud()
	_update_combo_hud()

	# Duvarcı için 5 saniyede bir duvar stack yenileme
	if player_class == "Builder":
		if wall_count < max_wall_count:
			wall_regen_timer += delta
			if wall_regen_timer >= WALL_REGEN_INTERVAL:
				wall_regen_timer = 0.0
				wall_count = min(max_wall_count, wall_count + 1)
				_update_wall_hud()
		else:
			wall_regen_timer = 0.0

	# YALNIZCA fare kilitliyken ateş et, tekme at ve varil koy (Arayüzde tıklarken ateş etmeyi engeller)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if is_multiplayer_authority():
			_handle_revive_interaction(delta)

		# Ateş Etme (Sol Tık) - Canlandırırken ateş etmeyi engelle
		if Input.is_action_pressed("shoot") and fire_timer <= 0 and revive_progress_timer <= 0:
			_shoot()

		# Tekme (F Tuşu)
		if Input.is_action_just_pressed("kick") and kick_timer <= 0 and revive_progress_timer <= 0:
			_kick()
			kick_timer = kick_cooldown

		# Varil Bırakma (G / Interact Tuşu)
		if Input.is_action_just_pressed("interact") and barrel_count > 0 and revive_progress_timer <= 0:
			_place_barrel()
	else:
		_reset_revive_state()

	# Geri tepme yumuşatma
	if gun:
		gun.position = gun.position.lerp(original_gun_pos, 16.0 * delta)
		gun.rotation = gun.rotation.lerp(Vector3.ZERO, 16.0 * delta)

	# Zıplama (Düşürüldü ve bekleme süresi eklendi - Vortex ve takım taktiği değer kazandı)
	if Input.is_action_just_pressed("jump") and is_on_floor() and jump_cooldown_timer <= 0:
		velocity.y = jump_velocity
		jump_cooldown_timer = 0.35

	# Hız (Kombo Bonusu Dahil)
	var speed_bonus = 1.0 + (combo_multiplier * 0.04)
	var current_speed = (sprint_speed if Input.is_action_pressed("sprint") else speed) * speed_bonus

	# WASD
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_forward"): input_dir.y -= 1
	if Input.is_action_pressed("move_backward"): input_dir.y += 1
	if Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1
	input_dir = input_dir.normalized()

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Dash (Taktiksel Atılma) Kontrolü: Açılmışsa Shift'e basıldığında veya yön verilirken
	if is_dash_unlocked and dash_timer <= 0 and direction != Vector3.ZERO:
		if Input.is_action_just_pressed("sprint"):
			is_dashing = true
			dash_duration_timer = DASH_DURATION
			dash_timer = dash_cooldown
			dash_dir = direction
			SoundManager.play_sfx("switch")
			camera_trauma = min(1.0, camera_trauma + 0.15)
			if ProgressionManager.has_perk("phantom_dash_unlocked"):
				_phantom_dash_blast()

	if is_dashing:
		dash_duration_timer -= delta
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
		if dash_duration_timer <= 0:
			is_dashing = false
	elif direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * 10 * delta)
		velocity.z = move_toward(velocity.z, 0, current_speed * 10 * delta)

	move_and_slide()

## Çoklu Silah Ateş Etme Fonksiyonu
func _shoot() -> void:
	if is_dead:
		return
	if gun:
		match current_weapon:
			"pistol":
				gun.position.z += 0.042
				gun.rotation.x += deg_to_rad(3.2)
				_animate_slide_recoil()
			"shotgun":
				gun.position.z += 0.075
				gun.rotation.x += deg_to_rad(5.5)
				_animate_shotgun_pump()
			"uzi":
				gun.position.z += 0.026
				gun.rotation.x += deg_to_rad(1.8)
				_animate_uzi_recoil()
			"bixi":
				gun.position.z += 0.055
				gun.position.x += randf_range(-0.005, 0.005)
				gun.rotation.x += deg_to_rad(4.2)
			"rocket":
				gun.position.z += 0.11
				gun.rotation.x += deg_to_rad(7.5)
				camera_trauma = min(1.0, camera_trauma + 0.35)
				_animate_rocket_launch()
	if head:
		match current_weapon:
			"pistol": head.rotation.x += deg_to_rad(0.35)
			"shotgun": head.rotation.x += deg_to_rad(0.75)
			"uzi": head.rotation.x += deg_to_rad(0.18)
			"bixi": head.rotation.x += deg_to_rad(0.42)
			"rocket": head.rotation.x += deg_to_rad(1.1)

	var cur_flash = _get_current_muzzle_flash()
	if cur_flash:
		_show_muzzle_flash.rpc()

	# Silah Ateşleme Ses Efekti (Yerel + Ağ 3D)
	SoundManager.play_sfx(current_weapon)
	_play_network_shoot_sfx.rpc(current_weapon)

	match current_weapon:
		"pistol":
			fire_timer = 0.22 / stat_firerate_mult
			_fire_bullet(38.0 * stat_damage_mult, Vector3.ZERO)
		"uzi":
			fire_timer = 0.08 / stat_firerate_mult
			var spread = Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), 0)
			_fire_bullet(25.0 * stat_damage_mult, spread)
			weapon_ammo_dict["uzi"] = max(0, weapon_ammo_dict.get("uzi", 0) - 1)
		"bixi":
			fire_timer = 0.10 / stat_firerate_mult
			var spread = Vector3(randf_range(-0.022, 0.022), randf_range(-0.022, 0.022), 0)
			_fire_bullet(34.0 * stat_damage_mult, spread)
			weapon_ammo_dict["bixi"] = max(0, weapon_ammo_dict.get("bixi", 0) - 1)
		"shotgun":
			fire_timer = 0.65 / stat_firerate_mult
			for i in range(6):
				var spread = Vector3(randf_range(-0.06, 0.06), randf_range(-0.06, 0.06), 0)
				_fire_bullet(22.0 * stat_damage_mult, spread)
			weapon_ammo_dict["shotgun"] = max(0, weapon_ammo_dict.get("shotgun", 0) - 1)
		"rocket":
			fire_timer = 0.90 / stat_firerate_mult
			var cam = $Head/Camera3D
			var spawn_pos = cam.global_position - cam.global_transform.basis.z * 1.0
			var forward = -cam.global_transform.basis.z
			_request_spawn_rocket.rpc_id(1, spawn_pos, forward)
			weapon_ammo_dict["rocket"] = max(0, weapon_ammo_dict.get("rocket", 0) - 1)

	# Mermisi biten silah kullanımdan gidecek!
	if current_weapon != "pistol" and weapon_ammo_dict.get(current_weapon, 0) <= 0:
		_discard_empty_weapon(current_weapon)

	_update_hud()

@rpc("call_local", "unreliable")
func _play_network_shoot_sfx(w_type: String) -> void:
	if not is_multiplayer_authority():
		SoundManager.play_3d_sfx(w_type, global_position)

func _fire_bullet(dmg: float, spread: Vector3) -> void:
	if not shoot_ray or not shoot_ray.is_colliding():
		return
	var hit_collider = shoot_ray.get_collider()
	if hit_collider == null:
		return

	# DOST ATEŞİ KAPALI: Takım arkadaşına hasar verme!
	if hit_collider.is_in_group("players") or (hit_collider.get_parent() and hit_collider.get_parent().is_in_group("players")):
		return

	var hit_point = shoot_ray.get_collision_point() + spread
	var hit_normal = shoot_ray.get_collision_normal()
	
	var is_headshot = false
	var target = null

	if hit_collider.name == "HeadshotArea":
		is_headshot = true
		target = hit_collider.get_parent()
	elif hit_collider.is_in_group("enemies") or hit_collider.is_in_group("barrels") or hit_collider.is_in_group("destructibles"):
		target = hit_collider

	var final_dmg = dmg

	# Run & Gun perk: Hareket halindeyken hasar bonusu
	if ProgressionManager.has_perk("run_and_gun_unlocked") and velocity.length() > 0.8:
		final_dmg *= (1.0 + ProgressionManager.get_stat("moving_damage_bonus", 0.15))

	# Last Stand perk: Düşük canda ek hasar
	if is_last_stand_active:
		final_dmg *= 1.25

	# Kritik Vuruş Kontrolü
	var crit_chance = ProgressionManager.get_stat("crit_chance", 0.05)
	if randf() < crit_chance:
		var crit_mult = ProgressionManager.get_stat("crit_multiplier", 1.5)
		final_dmg *= crit_mult
		camera_trauma = min(1.0, camera_trauma + 0.08)

	# Headshot Çarpanı
	if is_headshot:
		var hs_mult = ProgressionManager.get_stat("headshot_mult", 1.5)
		final_dmg *= (hs_mult / 1.5)

	# İnfazcı (Executioner perk): Düşük canı kalan zombiyi infaz et
	if target and target.has_method("take_damage"):
		if target.get("is_exploded") == true:
			return
		if ProgressionManager.has_perk("executioner_unlocked") and target.is_in_group("enemies"):
			var cur_hp = float(target.get("current_health")) if target.get("current_health") != null else 100.0
			var max_hp = float(target.get("max_health")) if target.get("max_health") != null else 100.0
			if cur_hp > 0 and (cur_hp / max_hp) <= ProgressionManager.get_stat("execute_threshold", 0.20):
				final_dmg = max(final_dmg, cur_hp + 50.0)

		target.take_damage(final_dmg, is_headshot, hit_point, player_id)
		if target.get("is_exploded") != true:
			_register_kill_streak()
	
	_spawn_hit_effect.rpc(hit_point, hit_normal)

@rpc("any_peer", "call_local", "reliable")
func _request_spawn_rocket(pos: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server():
		var r_scene = load(ROCKET_SCENE_PATH)
		if r_scene:
			var r = r_scene.instantiate()
			r.position = pos
			r.direction = dir
			r.look_at(pos + dir, Vector3.UP)
			get_tree().current_scene.add_child(r, true)

## Eşya Toplama (Zombilerden Düşenler & Mühimmat)
@rpc("any_peer", "call_local", "reliable")
func apply_pickup(p_type: String, p_amount: int) -> void:
	if is_dead:
		return
	match p_type:
		"gold":
			gold += p_amount
			if is_multiplayer_authority():
				SoundManager.play_sfx("pickup")
				sync_player_stats.rpc(gold)
		"shotgun", "uzi", "bixi", "rocket":
			var max_cap = WEAPON_MAX_AMMO.get(p_type, 250)
			var current_ammo = weapon_ammo_dict.get(p_type, 0)
			var is_new = not weapon_inventory.has(p_type)
			
			if not is_new and current_ammo >= max_cap:
				if is_multiplayer_authority():
					_show_weapon_notice("⚠️ " + _get_weapon_display_name(p_type).to_upper() + " CEPHANESİ DOLU! (" + str(max_cap) + ")")
				return
			
			if is_multiplayer_authority():
				SoundManager.play_sfx("pickup")
			if is_new:
				weapon_inventory.append(p_type)
				weapon_ammo_dict[p_type] = min(p_amount, max_cap)
				# Toplanan silaha hemen geçiş yap
				if is_multiplayer_authority():
					switch_to_weapon(p_type)
			else:
				weapon_ammo_dict[p_type] = min(max_cap, current_ammo + p_amount)
			if is_multiplayer_authority():
				_show_weapon_notice("🎁 " + _get_weapon_display_name(p_type).to_upper() + " ALINDI! (+" + str(p_amount) + ") [" + str(weapon_ammo_dict[p_type]) + "/" + str(max_cap) + "]")
		"barrel":
			barrel_count += p_amount
			if is_multiplayer_authority():
				SoundManager.play_sfx("pickup")
		"health":
			current_health = clamp(current_health + p_amount, 0, max_health)
			if is_multiplayer_authority():
				SoundManager.play_sfx("pickup")
	if is_multiplayer_authority():
		_update_hud()

## Kutu Tekmesi Fonksiyonu (F Tuşu)
func _kick() -> void:
	if is_dead:
		return
	head.rotation.x -= deg_to_rad(2.0)
	velocity += -transform.basis.z * 3.0
	
	if kick_ray and kick_ray.is_colliding():
		var collider = kick_ray.get_collider()
		if collider == null:
			return
		# DOST ATEŞİ KAPALI: Takım arkadaşına tekme vurma
		if collider.is_in_group("players") or (collider.get_parent() and collider.get_parent().is_in_group("players")):
			return
		
		var kick_dir = -transform.basis.z
		kick_dir.y = 0.2
		kick_dir = kick_dir.normalized()
		
		if collider.has_method("kick"):
			collider.kick(kick_dir, 22.0)
		elif collider.is_in_group("enemies"):
			if collider.has_method("take_damage"):
				collider.take_damage(25.0 * stat_damage_mult, false, global_position, player_id)
			collider.velocity += kick_dir * 18.0

## Varil Yerleştirme (G Tuşu)
func _place_barrel() -> void:
	if is_dead:
		return
	barrel_count -= 1
	_update_barrel_hud()
	var spawn_pos = global_position - transform.basis.z * 1.8
	spawn_pos.y = global_position.y + 0.3
	_request_spawn_barrel.rpc_id(1, spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func _request_spawn_barrel(pos: Vector3) -> void:
	if multiplayer.is_server():
		var main_level = get_tree().current_scene
		if main_level and main_level.has_method("spawn_barrel"):
			main_level.spawn_barrel(pos)

## Kombo & Çarpan Mantığı
func _register_kill_streak() -> void:
	combo_timer = COMBO_DURATION
	if combo_multiplier < 10:
		combo_multiplier += 1
	kill_count += 1
	if spell_manager:
		spell_manager.add_ultimate_charge(2.5)
	_update_combo_hud()

func _on_spell_updated(tac_pct: float, ult_pct: float) -> void:
	if is_multiplayer_authority():
		if player_class == "Builder":
			_update_wall_hud()
		elif tactical_bar:
			tactical_bar.value = tac_pct * 100.0
		
		var tac_label = hud.get_node_or_null("SpellContainer/TacticalBox/TacticalLabel")
		if tac_label and player_class != "Builder":
			if player_class == "Engineer":
				if tac_pct >= 1.0:
					tac_label.text = "[E] TARET HAZIR"
					tac_label.modulate = Color(0.4, 0.95, 1.0)
				else:
					var rem_cd = ceil(spell_manager.tactical_timer) if spell_manager else 0
					tac_label.text = "[E] TARET (%ds)" % rem_cd
					tac_label.modulate = Color(0.85, 0.65, 0.3)
			else:
				if tac_pct >= 1.0:
					tac_label.text = "[E] TAKTİK HAZIR"
					tac_label.modulate = Color(0.4, 0.95, 1.0)
				else:
					var rem_cd = ceil(spell_manager.tactical_timer) if spell_manager else 0
					tac_label.text = "[E] TAKTİK (%ds)" % rem_cd
					tac_label.modulate = Color(0.85, 0.65, 0.3)
		
		if ult_bar and ult_label:
			ult_bar.value = ult_pct
			if ult_pct >= 100.0:
				if player_class == "Engineer":
					ult_label.text = "[Q] ŞOK DALGASI HAZIR!"
				elif player_class == "Builder":
					ult_label.text = "[Q] VORTEX HAZIR!"
				else:
					ult_label.text = "[Q] ULTİ HAZIR!"
				ult_label.modulate = Color(1.0, 0.9, 0.2)
			else:
				ult_label.text = "[Q] ULTİ: %" + str(int(ult_pct))
				ult_label.modulate = Color(0.85, 0.85, 0.85)

func _update_wall_hud() -> void:
	if not is_multiplayer_authority():
		return
	if player_class == "Builder":
		if tactical_bar:
			tactical_bar.value = (float(wall_count) / float(max_wall_count)) * 100.0
		var tac_label = hud.get_node_or_null("SpellContainer/TacticalBox/TacticalLabel")
		if tac_label:
			tac_label.text = "[E] DUVAR: %d/%d" % [wall_count, max_wall_count]
			if wall_count <= 0:
				tac_label.modulate = Color(1.0, 0.35, 0.35)
			else:
				tac_label.modulate = Color(1.0, 0.75, 0.35)

## Duvar Yerleştirme (Duvarcı Sınıfı - E Tuşu)
func try_place_wall() -> void:
	if is_dead or is_in_shop or is_in_skill_tree or (pause_menu and pause_menu.visible):
		return
	if wall_count <= 0:
		SoundManager.play_sfx("empty")
		_show_weapon_notice("🧱 DUVAR TÜKENDİ! (5 sn içinde yenilenir)")
		return
	
	wall_count -= 1
	_update_wall_hud()
	SoundManager.play_sfx("switch")
	
	var forward = -transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	var wall_pos = global_position + forward * 2.2
	wall_pos.y = global_position.y
	var wall_rot_y = rotation.y
	
	_request_spawn_wall.rpc_id(1, wall_pos, wall_rot_y)
	_show_weapon_notice("🧱 DUVAR YERLEŞTİRİLDİ (%d/%d)" % [wall_count, max_wall_count])

@rpc("any_peer", "call_local", "reliable")
func _request_spawn_wall(pos: Vector3, rot_y: float) -> void:
	if multiplayer.is_server():
		var main_level = get_tree().current_scene
		if main_level and main_level.has_method("spawn_wall"):
			main_level.spawn_wall(pos, rot_y)

func _update_combo_hud() -> void:
	if is_multiplayer_authority() and multiplier_label and combo_bar:
		multiplier_label.text = "KOMBO: x" + str(combo_multiplier)
		combo_bar.value = (combo_timer / COMBO_DURATION) * 100.0
		if combo_multiplier > 1:
			multiplier_label.modulate = Color(1.0, 0.85, 0.2)
		else:
			multiplier_label.modulate = Color(0.9, 0.9, 0.9)

func _update_barrel_hud() -> void:
	if is_multiplayer_authority() and barrel_label:
		barrel_label.text = "VARİL (G): " + str(barrel_count)

func _update_hud() -> void:
	if is_multiplayer_authority():
		if health_bar and health_label:
			health_bar.max_value = max_health
			health_bar.value = current_health
			health_label.text = "CAN: " + str(int(current_health)) + " / " + str(int(max_health))
		
		if gold_label:
			gold_label.text = "🪙 ALTIN: " + str(gold)

		if weapon_label:
			var w_name_tr = _get_weapon_display_name(current_weapon)
			var w_ammo = "∞" if current_weapon == "pistol" else str(weapon_ammo_dict.get(current_weapon, 0))
			weapon_label.text = "🔫 " + w_name_tr.to_upper() + " (" + w_ammo + ")"
			match current_weapon:
				"pistol": weapon_label.modulate = Color(0.9, 0.9, 0.9)
				"shotgun": weapon_label.modulate = Color(1.0, 0.45, 0.2)
				"uzi": weapon_label.modulate = Color(0.3, 1.0, 0.4)
				"bixi": weapon_label.modulate = Color(0.95, 0.75, 0.2)
				"rocket": weapon_label.modulate = Color(1.0, 0.25, 0.9)

		if weapon_slots_label:
			var slots_text = ""
			for i in range(weapon_inventory.size()):
				var w = weapon_inventory[i]
				var w_title = _get_weapon_display_name(w)
				var ammo_str = "∞" if w == "pistol" else str(weapon_ammo_dict.get(w, 0))
				if w == current_weapon:
					slots_text += "▶ [" + str(i + 1) + ": " + w_title + " (" + ammo_str + ")] "
				else:
					slots_text += "[" + str(i + 1) + ": " + w_title + "] "
			weapon_slots_label.text = slots_text

		_update_combo_hud()
		_update_barrel_hud()

## Silah Seçme, Geçiş ve Envanter Yönetimi
func switch_to_weapon(weapon_name: String) -> void:
	if not weapon_inventory.has(weapon_name):
		return
	if current_weapon == weapon_name:
		return
	
	current_weapon = weapon_name
	current_weapon_index = weapon_inventory.find(weapon_name)
	fire_timer = 0.12 # Küçük geçiş beklemesi
	
	_update_gun_visuals()
	SoundManager.play_sfx("switch")
	_animate_weapon_switch()
	_update_hud()
	if multiplayer.has_multiplayer_peer():
		_sync_weapon.rpc(current_weapon)

@rpc("any_peer", "call_remote", "reliable")
func _sync_weapon(w_name: String) -> void:
	current_weapon = w_name
	_update_gun_visuals()

func _cycle_weapon(direction: int) -> void:
	if weapon_inventory.size() <= 1:
		return
	if weapon_switch_cooldown > 0:
		return
	weapon_switch_cooldown = 0.10
	
	var new_index = (current_weapon_index + direction) % weapon_inventory.size()
	if new_index < 0:
		new_index = weapon_inventory.size() - 1
	
	switch_to_weapon(weapon_inventory[new_index])

func _select_weapon_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < weapon_inventory.size():
		switch_to_weapon(weapon_inventory[slot_index])

func _discard_empty_weapon(w_name: String) -> void:
	SoundManager.play_sfx("empty")
	var idx = weapon_inventory.find(w_name)
	if idx != -1:
		weapon_inventory.remove_at(idx)
	weapon_ammo_dict[w_name] = 0
	
	var target_index = max(0, idx - 1)
	if target_index >= weapon_inventory.size():
		target_index = 0
	
	var next_w = weapon_inventory[target_index]
	current_weapon = next_w
	current_weapon_index = target_index
	
	_show_weapon_notice("⚠️ " + _get_weapon_display_name(w_name).to_upper() + " TÜKENDİ! " + _get_weapon_display_name(next_w).to_upper() + "'A DÖNÜLDÜ")
	_animate_weapon_switch()
	_update_gun_visuals()

func _animate_weapon_switch() -> void:
	if not gun or not is_inside_tree():
		return
	var tw = create_tween()
	tw.tween_property(gun, "position:y", original_gun_pos.y - 0.08, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(gun, "position:y", original_gun_pos.y, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _get_current_weapon_model() -> Node3D:
	match current_weapon:
		"pistol": return model_pistol
		"shotgun": return model_shotgun
		"uzi": return model_uzi
		"bixi": return model_bixi
		"rocket": return model_rocket
	return model_pistol

func _get_current_muzzle_flash() -> OmniLight3D:
	var cur_model = _get_current_weapon_model()
	if cur_model and cur_model.has_node("MuzzleFlash"):
		return cur_model.get_node("MuzzleFlash") as OmniLight3D
	return null

func _hide_all_muzzle_flashes() -> void:
	for m in [model_pistol, model_shotgun, model_uzi, model_bixi, model_rocket]:
		if m and m.has_node("MuzzleFlash"):
			var fl = m.get_node("MuzzleFlash")
			if fl:
				fl.visible = false

func _update_gun_visuals() -> void:
	if not gun:
		return
	if model_pistol: model_pistol.visible = (current_weapon == "pistol")
	if model_shotgun: model_shotgun.visible = (current_weapon == "shotgun")
	if model_uzi: model_uzi.visible = (current_weapon == "uzi")
	if model_bixi: model_bixi.visible = (current_weapon == "bixi")
	if model_rocket: model_rocket.visible = (current_weapon == "rocket")

	# Roketatar seçiliyse ve mermi varsa savaş başlığını (warhead) görünür yap
	if current_weapon == "rocket" and model_rocket:
		var warhead = model_rocket.get_node_or_null("Warhead")
		if warhead:
			warhead.visible = (weapon_ammo_dict.get("rocket", 0) > 0 or not is_multiplayer_authority())

	# Silahın ekrandaki ideal FPS pozisyon ve ölçek hizalaması
	match current_weapon:
		"pistol":
			gun.scale = Vector3(1.0, 1.0, 1.0)
			original_gun_pos = Vector3(0.24, -0.20, -0.42)
		"shotgun":
			gun.scale = Vector3(1.0, 1.0, 1.0)
			original_gun_pos = Vector3(0.24, -0.21, -0.46)
		"uzi":
			gun.scale = Vector3(1.0, 1.0, 1.0)
			original_gun_pos = Vector3(0.22, -0.20, -0.40)
		"bixi":
			gun.scale = Vector3(0.95, 0.95, 0.95)
			original_gun_pos = Vector3(0.25, -0.23, -0.50)
		"rocket":
			gun.scale = Vector3(0.95, 0.95, 0.95)
			original_gun_pos = Vector3(0.22, -0.22, -0.48)

	gun.position = original_gun_pos

func _get_weapon_display_name(w_name: String) -> String:
	match w_name:
		"pistol": return "Tabanca"
		"shotgun": return "Pompalı"
		"uzi": return "Uzi"
		"bixi": return "Bixi (PKM)"
		"rocket": return "Roketatar"
		_: return w_name.capitalize()

func _show_weapon_notice(msg: String) -> void:
	if not is_multiplayer_authority() or not weapon_notice_label:
		return
	weapon_notice_label.text = msg
	weapon_notice_label.modulate.a = 1.0
	if weapon_notice_tween and weapon_notice_tween.is_valid():
		weapon_notice_tween.kill()
	weapon_notice_tween = create_tween()
	weapon_notice_tween.tween_property(weapon_notice_label, "modulate:a", 0.0, 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

## Tabanca Üst Mekanizma Geri Tepme Animasyonu (Glock Blowback)
func _animate_slide_recoil() -> void:
	if not model_pistol:
		return
	var gun_slide = model_pistol.get_node_or_null("Slide")
	if not gun_slide:
		return
	if slide_tween and slide_tween.is_valid():
		slide_tween.kill()
	
	slide_tween = create_tween()
	# Üst mekanizmanın hızla geriye fırlaması (Blowback: 0.055m geriye)
	slide_tween.tween_property(gun_slide, "position:z", 0.055, 0.035).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Mekanizmanın yayla hızla öne kilitlenmesi (Return to battery: 0.0m)
	slide_tween.tween_property(gun_slide, "position:z", 0.0, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Pompalı Tüfek Kurma Kolu Animasyonu (Shotgun Pump Action)
func _animate_shotgun_pump() -> void:
	if not model_shotgun:
		return
	var pump = model_shotgun.get_node_or_null("PumpHandle")
	if not pump:
		return
	if pump_tween and pump_tween.is_valid():
		pump_tween.kill()
	
	pump_tween = create_tween()
	pump_tween.tween_interval(0.08)
	# Kurma kolunun geriye çekilmesi (-0.22 -> -0.14)
	pump_tween.tween_property(pump, "position:z", -0.14, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Kurma kolunun ileri itilmesi (-0.14 -> -0.22)
	pump_tween.tween_property(pump, "position:z", -0.22, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Uzi Üst Kurma Mandalı Mekanizma Hareketi (Rapid Cycling Knob)
func _animate_uzi_recoil() -> void:
	if not model_uzi:
		return
	var knob = model_uzi.get_node_or_null("CockingKnob")
	if not knob:
		return
	if uzi_tween and uzi_tween.is_valid():
		uzi_tween.kill()
	
	uzi_tween = create_tween()
	uzi_tween.tween_property(knob, "position:z", 0.02, 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	uzi_tween.tween_property(knob, "position:z", -0.02, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Roketatar Fırlatma ve Yeniden Doldurma Animasyonu (RPG-7 Rocket Launch)
func _animate_rocket_launch() -> void:
	if not model_rocket:
		return
	var warhead = model_rocket.get_node_or_null("Warhead")
	if not warhead:
		return
	# Roket namludan fırlar, başlık kaybolur
	warhead.visible = false
	var remaining = weapon_ammo_dict.get("rocket", 0)
	if remaining > 0:
		var reload_time = 0.70 / stat_firerate_mult
		get_tree().create_timer(reload_time).timeout.connect(func():
			if is_instance_valid(warhead) and current_weapon == "rocket":
				warhead.visible = true
		)

@rpc("call_local", "unreliable")
func _show_muzzle_flash() -> void:
	var flash = _get_current_muzzle_flash()
	if not flash or not is_inside_tree():
		return
	flash.visible = true
	# Ağdaki diğer istemciler için silah animasyonunu tetikle
	if not is_multiplayer_authority():
		match current_weapon:
			"pistol": _animate_slide_recoil()
			"shotgun": _animate_shotgun_pump()
			"uzi": _animate_uzi_recoil()
			"rocket": _animate_rocket_launch()
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(flash):
		flash.visible = false

@rpc("call_local", "unreliable")
func _spawn_hit_effect(pos: Vector3, normal: Vector3) -> void:
	var hit_scene = load(HIT_EFFECT_PATH)
	if hit_scene:
		var effect = hit_scene.instantiate()
		get_parent().add_child(effect)
		effect.global_position = pos
		if normal != Vector3.ZERO:
			var up_vec = Vector3.UP
			if abs(normal.dot(Vector3.UP)) > 0.98:
				up_vec = Vector3.RIGHT
			effect.look_at(pos + normal, up_vec)

static var hurt_material: StandardMaterial3D = null

static func _get_hurt_material() -> StandardMaterial3D:
	if hurt_material == null:
		hurt_material = StandardMaterial3D.new()
		hurt_material.albedo_color = Color(1.0, 0.15, 0.15, 1.0)
		hurt_material.emission_enabled = true
		hurt_material.emission = Color(1.0, 0.1, 0.1, 1.0)
		hurt_material.emission_energy_multiplier = 2.0
	return hurt_material

func _flash_mesh_red() -> void:
	if body_mesh:
		body_mesh.material_override = _get_hurt_material()
	if head_mesh:
		head_mesh.material_override = _get_hurt_material()
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self):
		if body_mesh and body_mesh.material_override == _get_hurt_material():
			body_mesh.material_override = null
		if head_mesh and head_mesh.material_override == _get_hurt_material():
			head_mesh.material_override = null

func take_damage(amount: float, _is_headshot: bool = false, _hit_point: Vector3 = Vector3.ZERO, _attacker_id: int = 1) -> void:
	if is_dead:
		return
	if not multiplayer.is_server():
		_request_player_damage.rpc_id(1, amount)
		return
	_apply_player_damage.rpc(amount)

@rpc("any_peer", "reliable")
func _request_player_damage(amount: float) -> void:
	if multiplayer.is_server():
		take_damage(amount)

@rpc("any_peer", "call_local", "reliable")
func _apply_player_damage(amount: float) -> void:
	if is_dead:
		return
	
	# Hasar azaltma (Survival perk)
	var reduction = ProgressionManager.get_stat("damage_reduction", 0.0)
	if is_last_stand_active:
		reduction = max(reduction, 0.30)
	var final_amount = amount * (1.0 - reduction)
	
	current_health = clamp(current_health - final_amount, 0, max_health)
	
	# Son Direniş (Last Stand perk) kontrolü
	if ProgressionManager.has_perk("last_stand_unlocked") and current_health > 0 and (current_health / max_health) <= 0.25:
		if not is_last_stand_active:
			is_last_stand_active = true
			last_stand_timer = 5.0
			if is_multiplayer_authority():
				_show_weapon_notice("⚡ SON DİRENİŞ AKTİF! (%30 ZIRH + %25 HASAR)")
				SoundManager.play_sfx("switch")

	_update_hud()
	_play_damage_effect(amount)
	if current_health <= 0 and not is_dead:
		die()
		if multiplayer.is_server():
			die.rpc()

func set_dash_enabled(enabled: bool, cd: float = 1.8) -> void:
	is_dash_unlocked = enabled
	dash_cooldown = cd

func _phantom_dash_blast() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and not e.get("is_dead") and global_position.distance_to(e.global_position) < 3.2:
			if e.has_method("take_damage"):
				e.take_damage(30.0, false, global_position)

func record_kill(is_headshot: bool = false) -> void:
	kill_count += 1
	if is_headshot:
		headshot_count += 1
	
	# Biyolojik Şifa (Kill Heal perk)
	var heal_amt = ProgressionManager.get_stat("kill_heal", 0.0)
	if heal_amt > 0 and current_health > 0:
		current_health = min(max_health, current_health + heal_amt)
		if is_multiplayer_authority():
			_update_hud()
			health_changed.emit(current_health)
	
	# Yıkım Uzmanı perk: Patlama / öldürmede ücretsiz varil şansı
	if ProgressionManager.has_perk("demolitionist_drop_unlocked") and randf() < 0.20:
		barrel_count += 1
		if is_multiplayer_authority():
			_update_barrel_hud()
			_show_weapon_notice("💥 YIKIM BONUSU: +1 Ücretsiz Varil!")
	
	# Ulti şarjına katkı
	if spell_manager and spell_manager.has_method("add_ultimate_charge"):
		var ult_mult = ProgressionManager.get_stat("ult_charge_mult", 1.0)
		spell_manager.add_ultimate_charge(2.5 * ult_mult)
	
	_register_kill_streak()
	if is_multiplayer_authority():
		sync_player_stats.rpc(gold, kill_count, headshot_count)

func _play_damage_effect(amount: float) -> void:
	_flash_mesh_red()
	
	if not is_multiplayer_authority():
		return
	
	# Kamera sarsıntısı ve travma
	camera_trauma = clamp(camera_trauma + (amount / 28.0), 0.35, 1.0)
	head.rotation_degrees.x += randf_range(-1.8, -0.6)
	camera.rotation_degrees.z += randf_range(-3.5, 3.5)
	
	# Ekran Kırmızı Flaş Efekti
	if damage_flash:
		damage_flash.color = Color(0.95, 0.08, 0.08, clamp(0.25 + (amount / 40.0) * 0.25, 0.25, 0.55))
		var flash_tween = create_tween()
		flash_tween.tween_property(damage_flash, "color:a", 0.0, 0.18)
	
	# Ekran Kan / Vignette Efekti
	if damage_vignette:
		var target_alpha = clamp(0.5 + (amount / 40.0) * 0.45, 0.5, 0.95)
		damage_vignette.modulate.a = target_alpha
		if hurt_tween and hurt_tween.is_valid():
			hurt_tween.kill()
		hurt_tween = create_tween()
		hurt_tween.tween_property(damage_vignette, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func heal(amount: float) -> void:
	if is_dead:
		return
	if not multiplayer.is_server():
		return
	_apply_heal.rpc(amount)

@rpc("any_peer", "call_local", "reliable")
func _apply_heal(amount: float) -> void:
	if is_dead:
		return
	current_health = clamp(current_health + amount, 0, max_health)
	_update_hud()

@rpc("any_peer", "call_local", "reliable")
func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0
	velocity = Vector3.ZERO
	
	combo_multiplier = 1
	combo_timer = 0.0
	_update_combo_hud()
	_reset_revive_state()
	
	# Cesedin yerde durması ve takım arkadaşının yanına gelip etkileşime girebilmesi için
	collision_layer = 2
	collision_mask = 1
	gun.visible = false
	
	# Karakterin 3D modelini yere devir (Boxhead ceset yerde kalır)
	if body_mesh:
		body_mesh.position = Vector3(0, 0.2, 0)
		body_mesh.rotation_degrees = Vector3(0, 0, 85)
	if head:
		head.position = Vector3(0.35, 0.2, 0)
		head.rotation_degrees = Vector3(0, 0, 85)
	
	if name_label:
		name_label.text = "💀 " + player_name + "\n[E] Canlandır (10 sn)"
		name_label.modulate = Color(1.0, 0.35, 0.35)
	
	# Küp parçalanma efekti doğur
	var gibs_scene = load(GIBS_SCENE_PATH)
	if gibs_scene:
		var gibs = gibs_scene.instantiate()
		gibs.position = global_position
		get_tree().current_scene.add_child(gibs)
	
	player_died.emit()
	
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var living_teammates = _get_living_teammates()
		if living_teammates.is_empty():
			all_players_dead = true
			var cam_tween = create_tween().set_parallel(true)
			cam_tween.tween_property(camera, "position:y", -0.5, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			cam_tween.tween_property(camera, "rotation_degrees:z", 40.0, 0.4)
			_update_spectator_hud()
		else:
			all_players_dead = false
			_start_spectating()

func _die() -> void:
	die()

func _get_living_teammates() -> Array[CharacterBody3D]:
	var list: Array[CharacterBody3D] = []
	var all_nodes: Array = get_tree().get_nodes_in_group("players")
	var p_container = get_tree().current_scene.find_child("Players", true, false)
	if p_container:
		for c in p_container.get_children():
			if c is CharacterBody3D and not all_nodes.has(c):
				all_nodes.append(c)
				
	for p in all_nodes:
		if is_instance_valid(p) and p != self:
			var p_dead = p.get("is_dead")
			var p_hp = p.get("current_health")
			if not p_dead and (p_hp == null or float(p_hp) > 0):
				list.append(p)
	return list

func _start_spectating() -> void:
	if not is_multiplayer_authority():
		return
	var living = _get_living_teammates()
	if living.is_empty():
		all_players_dead = true
		spectator_target = null
		_update_spectator_hud()
		return
	
	if spectator_target == null or not is_instance_valid(spectator_target) or spectator_target.get("is_dead"):
		spectator_target = living[0]
	
	camera.top_level = true
	camera.current = true
	if spectator_target and is_instance_valid(spectator_target):
		camera.global_position = spectator_target.global_position + Vector3(0, 2.2, 0) - spectator_target.transform.basis.z * 3.2
		camera.look_at(spectator_target.global_position + Vector3(0, 1.2, 0), Vector3.UP)
	_update_spectator_hud()

func _cycle_spectator_target(direction: int = 1) -> void:
	if not is_multiplayer_authority() or all_players_dead:
		return
	var living = _get_living_teammates()
	if living.is_empty():
		spectator_target = null
		all_players_dead = true
		_update_spectator_hud()
		return
	
	var current_index = -1
	if spectator_target and is_instance_valid(spectator_target):
		current_index = living.find(spectator_target)
	
	if current_index == -1:
		spectator_target = living[0]
	else:
		var next_index = (current_index + direction) % living.size()
		if next_index < 0:
			next_index = living.size() - 1
		spectator_target = living[next_index]
	
	if spectator_target and is_instance_valid(spectator_target):
		camera.global_position = spectator_target.global_position + Vector3(0, 2.2, 0) - spectator_target.transform.basis.z * 3.2
		camera.look_at(spectator_target.global_position + Vector3(0, 1.2, 0), Vector3.UP)
	
	_update_spectator_hud()

func toggle_death_ui() -> void:
	if not is_multiplayer_authority() or not is_dead:
		return
	is_death_ui_hidden = not is_death_ui_hidden
	_apply_death_ui_visibility()

func _apply_death_ui_visibility() -> void:
	if not death_screen:
		return
	var center = death_screen.get_node_or_null("CenterContainer")
	var backdrop = death_screen.get_node_or_null("Backdrop")
	
	if is_death_ui_hidden:
		if center: center.visible = false
		if backdrop: backdrop.visible = false
		if floating_show_ui_btn: floating_show_ui_btn.visible = true
	else:
		if center: center.visible = true
		if backdrop: backdrop.visible = true
		if floating_show_ui_btn: floating_show_ui_btn.visible = false

func set_all_players_dead() -> void:
	all_players_dead = true
	spectator_target = null
	if is_multiplayer_authority():
		_update_spectator_hud()

func _update_spectator_hud() -> void:
	if not is_multiplayer_authority() or not death_screen:
		return
	
	death_screen.visible = true
	_apply_death_ui_visibility()
	var backdrop = death_screen.get_node_or_null("Backdrop")
	
	if all_players_dead or _get_living_teammates().is_empty():
		if backdrop:
			backdrop.color = Color(0.06, 0.01, 0.01, 0.88)
		if death_title_label:
			death_title_label.text = "OYUN BİTTİ"
		if death_reason_label:
			death_reason_label.text = "Tüm takım alt edildi!"
		if death_info_label:
			if multiplayer.is_server():
				death_info_label.text = "[R] veya [Boşluk] tuşuna basarak mevcut seviyeyi yeniden başlatın."
			else:
				death_info_label.text = "Oda sahibinin seviyeyi yeniden başlatması bekleniyor..."
		if restart_btn:
			restart_btn.visible = multiplayer.is_server()
			restart_btn.disabled = not multiplayer.is_server()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Takım arkadaşları hayatta: İzleyici ekranı (arkası görünür, yarı saydam)
		if backdrop:
			backdrop.color = Color(0.0, 0.0, 0.0, 0.25)
		if death_title_label:
			death_title_label.text = "👁 İZLEYİCİ MODU"
		if death_reason_label:
			death_reason_label.text = "Takım arkadaşların savaşıyor! Asansöre ulaşıldığında canlanacaksın."
		if death_info_label:
			var target_name = spectator_target.player_name if (spectator_target and is_instance_valid(spectator_target)) else "Takım Arkadaşı"
			death_info_label.text = "İzlenen: " + target_name + "  |  [Sol/Sağ Tık / Boşluk] Oyuncu Değiştir\n[H] Arayüzü Gizle  |  (Arkadaşın 10 sn [E] ile seni kaldırabilir)"
		if restart_btn:
			restart_btn.visible = false
			restart_btn.disabled = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# --- Canlandırma (Revive) Etkileşimi ---

func is_targeting_downed_teammate() -> bool:
	return current_reviving_target != null

func _handle_revive_interaction(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead or is_in_shop or is_in_skill_tree or (pause_menu and pause_menu.visible):
		_reset_revive_state()
		return
	
	# Yakındaki ölü takım arkadaşlarını tara (3.2 metre mesafe)
	var nearest_downed: CharacterBody3D = null
	var min_dist: float = REVIVE_MAX_DISTANCE
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and p != self and p.get("is_dead"):
			var d = global_position.distance_to(p.global_position)
			if d < min_dist:
				# Oyuncunun baktığı yönde mi kontrolü
				var forward = -camera.global_transform.basis.z
				var dir_to_p = (p.global_position - camera.global_position).normalized()
				if forward.dot(dir_to_p) > 0.35:
					min_dist = d
					nearest_downed = p
	
	if nearest_downed:
		current_reviving_target = nearest_downed
		if revive_box:
			revive_box.visible = true
		
		# E tuşu basılı tutuluyor mu?
		if Input.is_key_pressed(KEY_E) or Input.is_action_pressed("spell_tactical"):
			revive_progress_timer += delta
			var pct = clamp((revive_progress_timer / REVIVE_REQUIRED_TIME) * 100.0, 0.0, 100.0)
			if revive_bar:
				revive_bar.value = pct
			if revive_label:
				var rem_sec = max(0.0, REVIVE_REQUIRED_TIME - revive_progress_timer)
				revive_label.text = "❤️ " + nearest_downed.player_name + " CANLANDIRILIYOR... %" + str(int(pct)) + " (" + str(snapped(rem_sec, 0.1)) + " sn)"
				revive_label.modulate = Color(0.2, 1.0, 0.4)
			
			# Canlandırılan oyuncunun ekranında göster
			if nearest_downed.has_method("notify_being_revived"):
				nearest_downed.notify_being_revived.rpc(player_name, pct)
			
			# 10 saniye dolduysa CANLANDIR!
			if revive_progress_timer >= REVIVE_REQUIRED_TIME:
				print("[Canlandırma] ", nearest_downed.player_name, " başarıyla canlandırıldı!")
				_complete_revive(nearest_downed)
				_reset_revive_state()
		else:
			# Tuşa basılmıyorken sadece ipucu göster
			revive_progress_timer = 0.0
			if revive_bar:
				revive_bar.value = 0.0
			if revive_label:
				revive_label.text = "❤️ [E'YE BASILI TUT] " + nearest_downed.player_name + " Canlandır (10 sn)"
				revive_label.modulate = Color(1.0, 0.9, 0.3)
	else:
		_reset_revive_state()

func _reset_revive_state() -> void:
	current_reviving_target = null
	revive_progress_timer = 0.0
	if revive_box:
		revive_box.visible = false

func _complete_revive(target_player: CharacterBody3D) -> void:
	if not is_instance_valid(target_player):
		return
	var t_pos = target_player.global_position
	# Sunucudan veya yetkiden revive RPC'sini çağır
	target_player.revive.rpc(50.0, t_pos)
	SoundManager.play_sfx("pickup")
	_show_weapon_notice("💚 " + target_player.player_name.to_upper() + " CANLANDIRILDI!")

@rpc("any_peer", "call_local", "reliable")
func notify_being_revived(reviver_name: String, percent: float) -> void:
	if is_multiplayer_authority() and is_dead and death_info_label:
		death_info_label.text = "💚 " + reviver_name + " seni canlandırıyor! %" + str(int(percent))

@rpc("any_peer", "call_local", "reliable")
func revive(health_amount: float = 50.0, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	is_dead = false
	all_players_dead = false
	spectator_target = null
	is_death_ui_hidden = false
	_apply_death_ui_visibility()
	current_health = health_amount
	collision_layer = 2
	collision_mask = 5
	_reset_revive_state()
	
	if spawn_pos != Vector3.ZERO:
		global_position = spawn_pos
		velocity = Vector3.ZERO
	
	if body_mesh:
		body_mesh.position = Vector3(0, 0.65, 0)
		body_mesh.rotation = Vector3.ZERO
	if head:
		head.position = Vector3(0, 1.45, 0)
		head.rotation = Vector3.ZERO
	
	if name_label:
		name_label.text = player_name
		name_label.modulate = Color.WHITE
	gun.visible = true
	_update_gun_visuals()
	
	if is_multiplayer_authority():
		camera.top_level = false
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.current = true
		if death_screen:
			death_screen.visible = false
		if pause_menu:
			pause_menu.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_update_hud()

@rpc("any_peer", "call_local", "reliable")
func teleport_to(target_pos: Vector3) -> void:
	global_position = target_pos
	velocity = Vector3.ZERO
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if camera:
			camera.top_level = false
			camera.position = Vector3.ZERO
			camera.rotation = Vector3.ZERO
			camera.current = true
		if pause_menu:
			pause_menu.visible = false
		if death_screen:
			death_screen.visible = false
		_update_hud()

@rpc("any_peer", "call_local", "reliable")
func reset_to_default_loadout(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	is_dead = false
	all_players_dead = false
	spectator_target = null
	is_death_ui_hidden = false
	_apply_death_ui_visibility()
	current_health = max_health
	collision_layer = 2
	collision_mask = 5
	
	combo_multiplier = 1
	combo_timer = 0.0
	fire_timer = 0.0
	kick_timer = 0.0
	barrel_count = 3
	wall_count = max_wall_count
	wall_regen_timer = 0.0
	_update_wall_hud()
	_reset_revive_state()
	
	# Varsayılan başlangıç tabancası ve mühimmatı
	current_weapon = "pistol"
	weapon_inventory = ["pistol"]
	current_weapon_index = 0
	weapon_ammo_dict = {
		"pistol": -1,
		"uzi": 0,
		"bixi": 0,
		"shotgun": 0,
		"rocket": 0
	}
	
	if spawn_pos != Vector3.ZERO:
		global_position = spawn_pos
		velocity = Vector3.ZERO
	
	if body_mesh:
		body_mesh.position = Vector3(0, 0.65, 0)
		body_mesh.rotation = Vector3.ZERO
	if head:
		head.position = Vector3(0, 1.45, 0)
		head.rotation = Vector3.ZERO
	
	if name_label:
		name_label.text = player_name
		name_label.modulate = Color.WHITE
	gun.visible = true
	_update_gun_visuals()
	
	if spell_manager:
		spell_manager.setup(self, player_class)
	
	if is_multiplayer_authority():
		camera.top_level = false
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.current = true
		if death_screen:
			death_screen.visible = false
		if pause_menu:
			pause_menu.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_update_hud()

func _on_restart_pressed() -> void:
	if not is_multiplayer_authority():
		return
	# Yaşayan takım arkadaşı varken kazara baştan başlatmayı engelle
	if not all_players_dead and not _get_living_teammates().is_empty():
		_show_weapon_notice("Takım arkadaşların hayatta! İzleyici modunda bekle.")
		return
	# Sadece sunucu (veya tüm takım elendiğinde client) yeniden başlatabilir
	if not multiplayer.is_server() and not all_players_dead:
		_show_weapon_notice("Yalnızca oda sahibi oyunu baştan başlatabilir!")
		return
	
	var main_level = get_tree().get_first_node_in_group("main_level")
	if not main_level:
		main_level = get_tree().current_scene
	if not main_level or not main_level.has_method("request_restart"):
		main_level = get_node_or_null("/root/MainLevel")

	if main_level and main_level.has_method("request_restart"):
		main_level.request_restart()
	else:
		push_error("[FPSController] MainLevel düğümü bulunamadı!")

func _on_lobby_pressed() -> void:
	if not is_multiplayer_authority():
		return
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if multiplayer.is_server():
			# Yalnızca oda kurucusu (host) tüm takımı lobiye geri çekebilir
			NetworkManager.return_to_lobby()
			return
		else:
			# Normal oyuncu ayrıldığında diğer oyuncuları oyundan çekmez, yalnızca kendisi çıkar
			NetworkManager.disconnect_game()
			get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")
			return
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")

# --- Duraklatma Menüsü (Pause Menu) ---

func _open_pause_menu() -> void:
	if not is_multiplayer_authority() or not pause_menu:
		return
	if pause_nav:
		pause_nav.visible = true
	if pause_settings:
		pause_settings.visible = false
	_sync_pause_settings_ui()
	pause_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_pause_menu() -> void:
	if not is_multiplayer_authority() or not pause_menu:
		return
	pause_menu.visible = false
	if not is_in_shop and not is_in_skill_tree and not is_dead and not (scoreboard and scoreboard.visible):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_pause_resume_pressed() -> void:
	_close_pause_menu()

func _on_pause_settings_pressed() -> void:
	if pause_nav:
		pause_nav.visible = false
	if pause_settings:
		pause_settings.visible = true
	_sync_pause_settings_ui()

func _on_pause_back_from_settings_pressed() -> void:
	if pause_settings:
		pause_settings.visible = false
	if pause_nav:
		pause_nav.visible = true

func _sync_pause_settings_ui() -> void:
	if not SettingsManager:
		return
	if pause_window_mode:
		for idx in range(pause_window_mode.item_count):
			if pause_window_mode.get_item_id(idx) == SettingsManager.current_window_mode:
				pause_window_mode.selected = idx
				break
	if pause_vsync_check:
		pause_vsync_check.set_pressed_no_signal(SettingsManager.vsync_enabled)
	if pause_volume_slider:
		pause_volume_slider.set_value_no_signal(SettingsManager.master_volume * 100.0)
	if pause_volume_label:
		pause_volume_label.text = "ANA SES (%%%d)" % int(SettingsManager.master_volume * 100.0)
	if pause_sens_slider:
		pause_sens_slider.set_value_no_signal(SettingsManager.mouse_sensitivity)
	if pause_sens_label:
		pause_sens_label.text = "FARE HASSASİYETİ (%.4f)" % SettingsManager.mouse_sensitivity

func _on_pause_window_mode_selected(index: int) -> void:
	if not pause_window_mode or not SettingsManager:
		return
	var mode_id = pause_window_mode.get_item_id(index)
	SettingsManager.set_window_mode(mode_id)

func _on_pause_vsync_toggled(toggled_on: bool) -> void:
	if SettingsManager:
		SettingsManager.set_vsync(toggled_on)

func _on_pause_volume_changed(val: float) -> void:
	if SettingsManager:
		SettingsManager.set_master_volume(val / 100.0)
	if pause_volume_label:
		pause_volume_label.text = "ANA SES (%%%d)" % int(val)

func _on_pause_sens_changed(val: float) -> void:
	if SettingsManager:
		SettingsManager.set_mouse_sensitivity(val)
		mouse_sensitivity = val
	if pause_sens_label:
		pause_sens_label.text = "FARE HASSASİYETİ (%.4f)" % val

func _on_pause_quit_pressed() -> void:
	get_tree().quit()

# --- Skor Tablosu (Scoreboard) ---

func _set_scoreboard_visible(visible_state: bool) -> void:
	if not is_multiplayer_authority() or not scoreboard:
		return
	scoreboard.visible = visible_state
	if visible_state:
		_refresh_scoreboard()

func _refresh_scoreboard() -> void:
	if not scoreboard_list:
		return
	for child in scoreboard_list.get_children():
		child.queue_free()
	
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if not is_instance_valid(p):
			continue
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		
		# İsim
		var lbl_name = Label.new()
		lbl_name.custom_minimum_size = Vector2(160, 0)
		var p_display = p.player_name
		if p == self:
			p_display += " (Sen)"
		lbl_name.text = p_display
		if p == self:
			lbl_name.modulate = Color(1.0, 0.85, 0.3)
		row.add_child(lbl_name)
		
		# Sınıf
		var lbl_cls = Label.new()
		lbl_cls.custom_minimum_size = Vector2(110, 0)
		match p.player_class:
			"Pyromancer": lbl_cls.text = "BÜYÜCÜ"
			"Builder": lbl_cls.text = "DUVARCI"
			"Engineer": lbl_cls.text = "MÜHENDİS"
			"Cryomancer": lbl_cls.text = "BUZCU"
			"Medic": lbl_cls.text = "SIHHİYE"
			_: lbl_cls.text = p.player_class.to_upper()
		row.add_child(lbl_cls)
		
		# Leş
		var lbl_kills = Label.new()
		lbl_kills.custom_minimum_size = Vector2(70, 0)
		lbl_kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_kills.text = str(p.kill_count)
		row.add_child(lbl_kills)
		
		# Kafadan Vuruş
		var lbl_hs = Label.new()
		lbl_hs.custom_minimum_size = Vector2(80, 0)
		lbl_hs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_hs.text = str(p.headshot_count)
		row.add_child(lbl_hs)
		
		# Kredi / Altın
		var lbl_gold = Label.new()
		lbl_gold.custom_minimum_size = Vector2(75, 0)
		lbl_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_gold.text = str(p.gold)
		row.add_child(lbl_gold)
		
		# Durum
		var lbl_status = Label.new()
		lbl_status.custom_minimum_size = Vector2(100, 0)
		lbl_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if p.is_dead:
			lbl_status.text = "ÖLÜ"
			lbl_status.modulate = Color(0.9, 0.2, 0.2)
		else:
			lbl_status.text = str(int(p.current_health)) + " HP"
			lbl_status.modulate = Color(0.2, 0.9, 0.3)
		row.add_child(lbl_status)
		
		scoreboard_list.add_child(row)

# --- İstatistik ve Ağ Senkronizasyonu ---

@rpc("any_peer", "call_local", "reliable")
func sync_player_stats(p_gold: int, p_kills: int = -1, p_headshots: int = -1) -> void:
	gold = p_gold
	if p_kills >= 0:
		kill_count = p_kills
	if p_headshots >= 0:
		headshot_count = p_headshots
	if is_multiplayer_authority():
		_update_hud()
