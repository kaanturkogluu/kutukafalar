extends Node3D
class_name SquadBackground3D

# --- 3D Taktik Tim Sahnesi (SquadBackground3D) ---
# Ana menüde 4 kişilik taktik ekibi sergiler, sınıf seçiminde öne çıkma ve fare takip animasyonunu yönetir.

@onready var char_pyro: MenuCharacter = $Characters/Pyromancer
@onready var char_eng: MenuCharacter = $Characters/Engineer
@onready var char_cryo: MenuCharacter = $Characters/Cryomancer
@onready var char_medic: MenuCharacter = $Characters/Medic
@onready var camera: Camera3D = $Camera3D

var characters: Dictionary = {}
var current_selected_class: String = "Pyromancer"
var camera_base_pos: Vector3 = Vector3(0, 1.15, 3.8)

func _ready() -> void:
	characters = {
		"Pyromancer": char_pyro,
		"Engineer": char_eng,
		"Cryomancer": char_cryo,
		"Medic": char_medic
	}
	if camera:
		camera_base_pos = camera.position
	select_class(current_selected_class, true)

func select_class(c_name: String, instant: bool = false) -> void:
	current_selected_class = c_name
	for c_key in characters:
		var c_node: MenuCharacter = characters[c_key]
		if c_node:
			c_node.set_selected(c_key == current_selected_class, instant)

func update_cursor(mouse_pos: Vector2, viewport_size: Vector2) -> void:
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var norm = (mouse_pos / viewport_size) * 2.0 - Vector2.ONE
	for c_key in characters:
		var c_node: MenuCharacter = characters[c_key]
		if c_node:
			c_node.update_cursor_look(norm)
	
	# Sinematik yumuşak kamera paralaksı
	if camera:
		var target_cam_x = camera_base_pos.x + norm.x * 0.15
		var target_cam_y = camera_base_pos.y - norm.y * 0.10
		camera.position.x = lerp(camera.position.x, target_cam_x, 0.05)
		camera.position.y = lerp(camera.position.y, target_cam_y, 0.05)
