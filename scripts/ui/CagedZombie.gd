extends Node3D

# --- Menü Kafesteki Test Zombisi Animasyonu (CagedZombie) ---
@onready var head_node: Node3D = get_node_or_null("Zombie/Head")
@onready var arm_l: Node3D = get_node_or_null("Zombie/ArmL")
@onready var arm_r: Node3D = get_node_or_null("Zombie/ArmR")
@onready var beacon_light: OmniLight3D = get_node_or_null("BeaconLight")

var twitch_timer: float = 0.0
var base_head_rot: Vector3 = Vector3.ZERO

func _ready() -> void:
	if head_node:
		base_head_rot = head_node.rotation

func _process(delta: float) -> void:
	var t = Time.get_ticks_msec() * 0.003
	
	# Kafesteki zombinin huzursuzca kafasını sağa sola çevirmesi
	if head_node:
		head_node.rotation.y = base_head_rot.y + sin(t * 1.5) * deg_to_rad(20.0)
		head_node.rotation.x = base_head_rot.x + cos(t * 2.2) * deg_to_rad(8.0)
	
	# Kolların parmaklıklara doğru uzanıp titremesi
	if arm_l:
		arm_l.rotation.x = deg_to_rad(-70.0) + sin(t * 4.0) * deg_to_rad(6.0)
	if arm_r:
		arm_r.rotation.x = deg_to_rad(-75.0) + cos(t * 3.7) * deg_to_rad(7.0)
	
	# Tepe alarm lambasının hafif nabız gibi parıldaması
	if beacon_light:
		beacon_light.light_energy = 1.4 + sin(t * 3.0) * 0.6
