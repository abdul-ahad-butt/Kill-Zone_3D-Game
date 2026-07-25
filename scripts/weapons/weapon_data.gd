extends Resource
class_name WeaponData

@export var weapon_name: String = "Weapon"
@export var damage: int = 25
@export var fire_rate: float = 0.1 # Seconds between shots
@export var mag_size: int = 30
@export var reload_time: float = 2.0
@export var range: float = 100.0
@export var spread: float = 0.0
@export var recoil_pattern: Array[Vector2] = []
@export var pellet_count: int = 1
@export var model_scene: PackedScene
