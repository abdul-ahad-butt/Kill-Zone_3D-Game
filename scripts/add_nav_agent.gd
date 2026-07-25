extends SceneTree

func _init():
    var packed_scene = load("res://player.tscn")
    var scene_root = packed_scene.instantiate()
    
    var nav_agent = NavigationAgent3D.new()
    nav_agent.name = "NavigationAgent3D"
    nav_agent.avoidance_enabled = true
    scene_root.add_child(nav_agent)
    nav_agent.owner = scene_root
    
    var new_packed = PackedScene.new()
    new_packed.pack(scene_root)
    ResourceSaver.save(new_packed, "res://player.tscn")
    
    print("NavAgent added successfully.")
    quit()