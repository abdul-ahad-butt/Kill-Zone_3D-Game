extends Node3D
class_name WeatherManager

enum WeatherType { SUNNY, CLOUDY, RAIN, FOG, NIGHT }

@export var world_environment: WorldEnvironment
@export var directional_light: DirectionalLight3D
@export var rain_particles: GPUParticles3D
@export var debug_weather: int = -1 # -1 for random

var current_weather: WeatherType = WeatherType.SUNNY
var target_sky_top: Color
var target_sky_horizon: Color
var target_ground_bottom: Color
var target_ground_horizon: Color
var target_light_color: Color
var target_light_energy: float = 1.0
var target_fog_density: float = 0.0
var target_fog_color: Color
var target_volumetric_fog_density: float = 0.0
var target_ssr_enabled: bool = false
var transition_speed: float = 0.5

var procedural_sky: ProceduralSkyMaterial
var environment: Environment

func _ready() -> void:
	if not world_environment or not world_environment.environment:
		push_warning("WeatherManager: No WorldEnvironment found!")
		return
		
	environment = world_environment.environment
	
	if environment.sky and environment.sky.sky_material is ProceduralSkyMaterial:
		procedural_sky = environment.sky.sky_material
	else:
		push_warning("WeatherManager: ProceduralSkyMaterial not found!")
	
	if debug_weather != -1 and debug_weather >= 0 and debug_weather < 5:
		if multiplayer.is_server(): set_weather(debug_weather as WeatherType)
	else:
		if multiplayer.is_server(): _randomize_weather()

func _randomize_weather() -> void:
	if not multiplayer.is_server(): return
	var roll = randf()
	if roll < 0.40:
		rpc("sync_weather", WeatherType.SUNNY)
	elif roll < 0.60:
		rpc("sync_weather", WeatherType.CLOUDY)
	elif roll < 0.75:
		rpc("sync_weather", WeatherType.RAIN)
	elif roll < 0.90:
		rpc("sync_weather", WeatherType.FOG)
	else:
		rpc("sync_weather", WeatherType.NIGHT)

@rpc("authority", "call_local", "reliable")
func sync_weather(type: int) -> void:
	set_weather(type as WeatherType)

func set_weather(type: WeatherType) -> void:
	current_weather = type
	
	# Default rain state
	if rain_particles:
		rain_particles.emitting = false
	
	match current_weather:
		WeatherType.SUNNY:
			target_sky_top = Color(0.3, 0.5, 0.7)
			target_sky_horizon = Color(0.65, 0.75, 0.85)
			target_ground_bottom = Color(0.15, 0.15, 0.15)
			target_ground_horizon = Color(0.65, 0.75, 0.85)
			target_light_color = Color(1.0, 0.95, 0.9)
			target_light_energy = 1.5
			target_fog_density = 0.001
			target_fog_color = Color(0.65, 0.75, 0.85)
			target_volumetric_fog_density = 0.0
			target_ssr_enabled = false
			
		WeatherType.CLOUDY:
			target_sky_top = Color(0.4, 0.45, 0.5)
			target_sky_horizon = Color(0.5, 0.55, 0.6)
			target_ground_bottom = Color(0.15, 0.15, 0.15)
			target_ground_horizon = Color(0.5, 0.55, 0.6)
			target_light_color = Color(0.9, 0.9, 0.95)
			target_light_energy = 0.8
			target_fog_density = 0.003
			target_fog_color = Color(0.5, 0.55, 0.6)
			target_volumetric_fog_density = 0.01
			target_ssr_enabled = false
			
		WeatherType.RAIN:
			target_sky_top = Color(0.2, 0.25, 0.3)
			target_sky_horizon = Color(0.35, 0.4, 0.45)
			target_ground_bottom = Color(0.1, 0.1, 0.1)
			target_ground_horizon = Color(0.35, 0.4, 0.45)
			target_light_color = Color(0.7, 0.75, 0.8)
			target_light_energy = 0.5
			target_fog_density = 0.005
			target_fog_color = Color(0.35, 0.4, 0.45)
			target_volumetric_fog_density = 0.02
			target_ssr_enabled = true
			if rain_particles:
				rain_particles.emitting = true
				
		WeatherType.FOG:
			target_sky_top = Color(0.5, 0.5, 0.55)
			target_sky_horizon = Color(0.6, 0.6, 0.65)
			target_ground_bottom = Color(0.2, 0.2, 0.2)
			target_ground_horizon = Color(0.6, 0.6, 0.65)
			target_light_color = Color(0.8, 0.8, 0.85)
			target_light_energy = 0.6
			target_fog_density = 0.04
			target_fog_color = Color(0.6, 0.6, 0.65)
			target_volumetric_fog_density = 0.05
			target_ssr_enabled = false
			
		WeatherType.NIGHT:
			target_sky_top = Color(0.01, 0.02, 0.05)
			target_sky_horizon = Color(0.05, 0.08, 0.12)
			target_ground_bottom = Color(0.01, 0.01, 0.01)
			target_ground_horizon = Color(0.05, 0.08, 0.12)
			target_light_color = Color(0.3, 0.4, 0.6)
			target_light_energy = 0.1
			target_fog_density = 0.002
			target_fog_color = Color(0.05, 0.08, 0.12)
			target_volumetric_fog_density = 0.005
			target_ssr_enabled = false
	
	# Apply immediately for first frame
	_apply_weather(1.0)
	
	# Setting SSR takes effect right away since it's a bool
	if environment:
		environment.ssr_enabled = target_ssr_enabled

func _process(delta: float) -> void:
	if procedural_sky and environment:
		_apply_weather(delta * transition_speed)

func _apply_weather(weight: float) -> void:
	if procedural_sky:
		procedural_sky.sky_top_color = procedural_sky.sky_top_color.lerp(target_sky_top, weight)
		procedural_sky.sky_horizon_color = procedural_sky.sky_horizon_color.lerp(target_sky_horizon, weight)
		procedural_sky.ground_bottom_color = procedural_sky.ground_bottom_color.lerp(target_ground_bottom, weight)
		procedural_sky.ground_horizon_color = procedural_sky.ground_horizon_color.lerp(target_ground_horizon, weight)
		
	if environment:
		environment.fog_density = lerpf(environment.fog_density, target_fog_density, weight)
		environment.fog_light_color = environment.fog_light_color.lerp(target_fog_color, weight)
		environment.volumetric_fog_density = lerpf(environment.volumetric_fog_density, target_volumetric_fog_density, weight)
		environment.volumetric_fog_albedo = environment.volumetric_fog_albedo.lerp(target_fog_color, weight)
		
	if directional_light:
		directional_light.light_color = directional_light.light_color.lerp(target_light_color, weight)
		directional_light.light_energy = lerpf(directional_light.light_energy, target_light_energy, weight)
		
		# Rotate sun based on day/night
		if current_weather == WeatherType.NIGHT:
			directional_light.rotation_degrees.x = lerpf(directional_light.rotation_degrees.x, -120.0, weight)
		else:
			directional_light.rotation_degrees.x = lerpf(directional_light.rotation_degrees.x, -45.0, weight)
