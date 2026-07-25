extends Node

var gunshot_sound: AudioStream
var footstep_sound: AudioStream
var reload_sound: AudioStream
var match_start_sound: AudioStream
var win_sound: AudioStream

func _ready():
	_generate_sounds()

func _generate_sounds():
	# Generate procedural footstep (short noise burst)
	footstep_sound = _create_noise_burst(0.05, 4000, 1.0)
	
	# Generate reload (series of clicks)
	reload_sound = _create_clicks()
	
	# Generate match start (sine wave chime)
	match_start_sound = _create_chime(440.0, 0.5)
	
	# Generate win (happy chime)
	win_sound = _create_chime(880.0, 1.0)
	
	gunshot_sound = load("res://Assets/audio/gunshot.wav")
	if not gunshot_sound:
		gunshot_sound = _create_noise_burst(0.2, 8000, 2.0)

func _create_noise_burst(duration: float, freq: float, volume: float) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	
	var length = int(44100 * duration)
	var data = PackedByteArray()
	data.resize(length * 2)
	
	for i in range(length):
		var env = 1.0 - (float(i) / float(length))
		# White noise
		var sample = randf_range(-1.0, 1.0) * env * volume * 32767.0
		var val = int(clamp(sample, -32768, 32767))
		data.encode_s16(i * 2, val)
		
	stream.data = data
	return stream

func _create_clicks() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	
	var length = int(44100 * 0.3)
	var data = PackedByteArray()
	data.resize(length * 2)
	
	for i in range(length):
		var t = float(i) / 44100.0
		var val = 0
		if fmod(t, 0.1) < 0.01:
			val = int(randf_range(-1.0, 1.0) * 10000.0)
		data.encode_s16(i * 2, val)
		
	stream.data = data
	return stream

func _create_chime(freq: float, duration: float) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	
	var length = int(44100 * duration)
	var data = PackedByteArray()
	data.resize(length * 2)
	
	for i in range(length):
		var t = float(i) / 44100.0
		var env = 1.0 - (t / duration)
		var sample = sin(t * freq * TAU) * env * 15000.0
		data.encode_s16(i * 2, int(sample))
		
	stream.data = data
	return stream

func play_2d(stream: AudioStream):
	var player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
