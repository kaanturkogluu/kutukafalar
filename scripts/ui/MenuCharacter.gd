extends Node3D
class_name MenuCharacter

# --- 3D Menü Karakteri (MenuCharacter) ---
# Taktik tim kadrosundaki Kutu Kafa karakterini, sınıf renklerini, silahını ve öne çıkma animasyonunu yönetir.

@export_enum("Pyromancer", "Engineer", "Cryomancer", "Medic") var character_class: String = "Pyromancer"
@export var is_selected: bool = false

var base_position: Vector3 = Vector3.ZERO
var base_rotation: Vector3 = Vector3.ZERO
var idle_phase_offset: float = 0.0

@onready var head_node: Node3D = $Head
@onready var head_mesh: MeshInstance3D = $Head/HeadMesh
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var vest_mesh: MeshInstance3D = $VestMesh
@onready var glasses_mesh: MeshInstance3D = $Head/GlassesMesh
@onready var weapon_mount: Node3D = $WeaponMount
@onready var spot_light: SpotLight3D = $SpotLight3D
@onready var class_label: Label3D = $ClassLabel

var step_tween: Tween = null
var current_target_z: float = 0.0

const CLASS_CONFIG: Dictionary = {
	"Pyromancer": {
		"title": "ATEŞ UZMANI",
		"body_color": Color(0.78, 0.22, 0.16),
		"accent_color": Color(1.0, 0.40, 0.20),
		"vest_color": Color(0.16, 0.14, 0.14),
		"weapon_scene": "res://scenes/weapons/rocket_model.tscn",
		"weapon_scale": Vector3(0.72, 0.72, 0.72),
		"weapon_pos": Vector3(0.24, 0.55, 0.28),
		"weapon_rot": Vector3(deg_to_rad(-10), deg_to_rad(-15), deg_to_rad(10))
	},
	"Engineer": {
		"title": "MÜHENDİS",
		"body_color": Color(0.90, 0.54, 0.12),
		"accent_color": Color(1.0, 0.75, 0.15),
		"vest_color": Color(0.22, 0.20, 0.18),
		"weapon_scene": "res://scenes/weapons/bixi_model.tscn",
		"weapon_scale": Vector3(0.68, 0.68, 0.68),
		"weapon_pos": Vector3(0.22, 0.52, 0.26),
		"weapon_rot": Vector3(deg_to_rad(-5), deg_to_rad(-18), deg_to_rad(8))
	},
	"Cryomancer": {
		"title": "BUZ MUHAFIZI",
		"body_color": Color(0.18, 0.62, 0.85),
		"accent_color": Color(0.45, 0.85, 1.0),
		"vest_color": Color(0.14, 0.18, 0.24),
		"weapon_scene": "res://scenes/weapons/uzi_model.tscn",
		"weapon_scale": Vector3(0.85, 0.85, 0.85),
		"weapon_pos": Vector3(0.20, 0.54, 0.24),
		"weapon_rot": Vector3(deg_to_rad(-12), deg_to_rad(-12), deg_to_rad(6))
	},
	"Medic": {
		"title": "SIHHİYE",
		"body_color": Color(0.18, 0.72, 0.38),
		"accent_color": Color(0.28, 0.95, 0.65),
		"vest_color": Color(0.14, 0.24, 0.16),
		"weapon_scene": "res://scenes/weapons/shotgun_model.tscn",
		"weapon_scale": Vector3(0.70, 0.70, 0.70),
		"weapon_pos": Vector3(0.22, 0.53, 0.26),
		"weapon_rot": Vector3(deg_to_rad(-8), deg_to_rad(-15), deg_to_rad(8))
	}
}

func _ready() -> void:
	base_position = position
	base_rotation = rotation
	idle_phase_offset = randf_range(0.0, TAU)
	apply_class_visuals()
	set_selected(is_selected, true)

