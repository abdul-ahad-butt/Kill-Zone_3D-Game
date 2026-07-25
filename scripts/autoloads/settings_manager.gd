extends Node

var config_path = "user://settings.cfg"
var config = ConfigFile.new()

var master_volume: float = 100.0 # 0 to 100
var is_muted: bool = false
var graphics_quality: int = 2 # 0: Low, 1: Medium, 2: High, 3: Ultra

signal settings_changed()

func _ready():
	load_settings()

func load_settings():
	var err = config.load(config_path)
	if err == OK:
		master_volume = config.get_value("Audio", "master_volume", 100.0)
		is_muted = config.get_value("Audio", "is_muted", false)
		graphics_quality = config.get_value("Graphics", "quality", 2)
	else:
		master_volume = 100.0
		is_muted = false
		graphics_quality = 2
		save_settings()
		
	apply_settings()

func save_settings():
	config.set_value("Audio", "master_volume", master_volume)
	config.set_value("Audio", "is_muted", is_muted)
	config.set_value("Graphics", "quality", graphics_quality)
	config.save(config_path)

func apply_settings():
	# Audio
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, is_muted)
	var db = linear_to_db(master_volume / 100.0)
	if master_volume <= 0.0: db = -80.0
	AudioServer.set_bus_volume_db(bus_idx, db)
	
	# Graphics
	var viewport = get_viewport()
	
	if graphics_quality == 0: # Low
		viewport.scaling_3d_scale = 0.7
		viewport.msaa_3d = Viewport.MSAA_DISABLED
	elif graphics_quality == 1: # Medium
		viewport.scaling_3d_scale = 0.85
		viewport.msaa_3d = Viewport.MSAA_2X
	elif graphics_quality == 2: # High
		viewport.scaling_3d_scale = 1.0
		viewport.msaa_3d = Viewport.MSAA_4X
	elif graphics_quality == 3: # Ultra
		viewport.scaling_3d_scale = 1.0
		viewport.msaa_3d = Viewport.MSAA_8X

	emit_signal("settings_changed")
