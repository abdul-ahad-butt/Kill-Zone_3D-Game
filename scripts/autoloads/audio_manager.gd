extends Node

var gunshot_sound: AudioStream
var footstep_sound: AudioStream
var reload_sound: AudioStream
var match_start_sound: AudioStream
var win_sound: AudioStream
var thunder_sound: AudioStream
var button_sound: AudioStream
var ambient_wind: AudioStream

const SAVE_PATH = "user://audio_settings.cfg"
var master_volume: float = 100.0
var is_muted: bool = false

func _ready():
	_setup_buses()
	_load_settings()
	_generate_sounds()
	_setup_audio_effects()
	play_ambient()

func _setup_buses():
	for bus_name in ["SFX", "Music", "Ambient", "UI", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

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

func _setup_audio_effects():
	var bus = AudioServer.get_bus_index("Master")
	# Add Reverb
	var reverb = AudioEffectReverb.new()
	reverb.room_size = 0.3
	reverb.damping = 0.5
	reverb.wet = 0.1
	AudioServer.add_bus_effect(bus, reverb)
	
	# Add EQ for punchier bass and clearer highs
	var eq = AudioEffectEQ.new()
	eq.set_band_gain(0, 3.0) # Bass boost
	eq.set_band_gain(5, 2.0) # High boost
	AudioServer.add_bus_effect(bus, eq)

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
	
	# Generate thunder (long low frequency noise burst)
	thunder_sound = _create_noise_burst(3.0, 1500, 3.0)
	
	# UI button sound
	button_sound = _create_clicks() # Using clicks for now
	
	# Ambient wind
	ambient_wind = _create_noise_burst(10.0, 2000, 0.3)
	
	gunshot_sound = load("res://Assets/audio/gunshot.wav")
	if not gunshot_sound:
		gunshot_sound = _create_gunshot()

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

func _create_gunshot() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	var length = int(44100 * 0.4)
	var data = PackedByteArray()
	data.resize(length * 2)
	for i in range(length):
		var t = float(i) / 44100.0
		var env = exp(-t * 15.0) # Fast decay for punch
		var noise = randf_range(-1.0, 1.0)
		var bass = sin(t * 150.0 * TAU) * 0.5 * exp(-t * 30.0) # Low end thump
		var sample = (noise + bass) * env * 2.5 * 32767.0
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

func play_2d(stream: AudioStream, bus: String = "UI"):
	if not stream: return
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func play_3d(stream: AudioStream, pos: Vector3, bus: String = "SFX"):
	if not stream: return
	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = bus
	player.global_position = pos
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	
func play_ambient():
	if not ambient_wind: return
	var p = AudioStreamPlayer.new()
	p.stream = ambient_wind
	p.bus = "Ambient"
	p.volume_db = -10.0
	add_child(p)
	p.play()
	p.finished.connect(p.play) # loop