func apply_class_visuals() -> void:
	var cfg = CLASS_CONFIG.get(character_class, CLASS_CONFIG["Pyromancer"])
	
	# Gövde materyali
	if body_mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = cfg["body_color"]
		mat.roughness = 0.5
		mat.metallic = 0.05
		body_mesh.material_override = mat
	
	# Kafa materyali
	if head_mesh:
		var head_mat = StandardMaterial3D.new()
		head_mat.albedo_color = Color(0.92, 0.76, 0.58) # Ten rengi
		head_mat.roughness = 0.6
		head_mesh.material_override = head_mat
	
	# Taktik yelek materyali
	if vest_mesh:
		var vest_mat = StandardMaterial3D.new()
		vest_mat.albedo_color = cfg["vest_color"]
		vest_mat.roughness = 0.7
		vest_mesh.material_override = vest_mat
	
	# Gözlük / Vizör / Bandana
	if glasses_mesh:
		var glass_mat = StandardMaterial3D.new()
		glass_mat.albedo_color = cfg["accent_color"]
		glass_mat.roughness = 0.2
		glass_mat.emission_enabled = true
		glass_mat.emission = cfg["accent_color"]
		glass_mat.emission_energy_multiplier = 0.8
		glasses_mesh.material_override = glass_mat
	
	# Başlık etiketi
	if class_label:
		class_label.text = cfg["title"]
		class_label.modulate = cfg["accent_color"]
	
	# Silahın yüklenmesi
	if weapon_mount:
		for child in weapon_mount.get_children():
			child.queue_free()
		
		var w_scene_path: String = cfg["weapon_scene"]
		if ResourceLoader.exists(w_scene_path):
			var w_res = load(w_scene_path)
			if w_res:
				var w_inst = w_res.instantiate()
				weapon_mount.add_child(w_inst)
				w_inst.scale = cfg["weapon_scale"]
				w_inst.position = cfg["weapon_pos"]
				w_inst.rotation = cfg["weapon_rot"]
				
				# Menüde namlu alevlerini kapalı tut
				if w_inst.has_node("MuzzleFlash"):
					w_inst.get_node("MuzzleFlash").visible = false

func set_selected(selected: bool, instant: bool = false) -> void:
	is_selected = selected
	var target_z = base_position.z + (0.65 if is_selected else 0.0)
	var target_scale = Vector3(1.06, 1.06, 1.06) if is_selected else Vector3(0.94, 0.94, 0.94)
	var target_light_energy = 1.1 if is_selected else 0.35
	var label_alpha = 1.0 if is_selected else 0.45
	
	if instant:
		position.z = target_z
		scale = target_scale
		if spot_light:
			spot_light.light_energy = target_light_energy
		if class_label:
			class_label.modulate.a = label_alpha
		return
	
	if step_tween and step_tween.is_valid():
		step_tween.kill()
	
	step_tween = create_tween().set_parallel(true)
	step_tween.tween_property(self, "position:z", target_z, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	step_tween.tween_property(self, "scale", target_scale, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if spot_light:
		step_tween.tween_property(spot_light, "light_energy", target_light_energy, 0.3)
	if class_label:
		step_tween.tween_property(class_label, "modulate:a", label_alpha, 0.25)

func _process(_delta: float) -> void:
	var t = Time.get_ticks_msec() * 0.002 + idle_phase_offset
	# Yaşayan hafif nefes alma ve ağırlık transferi hareketi
	var bob_y = sin(t) * 0.015
	var sway_z = cos(t * 0.7) * 0.008
	
	position.y = base_position.y + bob_y
	if not is_selected:
		position.x = base_position.x + sway_z

## Fare imlecini takip eden kafa hareketi
func update_cursor_look(normalized_mouse: Vector2) -> void:
	if not head_node:
		return
	if is_selected:
		# İmlece doğru yumuşak kafa çevirme (-20 ile +20 derece yatay, -15 ile +15 dikey)
		var target_rot_y = -normalized_mouse.x * deg_to_rad(24.0)
		var target_rot_x = -normalized_mouse.y * deg_to_rad(16.0)
		head_node.rotation.y = lerp_angle(head_node.rotation.y, target_rot_y, 0.12)
		head_node.rotation.x = lerp_angle(head_node.rotation.x, target_rot_x, 0.12)
	else:
		# Seçili değilse hafifçe merkeze ve öne doğru bak
		head_node.rotation.y = lerp_angle(head_node.rotation.y, 0.0, 0.08)
		head_node.rotation.x = lerp_angle(head_node.rotation.x, 0.0, 0.08)
