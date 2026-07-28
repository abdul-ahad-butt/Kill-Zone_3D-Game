extends Resource
class_name WeaponData

@export var weapon_name: String = "Weapon"
@export var damage: float = 25.0
@export var fire_rate: float = 10.0 # rounds/sec
@export var magazine_size: int = 30
@export var reserve_ammo: int = 90
@export var reload_time: float = 2.0

@export_group("Recoil and Spread")
@export var recoil_pattern: Array[Vector2] = []
@export var spread_base: float = 2.0
@export var spread_moving: float = 5.0
@export var spread_ads: float = 0.5

@export_group("Range and Falloff")
@export var range: float = 100.0
@export var range_falloff_curve: Curve

@export_group("Visuals and Audio")
@export var muzzle_flash_scene: PackedScene
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var viewmodel_scene: PackedScene
@export var worldmodel_scene: PackedScene

@export_group("View Model Positions")
@export var ads_fov: float = 50.0
@export var ads_position: Vector3 = Vector3(0, -0.15, -0.4)
@export var default_position: Vector3 = Vector3(0.3, -0.3, -0.6)
