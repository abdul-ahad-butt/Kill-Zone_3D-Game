extends Area3D

var weapon_path: String = ""

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Give it a tiny rotation animation so it looks like a pickup
	var t = create_tween().set_loops()
	t.tween_property($MeshInstance3D, "rotation:y", TAU, 2.0).as_relative()
	
func _on_body_entered(body: Node3D):
	if not multiplayer.is_server(): return
	
	if body.is_in_group("Players") and body.health > 0:
		# Check if they only have a pistol
		if body.current_weapon and body.current_weapon.weapon_name == "Pistol":
			# They picked it up!
			var p_id = body.name.to_int()
			if PlayerStats.stats.has(p_id):
				PlayerStats.stats[p_id]["weapon_path"] = weapon_path
				PlayerStats.sync_all_stats()
				
			# Equip immediately
			if ResourceLoader.exists(weapon_path):
				body.primary_weapon = load(weapon_path)
				body.equip_weapon(body.primary_weapon)
				
			queue_free()
