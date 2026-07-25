extends SceneTree

func _init():
    var packed_scene = load("res://player.tscn")
    var scene_root = packed_scene.instantiate()
    
    var footstep_audio = AudioStreamPlayer3D.new()
    footstep_audio.name = "FootstepAudio"
    footstep_audio.stream = load("res://resources/audio/footstep.tres")
    footstep_audio.max_distance = 25.0
    footstep_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
    scene_root.add_child(footstep_audio)
    footstep_audio.owner = scene_root
    
    var new_packed = PackedScene.new()
    new_packed.pack(scene_root)
    ResourceSaver.save(new_packed, "res://player.tscn")
    
    print("FootstepAudio added successfully.")
    quit()