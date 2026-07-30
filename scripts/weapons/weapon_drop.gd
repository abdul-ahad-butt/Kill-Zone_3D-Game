extends RigidBody3D

var weapon_data: WeaponData

func _ready():
	add_to_group("weapon_drops")
	if weapon_data and weapon_data.model_scene:
		var model = weapon_data.model_scene.instantiate()
		add_child(model)
		model.process_mode = Node.PROCESS_MODE_DISABLED
	
	$PickupArea.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if multiplayer.is_server() and body.is_in_group("players"):
		if weapon_data:
			body.rpc("client_pickup_weapon", weapon_data.resource_path)
		queue_free()
