extends Node

var gunshot_sound: AudioStream
var footstep_sound: AudioStream
var reload_sound: AudioStream
var match_start_sound: AudioStream
var win_sound: AudioStream

const SAVE_PATH = "user://audio_settings.cfg"
var master_volume: float = 100.0
var is_muted: bool = false

func _ready():
	_load_settings()
	_generate_sounds()

func set_master_volume(vol: float):
	master_volume = clamp(vol, 0.0, 100.0)
	_apply_audio()
	_save_settings()

func set_muted(muted: bool):
	is_muted = muted
	_apply_audio()
	_save_settings()

func _apply_audio():
	var bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, is_muted)
	var db = linear_to_db(master_volume / 100.0)
	if master_volume <= 0.0: db = -80.0
	AudioServer.set_bus_volume_db(bus, db)

func _load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		master_volume = cfg.get_value("Audio", "master_volume", 100.0)
		is_muted = cfg.get_value("Audio", "is_muted", false)
	_apply_audio()

func _save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("Audio", "master_volume", master_volume)
	cfg.set_value("Audio", "is_muted", is_muted)
	cfg.save(SAVE_PATH)

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
