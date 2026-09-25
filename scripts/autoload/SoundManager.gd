extends Node

# --- Kutu Kafalar Ses Yöneticisi (SoundManager) ---
# Saf GDScript ile oluşturulan prosedürel 16-bit retro arcade ses efektleri

var sound_streams: Dictionary = {}
var player_pool: Array[AudioStreamPlayer] = []
var player_pool_index: int = 0
const POOL_SIZE: int = 16

func _ready() -> void:
	_generate_all_sounds()
	_create_player_pool()

func _create_player_pool() -> void:
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		player_pool.append(p)

## Tüm ses efektlerini saf matematiksel dalga formlarıyla üret
func _generate_all_sounds() -> void:
	var sample_rate = 22050
	var sound_names = ["pistol", "shotgun", "uzi", "rocket", "switch", "empty", "pickup"]
	
	for s_name in sound_names:
		var dur = 0.2
		if s_name == "shotgun": dur = 0.36
		elif s_name == "uzi": dur = 0.10
		elif s_name == "rocket": dur = 0.50
		elif s_name == "switch" or s_name == "empty": dur = 0.08
		
		var total_samples = int(dur * sample_rate)
		var bytes = PackedByteArray()
		bytes.resize(total_samples * 2)
		
		for i in range(total_samples):
			var t = float(i) / sample_rate
			var prog = float(i) / total_samples
			var sample = 0.0
			
			match s_name:
				"pistol":
					var env = exp(-prog * 20.0)
					var freq = lerp(580.0, 90.0, prog * prog)
					var tone = sin(t * freq * TAU)
					var noise = randf_range(-1.0, 1.0) * exp(-prog * 28.0)
					sample = (tone * 0.6 + noise * 0.4) * env
				"shotgun":
					var env = exp(-prog * 12.0)
					var freq = lerp(95.0, 42.0, prog)
					var tone = sin(t * freq * TAU)
					var noise = randf_range(-1.0, 1.0) * exp(-prog * 15.0)
					sample = (tone * 0.55 + noise * 0.6) * env
				"uzi":
					var env = exp(-prog * 28.0)
					var freq = lerp(750.0, 240.0, prog)
					var tone = sin(t * freq * TAU)
					var noise = randf_range(-1.0, 1.0) * exp(-prog * 35.0)
					sample = (tone * 0.5 + noise * 0.5) * env
				"rocket":
					var env = sin(prog * PI) * exp(-prog * 3.0)
					var tone = sin(t * 70.0 * TAU) * 0.5
					var noise = randf_range(-1.0, 1.0) * 0.5
					sample = (tone + noise) * env
				"switch":
					var env = exp(-fmod(prog * 2.0, 1.0) * 35.0)
					var tone = sin(t * 2600.0 * TAU)
					sample = tone * env * 0.6
				"empty":
					var env = exp(-prog * 45.0)
					var tone = sin(t * 3600.0 * TAU)
					sample = tone * env * 0.7
				"pickup":
					var freq = 523.25
					if prog > 0.5: freq = 783.99
					elif prog > 0.25: freq = 659.25
					var env = exp(-prog * 6.0)
					sample = sin(t * freq * TAU) * env * 0.65
			
			sample = clamp(sample, -1.0, 1.0)
			bytes.encode_s16(i * 2, int(sample * 30000.0))
		
		var wav = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = sample_rate
		wav.data = bytes
		sound_streams[s_name] = wav

## 2D / Stereo Doğrudan Ses Çalma (Yerel Oyuncu ve UI için)
func play_sfx(sfx_name: String, pitch_range: float = 0.05, volume_db: float = 0.0) -> void:
	if not sound_streams.has(sfx_name):
		return
	
	var player = player_pool[player_pool_index]
	player_pool_index = (player_pool_index + 1) % POOL_SIZE
	
	player.stream = sound_streams[sfx_name]
	player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	player.volume_db = volume_db
	player.play()

## 3D Uzamsal Ses Çalma (Ağdaki diğer oyuncuların ateş sesleri için)
func play_3d_sfx(sfx_name: String, pos: Vector3, pitch_range: float = 0.05, volume_db: float = 0.0) -> void:
	if not sound_streams.has(sfx_name):
		return
	
	var p3d = AudioStreamPlayer3D.new()
	p3d.stream = sound_streams[sfx_name]
	p3d.position = pos
	p3d.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	p3d.volume_db = volume_db
	p3d.max_distance = 35.0
	p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	get_tree().current_scene.add_child(p3d)
	p3d.play()
	
	p3d.finished.connect(func(): p3d.queue_free())

## Ses akışını doğrudan alma
func get_stream(sfx_name: String) -> AudioStreamWAV:
	return sound_streams.get(sfx_name, null)
