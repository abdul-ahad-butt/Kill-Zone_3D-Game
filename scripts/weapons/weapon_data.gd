extends Resource
class_name WeaponData

@export var weapon_name: String = "Weapon"
@export var damage: int = 25
@export var fire_rate: float = 0.1 # Seconds between shots
@export var mag_size: int = 30
@export var reload_time: float = 2.0
@export var range: float = 100.0
@export var recoil_kick: float = 0.1
@export var ads_fov: float = 50.0
@export var ads_position: Vector3 = Vector3(0, -0.15, -0.4)
@export var default_position: Vector3 = Vector3(0.3, -0.3, -0.6)
@export var model_scene: PackedScene
