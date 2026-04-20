extends Node

var rat_player: AudioStreamPlayer
var pickup_player: AudioStreamPlayer
var combo_player: AudioStreamPlayer

func _ready() -> void:
	rat_player = AudioStreamPlayer.new()
	rat_player.volume_db = -8.0
	add_child(rat_player)
	
	pickup_player = AudioStreamPlayer.new()
	pickup_player.volume_db = -6.0
	add_child(pickup_player)
	
	combo_player = AudioStreamPlayer.new()
	combo_player.volume_db = -4.0
	add_child(combo_player)

func _build_wav(freq: float, length_ms: int, sweep: float = 0.0) -> AudioStreamWAV:
	var s = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_8_BITS
	s.mix_rate = 22050
	s.stereo = false
	var samples = int((length_ms / 1000.0) * 22050.0)
	var d = PackedByteArray()
	var current_freq = freq
	var t = 0.0
	for i in range(samples):
		var v = int(sin(t * TAU) * 90.0)
		# Convert to 8-bit unsigned
		var b = clampi(v + 128, 0, 255)
		d.append(b)
		current_freq += sweep
		t += current_freq / 22050.0
	s.data = d
	return s

func play_rat() -> void:
	rat_player.stream = _build_wav(300.0, 120, -1.0)
	rat_player.play()

func play_pickup() -> void:
	pickup_player.stream = _build_wav(700.0, 150, 0.5)
	pickup_player.play()

func play_combo() -> void:
	combo_player.stream = _build_wav(1100.0, 250, 1.0)
	combo_player.play()
